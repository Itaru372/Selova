import Foundation

enum StudyPreferences {
    enum Keys {
        static let closeRemindersEnabled = "studyCloseRemindersEnabled"
        static let closeReminderDailyLimit = "studyCloseReminderDailyLimit"
        static let closeReminderScheduledDay = "studyCloseReminderScheduledDay"
        static let closeReminderScheduledCount = "studyCloseReminderScheduledCount"
    }

    static var closeRemindersEnabled: Bool {
        if UserDefaults.standard.object(forKey: Keys.closeRemindersEnabled) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Keys.closeRemindersEnabled)
    }

    static var closeReminderDailyLimit: Int {
        let storedValue = UserDefaults.standard.integer(forKey: Keys.closeReminderDailyLimit)
        return storedValue == 0 ? 2 : max(1, min(storedValue, 5))
    }

    static func canScheduleCloseReminderEvent(on date: Date = Date()) -> Bool {
        resetDailyCloseReminderCountIfNeeded(on: date)
        return UserDefaults.standard.integer(forKey: Keys.closeReminderScheduledCount) < closeReminderDailyLimit
    }

    static func recordCloseReminderEvent(on date: Date = Date()) {
        resetDailyCloseReminderCountIfNeeded(on: date)
        let currentCount = UserDefaults.standard.integer(forKey: Keys.closeReminderScheduledCount)
        UserDefaults.standard.set(currentCount + 1, forKey: Keys.closeReminderScheduledCount)
    }

    private static func resetDailyCloseReminderCountIfNeeded(on date: Date) {
        let dayString = Self.dayString(for: date)
        let storedDay = UserDefaults.standard.string(forKey: Keys.closeReminderScheduledDay)
        guard storedDay != dayString else { return }

        UserDefaults.standard.set(dayString, forKey: Keys.closeReminderScheduledDay)
        UserDefaults.standard.set(0, forKey: Keys.closeReminderScheduledCount)
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
