import Foundation

/// Hot-patchable data describing what is reachable. Regexes and CSS only, never code.
public struct RulePack: Codable, Equatable, Sendable {
    public var version: Int
    public var allow: [String]
    public var quarantine: [String]
    public var hideCSS: [String]
    public var viewerCSS: [String]

    public static func bundled() throws -> RulePack {
        guard let url = Bundle.module.url(forResource: "rule-pack.default", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(RulePack.self, from: Data(contentsOf: url))
    }
}
