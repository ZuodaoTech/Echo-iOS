import SwiftUI
import CoreData

struct ScriptCard: View {
    @ObservedObject var script: SelftalkScript
    @StateObject private var audioService = AudioService.shared
    @State private var showingDeleteAlert = false
    @State private var showingPrivacyAlert = false
    
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
            
            // Recording Status Indicator
            if !script.hasRecording {
                HStack {
                    Image(systemName: "mic.slash")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Tap and hold to record")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.top, 4)
            }
            
            // Playback Progress (if playing or paused)
            if isPlaying || isPaused {
                VStack(spacing: 4) {
                    HStack {
                        ProgressView(value: audioService.playbackProgress)
                            .tint(.blue)
                            .animation(.linear, value: audioService.playbackProgress)
                        
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
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
    }
    
    private func handleTap() {
        guard script.hasRecording else { return }
        
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