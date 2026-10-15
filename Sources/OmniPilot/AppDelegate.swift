import AppKit
import OmniPilotKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let singleInstance = SingleInstance()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard singleInstance.acquire() else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        Notifier.shared.bootstrap()

        let manager = TunnelManager.shared
        manager.onRepeatedFailure = { tunnel in
            Notifier.shared.post(
                title: "「\(tunnel.host.alias)」连接反复失败",
                body: tunnel.lastError ?? "隧道无法保持连接，请检查网络或 ssh 配置。"
            )
        }
        manager.reload()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        TunnelManager.shared.terminateAllImmediately()
    }
}
