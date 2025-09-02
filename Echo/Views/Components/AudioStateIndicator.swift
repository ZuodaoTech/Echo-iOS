import SwiftUI

struct AudioStateIndicator: View {
    let state: AudioCoordinator.UserFacingState
    let progress: Double?
    
    @State private var pulseAnimation = false
    
    private var shouldPulse: Bool {
        switch state {
        case .recording, .processing, .transcribing:
            return true
        default:
            return false
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .initializing, .recovering:
            return .orange
        case .ready, .saved:
            return .green
        case .recording:
            return .red
        case .processing, .transcribing:
            return .blue
        case .playing:
            return .purple
        case .paused:
            return .gray
        case .interrupted:
            return .orange
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // State icon with animation
            ZStack {
                // Background pulse effect
                if shouldPulse {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                // Main icon
                Circle()
                    .fill(stateColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(state.emoji)
                            .font(.title2)
                    )
            }
            
            // State text
            VStack(spacing: 4) {
                Text(state.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(state.encouragingMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Progress bar if available
            if let progress = progress, progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: stateColor))
                    .frame(maxWidth: 200)
            }
        }
        .padding()
        .onAppear {
            if shouldPulse {
                pulseAnimation = true
            }
        }
        .onChange(of: state) { newState in
            pulseAnimation = shouldPulse
        }
    }
}

// MARK: - Compact Version

struct CompactAudioStateIndicator: View {
    let state: AudioCoordinator.UserFacingState
    
    private var stateColor: Color {
        switch state {
        case .recording:
            return .red
        case .processing, .transcribing:
            return .blue
        case .playing:
            return .purple
        case .ready, .saved:
            return .green
        default:
            return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Animated dot
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(stateColor.opacity(0.4), lineWidth: 2)
                        .scaleEffect(state == .recording ? 2 : 1)
                        .opacity(state == .recording ? 0 : 1)
                        .animation(
                            state == .recording ?
                            Animation.easeOut(duration: 1)
                                .repeatForever(autoreverses: false) :
                            .default,
                            value: state
                        )
                )
            
            // State text
            Text(state.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(stateColor.opacity(0.1))
        )
    }
}

// MARK: - Preview

struct AudioStateIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Full indicator
            AudioStateIndicator(
                state: .recording,
                progress: nil
            )
            
            AudioStateIndicator(
                state: .processing,
                progress: 0.6
            )
            
            // Compact indicators
            HStack(spacing: 20) {
                CompactAudioStateIndicator(state: .ready)
                CompactAudioStateIndicator(state: .recording)
                CompactAudioStateIndicator(state: .processing)
            }
        }
        .padding()
    }
}