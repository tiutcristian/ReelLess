import SwiftUI
import WebKit
import ReelLessCore

/// One shared reel/post/story. Nothing in here can lead to another item.
struct ViewerSheet: View {
    let url: URL
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ViewerWebView(url: url, pack: model.pack)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
        }
        .interactiveDismissDisabled(false)
    }
}

struct ViewerWebView: UIViewRepresentable {
    let url: URL
    let pack: RulePack

    func makeCoordinator() -> Coordinator { Coordinator(item: url) }

    func makeUIView(context: Context) -> WKWebView {
        let config = Browser.configuration()
        config.userContentController.addUserScript(
            WKUserScript(source: Shield.viewerScript(pack: pack), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = false
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        #if DEBUG
        web.isInspectable = true
        #endif
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let item: URL
        init(item: URL) { self.item = item }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = action.request.url, action.targetFrame?.isMainFrame ?? true else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(RoutePolicy.allowsInViewer(target, item: item) ? .allow : .cancel)
        }
    }
}
