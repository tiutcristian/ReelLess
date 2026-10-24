import SwiftUI
import WebKit

/// Opened with a three-finger tap; nothing on the main screen invites tweaking.
struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            List {
                Section("Shield") {
                    LabeledContent("Rule pack", value: "v\(model.pack.version) (bundled)")
                    LabeledContent("Blocked routes logged", value: "\(model.blocked.count)")
                }
                if !model.blocked.isEmpty {
                    Section("Recently blocked (add a rule if one was wrong)") {
                        ForEach(model.blocked.prefix(50), id: \.self) { Text($0).font(.footnote) }
                    }
                }
                Section {
                    Button("Reload inbox") { model.reloadInbox?(); dismiss() }
                    Button("Log out", role: .destructive) { confirmLogout = true }
                }
            }
            .navigationTitle("ReelLess")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Clear the Instagram session on this device?", isPresented: $confirmLogout) {
                Button("Log out", role: .destructive) {
                    WKWebsiteDataStore.default().removeData(
                        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                        model.reloadInbox?()
                    }
                    dismiss()
                }
            }
        }
    }
}
