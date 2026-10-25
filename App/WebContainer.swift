import SafariServices
import SwiftUI
import WebKit
import ReelLessCore

struct WebContainer: UIViewRepresentable {
    @EnvironmentObject var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = Browser.configuration()
        let script = WKUserScript(source: Shield.mainScript(pack: model.pack),
                                  injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(context.coordinator, name: Shield.bridgeName)

        let web = WKWebView(frame: .zero, configuration: config)
        web.allowsBackForwardNavigationGestures = true
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        #if DEBUG
        if #available(iOS 16.4, *) { web.isInspectable = true }
        #endif

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pulled(_:)), for: .valueChanged)
        web.scrollView.refreshControl = refresh

        let settingsTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.threeFingerTap))
        settingsTap.numberOfTouchesRequired = 3
        settingsTap.cancelsTouchesInView = false
        web.addGestureRecognizer(settingsTap)

        context.coordinator.attach(web)
        web.load(URLRequest(url: self.model.policy.inboxURL))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let model: AppModel
        private weak var web: WKWebView?
        private var urlObservation: NSKeyValueObservation?

        init(model: AppModel) { self.model = model }

        func attach(_ web: WKWebView) {
            self.web = web
            model.reloadInbox = { [weak web] in web?.load(URLRequest(url: self.model.policy.inboxURL)) }
            // Backstop for route changes that bypass both the JS guard and the navigation delegate.
            urlObservation = web.observe(\.url) { [weak self] web, _ in
                guard let self, let url = web.url else { return }
                if self.model.policy.decide(url) != .allow { self.handle(url) }
            }
        }

        @objc func pulled(_ sender: UIRefreshControl) {
            web?.reload()
            sender.endRefreshing()
        }

        @objc func threeFingerTap() { model.showSettings = true }

        /// `fromHistory` is true when the page changed its own route (pushState). It may already be
        /// rendering that route, e.g. a swipeable reel player over the chat, so it is reloaded at
        /// its current, still allowed URL to tear that down.
        private func handle(_ url: URL, fromHistory: Bool = false) {
            let decision = model.policy.decide(url)
            model.record(decision, for: url)
            switch decision {
            case .allow, .block:
                break
            case .quarantine(let item):
                model.viewerItem = ViewerItem(url: item)
                if fromHistory { web?.reload() }
            case .redirectToInbox:
                web?.load(URLRequest(url: self.model.policy.inboxURL))
            case .external(let target):
                UIApplication.shared.open(target)
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url, action.targetFrame?.isMainFrame ?? true else {
                decisionHandler(.allow)
                return
            }
            if model.policy.decide(url) == .allow {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                handle(url)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { model.isLoading = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { model.isLoading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { model.isLoading = false }

        // MARK: WKUIDelegate

        /// target=_blank and window.open: never open a new web view, just classify the URL.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = action.request.url { handle(url) }
            return nil
        }

        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(origin.host.hasSuffix("instagram.com") ? .grant : .deny)
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  model.policy.isOwnHost(message.frameInfo.securityOrigin.host),
                  let route = BridgeMessage.parseRoute(message.body) else { return }
            handle(route.url, fromHistory: route.fromHistory)
        }
    }
}
