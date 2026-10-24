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
    public static let inboxURL = URL(string: "https://www.instagram.com/direct/inbox/")!
    static let hosts: Set<String> = ["instagram.com", "www.instagram.com"]

    private let allow: [NSRegularExpression]
    private let quarantine: [NSRegularExpression]

    public init(pack: RulePack) throws {
        allow = try pack.allow.map { try NSRegularExpression(pattern: $0) }
        quarantine = try pack.quarantine.map { try NSRegularExpression(pattern: $0) }
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
            if let target, target.scheme?.lowercased() == "https", !Self.hosts.contains(target.host?.lowercased() ?? "") {
                return .external(target)
            }
            return .block
        }
        guard Self.hosts.contains(host) else { return .external(url) }

        let path = url.path.isEmpty ? "/" : url.path
        if matches(allow, path) { return .allow }
        if matches(quarantine, path) { return .quarantine(url) }
        return .redirectToInbox
    }

    /// The viewer may only show its own item; every other navigation is dropped.
    public static func allowsInViewer(_ url: URL, item: URL) -> Bool {
        if url.scheme?.lowercased() == "about" { return true }
        guard hosts.contains(url.host?.lowercased() ?? "") else { return false }
        return normalized(url.path) == normalized(item.path)
    }

    private static func normalized(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private func matches(_ regexes: [NSRegularExpression], _ path: String) -> Bool {
        let range = NSRange(path.startIndex..., in: path)
        return regexes.contains { $0.firstMatch(in: path, range: range) != nil }
    }
}
