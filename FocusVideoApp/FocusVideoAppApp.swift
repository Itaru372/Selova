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
import UserNotifications
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
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppOrientation.shared.supportedOrientations
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        SelovaResumeRoute.handleNotificationResponse(response)
        completionHandler()
    }
}
#endif

@main
struct FocusVideoAppApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        SelovaAnalytics.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [FolderItem.self, VideoItem.self, VideoNote.self, StudySession.self])
        }
    }
}
