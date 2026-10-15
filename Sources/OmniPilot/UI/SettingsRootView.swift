import SwiftUI
import OmniPilotKit

struct SettingsRootView: View {
    @ObservedObject var manager: TunnelManager
    @ObservedObject private var ui = AppUIState.shared

    var body: some View {
        TabView(selection: $ui.settingsTab) {
            GeneralSettingsView(manager: manager)
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            LogsView(manager: manager)
                .tabItem { Label("日志", systemImage: "doc.text") }
                .tag(SettingsTab.logs)

            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 620, height: 440)
    }
}
