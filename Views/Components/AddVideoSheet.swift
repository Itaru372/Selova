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
    
    @State private var selectedType: VideoType = .youtube
    @State private var urlString = ""
    @State private var title = ""
    @State private var thumbnailData: Data? = nil
    @State private var selectedFolder: FolderItem?
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isFetchingTitle = false
    
    @Query(sort: \FolderItem.createdAt) private var allFolders: [FolderItem]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Video Type")) {
                    Picker("Type", selection: $selectedType) {
                        Text("YouTube").tag(VideoType.youtube)
                        Text("Vimeo").tag(VideoType.vimeo)
                        Text("Local File").tag(VideoType.local)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Video Details")) {
                    if selectedType == .local {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Select from Photos")
                            }
                        }
                        if !urlString.isEmpty {
                            Text(urlString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            TextField(selectedType == .youtube ? "YouTube URL" : "Vimeo URL", text: $urlString)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                            
                            Button {
                                Task { await fetchTitle() }
                            } label: {
                                if isFetchingTitle {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Fetch Title")
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
                    
                    TextField("Title", text: $title)
                }
                
                Section(header: Text("Save to Folder")) {
                    Picker("Folder", selection: $selectedFolder) {
                        Text("No Folder").tag(FolderItem?(nil))
                        ForEach(allFolders) { folder in
                            Text(folder.name).tag(FolderItem?(folder))
                        }
                    }
                }
            }
            .navigationTitle("Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                            await MainActor.run {
                                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                let destinationURL = documentsDirectory.appendingPathComponent(file.url.lastPathComponent)
                                
                                do {
                                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                                        try FileManager.default.removeItem(at: destinationURL)
                                    }
                                    try FileManager.default.copyItem(at: file.url, to: destinationURL)
                                    urlString = destinationURL.lastPathComponent
                                    title = destinationURL.deletingPathExtension().lastPathComponent
                                    
                                    let asset = AVURLAsset(url: destinationURL)
                                    let generator = AVAssetImageGenerator(asset: asset)
                                    generator.appliesPreferredTrackTransform = true
                                    generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) { _, cgImage, _, _, _ in
                                        if let image = cgImage {
                                            let uiImage = UIImage(cgImage: image)
                                            DispatchQueue.main.async {
                                                self.thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
                                            }
                                        }
                                    }
                                } catch {
                                    print("Error copying file: \(error)")
                                }
                            }
                        }
                    } catch {
                        print("Failed to load video: \(error)")
                    }
                }
            }
            .onChange(of: selectedType) { oldValue, newValue in
                urlString = ""
                title = ""
                selectedPhotoItem = nil
            }
        }
    }
    
    private func fetchTitle() async {
        guard URL(string: urlString) != nil else { return }
        isFetchingTitle = true
        defer { isFetchingTitle = false }
        
        do {
            let oembedURLString: String
            if selectedType == .youtube {
                oembedURLString = "https://www.youtube.com/oembed?url=\(urlString)&format=json"
            } else if selectedType == .vimeo {
                oembedURLString = "https://vimeo.com/api/oembed.json?url=\(urlString)"
            } else {
                return
            }
            
            guard let oembedURL = URL(string: oembedURLString) else { return }
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
    
    private func addVideo() {
        let video = VideoItem(title: title, urlString: urlString, type: selectedType)
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
