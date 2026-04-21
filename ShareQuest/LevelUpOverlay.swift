import SwiftUI

struct LevelUpOverlay: View {
    let level: Int
    let levelName: String
    let icon: String
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Glass effect background
            if #available(iOS 15.0, *) {
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }
            } else {
                Color.black.opacity(0.65).ignoresSafeArea()
                    .onTapGesture { onDismiss() }
            }
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .top, endPoint: .bottom))
                        .frame(width: 110, height: 110)
                        .shadow(color: .yellow.opacity(0.5), radius: 24, x: 0, y: 8)
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .foregroundColor(.white)
                }
                Text("Level Up!")
                    .font(.largeTitle.weight(.bold))
                    .dynamicTypeSize(.xSmall ... .accessibility2)
                    .foregroundColor(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("You reached Level \(level): \(levelName)")
                    .font(.title3.weight(.semibold))
                    .dynamicTypeSize(.xSmall ... .accessibility2)
                    .foregroundColor(.yellow)
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline.weight(.semibold))
                        .dynamicTypeSize(.xSmall ... .accessibility2)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 40)
                        .background(Color.green)
                        .cornerRadius(16)
                }
                .accessibilityLabel("Continue to next screen")
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.1, green: 0.13, blue: 0.2).opacity(0.98))
                    .shadow(radius: 24)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
                // Optionally trigger confetti
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }
            }
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.yellow, .orange, .green, .purple, .white, .blue, .pink]
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<24, id: \.self) { i in
                let color = colors[i % colors.count]
                let size = 10 + CGFloat(i % 3) * 4
                let xPos = CGFloat.random(in: 0...geo.size.width)
                let yPos = animate ? geo.size.height + 40 : -40
                let animation = Animation.interpolatingSpring(stiffness: 80, damping: 8)
                    .delay(Double(i) * 0.04)
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .position(x: xPos, y: yPos)
                    .opacity(0.8)
                    .animation(animation, value: animate)
            }
        }
        .onAppear { animate = true }
    }
}
