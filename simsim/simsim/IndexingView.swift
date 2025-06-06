import SwiftUI

struct IndexingView: View {
    @State private var animationProgress: Double = 0
    @State private var pulse: Bool = false
    let isComplete: Bool
    let startIndexing: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon with pulsing animation
            ZStack {
                Circle()
                    .fill(Color.accentTeal.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .opacity(pulse ? 0.5 : 0.8)
                
                Circle()
                    .fill(Color.cardBackground)
                    .frame(width: 100, height: 100)
                
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.indexingGreen)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.accentTeal)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isComplete)
            
            // Title
            Text(isComplete ? "Ready to Search" : "Photo Indexing")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.lightText)
            
            // Description
            Text(isComplete 
                ? "Your photos are now ready to search by description" 
                : "We need to index your photos to make them searchable")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.subtleText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Progress indicator or button
            if isComplete {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        startIndexing()
                    }
                }) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.darkBackground)
                        .frame(width: 200)
                        .padding(.vertical, 15)
                        .background(Color.accentTeal)
                        .cornerRadius(25)
                        .shadow(color: Color.accentTeal.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Begin searching your photos")
                .padding(.top, 10)
            } else {
                VStack(spacing: 15) {
                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: 250, height: 6)
                            .foregroundColor(Color.cardBackground)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .frame(width: 250 * animationProgress, height: 6)
                            .foregroundColor(Color.indexingGreen)
                    }
                    
                    // Progress text
                    Text("Analyzing your photos...")
                        .font(.system(size: 14))
                        .foregroundColor(.subtleText)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Indexing in progress, \(Int(animationProgress * 100))% complete")
                .padding(.top, 20)
            }
        }
        .padding(.horizontal)
        .onAppear {
            // Start animations
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            
            // Fake progress animation
            animateProgress()
        }
    }
    
    private func animateProgress() {
        // Only animate if not complete
        if !isComplete {
            withAnimation(.easeInOut(duration: 2)) {
                animationProgress = 0.3
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 3)) {
                    animationProgress = 0.7
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeInOut(duration: 2)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}

// Custom button style for scale animation on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.darkBackground.edgesIgnoringSafeArea(.all)
        IndexingView(isComplete: false) { }
    }
}