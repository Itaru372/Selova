import Foundation

enum StudyGrowth {
    struct LevelState: Equatable {
        var level: Int
        var xp: Int
        var currentLevelXP: Int
        var requiredXP: Int
        var progress: Double
        var assetName: String
    }

    static let xpPerMinute = 10
    static let streakXP = 40

    static func totalXP(totalFocusedTime: TimeInterval, streakDays: Int) -> Int {
        let focusedMinutes = max(0, Int(totalFocusedTime / 60))
        return focusedMinutes * xpPerMinute + max(0, streakDays) * streakXP
    }

    static func requiredXPToAdvance(from level: Int) -> Int {
        let level = max(1, level)
        let step = level - 1
        return 100 + step * 65 + step * step * 35
    }

    static func levelState(totalFocusedTime: TimeInterval, streakDays: Int) -> LevelState {
        let xp = totalXP(totalFocusedTime: totalFocusedTime, streakDays: streakDays)
        return makeLevelState(xp: xp)
    }

    private static func makeLevelState(xp: Int) -> LevelState {
        var remainingXP = xp
        var level = 1
        var requiredXP = requiredXPToAdvance(from: level)

        while remainingXP >= requiredXP {
            remainingXP -= requiredXP
            level += 1
            requiredXP = requiredXPToAdvance(from: level)
        }

        return LevelState(
            level: level,
            xp: xp,
            currentLevelXP: remainingXP,
            requiredXP: requiredXP,
            progress: min(max(Double(remainingXP) / Double(requiredXP), 0), 1),
            assetName: growthAssetName(for: level)
        )
    }

    static func growthAssetName(for level: Int) -> String {
        switch level {
        case ...1:
            return "GrowthSeed"
        case 2:
            return "GrowthSprout"
        case 3:
            return "GrowthYoungTree"
        case 4:
            return "GrowthTree"
        case 5:
            return "GrowthFlowerTree"
        default:
            return "GrowthForest"
        }
    }
}
