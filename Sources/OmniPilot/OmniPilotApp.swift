import SwiftUI
import OmniPilotKit

@main
struct OmniPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = TunnelManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(manager: manager)
        } label: {
            MenuBarLabel(manager: manager)
        }
        .menuBarExtraStyle(.window)

        Window("OmniPilot 设置", id: AppUIState.settingsWindowID) {
            SettingsRootView(manager: manager)
        }
        .windowResizability(.contentSize)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var manager: TunnelManager

    var body: some View {
        if manager.hasFailures {
            if let icon = MenuBarIcon.errorImage {
                Image(nsImage: icon)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
            }
        } else if let icon = MenuBarIcon.image {
            Image(nsImage: icon)
        } else {
            Image(systemName: "arrow.left.arrow.right.circle")
        }
    }
}
