import SwiftUI
import OmniPilotKit

struct TunnelRow: View {
    @ObservedObject var tunnel: ManagedTunnel

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            statusDot
            VStack(alignment: .leading, spacing: 3) {
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
                    ForwardLineButton(forward: forward)
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
            Button("启动") { tunnel.start() }
                .disabled(tunnel.state.isActive)
            Button("停止") { tunnel.stop() }
                .disabled(!tunnel.state.isActive)
            Button("重载") { tunnel.restart() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct ForwardLineButton: View {
    let forward: PortForward

    @State private var hovering = false
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button(action: copyAddress) {
            HStack(spacing: 6) {
                Text("\(forward.kind.shortLabel)  \(forward.display)")
                    .font(.caption2)
                    .monospaced()
                    .foregroundStyle(hovering ? .primary : .secondary)

                if copied {
                    Text("已复制 \(forward.copyableAddress)")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else if hovering {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(hovering ? Color.secondary.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help("点击复制 \(forward.copyableAddress)")
        .onHover { hovering = $0 }
        .onDisappear { resetTask?.cancel() }
    }

    private func copyAddress() {
        PasteboardMonitor.shared.writeToPasteboard(forward.copyableAddress)
        copied = true
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}
