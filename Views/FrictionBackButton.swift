import SwiftUI
import Combine

struct FrictionBackButton: View {
    var onDismiss: () -> Void
    var allowsImmediateDismiss: Bool = false
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var isLongPressing = false
    @State private var pressProgress: CGFloat = 0.0
    
    // Timer to track how long the user has been on the screen
    let screenTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    // The threshold after which friction is applied (20 seconds)
    let frictionThreshold: TimeInterval = 20.0
    // How long to press after friction is applied (5 seconds)
    let requiredPressDuration: TimeInterval = 5.0
    
    // Timer for the long press progress
    @State private var pressTimer: Timer?
    
    var hasFriction: Bool {
        timeElapsed >= frictionThreshold && !allowsImmediateDismiss
    }
    
    var body: some View {
        ZStack {
            // Background ring (progress)
            if hasFriction && isLongPressing {
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 1.0 - pressProgress) // Disappears clockwise
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
            }
            
            Button(action: {
                if !hasFriction || allowsImmediateDismiss {
                    onDismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
                    .scaleEffect(isLongPressing ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLongPressing)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if hasFriction {
                            startPressing()
                        }
                    }
                    .onEnded { _ in
                        if hasFriction {
                            stopPressing()
                        }
                    }
            )
        }
        .onReceive(screenTimer) { _ in
            timeElapsed += 1.0
        }
    }
    
    private func startPressing() {
        guard !isLongPressing else { return }
        isLongPressing = true
        pressProgress = 0.0
        
        let interval = 0.05
        pressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            withAnimation(.linear(duration: interval)) {
                pressProgress += interval / requiredPressDuration
            }
            
            if pressProgress >= 1.0 {
                timer.invalidate()
                onDismiss()
            }
        }
    }
    
    private func stopPressing() {
        isLongPressing = false
        pressTimer?.invalidate()
        pressTimer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            pressProgress = 0.0
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        FrictionBackButton(onDismiss: {})
    }
}
