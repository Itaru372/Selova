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
    var onAddNow: (() -> Void)?

    @State private var selectedType: VideoType = .local
    @State private var urlString = ""
    @State private var title = ""
    @State private var duration: TimeInterval = 0
    @State private var thumbnailData: Data? = nil
    @State private var selectedFolder: FolderItem?

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showingFileImporter = false
    @State private var isFetchingTitle = false
    @State private var localImportMessage: String?

    @Query(sort: \FolderItem.createdAt) private var allFolders: [FolderItem]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("種類")) {
                    Picker("ソース", selection: $selectedType) {
                        sourcePickerLabel(title: "ローカル", type: .local)
                            .tag(VideoType.local)
                        sourcePickerLabel(title: "YouTube", type: .youtube)
                            .tag(VideoType.youtube)
                        sourcePickerLabel(title: "Vimeo", type: .vimeo)
                            .tag(VideoType.vimeo)
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("動画")) {
                    if selectedType == .local {
                        if urlString.isEmpty {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                                    Label("写真", systemImage: "photo.on.rectangle.angled")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button {
                                    showingFileImporter = true
                                } label: {
                                    Label("ファイル", systemImage: "doc.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            selectedLocalVideoRow
                        }
                        
                        if let localImportMessage {
                            Label(localImportMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
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
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(urlString.isEmpty || isFetchingTitle)
                        }
                    }

                    TextField("タイトル", text: $title)
                }

                Section(header: Text("保存先")) {
                    Picker("フォルダ", selection: $selectedFolder) {
                        Text("指定なし").tag(FolderItem?(nil))
                        ForEach(allFolders) { folder in
                            Text(folder.name).tag(FolderItem?(folder))
                        }
                    }
                }
            }
            .navigationTitle("動画を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addVideo()
                    }
                    .disabled(title.isEmpty || urlString.isEmpty)
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
                selectedPhotoItem = nil
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let fileURL = try result.get().first else { return }
                    Task {
                        await importLocalVideo(from: fileURL)
                    }
                } catch {
                    print("Failed to import local file: \(error)")
                }
            }
        }
    }
    
    @ViewBuilder
    private func sourcePickerLabel(title: String, type: VideoType) -> some View {
        HStack(spacing: 8) {
            sourceIcon(for: type)
                .frame(width: 24, height: 24)
            
            Text(title)
        }
    }

    @ViewBuilder
    private func sourceIcon(for type: VideoType) -> some View {
        switch type {
        case .local:
            Image(systemName: "folder.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
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
    
    private var selectedLocalVideoRow: some View {
        HStack(spacing: 12) {
            thumbnailPreview
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title.isEmpty ? "選択済みの動画" : title)
                    .font(.body)
                    .lineLimit(1)
                Text(formattedLocalVideoDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                clearLocalVideo()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
    }
    
    private var thumbnailPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
            
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
    }

    private func fetchTitle() async {
        guard URL(string: urlString) != nil else { return }
        isFetchingTitle = true
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
                URLQueryItem(name: "url", value: urlString),
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
        let video = VideoItem(title: title, urlString: urlString, type: selectedType, duration: duration)
        video.folder = selectedFolder
        video.thumbnailData = thumbnailData

        modelContext.insert(video)
        try? modelContext.save()

        if let onAddNow = onAddNow {
            activeVideo = video
            onAddNow()
            dismiss()
        } else {
            dismiss()
        }
    }
}
