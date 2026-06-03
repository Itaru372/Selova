import SwiftUI
import SwiftData

struct LibraryView: View {
    @Binding var activeVideo: VideoItem?
    
    // We only want root folders here
    @Query(filter: #Predicate<FolderItem> { $0.parent == nil }, sort: \FolderItem.createdAt)
    private var rootFolders: [FolderItem]
    
    @Query(filter: #Predicate<VideoItem> { $0.folder == nil }, sort: \VideoItem.createdAt)
    private var rootVideos: [VideoItem]
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("フォルダ")) {
                    ForEach(rootFolders) { folder in
                        NavigationLink(destination: FolderDetailView(folder: folder, activeVideo: $activeVideo)) {
                            Label(folder.name, systemImage: "folder.fill")
                                .foregroundColor(TikTokTheme.cyan)
                        }
                        .listRowBackground(TikTokTheme.elevatedBackground)
                    }
                    .onDelete(perform: deleteFolders)
                }
                
                Section(header: Text("動画")) {
                    ForEach(rootVideos) { video in
                        Button {
                            activeVideo = video
                        } label: {
                            Label(video.title, systemImage: "play.rectangle")
                        }
                        .foregroundColor(TikTokTheme.primaryText)
                        .listRowBackground(TikTokTheme.elevatedBackground)
                    }
                    .onDelete(perform: deleteVideos)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(TikTokTheme.background)
            .navigationTitle("ライブラリ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TikTokTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("フォルダを追加")
                }
            }
            .tint(TikTokTheme.cyan)
            .alert("新規フォルダ", isPresented: $showingAddFolder) {
                TextField("フォルダ名", text: $newFolderName)
                Button("キャンセル", role: .cancel) {
                    newFolderName = ""
                }
                Button("作成") {
                    createFolder()
                }
            }
        }
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        let folder = FolderItem(name: newFolderName)
        modelContext.insert(folder)
        try? modelContext.save()
        newFolderName = ""
    }
    
    private func deleteFolders(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rootFolders[index])
        }
        try? modelContext.save()
    }
    
    private func deleteVideos(offsets: IndexSet) {
        for index in offsets {
            deleteVideo(rootVideos[index])
        }
        try? modelContext.save()
    }

    private func deleteVideo(_ video: VideoItem) {
        if activeVideo?.id == video.id {
            activeVideo = nil
        }
        modelContext.delete(video)
    }
}

struct FolderDetailView: View {
    var folder: FolderItem
    @Binding var activeVideo: VideoItem?
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        List {
            if let children = folder.children, !children.isEmpty {
                Section(header: Text("サブフォルダ")) {
                    ForEach(children) { child in
                        NavigationLink(destination: FolderDetailView(folder: child, activeVideo: $activeVideo)) {
                            Label(child.name, systemImage: "folder.fill")
                                .foregroundColor(TikTokTheme.cyan)
                        }
                        .listRowBackground(TikTokTheme.elevatedBackground)
                    }
                    .onDelete(perform: deleteSubfolders)
                }
            }
            
            if let videos = folder.videos, !videos.isEmpty {
                Section(header: Text("動画")) {
                    ForEach(videos) { video in
                        Button {
                            activeVideo = video
                        } label: {
                            Label(video.title, systemImage: "play.rectangle")
                        }
                        .foregroundColor(TikTokTheme.primaryText)
                        .listRowBackground(TikTokTheme.elevatedBackground)
                    }
                    .onDelete(perform: deleteVideos)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(TikTokTheme.background)
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TikTokTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("サブフォルダを追加")
            }
        }
        .tint(TikTokTheme.cyan)
        .alert("新規サブフォルダ", isPresented: $showingAddFolder) {
            TextField("フォルダ名", text: $newFolderName)
            Button("キャンセル", role: .cancel) {
                newFolderName = ""
            }
            Button("作成") {
                createSubfolder()
            }
        }
    }
    
    private func createSubfolder() {
        guard !newFolderName.isEmpty else { return }
        let subfolder = FolderItem(name: newFolderName, parent: folder)
        modelContext.insert(subfolder)
        try? modelContext.save()
        newFolderName = ""
    }
    
    private func deleteSubfolders(offsets: IndexSet) {
        guard let children = folder.children else { return }
        for index in offsets {
            modelContext.delete(children[index])
        }
        try? modelContext.save()
    }
    
    private func deleteVideos(offsets: IndexSet) {
        guard let videos = folder.videos else { return }
        for index in offsets {
            deleteVideo(videos[index])
        }
        try? modelContext.save()
    }

    private func deleteVideo(_ video: VideoItem) {
        if activeVideo?.id == video.id {
            activeVideo = nil
        }
        modelContext.delete(video)
    }
}
