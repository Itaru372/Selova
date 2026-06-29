import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct StudySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StudyPreferences.Keys.closeRemindersEnabled) private var closeRemindersEnabled = true
    @AppStorage(StudyPreferences.Keys.closeReminderDailyLimit) private var closeReminderDailyLimit = 2
    @State private var notificationStatusText = String(localized: "確認中")
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingNotificationDeniedDialog = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("離脱後の通知", isOn: $closeRemindersEnabled)

                    Stepper(value: $closeReminderDailyLimit, in: 1...5) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("1日の通知セット上限")
                            Text("\(closeReminderDailyLimit)回まで")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!closeRemindersEnabled)
                } header: {
                    Text("集中サポート")
                } footer: {
                    Text("動画モードを10秒以上続けたあとにアプリを閉じた場合、即時・5分後・10分後に再開通知を送ります。")
                }

                Section {
                    HStack {
                        Text("通知許可")
                        Spacer()
                        Text(notificationStatusText)
                            .foregroundStyle(.secondary)
                    }

                    if shouldShowNotificationAuthorizationButton {
                        Button(notificationAuthorizationButtonTitle) {
                            requestNotificationAuthorizationOrShowInstructions()
                        }
                        .disabled(!closeRemindersEnabled)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear(perform: refreshNotificationStatus)
            .onChange(of: closeRemindersEnabled) { _, isEnabled in
                SelovaAnalytics.track(.settingChanged, properties: [
                    "setting_name": "close_reminders_enabled",
                    "setting_value": isEnabled
                ])
            }
            .onChange(of: closeReminderDailyLimit) { _, limit in
                SelovaAnalytics.track(.settingChanged, properties: [
                    "setting_name": "close_reminder_daily_limit",
                    "setting_value": limit
                ])
            }
            .alert("通知が拒否されています", isPresented: $showingNotificationDeniedDialog) {
                Button("設定を開く") {
                    openAppSettings()
                }
                Button("閉じる", role: .cancel) {}
            } message: {
                Text("iPhoneの「設定」アプリで「Selova」>「通知」を開き、「通知を許可」をオンにしてください。")
            }
        }
    }

    private func requestNotificationAuthorizationOrShowInstructions() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                DispatchQueue.main.async {
                    showingNotificationDeniedDialog = true
                    notificationStatusText = String(localized: "拒否")
                }
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                refreshNotificationStatus()
            }
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let text: String
            switch settings.authorizationStatus {
            case .authorized:
                text = String(localized: "許可済み")
            case .provisional:
                text = String(localized: "仮許可")
            case .denied:
                text = String(localized: "拒否")
            case .notDetermined:
                text = String(localized: "未設定")
            case .ephemeral:
                text = String(localized: "一時許可")
            @unknown default:
                text = String(localized: "不明")
            }

            DispatchQueue.main.async {
                notificationStatusText = text
                notificationAuthorizationStatus = settings.authorizationStatus
            }
        }
    }

    private var shouldShowNotificationAuthorizationButton: Bool {
        switch notificationAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return false
        case .denied, .notDetermined:
            return true
        @unknown default:
            return true
        }
    }

    private var notificationAuthorizationButtonTitle: String {
        notificationAuthorizationStatus == .denied
            ? String(localized: "通知設定を開く")
            : String(localized: "通知を許可する")
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
