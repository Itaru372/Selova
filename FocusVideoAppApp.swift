//
//  FocusVideoAppApp.swift
//  FocusVideoApp
//
//  Created by 岡崎格 on 2026/05/26.
//

import SwiftUI
import SwiftData

@main
struct FocusVideoAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [FolderItem.self, VideoItem.self, StudySession.self])
        }
    }
}
