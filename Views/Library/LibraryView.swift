import SwiftUI
import SwiftData

struct LibraryView: View {
    @Binding var activeVideo: VideoItem?

    @Query(filter: #Predicate<FolderItem> { $0.parent == nil }, sort: \FolderItem.createdAt)
    private var rootFolders: [FolderItem]

    @Query(filter: #Predicate<VideoItem> { $0.folder == nil }, sort: \VideoItem.createdAt)
    private var rootVideos: [VideoItem]

    @Query(sort: \FolderItem.createdAt)
    private var allFolders: [FolderItem]

    @Query(sort: \VideoItem.createdAt)
    private var allVideos: [VideoItem]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    @State private var folderNameError: String?
    @State private var foldersPendingDeletion: [FolderItem] = []
    @State private var showingDeleteFolderConfirmation = false
    @State private var folderPendingEdit: FolderItem?
    @State private var editedFolderName = ""
    @State private var videoPendingMove: VideoItem?
    @State private var searchText = ""
    @State private var sortOption: LibrarySortOption = .createdNewest

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleFolders: [FolderItem] {
        let folders = isSearching ? allFolders.filter { matchesSearch($0.name) } : rootFolders
        return sortedFolders(folders)
    }

    private var visibleVideos: [VideoItem] {
        let videos = isSearching ? allVideos.filter { matchesSearch($0.title) } : rootVideos
        return sortedVideos(videos)
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching && visibleFolders.isEmpty && visibleVideos.isEmpty {
                    ContentUnavailableView("見つかりません", systemImage: "magnifyingglass", description: Text("別のキーワードで検索してください"))
                        .listRowBackground(Color.clear)
                }

                if !visibleFolders.isEmpty {
                    Section(header: Text(isSearching ? "フォルダ検索結果" : "フォルダ")) {
                        ForEach(visibleFolders) { folder in
                            folderRow(folder)
                        }
                        .onDelete(perform: requestFolderDeletion)
                    }
                }

                if !visibleVideos.isEmpty {
                    Section(header: Text(isSearching ? "動画検索結果" : "動画")) {
                        ForEach(visibleVideos) { video in
                            videoRow(video)
                        }
                        .onDelete(perform: deleteVideos)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(TikTokTheme.background)
            .navigationTitle("ライブラリ")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "動画・フォルダを検索")
            .toolbarBackground(TikTokTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    sortMenu
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        folderNameError = nil
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("フォルダを追加")
                }
            }
            .tint(TikTokTheme.readableBlue)
            .alert("新規フォルダ", isPresented: $showingAddFolder) {
                TextField("フォルダ名", text: $newFolderName)
                Button("キャンセル", role: .cancel) {
                    resetNewFolderForm()
                }
                Button("作成") {
                    createFolder()
                }
                .disabled(folderNameIsInvalid(newFolderName, parent: nil))
            } message: {
                Text(folderNameError ?? "ライブラリ直下にフォルダを作成します")
            }
            .alert("フォルダ名を編集", isPresented: editFolderBinding) {
                TextField("フォルダ名", text: $editedFolderName)
                Button("キャンセル", role: .cancel) {
                    resetEditFolderForm()
                }
                Button("保存") {
                    updateFolderName()
                }
                .disabled(editFolderNameIsInvalid)
            } message: {
                Text(folderNameError ?? "同じ場所に同じ名前のフォルダは作成できません")
            }
            .alert("フォルダを削除しますか？", isPresented: $showingDeleteFolderConfirmation) {
                Button("キャンセル", role: .cancel) {
                    foldersPendingDeletion = []
                }
                Button("削除", role: .destructive) {
                    deletePendingFolders()
                }
            } message: {
                Text(folderDeletionMessage)
            }
            .sheet(item: $videoPendingMove) { video in
                MoveVideoSheet(video: video)
                    .presentationDetents([.medium])
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("並び替え", selection: $sortOption) {
                ForEach(LibrarySortOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("並び替え")
    }

    private func folderRow(_ folder: FolderItem) -> some View {
        NavigationLink(destination: FolderDetailView(folder: folder, activeVideo: $activeVideo, sortOption: $sortOption)) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(folder.name)
                    if isSearching, let path = folder.parent?.name {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(TikTokTheme.secondaryText)
                    }
                }
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(TikTokTheme.readableBlue)
            }
        }
        .listRowBackground(TikTokTheme.elevatedBackground)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                beginEditing(folder)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(TikTokTheme.actionBlue)
        }
    }

    private func videoRow(_ video: VideoItem) -> some View {
        Button {
            activeVideo = video
        } label: {
            VideoLibraryRow(video: video, showsFolderPath: isSearching)
        }
        .foregroundColor(TikTokTheme.primaryText)
        .listRowBackground(TikTokTheme.elevatedBackground)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                videoPendingMove = video
            } label: {
                Label("移動", systemImage: "folder")
            }
            .tint(TikTokTheme.actionBlue)
        }
    }

    private func matchesSearch(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func createFolder() {
        let trimmedName = normalizedFolderName(newFolderName)
        guard !folderNameIsInvalid(trimmedName, parent: nil) else {
            folderNameError = duplicateFolderExists(named: trimmedName, parent: nil) ? "同じ名前のフォルダがすでにあります" : "フォルダ名を入力してください"
            return
        }

        let folder = FolderItem(name: trimmedName)
        modelContext.insert(folder)
        try? modelContext.save()
        resetNewFolderForm()
    }

    private func requestFolderDeletion(offsets: IndexSet) {
        foldersPendingDeletion = offsets.map { visibleFolders[$0] }
        showingDeleteFolderConfirmation = !foldersPendingDeletion.isEmpty
    }

    private func deletePendingFolders() {
        for folder in foldersPendingDeletion {
            if activeVideoBelongs(to: folder) {
                activeVideo = nil
            }
            modelContext.delete(folder)
        }
        try? modelContext.save()
        foldersPendingDeletion = []
    }

    private func deleteVideos(offsets: IndexSet) {
        for index in offsets {
            deleteVideo(visibleVideos[index])
        }
        try? modelContext.save()
    }

    private func deleteVideo(_ video: VideoItem) {
        if activeVideo?.id == video.id {
            activeVideo = nil
        }
        modelContext.delete(video)
    }

    private func beginEditing(_ folder: FolderItem) {
        folderNameError = nil
        folderPendingEdit = folder
        editedFolderName = folder.name
    }

    private func updateFolderName() {
        guard let folder = folderPendingEdit else { return }
        let trimmedName = normalizedFolderName(editedFolderName)
        guard !folderNameIsInvalid(trimmedName, parent: folder.parent, excluding: folder) else {
            folderNameError = duplicateFolderExists(named: trimmedName, parent: folder.parent, excluding: folder) ? "同じ名前のフォルダがすでにあります" : "フォルダ名を入力してください"
            return
        }

        folder.name = trimmedName
        try? modelContext.save()
        resetEditFolderForm()
    }

    private func resetNewFolderForm() {
        newFolderName = ""
        folderNameError = nil
    }

    private func resetEditFolderForm() {
        folderPendingEdit = nil
        editedFolderName = ""
        folderNameError = nil
    }

    private var editFolderBinding: Binding<Bool> {
        Binding(
            get: { folderPendingEdit != nil },
            set: { isPresented in
                if !isPresented {
                    resetEditFolderForm()
                }
            }
        )
    }

    private var editFolderNameIsInvalid: Bool {
        guard let folder = folderPendingEdit else { return true }
        return folderNameIsInvalid(editedFolderName, parent: folder.parent, excluding: folder)
    }

    private var folderDeletionMessage: String {
        guard let folder = foldersPendingDeletion.first else {
            return "選択したフォルダを削除します"
        }

        let folderCount = foldersPendingDeletion.reduce(0) { $0 + descendantFolderCount(for: $1) + 1 }
        let videoCount = foldersPendingDeletion.reduce(0) { $0 + recursiveVideoCount(for: $1) }

        if foldersPendingDeletion.count == 1 {
            return "「\(folder.name)」を削除します。含まれるサブフォルダ \(max(folderCount - 1, 0)) 件、動画 \(videoCount) 件も削除されます。"
        }
        return "選択した \(foldersPendingDeletion.count) 件のフォルダを削除します。含まれるサブフォルダ \(max(folderCount - foldersPendingDeletion.count, 0)) 件、動画 \(videoCount) 件も削除されます。"
    }

    private func sortedFolders(_ folders: [FolderItem]) -> [FolderItem] {
        folders.sorted { lhs, rhs in
            switch sortOption {
            case .title:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .createdOldest:
                return lhs.createdAt < rhs.createdAt
            default:
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func sortedVideos(_ videos: [VideoItem]) -> [VideoItem] {
        videos.sorted { lhs, rhs in
            switch sortOption {
            case .createdNewest:
                return lhs.createdAt > rhs.createdAt
            case .createdOldest:
                return lhs.createdAt < rhs.createdAt
            case .recentlyWatched:
                return (lhs.lastWatchedAt ?? .distantPast) > (rhs.lastWatchedAt ?? .distantPast)
            case .title:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .progress:
                return progress(for: lhs) > progress(for: rhs)
            }
        }
    }

    private func progress(for video: VideoItem) -> Double {
        guard video.duration > 0 else { return 0 }
        return min(max(lastPlaybackPosition(for: video) / video.duration, 0), 1)
    }

    private func folderNameIsInvalid(_ name: String, parent: FolderItem?, excluding excludedFolder: FolderItem? = nil) -> Bool {
        let trimmedName = normalizedFolderName(name)
        guard !trimmedName.isEmpty else { return true }
        return duplicateFolderExists(named: trimmedName, parent: parent, excluding: excludedFolder)
    }

    private func duplicateFolderExists(named name: String, parent: FolderItem?, excluding excludedFolder: FolderItem? = nil) -> Bool {
        allFolders.contains { folder in
            guard folder.id != excludedFolder?.id else { return false }
            guard foldersShareParent(folder, parent) else { return false }
            return folder.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func foldersShareParent(_ folder: FolderItem, _ parent: FolderItem?) -> Bool {
        switch (folder.parent?.id, parent?.id) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs == rhs
        default:
            return false
        }
    }

    private func activeVideoBelongs(to folder: FolderItem) -> Bool {
        guard let activeVideo else { return false }
        return folderContainsVideo(folder, videoID: activeVideo.id)
    }
}

struct FolderDetailView: View {
    var folder: FolderItem
    @Binding var activeVideo: VideoItem?
    @Binding var sortOption: LibrarySortOption

    @Query(sort: \FolderItem.createdAt)
    private var allFolders: [FolderItem]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    @State private var folderNameError: String?
    @State private var foldersPendingDeletion: [FolderItem] = []
    @State private var showingDeleteFolderConfirmation = false
    @State private var folderPendingEdit: FolderItem?
    @State private var editedFolderName = ""
    @State private var videoPendingMove: VideoItem?
    @State private var searchText = ""

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visibleSubfolders: [FolderItem] {
        let folders = folder.children ?? []
        return sortedFolders(isSearching ? folders.filter { matchesSearch($0.name) } : folders)
    }

    private var visibleVideos: [VideoItem] {
        let videos = folder.videos ?? []
        return sortedVideos(isSearching ? videos.filter { matchesSearch($0.title) } : videos)
    }

    var body: some View {
        List {
            if isSearching && visibleSubfolders.isEmpty && visibleVideos.isEmpty {
                ContentUnavailableView("見つかりません", systemImage: "magnifyingglass", description: Text("このフォルダ内に一致する項目はありません"))
                    .listRowBackground(Color.clear)
            }

            if !visibleSubfolders.isEmpty {
                Section(header: Text("サブフォルダ")) {
                    ForEach(visibleSubfolders) { child in
                        folderRow(child)
                    }
                    .onDelete(perform: requestFolderDeletion)
                }
            }

            if !visibleVideos.isEmpty {
                Section(header: Text("動画")) {
                    ForEach(visibleVideos) { video in
                        videoRow(video)
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
        .searchable(text: $searchText, prompt: "このフォルダ内を検索")
        .toolbarBackground(TikTokTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    folderNameError = nil
                    showingAddFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("サブフォルダを追加")
            }
        }
        .tint(TikTokTheme.readableBlue)
        .alert("新規サブフォルダ", isPresented: $showingAddFolder) {
            TextField("フォルダ名", text: $newFolderName)
            Button("キャンセル", role: .cancel) {
                resetNewFolderForm()
            }
            Button("作成") {
                createSubfolder()
            }
            .disabled(folderNameIsInvalid(newFolderName, parent: folder))
        } message: {
            Text(folderNameError ?? "「\(folder.name)」内にサブフォルダを作成します")
        }
        .alert("フォルダ名を編集", isPresented: editFolderBinding) {
            TextField("フォルダ名", text: $editedFolderName)
            Button("キャンセル", role: .cancel) {
                resetEditFolderForm()
            }
            Button("保存") {
                updateFolderName()
            }
            .disabled(editFolderNameIsInvalid)
        } message: {
            Text(folderNameError ?? "同じ場所に同じ名前のフォルダは作成できません")
        }
        .alert("フォルダを削除しますか？", isPresented: $showingDeleteFolderConfirmation) {
            Button("キャンセル", role: .cancel) {
                foldersPendingDeletion = []
            }
            Button("削除", role: .destructive) {
                deletePendingFolders()
            }
        } message: {
            Text(folderDeletionMessage)
        }
        .sheet(item: $videoPendingMove) { video in
            MoveVideoSheet(video: video)
                .presentationDetents([.medium])
        }
    }

    private func folderRow(_ child: FolderItem) -> some View {
        NavigationLink(destination: FolderDetailView(folder: child, activeVideo: $activeVideo, sortOption: $sortOption)) {
            Label {
                Text(child.name)
            } icon: {
                Image(systemName: "folder.fill")
                    .foregroundStyle(TikTokTheme.readableBlue)
            }
        }
        .listRowBackground(TikTokTheme.elevatedBackground)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                beginEditing(child)
            } label: {
                Label("編集", systemImage: "pencil")
            }
            .tint(TikTokTheme.actionBlue)
        }
    }

    private func videoRow(_ video: VideoItem) -> some View {
        Button {
            activeVideo = video
        } label: {
            VideoLibraryRow(video: video, showsFolderPath: false)
        }
        .foregroundColor(TikTokTheme.primaryText)
        .listRowBackground(TikTokTheme.elevatedBackground)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                videoPendingMove = video
            } label: {
                Label("移動", systemImage: "folder")
            }
            .tint(TikTokTheme.actionBlue)
        }
    }

    private func matchesSearch(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains(searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func createSubfolder() {
        let trimmedName = normalizedFolderName(newFolderName)
        guard !folderNameIsInvalid(trimmedName, parent: folder) else {
            folderNameError = duplicateFolderExists(named: trimmedName, parent: folder) ? "同じ名前のフォルダがすでにあります" : "フォルダ名を入力してください"
            return
        }

        let subfolder = FolderItem(name: trimmedName, parent: folder)
        modelContext.insert(subfolder)
        try? modelContext.save()
        resetNewFolderForm()
    }

    private func requestFolderDeletion(offsets: IndexSet) {
        foldersPendingDeletion = offsets.map { visibleSubfolders[$0] }
        showingDeleteFolderConfirmation = !foldersPendingDeletion.isEmpty
    }

    private func deletePendingFolders() {
        for folder in foldersPendingDeletion {
            if activeVideoBelongs(to: folder) {
                activeVideo = nil
            }
            modelContext.delete(folder)
        }
        try? modelContext.save()
        foldersPendingDeletion = []
    }

    private func deleteVideos(offsets: IndexSet) {
        for index in offsets {
            deleteVideo(visibleVideos[index])
        }
        try? modelContext.save()
    }

    private func deleteVideo(_ video: VideoItem) {
        if activeVideo?.id == video.id {
            activeVideo = nil
        }
        modelContext.delete(video)
    }

    private func beginEditing(_ folder: FolderItem) {
        folderNameError = nil
        folderPendingEdit = folder
        editedFolderName = folder.name
    }

    private func updateFolderName() {
        guard let folder = folderPendingEdit else { return }
        let trimmedName = normalizedFolderName(editedFolderName)
        guard !folderNameIsInvalid(trimmedName, parent: folder.parent, excluding: folder) else {
            folderNameError = duplicateFolderExists(named: trimmedName, parent: folder.parent, excluding: folder) ? "同じ名前のフォルダがすでにあります" : "フォルダ名を入力してください"
            return
        }

        folder.name = trimmedName
        try? modelContext.save()
        resetEditFolderForm()
    }

    private func resetNewFolderForm() {
        newFolderName = ""
        folderNameError = nil
    }

    private func resetEditFolderForm() {
        folderPendingEdit = nil
        editedFolderName = ""
        folderNameError = nil
    }

    private var editFolderBinding: Binding<Bool> {
        Binding(
            get: { folderPendingEdit != nil },
            set: { isPresented in
                if !isPresented {
                    resetEditFolderForm()
                }
            }
        )
    }

    private var editFolderNameIsInvalid: Bool {
        guard let folder = folderPendingEdit else { return true }
        return folderNameIsInvalid(editedFolderName, parent: folder.parent, excluding: folder)
    }

    private var folderDeletionMessage: String {
        guard let folder = foldersPendingDeletion.first else {
            return "選択したフォルダを削除します"
        }

        let folderCount = foldersPendingDeletion.reduce(0) { $0 + descendantFolderCount(for: $1) + 1 }
        let videoCount = foldersPendingDeletion.reduce(0) { $0 + recursiveVideoCount(for: $1) }

        if foldersPendingDeletion.count == 1 {
            return "「\(folder.name)」を削除します。含まれるサブフォルダ \(max(folderCount - 1, 0)) 件、動画 \(videoCount) 件も削除されます。"
        }
        return "選択した \(foldersPendingDeletion.count) 件のフォルダを削除します。含まれるサブフォルダ \(max(folderCount - foldersPendingDeletion.count, 0)) 件、動画 \(videoCount) 件も削除されます。"
    }

    private func sortedFolders(_ folders: [FolderItem]) -> [FolderItem] {
        folders.sorted { lhs, rhs in
            switch sortOption {
            case .title:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .createdOldest:
                return lhs.createdAt < rhs.createdAt
            default:
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func sortedVideos(_ videos: [VideoItem]) -> [VideoItem] {
        videos.sorted { lhs, rhs in
            switch sortOption {
            case .createdNewest:
                return lhs.createdAt > rhs.createdAt
            case .createdOldest:
                return lhs.createdAt < rhs.createdAt
            case .recentlyWatched:
                return (lhs.lastWatchedAt ?? .distantPast) > (rhs.lastWatchedAt ?? .distantPast)
            case .title:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .progress:
                return progress(for: lhs) > progress(for: rhs)
            }
        }
    }

    private func progress(for video: VideoItem) -> Double {
        guard video.duration > 0 else { return 0 }
        return min(max(lastPlaybackPosition(for: video) / video.duration, 0), 1)
    }

    private func folderNameIsInvalid(_ name: String, parent: FolderItem?, excluding excludedFolder: FolderItem? = nil) -> Bool {
        let trimmedName = normalizedFolderName(name)
        guard !trimmedName.isEmpty else { return true }
        return duplicateFolderExists(named: trimmedName, parent: parent, excluding: excludedFolder)
    }

    private func duplicateFolderExists(named name: String, parent: FolderItem?, excluding excludedFolder: FolderItem? = nil) -> Bool {
        allFolders.contains { folder in
            guard folder.id != excludedFolder?.id else { return false }
            guard foldersShareParent(folder, parent) else { return false }
            return folder.name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func foldersShareParent(_ folder: FolderItem, _ parent: FolderItem?) -> Bool {
        switch (folder.parent?.id, parent?.id) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs == rhs
        default:
            return false
        }
    }

    private func activeVideoBelongs(to folder: FolderItem) -> Bool {
        guard let activeVideo else { return false }
        return folderContainsVideo(folder, videoID: activeVideo.id)
    }
}

struct MoveVideoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var video: VideoItem
    @State private var selectedFolder: FolderItem?

    @Query(sort: \FolderItem.createdAt)
    private var allFolders: [FolderItem]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("保存先", selection: $selectedFolder) {
                        Label("指定なし", systemImage: "tray")
                            .tag(FolderItem?(nil))

                        ForEach(sortedFolders) { folder in
                            Text(folderPath(for: folder))
                                .tag(FolderItem?(folder))
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("移動先")
                } footer: {
                    Text("「\(video.title)」の保存先を変更します")
                }
            }
            .scrollContentBackground(.hidden)
            .background(TikTokTheme.background)
            .navigationTitle("動画を移動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        video.folder = selectedFolder
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .tint(TikTokTheme.readableBlue)
            .onAppear {
                selectedFolder = video.folder
            }
        }
    }

    private var sortedFolders: [FolderItem] {
        allFolders.sorted { lhs, rhs in
            folderPath(for: lhs).localizedStandardCompare(folderPath(for: rhs)) == .orderedAscending
        }
    }
}

struct VideoLibraryRow: View {
    var video: VideoItem
    var showsFolderPath: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if showsFolderPath, let folder = video.folder {
                        Text(folderPath(for: folder))
                    }

                    if video.duration > 0 {
                        Text(progressText)
                    }
                }
                .font(.caption)
                .foregroundStyle(TikTokTheme.secondaryText)
            }
        } icon: {
            Image(systemName: "play.rectangle")
        }
    }

    private var progressText: String {
        playbackPositionText(for: video)
    }
}

enum LibrarySortOption: String, CaseIterable, Identifiable {
    case createdNewest
    case recentlyWatched
    case title
    case progress
    case createdOldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createdNewest:
            return "追加日が新しい順"
        case .recentlyWatched:
            return "最近見た順"
        case .title:
            return "タイトル順"
        case .progress:
            return "進捗順"
        case .createdOldest:
            return "追加日が古い順"
        }
    }

    var systemImage: String {
        switch self {
        case .createdNewest:
            return "clock.badge.plus"
        case .recentlyWatched:
            return "play.circle"
        case .title:
            return "textformat.abc"
        case .progress:
            return "chart.line.uptrend.xyaxis"
        case .createdOldest:
            return "clock"
        }
    }
}

private func normalizedFolderName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines)
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

private func descendantFolderCount(for folder: FolderItem) -> Int {
    (folder.children ?? []).reduce(0) { count, child in
        count + 1 + descendantFolderCount(for: child)
    }
}

private func recursiveVideoCount(for folder: FolderItem) -> Int {
    let directVideos = folder.videos?.count ?? 0
    let childVideos = (folder.children ?? []).reduce(0) { $0 + recursiveVideoCount(for: $1) }
    return directVideos + childVideos
}

private func folderContainsVideo(_ folder: FolderItem, videoID: UUID) -> Bool {
    if (folder.videos ?? []).contains(where: { $0.id == videoID }) {
        return true
    }

    return (folder.children ?? []).contains { child in
        folderContainsVideo(child, videoID: videoID)
    }
}

private func playbackPositionText(for video: VideoItem) -> String {
    let playbackTime = lastPlaybackPosition(for: video)
    guard playbackTime > 0 else {
        return "未視聴"
    }

    if video.duration > 0 {
        return "\(formattedPlaybackPosition(playbackTime))まで / \(formattedPlaybackPosition(video.duration))"
    }
    return "\(formattedPlaybackPosition(playbackTime))まで"
}

private func lastPlaybackPosition(for video: VideoItem) -> TimeInterval {
    guard let playbackTime = video.lastPlaybackTime, playbackTime.isFinite, playbackTime > 0 else {
        return 0
    }
    return playbackTime
}

private func formattedPlaybackPosition(_ seconds: TimeInterval) -> String {
    let totalSeconds = max(0, Int(seconds.rounded(.down)))
    let minutes = totalSeconds / 60
    let remainingSeconds = totalSeconds % 60

    if minutes == 0 {
        return "0:\(String(format: "%02d", remainingSeconds))"
    }
    return "\(minutes)分"
}
