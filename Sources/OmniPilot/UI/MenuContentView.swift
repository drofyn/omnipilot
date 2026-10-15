import SwiftUI
import AppKit
import OmniPilotKit

struct MenuContentView: View {
    @ObservedObject var manager: TunnelManager
    @ObservedObject private var ui = AppUIState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
            Divider()
            bulkActions
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
            VStack(alignment: .leading, spacing: 1) {
                Text("OmniPilot").font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if manager.isScanning {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    manager.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新读取 ssh config")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        if manager.tunnels.isEmpty {
            return manager.isScanning ? "扫描中…" : "未发现带转发的 Host"
        }
        return "运行中 \(manager.runningCount)/\(manager.tunnels.count)"
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
                        TunnelRow(tunnel: tunnel, manager: manager)
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .frame(maxHeight: 380)
        }
    }

    private var bulkActions: some View {
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

    private var footer: some View {
        VStack(alignment: .leading, spacing: 1) {
            MenuItemButton(title: "打开 ssh config", systemImage: "doc.text") {
                NSWorkspace.shared.open(manager.configPath)
            }
            MenuItemButton(title: "设置…", systemImage: "gearshape") {
                openSettings(tab: .general)
            }
            MenuItemButton(title: "关于 OmniPilot", systemImage: "info.circle") {
                openSettings(tab: .about)
            }
            Divider().padding(.vertical, 4)
            MenuItemButton(title: "退出", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
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
