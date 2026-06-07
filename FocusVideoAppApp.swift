//
//  FocusVideoAppApp.swift
//  FocusVideoApp
//
//  Created by 岡崎格 on 2026/05/26.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
final class AppOrientation {
    static let shared = AppOrientation()
    var supportedOrientations: UIInterfaceOrientationMask = .portrait

    private init() {}
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientation.shared.supportedOrientations
    }
}
#endif

@main
struct FocusVideoAppApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [FolderItem.self, VideoItem.self, StudySession.self])
        }
    }
}
