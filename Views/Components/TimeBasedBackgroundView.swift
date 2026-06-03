import SwiftUI

struct TimeBasedBackgroundView: View {
    var hour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var gradientColors: [Color] {
        [
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
