import SwiftUI
import AppKit
import OmniPilotKit

struct LogsView: View {
    @ObservedObject var manager: TunnelManager

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logList
        }
    }

    private var toolbar: some View {
        HStack {
            Text("共 \(manager.logs.count) 条")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("在访达中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([manager.logFileURL])
            }
            Button("清空") { manager.clearLogs() }
                .disabled(manager.logs.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(manager.logs) { line in
                        LogRow(line: line).id(line.id)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: manager.logs.count) { _ in
                guard let last = manager.logs.last else { return }
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct LogRow: View {
    let line: LogLine

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Self.formatter.string(from: line.date))
                .foregroundStyle(.secondary)
            Text(line.source)
                .foregroundStyle(.blue)
                .frame(width: 96, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(line.text)
                .foregroundStyle(line.isError ? Color.red : Color.primary)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
    }
}
