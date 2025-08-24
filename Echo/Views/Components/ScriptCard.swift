import SwiftUI
import CoreData
import UIKit

struct ScriptCard: View {
    @ObservedObject var script: SelftalkScript
    @StateObject private var audioService = AudioCoordinator.shared
    @State private var showingPrivacyAlert = false
    @State private var showingNoRecordingAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isPressed = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    
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
                
                if script.notificationEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(cardAccentColor)
                }
                
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
            } else if isProcessing {
                // Show processing indicator
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                    Text("Processing...")
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
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                shareScript()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            if audioService.hasRecording(for: script) {
                Button(role: .destructive) {
                    audioService.deleteRecording(for: script)
                } label: {
                    Label("Delete Recording", systemImage: "mic.slash")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Privacy Mode", isPresented: $showingPrivacyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please connect earphones to play this audio")
        }
        .alert("No Recording", isPresented: $showingNoRecordingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please long press to edit and record audio first")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleTap() {
        // DEFENSIVE: Check script validity first
        guard isScriptValid else { return }
        
        // If processing, do nothing - wait for it to complete
        if isProcessing {
            return
        }
        
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
                // Silently retry once after a brief delay instead of showing error immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    do {
                        try audioService.play(script: script)
                    } catch AudioServiceError.privacyModeActive {
                        showingPrivacyAlert = true
                    } catch {
                        // Only show error if retry also fails
                        // Could also just ignore and let user tap again
                        print("Playback failed after retry: \(error)")
                        // Optionally show error only for critical failures
                        if (error as NSError).code != -50 {
                            errorMessage = "Unable to play audio. Please try again."
                            showingErrorAlert = true
                        }
                    }
                }
            }
        }
    }
    
    private func shareScript() {
        guard isScriptValid else { return }
        
        let exportService = ExportService()
        
        do {
            // Export script with audio if available
            let hasAudio = audioService.hasRecording(for: script)
            exportURL = try exportService.exportScript(script, includeAudio: hasAudio)
            showingShareSheet = true
        } catch {
            errorMessage = "Failed to export script: \(error.localizedDescription)"
            showingErrorAlert = true
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
            onEdit: { }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}