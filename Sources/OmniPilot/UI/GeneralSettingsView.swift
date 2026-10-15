import SwiftUI
import OmniPilotKit

struct GeneralSettingsView: View {
    @ObservedObject var manager: TunnelManager

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
                Toggle("开机时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        applyLoginItem(newValue)
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("ssh 配置") {
                LabeledContent("配置文件") {
                    Text(manager.configPathDisplay)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LabeledContent("ssh 可执行文件") {
                    Text(manager.sshBinary)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                HStack {
                    Button("重新读取 ssh config") { manager.reload() }
                    if manager.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }
            }

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

    private func applyLoginItem(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemError = nil
        } catch {
            loginItemError = "设置失败：\(error.localizedDescription)"
            launchAtLogin = LoginItem.isEnabled
        }
    }
}
