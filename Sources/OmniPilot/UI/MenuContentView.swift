import SwiftUI
import AppKit
import OmniPilotKit

struct MenuContentView: View {
    @ObservedObject var manager: TunnelManager
    @ObservedObject private var ui = AppUIState.shared
    @Environment(\.openWindow) private var openWindow

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tunnelSection
            Divider()
            launchSection
            Divider()
            footer
        }
        .frame(width: 390)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: AppIcon.image)
                .resizable()
                .interpolation(.high)
                .frame(width: 26, height: 26)
            Text("OmniPilot").font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusText: String {
        if manager.tunnels.isEmpty {
            return manager.isScanning ? "扫描中…" : "未发现带转发的 Host"
        }
        return "运行中 \(manager.runningCount)/\(manager.tunnels.count)"
    }

    @ViewBuilder
    private var tunnelSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            content

            if !manager.tunnels.isEmpty {
                Divider()
                forwardList
            }

            HStack(spacing: 8) {
                Button("全部启动") { manager.startAll() }
                Button("全部停止") { manager.stopAll() }
                Spacer()
                Button("重载") { manager.reload() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(manager.tunnels.isEmpty)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var forwardList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("SSH 端口转发管理")
                    .font(.caption)
                    .bold()
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.green)
                if manager.isScanning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }
            ForEach(manager.tunnels) { tunnel in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(tunnel.host.alias)
                            .font(.caption)
                            .bold()
                        Text(tunnel.host.remoteDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tunnel.host.forwards) { forward in
                        Text("\(forward.kind.shortLabel)  \(forward.display)")
                            .font(.caption2)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if manager.tunnels.isEmpty {
            VStack(spacing: 6) {
                Text(manager.isScanning
                     ? "正在读取 ssh config…"
                     : "没有找到带 LocalForward / RemoteForward 的 Host")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !manager.isScanning {
                    Text(manager.configPathDisplay)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(manager.tunnels) { tunnel in
                        TunnelRow(tunnel: tunnel)
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuCheckItemButton(
                title: "开机时自动启动",
                systemImage: "arrow.up.forward.app",
                isOn: launchAtLogin
            ) {
                applyLoginItem(!launchAtLogin)
            }
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuItemButton(title: "设置", systemImage: "gearshape") {
                openSettings(tab: .general)
            }
            MenuItemButton(title: "关于", systemImage: "info.circle") {
                openSettings(tab: .about)
            }
            MenuItemButton(title: "退出", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private func applyLoginItem(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
            loginItemError = nil
            launchAtLogin = LoginItem.isEnabled
        } catch {
            loginItemError = "设置失败：\(error.localizedDescription)"
            launchAtLogin = LoginItem.isEnabled
        }
    }

    private func openSettings(tab: SettingsTab) {
        ui.settingsTab = tab
        openWindow(id: AppUIState.settingsWindowID)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// A borderless button styled like a native menu item.
struct MenuItemButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).frame(width: 16)
                Text(title)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(hovering ? Color.secondary.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A borderless toggle styled like a native menu item with a checkmark.
struct MenuCheckItemButton: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).frame(width: 16)
                Text(title)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(isOn ? 1 : 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(hovering ? Color.secondary.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
