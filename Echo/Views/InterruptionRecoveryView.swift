import SwiftUI

// MARK: - Recovery Action

enum RecoveryAction {
    case continueRecording
    case savePartial
    case startOver
    case dismiss
}

// MARK: - Interruption Recovery View

struct InterruptionRecoveryView: View {
    let duration: TimeInterval
    let isPhoneCall: Bool
    let onAction: (RecoveryAction) -> Void
    
    @State private var selectedAction: RecoveryAction?
    @State private var animateIn = false
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes) min \(seconds) sec"
        } else {
            return "\(seconds) seconds"
        }
    }
    
    private var encouragingMessage: String {
        [
            "Every word you speak matters",
            "Your practice is valuable, interrupted or not",
            "You're building resilience right now",
            "This pause is part of your journey",
            "Your words have power, always"
        ].randomElement() ?? "Every word counts"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle area for sheet
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // Icon with animation
            Image(systemName: isPhoneCall ? "phone.circle.fill" : "pause.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(isPhoneCall ? .orange : .blue)
                .padding(.bottom, 20)
            
            // Main message
            VStack(spacing: 8) {
                Text(isPhoneCall ? "Call Ended" : "Recording Paused")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your recording is safe")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 16)
            
            // Duration info
            if duration > 0 {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("You recorded \(formattedDuration) of powerful affirmations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            
            // Recovery options
            VStack(spacing: 12) {
                // Continue button - most prominent
                Button(action: { 
                    selectedAction = .continueRecording
                    onAction(.continueRecording)
                }) {
                    Label("Continue Recording", systemImage: "mic.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                // Save what we have - secondary option
                Button(action: { 
                    selectedAction = .savePartial
                    onAction(.savePartial)
                }) {
                    Label("Save What I Have", systemImage: "checkmark.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                
                // Start over - tertiary option
                Button(action: { 
                    selectedAction = .startOver
                    onAction(.startOver)
                }) {
                    Text("Start Fresh")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            .disabled(selectedAction != nil) // Prevent multiple taps
            
            // Encouraging message
            Text(encouragingMessage)
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                animateIn = true
            }
        }
    }
}

// MARK: - Sheet Presentation Helper

struct InterruptionRecoverySheet: ViewModifier {
    @Binding var isPresented: Bool
    let duration: TimeInterval
    let isPhoneCall: Bool
    let onAction: (RecoveryAction) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                InterruptionRecoveryView(
                    duration: duration,
                    isPhoneCall: isPhoneCall,
                    onAction: { action in
                        isPresented = false
                        onAction(action)
                    }
                )
                // iOS 16+ features are removed for compatibility
            }
    }
}

// MARK: - View Extension

extension View {
    func interruptionRecoverySheet(
        isPresented: Binding<Bool>,
        duration: TimeInterval,
        isPhoneCall: Bool,
        onAction: @escaping (RecoveryAction) -> Void
    ) -> some View {
        modifier(InterruptionRecoverySheet(
            isPresented: isPresented,
            duration: duration,
            isPhoneCall: isPhoneCall,
            onAction: onAction
        ))
    }
}

// MARK: - Preview

struct InterruptionRecoveryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Phone call interruption
            InterruptionRecoveryView(
                duration: 15,
                isPhoneCall: true,
                onAction: { _ in }
            )
            .previewDisplayName("Phone Call")
            
            // Other interruption
            InterruptionRecoveryView(
                duration: 45,
                isPhoneCall: false,
                onAction: { _ in }
            )
            .previewDisplayName("Other Interruption")
        }
    }
}