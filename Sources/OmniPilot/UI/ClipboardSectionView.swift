import AppKit
import OmniPilotKit
import SwiftUI

struct ClipboardSectionView: View {
    @ObservedObject var history: ClipboardHistory
    @Binding var historyLimit: Int

    @State private var searchQuery = ""
    @State private var copiedItemID: UUID?
    @State private var editingNoteItemID: UUID?
    @State private var copyFeedbackTask: Task<Void, Never>?

    private var filteredItems: [ClipboardItem] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return history.items }
        return history.items.filter { item in
            item.text.localizedCaseInsensitiveContains(trimmed)
                || (item.note?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        historyContent
            .padding(10)
            .frame(height: 378)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            .onDisappear { copyFeedbackTask?.cancel() }
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("剪贴板历史")
                    .font(.callout)
                    .bold()
                Text("\(history.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ClipboardLimitPicker(selection: $historyLimit)
                ClipboardClearButton(
                    history: history,
                    onClearUnpinned: {
                        history.clearUnpinned()
                    },
                    onClearAll: {
                        editingNoteItemID = nil
                        history.clear()
                        searchQuery = ""
                    }
                )
            }
            .padding(.bottom, 8)

            if !history.items.isEmpty {
                searchBar
                    .padding(.bottom, 8)
            }

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
            } else if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("未找到匹配的剪贴板记录")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            ClipboardHistoryRow(
                                item: item,
                                isCopied: copiedItemID == item.id,
                                isEditingNote: editingNoteItemID == item.id,
                                onSelect: { selectItem(item) },
                                onStartEditingNote: { editingNoteItemID = item.id },
                                onSaveNote: { newNote in
                                    history.updateNote(item.id, note: newNote)
                                    if editingNoteItemID == item.id {
                                        editingNoteItemID = nil
                                    }
                                },
                                onCancelEditingNote: {
                                    if editingNoteItemID == item.id {
                                        editingNoteItemID = nil
                                    }
                                },
                                onTogglePin: { history.togglePin(item.id) },
                                onDelete: {
                                    if editingNoteItemID == item.id {
                                        editingNoteItemID = nil
                                    }
                                    history.remove(item.id)
                                }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("搜索剪贴板内容或备注…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.caption)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func selectItem(_ item: ClipboardItem) {
        PasteboardMonitor.shared.writeToPasteboard(item.text)
        copiedItemID = item.id
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            if copiedItemID == item.id {
                copiedItemID = nil
            }
        }
    }
}

private struct ClipboardLimitPicker: View {
    @Binding var selection: Int

    @State private var isPresented = false
    @State private var isHoveringAnchor = false
    @State private var customInput = ""

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
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
        .help("设置剪贴板历史条数（10–500）")
        .onHover { isHoveringAnchor = $0 }
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            options
                .padding(10)
                .frame(width: 185)
        }
        .onChange(of: isPresented) { presented in
            if presented {
                customInput = "\(selection)"
            }
        }
        .onChange(of: selection) { newValue in
            customInput = "\(newValue)"
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("历史条数")
                .font(.callout)
                .bold()
                .padding(.bottom, 2)

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
                .padding(.vertical, 3)
            }

            Divider()
                .padding(.vertical, 4)

            Text("自定义（\(ClipboardHistory.minimumLimit)–\(ClipboardHistory.maximumLimit)）")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("10–500", text: $customInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit(applyCustomLimit)

                Button("确定", action: applyCustomLimit)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }

    private func applyCustomLimit() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Int(trimmed) else {
            customInput = "\(selection)"
            return
        }
        let normalized = ClipboardHistory.normalizedLimit(raw)
        selection = normalized
        customInput = "\(normalized)"
        isPresented = false
    }
}

private struct ClipboardClearButton: View {
    @ObservedObject var history: ClipboardHistory
    let onClearUnpinned: () -> Void
    let onClearAll: () -> Void

    @State private var isPresented = false
    @State private var isHoveringAnchor = false

    private var isDisabled: Bool {
        history.items.isEmpty && history.persistenceError == nil
    }

    private var pinnedCount: Int {
        history.items.count - history.unpinnedCount
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                Text("清空")
            }
            .font(.caption)
            .foregroundStyle(isDisabled ? Color.secondary.opacity(0.5) : Color.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isHoveringAnchor && !isDisabled ? Color.secondary.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help("清空剪贴板历史")
        .onHover { isHoveringAnchor = $0 }
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            popoverContent
                .padding(12)
                .frame(width: 220)
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if history.hasPinnedItems {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.orange)
                    Text("清空剪贴板历史")
                        .font(.callout)
                        .bold()
                }

                Text("共 \(history.items.count) 条记录，含 \(pinnedCount) 条已置顶。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    if history.unpinnedCount > 0 {
                        Button {
                            onClearUnpinned()
                            isPresented = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("仅清空未置顶（\(history.unpinnedCount) 条）")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button(role: .destructive) {
                        onClearAll()
                        isPresented = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("全部清空（含置顶）")
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        isPresented = false
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("确定清空历史？")
                        .font(.callout)
                        .bold()
                }

                Text("将清空全部 \(history.items.count) 条剪贴板记录，此操作不可撤销。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        onClearAll()
                        isPresented = false
                    } label: {
                        Text("确认清空")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
        }
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let isEditingNote: Bool
    let onSelect: () -> Void
    let onStartEditingNote: () -> Void
    let onSaveNote: (String) -> Void
    let onCancelEditingNote: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false
    @State private var draftNote = ""
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Button(action: onSelect) {
                    firstLine
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isEditingNote {
                    inlineNoteEditor
                } else {
                    Button(action: onSelect) {
                        secondLine
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 2) {
                Button {
                    if isEditingNote {
                        onCancelEditingNote()
                    } else {
                        draftNote = item.note ?? ""
                        onStartEditingNote()
                    }
                } label: {
                    Image(systemName: item.note != nil ? "tag.fill" : "tag")
                        .font(.caption)
                        .foregroundStyle(item.note != nil ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(item.note != nil ? "修改备注" : "添加备注")
                .opacity(hovering || item.note != nil || isEditingNote ? 1 : 0)
                .disabled(!hovering && item.note == nil && !isEditingNote)

                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .font(.caption)
                        .foregroundStyle(item.isPinned ? Color.accentColor : Color.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(item.isPinned ? "取消置顶" : "置顶这条记录")
                .opacity(hovering || item.isPinned ? 1 : 0)
                .disabled(!hovering && !item.isPinned)

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
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(hovering ? Color.secondary.opacity(0.08) : .clear)
        .onHover { hovering = $0 }
        .onChange(of: isEditingNote) { editing in
            if editing {
                draftNote = item.note ?? ""
                noteFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var firstLine: some View {
        if let note = item.note, !note.isEmpty {
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text(note)
                        .font(.caption)
                        .bold()
                        .lineLimit(1)
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(item.preview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } else {
            Text(item.preview)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var secondLine: some View {
        HStack(spacing: 6) {
            if item.isPinned {
                Label("已置顶", systemImage: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
            Text(item.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if isCopied {
                Text("✓ 已复制")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }

    private var inlineNoteEditor: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
            TextField("输入备注，回车保存（清空即移除）…", text: $draftNote)
                .textFieldStyle(.plain)
                .font(.caption2)
                .focused($noteFieldFocused)
                .onSubmit {
                    onSaveNote(draftNote)
                }
            Button("保存") {
                onSaveNote(draftNote)
            }
            .buttonStyle(.borderless)
            .font(.caption2)
            .foregroundStyle(Color.accentColor)

            Button("取消") {
                onCancelEditingNote()
            }
            .buttonStyle(.borderless)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
        )
    }
}
