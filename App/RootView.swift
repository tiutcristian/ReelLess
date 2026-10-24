import SwiftUI
import WebKit

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            WebContainer()
            if model.isLoading {
                Color(.systemBackground).ignoresSafeArea()
                ProgressView()
            }
        }
        .sheet(item: $model.viewerItem) { item in
            ViewerSheet(url: item.url).environmentObject(model)
        }
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
    }
}

enum Browser {
    /// Real Mobile Safari UA (OS version comes from the system), so Instagram serves its normal web client.
    static func configuration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        return config
    }
}
