import SwiftUI
import SwiftData

struct VideoNotesEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var video: VideoItem
    var currentTime: TimeInterval?
    var isInStudyMode: Bool
    var onJump: (TimeInterval) -> Void

    @State private var noteText = ""
    @State private var manualTimestampText = ""
    @State private var timestampError: String?

    private var sortedNotes: [VideoNote] {
        (video.notes ?? []).sorted {
            if $0.timestamp == $1.timestamp {
                return $0.createdAt > $1.createdAt
            }
            return $0.timestamp < $1.timestamp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            quickAddSection

            Divider()
                .overlay(TikTokTheme.border)

            notesList
        }
        .background(TikTokTheme.background)
        .tint(TikTokTheme.readableBlue)
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    insertCurrentTimestamp()
                } label: {
                    Label(currentTimestampLabel, systemImage: "clock.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(TikTokTheme.pink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(currentTime == nil)

                TextField("20:15 または 1:05:30", text: $manualTimestampText)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.subheadline.monospacedDigit())
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }

            HStack(spacing: 10) {
                TextField("短いメモ", text: $noteText)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(TikTokTheme.panelStrong, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                Button {
                    addManualTimestamp()
                } label: {
                    Text("メモを追加")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 92)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(TikTokTheme.readableBlue, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .disabled(manualTimestampText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let timestampError {
                Text(timestampError)
                    .font(.caption)
                    .foregroundStyle(TikTokTheme.pink)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(TikTokTheme.background)
    }

    private var notesList: some View {
        Group {
            if sortedNotes.isEmpty {
                ContentUnavailableView(
                    "メモはまだありません",
                    systemImage: "bookmark",
                    description: Text("復習したい場所だけ、軽く残せます")
                )
                .foregroundStyle(TikTokTheme.secondaryText)
            } else {
                List {
                    ForEach(sortedNotes) { note in
                        noteRow(note)
                    }
                    .onDelete(perform: deleteNotes)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func noteRow(_ note: VideoNote) -> some View {
        Button {
            onJump(note.timestamp)
            if !isInStudyMode {
                dismiss()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(VideoTimestampFormatter.string(from: note.timestamp))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(TikTokTheme.readableBlue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(TikTokTheme.readableBlue.opacity(0.12), in: Capsule())

                VStack(alignment: .leading, spacing: 4) {
                    Text(noteText(for: note))
                        .font(.subheadline.weight(note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .regular : .medium))
                        .foregroundStyle(TikTokTheme.primaryText)
                        .lineLimit(2)

                    Text("タップしてこの位置へ")
                        .font(.caption2)
                        .foregroundStyle(TikTokTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TikTokTheme.mutedText)
                    .padding(.top, 5)
            }
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .listRowBackground(TikTokTheme.elevatedBackground)
    }

    private var currentTimestampLabel: String {
        guard let currentTime else { return String(localized: "現在位置を挿入") }
        return String(
            localized: "\(VideoTimestampFormatter.string(from: currentTime)) を挿入",
            comment: "Button label for inserting current video timestamp."
        )
    }

    private func insertCurrentTimestamp() {
        guard let currentTime else { return }
        manualTimestampText = VideoTimestampFormatter.string(from: currentTime)
        timestampError = nil
    }

    private func addManualTimestamp() {
        guard let seconds = VideoTimestampFormatter.seconds(from: manualTimestampText) else {
            timestampError = String(localized: "タイムスタンプは 20:15 または 1:05:30 の形で入力してください")
            return
        }
        if video.duration > 0 && seconds > video.duration {
            timestampError = String(localized: "動画の長さを超えない位置を入力してください")
            return
        }

        addNote(timestamp: seconds)
    }

    private func addNote(timestamp: TimeInterval) {
        timestampError = nil
        let note = VideoNote(
            timestamp: max(0, timestamp),
            text: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
            video: video
        )
        modelContext.insert(note)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(note)
            timestampError = String(localized: "メモを保存できませんでした。もう一度試してください")
            print("Failed to save video note: \(error)")
            return
        }
        manualTimestampText = ""
        noteText = ""
    }

    private func deleteNotes(offsets: IndexSet) {
        let notes = sortedNotes
        for index in offsets {
            modelContext.delete(notes[index])
        }
        do {
            try modelContext.save()
            timestampError = nil
        } catch {
            timestampError = String(localized: "メモを削除できませんでした。もう一度試してください")
            print("Failed to delete video note: \(error)")
        }
    }

    private func noteText(for note: VideoNote) -> String {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "メモなし") : trimmed
    }
}

struct VideoNotesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var video: VideoItem
    var currentTime: TimeInterval?
    var isInStudyMode: Bool
    var onJump: (TimeInterval) -> Void

    var body: some View {
        NavigationStack {
            VideoNotesEditor(
                video: video,
                currentTime: currentTime,
                isInStudyMode: isInStudyMode,
                onJump: onJump
            )
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .tint(TikTokTheme.readableBlue)
    }
}
