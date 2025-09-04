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
    
    // Get randomized color for this script (consistent within session)
    private var cardAccentColor: Color {
        guard isScriptValid else { return Color.blue.opacity(0.6) }  // Default if invalid
        return CardColorManager.shared.getColor(for: script.id)
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
                .foregroundColor(script.scriptText == NSLocalizedString("script.recording_only_placeholder", comment: "") ? .secondary : .primary)
            
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
                // Show recording indicator with duration
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.caption)
                        .foregroundColor(cardAccentColor)
                    Text(script.formattedTotalDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
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
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isPressed ? cardAccentColor : (isPlaying || isPaused ? cardAccentColor.opacity(0.8) : Color(.separator)),
                            lineWidth: isPressed ? 1.5 : 0.5
                        )
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
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
        #if DEBUG
        print("\n👆 TAP: ScriptCard tapped for script \(script.id)")
        #endif
        #if DEBUG
        print("   Script text: \(script.scriptText.prefix(30))...")
        #endif
        
        // DEFENSIVE: Check script validity first
        guard isScriptValid else {
            #if DEBUG
            print("   ⛔ Script invalid or deleted")
            #endif
            return
        }
        
        // Check if audio is still being processed
        if isProcessing || audioService.isProcessingRecording || audioService.processingScriptIds.contains(script.id) {
            #if DEBUG
            print("   ⏳ Audio is still being processed")
            #endif
            #if DEBUG
            print("   isProcessing: \(isProcessing)")
            #endif
            #if DEBUG
            print("   audioService.isProcessingRecording: \(audioService.isProcessingRecording)")
            #endif
            #if DEBUG
            print("   Script in processing list: \(audioService.processingScriptIds.contains(script.id))")
            #endif
            // Could show a toast or visual indicator here
            return
        }
        
        // Check if recording exists
        guard script.hasRecording else {
            #if DEBUG
            print("   📦 No recording found for this script")
            #endif
            showingNoRecordingAlert = true
            return 
        }
        
        // Double-check the audio file actually exists on disk
        if !audioService.hasRecording(for: script) {
            #if DEBUG
            print("   ⚠️ Script thinks it has recording but file doesn't exist!")
            #endif
            #if DEBUG
            print("   audioFilePath: \(script.audioFilePath ?? "nil")")
            #endif
            #if DEBUG
            print("   audioDuration: \(script.audioDuration)")
            #endif
            showingNoRecordingAlert = true
            return
        }
        
        // Check if this script is in a playback session (including intervals)
        let isThisScriptInSession = audioService.isInPlaybackSession && audioService.currentPlayingScriptId == script.id
        #if DEBUG
        print("   Is in session: \(isThisScriptInSession)")
        #endif
        #if DEBUG
        print("   Audio session state: \(audioService.audioSessionState)")
        #endif
        
        if isThisScriptInSession {
            // We're in a playback session for this script
            if audioService.isPaused {
                #if DEBUG
                print("   ▶️ Resuming paused playback")
                #endif
                audioService.resumePlayback()
            } else {
                #if DEBUG
                print("   ⏸ Pausing playback")
                #endif
                audioService.pausePlayback()
            }
        } else {
            // Start new playback
            #if DEBUG
            print("   🎵 Starting new playback")
            #endif
            do {
                try audioService.play(script: script)
                #if DEBUG
                print("   ✅ Playback started successfully")
                #endif
            } catch AudioServiceError.privateModeActive {
                showingPrivateAlert = true
            } catch {
                #if DEBUG
                print("⚠️ ScriptCard: Initial playback failed: \(error)")
                #endif
                
                // For simulator error -50 or state issues, retry with a brief delay
                let shouldRetry = (error as NSError).code == -50 || 
                                 error.localizedDescription.contains("Preparing to Play")
                
                if shouldRetry {
                    #if DEBUG
                    print("   Retrying playback after delay...")
                    #endif
                    // Give audio session more time to reset on real device
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        do {
                            try audioService.play(script: script)
                            #if DEBUG
                            print("✅ ScriptCard: Retry successful")
                            #endif
                        } catch AudioServiceError.privateModeActive {
                            showingPrivateAlert = true
                        } catch {
                            #if DEBUG
                            print("🔴 ScriptCard: Retry failed: \(error)")
                            #endif
                            // Only show error for non-simulator issues
                            if (error as NSError).code != -50 {
                                errorMessage = NSLocalizedString("error.playback.unable", comment: "Unable to play audio. Please try again.")
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