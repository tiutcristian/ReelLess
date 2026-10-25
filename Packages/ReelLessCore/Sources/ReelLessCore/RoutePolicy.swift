import Foundation

public enum RouteDecision: Equatable {
    case allow
    /// A single shared item: open it in the one-item viewer sheet.
    case quarantine(URL)
    /// Fail closed: unknown or feed-like route.
    case redirectToInbox
    case external(URL)
    case block
}

public struct RoutePolicy {
    public static let instagram = URL(string: "https://www.instagram.com")!

    /// Where Instagram is served from. Only tests point this anywhere else (a local fixture server).
    public let origin: URL
    public let inboxURL: URL
    private let hosts: Set<String>
    private let allow: [NSRegularExpression]
    private let quarantine: [NSRegularExpression]

    public init(pack: RulePack, origin: URL = RoutePolicy.instagram) throws {
        self.origin = origin
        inboxURL = origin.appendingPathComponent("direct/inbox/")
        let host = origin.host?.lowercased() ?? ""
        hosts = host == "www.instagram.com" ? ["instagram.com", "www.instagram.com"] : [host]
        allow = try pack.allow.map { try NSRegularExpression(pattern: $0) }
        quarantine = try pack.quarantine.map { try NSRegularExpression(pattern: $0) }
    }

    public func isOwnHost(_ host: String?) -> Bool {
        hosts.contains(host?.lowercased() ?? "")
    }

    public func decide(_ url: URL) -> RouteDecision {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "about" { return .allow }
        if scheme == "mailto" || scheme == "tel" { return .external(url) }
        guard scheme == "https" || scheme == "http" else { return .block }

        let host = url.host?.lowercased() ?? ""
        if host == "l.instagram.com" {
            let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "u" }?.value
                .flatMap(URL.init(string:))
            if let target, target.scheme?.lowercased() == "https", !isOwnHost(target.host) {
                return .external(target)
            }
            return .block
        }
        guard isOwnHost(host) else { return .external(url) }

        let path = url.path.isEmpty ? "/" : url.path
        if matches(allow, path) { return .allow }
        if matches(quarantine, path) { return .quarantine(canonicalItem(url)) }
        return .redirectToInbox
    }

    /// `/reels/{id}` is the swipeable reels feed; `/reel/{id}` is the single-item page.
    /// Also drops tracking query parameters such as `igsh`.
    public func canonicalItem(_ url: URL) -> URL {
        guard let (kind, id) = Self.shortcode(url.path) else {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.query = nil
            return parts?.url ?? url
        }
        let single = kind == "reels" ? "reel" : kind
        return origin.appendingPathComponent("\(single)/\(id)/")
    }

    /// The viewer may only show its own item; every other navigation is dropped.
    /// `/p/`, `/reel/`, `/reels/` and `/tv/` with the same shortcode are the same item.
    public func allowsInViewer(_ url: URL, item: URL) -> Bool {
        if url.scheme?.lowercased() == "about" { return true }
        guard isOwnHost(url.host) else { return false }
        if let a = Self.shortcode(url.path), let b = Self.shortcode(item.path) { return a.id == b.id }
        return Self.normalized(url.path) == Self.normalized(item.path)
    }

    private static let shortcodeRegex = try! NSRegularExpression(pattern: "^/(p|reel|reels|tv)/([A-Za-z0-9_-]+)/?$")

    private static func shortcode(_ path: String) -> (kind: String, id: String)? {
        guard let m = shortcodeRegex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
              let kind = Range(m.range(at: 1), in: path), let id = Range(m.range(at: 2), in: path) else { return nil }
        return (String(path[kind]), String(path[id]))
    }

    private static func normalized(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func matches(_ regexes: [NSRegularExpression], _ path: String) -> Bool {
        let range = NSRange(path.startIndex..., in: path)
        return regexes.contains { $0.firstMatch(in: path, range: range) != nil }
    }
}
