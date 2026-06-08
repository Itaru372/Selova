import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation
import UIKit
import PhotosUI

struct MovieFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(received.file.lastPathComponent)
            if FileManager.default.fileExists(atPath: copy.path) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return MovieFile(url: copy)
        }
    }
}

struct AddVideoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Binding var activeVideo: VideoItem?
    var initialFolder: FolderItem? = nil
    var onAddNow: (() -> Void)? = nil

    @State private var selectedType: VideoType = .local
    @State private var urlString = ""
    @State private var title = ""
    @State private var duration: TimeInterval = 0
    @State private var thumbnailData: Data? = nil
    @State private var selectedFolder: FolderItem?

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingFileImporter = false
    @State private var isFetchingTitle = false
    @State private var isSubmitting = false
    @State private var localImportMessage: String?
    @State private var remoteImportMessage: String?
    @State private var pendingPlaybackVideo: VideoItem?
    @State private var showingPlaybackPrompt = false

    @Query(sort: \FolderItem.createdAt) private var allFolders: [FolderItem]
    @Query(sort: \VideoItem.createdAt) private var allVideos: [VideoItem]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("種類")) {
                    sourceSegmentedControl
                }
                .listRowBackground(TikTokTheme.elevatedBackground)

                Section(header: Text("動画")) {
                    if selectedType == .local {
                        if urlString.isEmpty {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                                    uploadButtonLabel(title: "写真", systemImage: "photo.on.rectangle.angled", isProminent: false)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    showingFileImporter = true
                                } label: {
                                    uploadButtonLabel(title: "ファイル", systemImage: "doc.fill", isProminent: false)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            selectedLocalVideoRow
                        }
                        
                        if let localImportMessage {
                            Label(localImportMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(TikTokTheme.pink)
                        }
                    } else {
                        HStack {
                            TextField(selectedType == .youtube ? "YouTube URL" : "Vimeo URL", text: $urlString)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            
                            if !urlString.isEmpty {
                                Button {
                                    clearRemoteVideo()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button {
                                Task { await fetchTitle() }
                            } label: {
                                if isFetchingTitle {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("取得")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(TikTokTheme.pink)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(urlString.isEmpty || isFetchingTitle)
                        }

                        if let remoteImportMessage {
                            Label(remoteImportMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(TikTokTheme.pink)
                        }
                    }

                    TextField("タイトル", text: $title)

                    if titleIsDuplicate {
                        Label("同じ名前の動画がすでにあります", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(TikTokTheme.pink)
                    }
                }
                .listRowBackground(TikTokTheme.elevatedBackground)

                Section(header: Text("保存先")) {
                    Picker("フォルダ", selection: $selectedFolder) {
                        Text("指定なし").tag(FolderItem?(nil))
                        ForEach(allFolders) { folder in
                            Text(folderDisplayName(for: folder))
                                .tag(FolderItem?(folder))
                        }
                    }
                }
                .listRowBackground(TikTokTheme.elevatedBackground)
            }
            .scrollContentBackground(.hidden)
            .background(TimeBasedBackgroundView())
            .navigationTitle("動画を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(TikTokTheme.readableBlue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(TikTokTheme.readableBlue)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addVideo()
                    }
                    .disabled(!canAddVideo)
                }
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                guard let item = newValue else { return }

                Task {
                    do {
                        if let file = try await item.loadTransferable(type: MovieFile.self) {
                            await importLocalVideo(from: file.url)
                        }
                    } catch {
                        localImportMessage = "写真ライブラリから動画を読み込めませんでした"
                        print("Failed to load video: \(error)")
                    }
                }
            }
            .onChange(of: selectedType) { oldValue, newValue in
                urlString = ""
                title = ""
                duration = 0
                thumbnailData = nil
                localImportMessage = nil
                remoteImportMessage = nil
                selectedPhotoItem = nil
            }
            .onAppear {
                if selectedFolder == nil {
                    selectedFolder = initialFolder
                }
            }
            .fullScreenCover(isPresented: $showingFileImporter) {
                LocalVideoDocumentPicker { fileURL in
                    showingFileImporter = false
                    Task {
                        await importLocalVideo(from: fileURL)
                    }
                }
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "追加した動画を今すぐ再生しますか？",
                isPresented: $showingPlaybackPrompt,
                titleVisibility: .visible
            ) {
                Button("今すぐ再生") {
                    if let pendingPlaybackVideo {
                        startPlaybackAndDismiss(pendingPlaybackVideo)
                    }
                }
                Button("あとで見る") {
                    pendingPlaybackVideo = nil
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {
                    pendingPlaybackVideo = nil
                    dismiss()
                }
            } message: {
                Text("保存は完了しています。すぐ学習を始めることも、あとでライブラリから開くこともできます。")
            }
        }
    }

    private var sourceSegmentedControl: some View {
        Picker("ソース", selection: $selectedType) {
            Label("ローカル", systemImage: "folder.fill")
                .tag(VideoType.local)
            Label("YouTube", systemImage: "play.rectangle.fill")
                .tag(VideoType.youtube)
            Label("Vimeo", systemImage: "v.circle.fill")
                .tag(VideoType.vimeo)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(TikTokTheme.readableBlue)
    }

    @ViewBuilder
    private func uploadButtonLabel(title: String, systemImage: String, isProminent: Bool = true) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .symbolRenderingMode(.monochrome)
            Text(title)
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(isProminent ? .white : TikTokTheme.readableBlue)
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .frame(minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isProminent ? TikTokTheme.actionBlue : TikTokTheme.readableBlue.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TikTokTheme.readableBlue.opacity(isProminent ? 0 : 0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sourceIcon(for type: VideoType) -> some View {
        switch type {
        case .local:
            Image(systemName: "folder.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(TikTokTheme.readableBlue)
        case .youtube:
            Image("YouTubeLogo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipped()
        case .vimeo:
            Image("VimeoLogo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipped()
        }
    }

    private func folderDisplayName(for folder: FolderItem) -> String {
        guard folder.parent != nil else { return folder.name }
        return folderPath(for: folder)
    }

    private func folderPath(for folder: FolderItem) -> String {
        var names = [folder.name]
        var parent = folder.parent

        while let currentParent = parent {
            names.insert(currentParent.name, at: 0)
            parent = currentParent.parent
        }

        return names.joined(separator: " / ")
    }
    
    private var selectedLocalVideoRow: some View {
        HStack(spacing: 12) {
            thumbnailPreview
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? "選択済みの動画" : title)
                    .font(.body)
                    .foregroundStyle(TikTokTheme.primaryText)
                    .lineLimit(1)
                Text(formattedLocalVideoDetail)
                    .font(.caption)
                    .foregroundStyle(TikTokTheme.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                clearLocalVideo()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(TikTokTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var thumbnailPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(TikTokTheme.panelStrong)
            
            if let thumbnailData,
               let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 54, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var formattedLocalVideoDetail: String {
        guard duration > 0 else { return urlString }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    private func clearLocalVideo() {
        urlString = ""
        title = ""
        duration = 0
        thumbnailData = nil
        localImportMessage = nil
        selectedPhotoItem = nil
    }
    
    private func clearRemoteVideo() {
        urlString = ""
        title = ""
        thumbnailData = nil
        remoteImportMessage = nil
    }

    private var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titleIsDuplicate: Bool {
        guard !isSubmitting else { return false }
        guard !normalizedTitle.isEmpty else { return false }
        return allVideos.contains {
            $0.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(normalizedTitle) == .orderedSame
        }
    }

    private var canAddVideo: Bool {
        !normalizedTitle.isEmpty && !urlString.isEmpty && !titleIsDuplicate
    }

    private func fetchTitle() async {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            remoteImportMessage = "URLを入力してください"
            return
        }

        isFetchingTitle = true
        remoteImportMessage = nil
        defer { isFetchingTitle = false }

        do {
            var components: URLComponents
            if selectedType == .youtube {
                components = URLComponents(string: "https://www.youtube.com/oembed")!
            } else if selectedType == .vimeo {
                components = URLComponents(string: "https://vimeo.com/api/oembed.json")!
            } else {
                return
            }
            components.queryItems = [
                URLQueryItem(name: "url", value: trimmedURL),
                URLQueryItem(name: "format", value: "json")
            ]

            guard let oembedURL = components.url else { return }
            let (data, _) = try await URLSession.shared.data(from: oembedURL)

            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let fetchedTitle = json["title"] as? String {
                    await MainActor.run {
                        self.title = fetchedTitle
                    }
                }

                if let thumbnailUrlString = json["thumbnail_url"] as? String,
                   let thumbURL = URL(string: thumbnailUrlString) {
                    if let thumbData = try? await URLSession.shared.data(from: thumbURL).0 {
                        await MainActor.run {
                            self.thumbnailData = thumbData
                        }
                    }
                }
            }
        } catch {
            remoteImportMessage = "タイトルを取得できませんでした。URLを確認してください"
            print("Failed to fetch title: \(error)")
        }
    }

    private func importLocalVideo(from sourceURL: URL) async {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let safeBaseName = baseName.isEmpty ? "Local Video" : baseName
            let destinationName = "\(UUID().uuidString)-\(safeBaseName).\(fileExtension)"
            let destinationURL = documentsDirectory.appendingPathComponent(destinationName)

            try coordinatedCopyItem(at: sourceURL, to: destinationURL)
            let isPlayable = await localVideoIsPlayable(destinationURL)

            selectedType = .local
            urlString = destinationURL.lastPathComponent
            title = safeBaseName
            duration = await localVideoDuration(for: destinationURL)
            localImportMessage = isPlayable ? nil : "この動画形式はiOS標準プレイヤーで再生できない可能性があります"
            remoteImportMessage = nil
            thumbnailData = nil
            generateThumbnail(for: destinationURL)
        } catch {
            localImportMessage = "ローカル動画をコピーできませんでした"
            print("Error copying local video: \(error)")
        }
    }

    private func coordinatedCopyItem(at sourceURL: URL, to destinationURL: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?

        NSFileCoordinator().coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { readableURL in
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: readableURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }

        if let copyError {
            throw copyError
        }
        if let coordinationError {
            throw coordinationError
        }
    }

    private func localVideoIsPlayable(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        do {
            return try await asset.load(.isPlayable)
        } catch {
            return false
        }
    }

    private func localVideoDuration(for url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return seconds.isFinite ? seconds : 0
        } catch {
            return 0
        }
    }

    private func generateThumbnail(for url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { _, cgImage, _, _, _ in
            guard let cgImage else { return }
            let uiImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
            }
        }
    }

    private func addVideo() {
        guard canAddVideo else { return }
        isSubmitting = true
        let video = VideoItem(title: normalizedTitle, urlString: urlString, type: selectedType, duration: duration)
        video.folder = selectedFolder
        video.thumbnailData = thumbnailData

        modelContext.insert(video)
        try? modelContext.save()

        pendingPlaybackVideo = video
        showingPlaybackPrompt = true
    }

    private func startPlaybackAndDismiss(_ video: VideoItem) {
        pendingPlaybackVideo = nil
        onAddNow?()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            activeVideo = video
        }
    }
}

private struct LocalVideoDocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
