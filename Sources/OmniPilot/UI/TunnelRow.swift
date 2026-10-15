import SwiftUI
import AppKit
import OmniPilotKit

struct TunnelRow: View {
    @ObservedObject var tunnel: ManagedTunnel
    @ObservedObject var manager: TunnelManager
    @ObservedObject private var ui = AppUIState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(tunnel.host.alias)
                        .font(.system(.body, design: .monospaced))
                        .bold()
                    Text(tunnel.state.label)
                        .font(.caption2)
                        .foregroundStyle(statusColor)
                }
                Text(tunnel.host.remoteDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(tunnel.host.forwards) { forward in
                    Text("\(forward.kind.shortLabel)  \(forward.display)")
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
                if let error = tunnel.lastError,
                   tunnel.state == .retrying || tunnel.state == .failed {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            controls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .padding(.top, 5)
    }

    private var statusColor: Color {
        switch tunnel.state {
        case .running:
            return .green
        case .starting, .retrying, .stopping:
            return .orange
        case .failed:
            return .red
        case .stopped:
            return .secondary
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            if tunnel.state.isActive {
                Button("停止") { tunnel.stop() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("启动") { tunnel.start() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Menu {
                Button("重启") { tunnel.restart() }
                Button("复制命令") { copyCommand() }
                Divider()
                Button("查看日志") { openLogs() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
        }
    }

    private func copyCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(tunnel.command.display, forType: .string)
    }

    private func openLogs() {
        ui.settingsTab = .logs
        openWindow(id: AppUIState.settingsWindowID)
        NSApp.activate(ignoringOtherApps: true)
    }
}
