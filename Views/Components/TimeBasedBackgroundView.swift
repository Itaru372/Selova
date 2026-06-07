import SwiftUI

struct TimeBasedBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var hour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.060, green: 0.066, blue: 0.090),
                Color(red: 0.046, green: 0.058, blue: 0.082),
                TikTokTheme.background
            ]
        }

        return [
            Color(red: 0.99, green: 0.99, blue: 1.0),
            Color(red: 0.94, green: 0.98, blue: 1.0),
            TikTokTheme.background
        ]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [TikTokTheme.pink.opacity(0.10), .clear, TikTokTheme.cyan.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }
}
