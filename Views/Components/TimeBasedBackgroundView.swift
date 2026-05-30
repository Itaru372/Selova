import SwiftUI

struct TimeBasedBackgroundView: View {
    var hour: Int {
        Calendar.current.component(.hour, from: Date())
    }
    
    var gradientColors: [Color] {
        switch hour {
        case 5..<11: // Morning (Bright warm sunrise to light sky)
            return [Color(red: 1.0, green: 0.96, blue: 0.85), Color(red: 0.85, green: 0.95, blue: 1.0)]
        case 11..<16: // Day (Very light sky blue to clear blue)
            return [Color(red: 0.88, green: 0.95, blue: 1.0), Color(red: 0.75, green: 0.90, blue: 1.0)]
        case 16..<19: // Evening (Soft pastel peach to light rose)
            return [Color(red: 1.0, green: 0.92, blue: 0.88), Color(red: 1.0, green: 0.85, blue: 0.85)]
        default: // Night (Light lavender to soft blue)
            return [Color(red: 0.90, green: 0.90, blue: 0.98), Color(red: 0.85, green: 0.85, blue: 0.95)]
        }
    }
    
    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
