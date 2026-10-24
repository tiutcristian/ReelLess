import Foundation
import os
import ReelLessCore

struct ViewerItem: Identifiable {
    let url: URL
    var id: URL { url }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var viewerItem: ViewerItem?
    @Published var showSettings = false
    @Published var isLoading = true
    @Published private(set) var blocked: [String] = []

    let pack: RulePack
    let policy: RoutePolicy
    var reloadInbox: (() -> Void)?
    private let logger = Logger(subsystem: "ro.tiut.reelless", category: "route")

    init() {
        // The bundled pack ships with the app; failing to load it is a build error, not a runtime state.
        pack = try! RulePack.bundled()
        policy = try! RoutePolicy(pack: pack)
    }

    /// URLs only, never message text.
    func record(_ decision: RouteDecision, for url: URL) {
        logger.info("\(String(describing: decision), privacy: .public) \(url.absoluteString, privacy: .private)")
        if decision == .redirectToInbox {
            blocked = Array(([url.absoluteString] + blocked).prefix(500))
        }
    }
}
