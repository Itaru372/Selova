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
                Section(header: Text("Folders")) {
                    ForEach(rootFolders) { folder in
                        NavigationLink(destination: FolderDetailView(folder: folder, activeVideo: $activeVideo)) {
                            Label(folder.name, systemImage: "folder.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: deleteFolders)
                }
                
                Section(header: Text("Videos")) {
                    ForEach(rootVideos) { video in
                        Button {
                            activeVideo = video
                        } label: {
                            Label(video.title, systemImage: "play.rectangle")
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteVideos)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .alert("New Folder", isPresented: $showingAddFolder) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    createFolder()
                }
            }
        }
    }
    
    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        let folder = FolderItem(name: newFolderName)
        modelContext.insert(folder)
        newFolderName = ""
    }
    
    private func deleteFolders(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rootFolders[index])
        }
    }
    
    private func deleteVideos(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rootVideos[index])
        }
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
                Section(header: Text("Subfolders")) {
                    ForEach(children) { child in
                        NavigationLink(destination: FolderDetailView(folder: child, activeVideo: $activeVideo)) {
                            Label(child.name, systemImage: "folder.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: deleteSubfolders)
                }
            }
            
            if let videos = folder.videos, !videos.isEmpty {
                Section(header: Text("Videos")) {
                    ForEach(videos) { video in
                        Button {
                            activeVideo = video
                        } label: {
                            Label(video.title, systemImage: "play.rectangle")
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteVideos)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .alert("New Subfolder", isPresented: $showingAddFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createSubfolder()
            }
        }
    }
    
    private func createSubfolder() {
        guard !newFolderName.isEmpty else { return }
        let subfolder = FolderItem(name: newFolderName, parent: folder)
        modelContext.insert(subfolder)
        newFolderName = ""
    }
    
    private func deleteSubfolders(offsets: IndexSet) {
        guard let children = folder.children else { return }
        for index in offsets {
            modelContext.delete(children[index])
        }
    }
    
    private func deleteVideos(offsets: IndexSet) {
        guard let videos = folder.videos else { return }
        for index in offsets {
            modelContext.delete(videos[index])
        }
    }
}
