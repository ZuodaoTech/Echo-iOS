import SwiftUI
import CoreData
import UIKit

struct ScriptCard: View {
    @ObservedObject var script: SelftalkScript
    @StateObject private var audioService = AudioCoordinator.shared
    @State private var showingPrivateAlert = false
    @State private var showingNoRecordingAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isPressed = false
    
    var onEdit: () -> Void
    
    // DEFENSIVE: Check validity before accessing script properties
    private var isScriptValid: Bool {
        !script.isDeleted && !script.isFault && script.managedObjectContext != nil
    }
    
    private var isPlaying: Bool {
        guard isScriptValid else { return false }
        return audioService.isPlaying && audioService.currentPlayingScriptId == script.id
    }
    
    private var isPaused: Bool {
        guard isScriptValid else { return false }
        return audioService.isPaused && audioService.currentPlayingScriptId == script.id
    }
    
    private var isProcessing: Bool {
        guard isScriptValid else { return false }
        return audioService.isProcessing(script: script)
    }
    
    // Predefined subtle color palette
    private let colorPalette: [Color] = [
        Color.blue.opacity(0.6),
        Color.purple.opacity(0.6),
        Color.pink.opacity(0.6),
        Color.orange.opacity(0.6),
        Color.green.opacity(0.6),
        Color.teal.opacity(0.6),
        Color.indigo.opacity(0.6),
        Color.mint.opacity(0.6)
    ]
    
    // Get consistent color for this script
    private var cardAccentColor: Color {
        guard isScriptValid else { return colorPalette[0] }  // Default to first color if invalid
        let index = abs(script.id.hashValue) % colorPalette.count
        return colorPalette[index]
    }
    
    var body: some View {
        // DEFENSIVE: Show placeholder if script is invalid/deleted
        Group {
            if isScriptValid {
                validScriptCard
            } else {
                // Show empty card or placeholder while being deleted
                EmptyView()
            }
        }
    }
    
    private var validScriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tags and Repetitions Header
            HStack {
                // Show tags or "Untagged"
                if script.tagsArray.isEmpty {
                    Text(NSLocalizedString("tag.untagged", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gray.opacity(0.15))
                        .foregroundColor(.gray)
                        .cornerRadius(10)
                } else {
                    HStack(spacing: 6) {
                        ForEach(script.tagsArray.prefix(2), id: \.id) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(cardAccentColor.opacity(0.15))
                                .foregroundColor(cardAccentColor)
                                .cornerRadius(10)
                        }
                        
                        if script.tagsArray.count > 2 {
                            Text("+\(script.tagsArray.count - 2)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("\(script.repetitions)x")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if script.notificationEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(cardAccentColor)
                }
                
                if script.privateModeEnabled {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Script Text
            Text(script.scriptText)
                .font(.body)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            // Playback Progress (if playing or paused or in interval)
            if isPlaying || isPaused || (audioService.isInInterval && audioService.currentPlayingScriptId == script.id) {
                VStack(spacing: 4) {
                    HStack {
                        // Always use blue, show interval or playback progress
                        let showingInterval = audioService.isInInterval && audioService.currentPlayingScriptId == script.id
                        let progressValue = showingInterval ? audioService.intervalProgress : audioService.playbackProgress
                        
                        ProgressView(value: progressValue)
                            .tint(cardAccentColor)
                            .animation(.linear(duration: 0.02), value: progressValue)
                            .onAppear {
                                if showingInterval {
                                    // ScriptCard: Showing interval progress
                                }
                            }
                        
                        if isPaused {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                                .foregroundColor(cardAccentColor)
                        }
                    }
                    
                    if audioService.totalRepetitions > 1 {
                        Text("\(audioService.currentRepetition)/\(audioService.totalRepetitions)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if isProcessing {
                // Show processing indicator
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                    Text(NSLocalizedString("recording.processing", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if script.hasRecording && script.audioDuration > 0 {
                // Show total duration when not playing
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(script.formattedTotalDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Show no recording indicator
                HStack {
                    Image(systemName: "mic.slash")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPressed ? cardAccentColor.opacity(0.12) : (isPlaying || isPaused ? cardAccentColor.opacity(0.08) : Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isPressed ? cardAccentColor.opacity(0.6) : (isPlaying || isPaused ? cardAccentColor.opacity(0.5) : cardAccentColor.opacity(0.25)),
                            lineWidth: isPressed ? 2 : (isPlaying || isPaused ? 1.5 : 1)
                        )
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .shadow(color: cardAccentColor.opacity(0.15), radius: 8, x: 0, y: 3)
        .shadow(color: cardAccentColor.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // Trigger edit on long press
                onEdit()
            }
        )
        .alert(NSLocalizedString("settings.private_mode.title", comment: ""), isPresented: $showingPrivateAlert) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("settings.private_mode.info", comment: ""))
        }
        .alert(NSLocalizedString("script.no_recording", comment: ""), isPresented: $showingNoRecordingAlert) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(NSLocalizedString("recording.no_recording_message", comment: ""))
        }
        .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingErrorAlert) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleTap() {
        print("\n👆 TAP: ScriptCard tapped for script \(script.id)")
        print("   Script text: \(script.scriptText.prefix(30))...")
        
        // DEFENSIVE: Check script validity first
        guard isScriptValid else {
            print("   ⛔ Script invalid or deleted")
            return
        }
        
        // Check if audio is still being processed
        if isProcessing || audioService.isProcessingRecording || audioService.processingScriptIds.contains(script.id) {
            print("   ⏳ Audio is still being processed")
            print("   isProcessing: \(isProcessing)")
            print("   audioService.isProcessingRecording: \(audioService.isProcessingRecording)")
            print("   Script in processing list: \(audioService.processingScriptIds.contains(script.id))")
            // Could show a toast or visual indicator here
            return
        }
        
        // Check if recording exists
        guard script.hasRecording else {
            print("   📦 No recording found for this script")
            showingNoRecordingAlert = true
            return 
        }
        
        // Double-check the audio file actually exists on disk
        if !audioService.hasRecording(for: script) {
            print("   ⚠️ Script thinks it has recording but file doesn't exist!")
            print("   audioFilePath: \(script.audioFilePath ?? "nil")")
            print("   audioDuration: \(script.audioDuration)")
            showingNoRecordingAlert = true
            return
        }
        
        // Check if this script is in a playback session (including intervals)
        let isThisScriptInSession = audioService.isInPlaybackSession && audioService.currentPlayingScriptId == script.id
        print("   Is in session: \(isThisScriptInSession)")
        print("   Audio session state: \(audioService.audioSessionState)")
        
        if isThisScriptInSession {
            // We're in a playback session for this script
            if audioService.isPaused {
                print("   ▶️ Resuming paused playback")
                audioService.resumePlayback()
            } else {
                print("   ⏸ Pausing playback")
                audioService.pausePlayback()
            }
        } else {
            // Start new playback
            print("   🎵 Starting new playback")
            do {
                try audioService.play(script: script)
                print("   ✅ Playback started successfully")
            } catch AudioServiceError.privateModeActive {
                showingPrivateAlert = true
            } catch {
                print("⚠️ ScriptCard: Initial playback failed: \(error)")
                
                // For simulator error -50 or state issues, retry with a brief delay
                let shouldRetry = (error as NSError).code == -50 || 
                                 error.localizedDescription.contains("Preparing to Play")
                
                if shouldRetry {
                    print("   Retrying playback after delay...")
                    // Give audio session more time to reset on real device
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        do {
                            try audioService.play(script: script)
                            print("✅ ScriptCard: Retry successful")
                        } catch AudioServiceError.privateModeActive {
                            showingPrivateAlert = true
                        } catch {
                            print("🔴 ScriptCard: Retry failed: \(error)")
                            // Only show error for non-simulator issues
                            if (error as NSError).code != -50 {
                                errorMessage = "Unable to play audio. Please try again."
                                showingErrorAlert = true
                            }
                        }
                    }
                } else if case AudioServiceError.privateModeActive = error {
                    showingPrivateAlert = true
                } else {
                    // Show error immediately for other failures
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct ScriptCard_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let script = SelftalkScript.create(
            scriptText: "I am confident and capable of achieving my goals. Every day I grow stronger and more resilient.",
            repetitions: 3,
            privateMode: true,
            in: context
        )
        
        return ScriptCard(
            script: script,
            onEdit: { }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}