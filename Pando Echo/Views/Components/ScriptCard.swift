import SwiftUI
import CoreData

struct ScriptCard: View {
    @ObservedObject var script: SelftalkScript
    @StateObject private var audioService = AudioService.shared
    @State private var showingDeleteAlert = false
    @State private var showingPrivacyAlert = false
    @State private var showingNoRecordingAlert = false
    
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    private var isPlaying: Bool {
        audioService.isPlaying && audioService.currentPlayingScriptId == script.id
    }
    
    private var isPaused: Bool {
        audioService.isPaused && audioService.currentPlayingScriptId == script.id
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
                            .tint(.blue)
                            .animation(.linear(duration: 0.02), value: progressValue)
                            .onAppear {
                                if showingInterval {
                                    print("ScriptCard: Showing interval progress: \(audioService.intervalProgress)")
                                }
                            }
                        
                        if isPaused {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if audioService.totalRepetitions > 1 {
                        Text("Repetition \(audioService.currentRepetition) of \(audioService.totalRepetitions)")
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
                .fill(isPlaying || isPaused ? Color.blue.opacity(0.05) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPlaying || isPaused ? Color.blue.opacity(0.3) : Color(.systemGray5), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
            Text("Please tap and hold the card in Edit mode to record audio first")
        }
    }
    
    private func handleTap() {
        guard script.hasRecording else { 
            showingNoRecordingAlert = true
            return 
        }
        
        if isPlaying {
            audioService.pausePlayback()
        } else if isPaused {
            // Resume from paused position
            audioService.resumePlayback()
        } else {
            // Start new playback
            do {
                try audioService.play(script: script)
            } catch AudioServiceError.privacyModeActive {
                showingPrivacyAlert = true
            } catch {
                print("Playback error: \(error)")
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