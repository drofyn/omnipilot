import AppKit
import OmniPilotKit
import SwiftUI

struct ClipboardSectionView: View {
    @ObservedObject var history: ClipboardHistory
    @Binding var historyLimit: Int

    @State private var confirmingClear = false

    var body: some View {
        historyContent
        .padding(10)
        .frame(height: 378)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if confirmingClear {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("确定清空全部历史？")
                        .font(.callout)
                    Spacer()
                    Button("取消") { confirmingClear = false }
                        .buttonStyle(.borderless)
                    Button("清空", role: .destructive) {
                        history.clear()
                        confirmingClear = false
                    }
                    .buttonStyle(.borderless)
                } else {
                    Text("剪贴板历史")
                        .font(.callout)
                        .bold()
                    Text("\(history.items.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ClipboardLimitPicker(selection: $historyLimit)
                    Button("清空") { confirmingClear = true }
                        .buttonStyle(.borderless)
                        .disabled(history.items.isEmpty && history.persistenceError == nil)
                }
            }
            .padding(.bottom, 8)

            Divider()

            if let persistenceError = history.persistenceError {
                Text("历史保存失败：\(persistenceError)")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.vertical, 4)
            }

            if history.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("暂无历史")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("复制的文本会显示在这里。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(history.items) { item in
                            ClipboardHistoryRow(
                                item: item,
                                onSelect: { writeToPasteboard(item.text) },
                                onDelete: { history.remove(item.id) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func writeToPasteboard(_ text: String) {
        PasteboardMonitor.shared.writeToPasteboard(text)
    }
}

private struct ClipboardLimitPicker: View {
    @Binding var selection: Int

    @State private var isPresented = false
    @State private var isHoveringAnchor = false
    @State private var isHoveringPopover = false
    @State private var dismissalTask: Task<Void, Never>?

    var body: some View {
        Button(action: presentPopover) {
            HStack(spacing: 5) {
                Image(systemName: "list.number")
                Text("保留 \(selection) 条")
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isHoveringAnchor ? Color.secondary.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("设置剪贴板历史条数")
        .onHover(perform: updateAnchorHover)
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            options
                .padding(10)
                .frame(width: 150)
                .onHover(perform: updatePopoverHover)
        }
        .onChange(of: isPresented) { presented in
            if !presented {
                dismissalTask?.cancel()
                isHoveringPopover = false
            }
        }
        .onDisappear { dismissalTask?.cancel() }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("历史条数")
                .font(.callout)
                .bold()
                .padding(.bottom, 3)

            ForEach(ClipboardHistory.allowedLimits, id: \.self) { limit in
                Button {
                    selection = limit
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selection == limit ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selection == limit ? Color.accentColor : Color.secondary)
                        Text("\(limit) 条")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
    }

    private func presentPopover() {
        dismissalTask?.cancel()
        isPresented = true
    }

    private func updateAnchorHover(_ hovering: Bool) {
        isHoveringAnchor = hovering
        if hovering {
            presentPopover()
        } else {
            scheduleDismissal()
        }
    }

    private func updatePopoverHover(_ hovering: Bool) {
        isHoveringPopover = hovering
        if hovering {
            dismissalTask?.cancel()
        } else {
            scheduleDismissal()
        }
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()
        dismissalTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, !isHoveringAnchor, !isHoveringPopover else { return }
            isPresented = false
        }
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardItem
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.preview)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("删除这条记录")
            .opacity(hovering ? 1 : 0)
            .disabled(!hovering)
            .accessibilityHidden(!hovering)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(hovering ? Color.secondary.opacity(0.08) : .clear)
        .onHover { hovering = $0 }
    }
}
