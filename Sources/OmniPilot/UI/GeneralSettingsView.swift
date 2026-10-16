import SwiftUI
import OmniPilotKit

struct GeneralSettingsView: View {
    @ObservedObject var manager: TunnelManager

    var body: some View {
        Form {
            Section("日志文件") {
                LabeledContent("位置") {
                    Text(manager.logFileURL.path)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }
}
