import SwiftUI
import CoreData

struct ScriptCard: View {
    @ObservedObject var script: SelftalkScript
    @StateObject private var audioService = AudioService.shared
    @State private var showingDeleteAlert = false
    @State private var showingPrivacyAlert = false
    @State private var showingNoRecordingAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    private var isPlaying: Bool {
        audioService.isPlaying && audioService.currentPlayingScriptId == script.id
    }
    
    private var isPaused: Bool {
        audioService.isPaused && audioService.currentPlayingScriptId == script.id
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
        let index = abs(script.id.hashValue) % colorPalette.count
        return colorPalette[index]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category and Repetitions Header
            HStack {
                if let category = script.category {
                    Text(category.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("\(script.repetitions)x")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if script.privacyModeEnabled {
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
                .fill(isPlaying || isPaused ? cardAccentColor.opacity(0.08) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isPlaying || isPaused ? cardAccentColor.opacity(0.5) : cardAccentColor.opacity(0.25),
                            lineWidth: isPlaying || isPaused ? 1.5 : 1
                        )
                )
        )
        .shadow(color: cardAccentColor.opacity(0.15), radius: 8, x: 0, y: 3)
        .shadow(color: cardAccentColor.opacity(0.05), radius: 2, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .alert("Privacy Mode", isPresented: $showingPrivacyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please connect earphones to play this audio")
        }
        .alert("Delete Script", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this script? This action cannot be undone.")
        }
        .alert("No Recording", isPresented: $showingNoRecordingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please swipe left to edit and record audio first")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleTap() {
        guard script.hasRecording else { 
            showingNoRecordingAlert = true
            return 
        }
        
        // Check if this script is in a playback session (including intervals)
        let isThisScriptInSession = audioService.isInPlaybackSession && audioService.currentPlayingScriptId == script.id
        
        if isThisScriptInSession {
            // We're in a playback session for this script
            if audioService.isPaused {
                // Resume from paused position
                audioService.resumePlayback()
            } else {
                // Pause (works during playback or intervals)
                audioService.pausePlayback()
            }
        } else {
            // Start new playback
            do {
                try audioService.play(script: script)
            } catch AudioServiceError.privacyModeActive {
                showingPrivacyAlert = true
            } catch {
                errorMessage = "Unable to play audio. Please try again."
                showingErrorAlert = true
            }
        }
    }
}

struct ScriptCard_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let script = SelftalkScript.create(
            scriptText: "I am confident and capable of achieving my goals. Every day I grow stronger and more resilient.",
            category: nil,
            repetitions: 3,
            privacyMode: true,
            in: context
        )
        
        return ScriptCard(
            script: script,
            onEdit: { },
            onDelete: { }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}