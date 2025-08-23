import SwiftUI
import CoreData
import AVFoundation
import UIKit

struct AddEditScriptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService = AudioCoordinator.shared
    
    let script: SelftalkScript?
    
    @State private var scriptText = ""
    @State private var selectedCategory: Category?
    @State private var repetitions: Int16 = 3
    @State private var intervalSeconds: Double = 2.0
    @State private var privacyModeEnabled = true
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var isRecording = false
    @State private var hasRecording = false
    @State private var isProcessingRecording = false
    @State private var originalScriptBeforeTranscript: String? = nil
    @State private var showingMicPermissionAlert = false
    @State private var showingPrivacyAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>
    
    private var isEditing: Bool {
        script != nil
    }
    
    private var isPlaying: Bool {
        audioService.isPlaying && audioService.currentPlayingScriptId == script?.id
    }
    
    private var isPaused: Bool {
        audioService.isPaused && audioService.currentPlayingScriptId == script?.id
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Script") {
                    TextEditor(text: $scriptText)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if scriptText.isEmpty {
                                    Text("Enter your self-talk script here...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("Settings") {
                    // Category Picker
                    HStack {
                        Text("Category")
                        Spacer()
                        Menu {
                            ForEach(categories, id: \.id) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    if selectedCategory == category {
                                        Label(category.name, systemImage: "checkmark")
                                    } else {
                                        Text(category.name)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button {
                                showingNewCategoryAlert = true
                            } label: {
                                Label("Add New Category...", systemImage: "plus")
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory?.name ?? "Select Category")
                                    .foregroundColor(selectedCategory == nil ? .secondary : .primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Repetitions Stepper
                    Stepper(value: $repetitions, in: 1...10) {
                        HStack {
                            Text("Repetitions")
                            Spacer()
                            Text("\(repetitions)x")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: repetitions) { newValue in
                        // Apply repetitions change immediately
                        if let script = script {
                            script.repetitions = newValue
                            do {
                                try viewContext.save()
                            } catch {
                                print("Failed to save repetitions change: \(error)")
                            }
                        }
                    }
                    
                    // Privacy Mode Toggle
                    Toggle("Privacy Mode", isOn: $privacyModeEnabled)
                        .onChange(of: privacyModeEnabled) { newValue in
                            // Apply privacy mode change immediately
                            if let script = script {
                                script.privacyModeEnabled = newValue
                                do {
                                    try viewContext.save()
                                } catch {
                                    print("Failed to save privacy mode change: \(error)")
                                }
                            }
                        }
                    
                    if privacyModeEnabled {
                        Text("Audio will only play when earphones are connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isEditing {
                    Section("Recording") {
                        RecordingButton(
                            isRecording: $isRecording,
                            hasRecording: hasRecording,
                            isProcessing: audioService.isProcessingRecording,
                            recordingDuration: script?.formattedDuration ?? "",
                            isPlaying: isPlaying,
                            isPaused: isPaused,
                            onRecord: handleRecording,
                            onDelete: deleteRecording,
                            onPlay: handlePlayPreview
                        )
                        
                        // Show transcript if available
                        if hasRecording, let transcript = script?.transcribedText, !transcript.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Transcript", systemImage: "text.quote")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(transcript)
                                    .font(.footnote)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                                
                                HStack {
                                    // Show "Use as Script" if transcript differs from current script
                                    if scriptText != transcript {
                                        Button {
                                            // Save original before replacing
                                            if originalScriptBeforeTranscript == nil {
                                                originalScriptBeforeTranscript = scriptText
                                            }
                                            // Replace script text with transcript
                                            scriptText = transcript
                                            // Save immediately
                                            if let script = script {
                                                script.scriptText = transcript
                                                script.updatedAt = Date()
                                                do {
                                                    try viewContext.save()
                                                } catch {
                                                    print("Failed to save transcript as script: \(error)")
                                                }
                                            }
                                        } label: {
                                            Label("Use as Script", systemImage: "doc.text.fill")
                                                .font(.footnote)
                                                .foregroundColor(.white)
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    
                                    // Show "Undo" button if we have an original to revert to
                                    if let original = originalScriptBeforeTranscript, scriptText == transcript {
                                        Button {
                                            // Revert to original
                                            scriptText = original
                                            // Save immediately
                                            if let script = script {
                                                script.scriptText = original
                                                script.updatedAt = Date()
                                                do {
                                                    try viewContext.save()
                                                } catch {
                                                    print("Failed to revert script: \(error)")
                                                }
                                            }
                                            // Clear the stored original
                                            originalScriptBeforeTranscript = nil
                                        } label: {
                                            Label("Undo", systemImage: "arrow.uturn.backward")
                                                .font(.footnote)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.orange)
                                    }
                                    
                                    Button {
                                        // Copy to clipboard
                                        UIPasteboard.general.string = transcript
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.footnote)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        
                        if hasRecording {
                            VStack(alignment: .leading, spacing: 8) {
                                // Interval slider
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pause between repetitions: \(Int(intervalSeconds)) second\(Int(intervalSeconds) == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $intervalSeconds, in: 1...3, step: 1)
                                        .onChange(of: intervalSeconds) { newValue in
                                            // Apply interval change immediately
                                            if let script = script {
                                                script.intervalSeconds = newValue
                                                do {
                                                    try viewContext.save()
                                                } catch {
                                                    print("Failed to save interval change: \(error)")
                                                }
                                            }
                                        }
                                }
                                
                                // Duration info
                                HStack {
                                    Label("Total duration", systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(calculateTotalDuration())
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
                
                // Delete button - only for existing scripts
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Script")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Script" : "New Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        handleDone()
                    }
                    .font(.body.weight(.medium))
                }
            }
            .interactiveDismissDisabled(false)
            .onDisappear {
                // Auto-save when view disappears (including swipe down)
                autoSave()
            }
            .alert("New Category", isPresented: $showingNewCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Add") {
                    createNewCategory()
                }
            } message: {
                Text("Enter the name for your new category")
            }
            .alert("Microphone Access", isPresented: $showingMicPermissionAlert) {
                Button("OK") { }
            } message: {
                Text("Please grant microphone access in Settings to record audio")
            }
            .alert("Privacy Mode", isPresented: $showingPrivacyAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please connect earphones to play this audio")
            }
            .alert("Delete Script", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteScript()
                }
            } message: {
                Text("Are you sure you want to delete this script? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .onChange(of: audioService.isProcessingRecording) { isProcessing in
            // When processing completes, update hasRecording
            if !isProcessing && !audioService.isRecording {
                if let script = script {
                    hasRecording = script.hasRecording
                }
            }
        }
    }
    
    private func setupInitialValues() {
        if let script = script {
            scriptText = script.scriptText
            selectedCategory = script.category
            repetitions = script.repetitions
            intervalSeconds = script.intervalSeconds
            privacyModeEnabled = script.privacyModeEnabled
            hasRecording = script.hasRecording
        }
    }
    
    private func calculateTotalDuration() -> String {
        guard let script = script, script.audioDuration > 0 else { return "—" }
        
        let totalAudioTime = Double(repetitions) * script.audioDuration
        let totalIntervalTime = Double(repetitions - 1) * intervalSeconds
        let total = totalAudioTime + totalIntervalTime
        
        let mins = Int(total) / 60
        let secs = Int(total) % 60
        
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private func handleDone() {
        // Save and dismiss
        if saveScript() {
            dismiss()
        }
    }
    
    private func autoSave() {
        // Stop recording if in progress
        if isRecording {
            audioService.stopRecording()
            isRecording = false
        }
        
        // Silently save changes if valid
        _ = saveScript()
    }
    
    @discardableResult
    private func saveScript() -> Bool {
        let trimmedText = scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For new scripts, only save if there's content
        if !isEditing && trimmedText.isEmpty {
            return true // Allow dismissal but don't create empty script
        }
        
        // For existing scripts, always save (even if emptied - user can delete if needed)
        if let existingScript = script {
            // Update existing script
            existingScript.scriptText = trimmedText.isEmpty ? existingScript.scriptText : trimmedText
            existingScript.category = selectedCategory
            existingScript.repetitions = repetitions
            existingScript.intervalSeconds = intervalSeconds
            existingScript.privacyModeEnabled = privacyModeEnabled
            existingScript.updatedAt = Date()
        } else if !trimmedText.isEmpty {
            // Create new script only if there's content
            _ = SelftalkScript.create(
                scriptText: trimmedText,
                category: selectedCategory,
                repetitions: repetitions,
                intervalSeconds: intervalSeconds,
                privacyMode: privacyModeEnabled,
                in: viewContext
            )
        }
        
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
            return true
        } catch {
            errorMessage = "Failed to save script. Please try again."
            showingErrorAlert = true
            return false
        }
    }
    
    private func createNewCategory() {
        guard !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = newCategoryName
        category.createdAt = Date()
        category.sortOrder = Int32(categories.count)
        
        do {
            try viewContext.save()
            selectedCategory = category
            newCategoryName = ""
        } catch {
            errorMessage = "Failed to create category. Please try again."
            showingErrorAlert = true
        }
    }
    
    private func handleRecording() {
        guard let script = script else { return }
        
        if isRecording {
            audioService.stopRecording()
            isRecording = false
            // Don't set hasRecording immediately - wait for processing
        } else {
            // Clear any stored original when making a new recording
            originalScriptBeforeTranscript = nil
            audioService.requestMicrophonePermission { granted in
                if granted {
                    do {
                        try audioService.startRecording(for: script)
                        isRecording = true
                    } catch {
                        errorMessage = "Failed to start recording. Please check microphone permissions."
                        showingErrorAlert = true
                    }
                } else {
                    showingMicPermissionAlert = true
                }
            }
        }
    }
    
    private func deleteRecording() {
        guard let script = script else { return }
        audioService.deleteRecording(for: script)
        hasRecording = false  // Update state to reflect deletion
    }
    
    private func deleteScript() {
        guard let script = script else { return }
        
        // Stop any playback
        audioService.stopPlayback()
        
        // Delete the recording file if it exists
        audioService.deleteRecording(for: script)
        
        // Delete the script from Core Data
        viewContext.delete(script)
        
        do {
            try viewContext.save()
            dismiss()  // Close the edit view after deletion
        } catch {
            errorMessage = "Failed to delete script. Please try again."
            showingErrorAlert = true
        }
    }
    
    private func handlePlayPreview() {
        guard let script = script else { return }
        
        if isPlaying {
            audioService.pausePlayback()
        } else if isPaused {
            audioService.resumePlayback()
        } else {
            // Start new playback with single repetition for preview
            do {
                // Temporarily set repetitions to 1 for preview
                let originalRepetitions = script.repetitions
                script.repetitions = 1
                
                try audioService.play(script: script)
                
                // Restore original repetitions
                script.repetitions = originalRepetitions
            } catch AudioServiceError.privacyModeActive {
                showingPrivacyAlert = true
            } catch {
                // Preview playback error
            }
        }
    }
}

struct RecordingButton: View {
    @Binding var isRecording: Bool
    let hasRecording: Bool
    let isProcessing: Bool
    let recordingDuration: String
    let isPlaying: Bool
    let isPaused: Bool
    let onRecord: () -> Void
    let onDelete: () -> Void
    let onPlay: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if hasRecording && !isRecording {
                VStack(spacing: 12) {
                    // Recording info and delete button
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)  // Standardized size
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recording saved")
                                .foregroundColor(.secondary)
                            if !recordingDuration.isEmpty {
                                Text(recordingDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        
                        Button {
                            onDelete()
                        } label: {
                            Text("Delete")
                                .font(.callout)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Play/Pause preview button - separate and prominent
                    Button {
                        onPlay()
                    } label: {
                        HStack {
                            Image(systemName: isPlaying ? "pause.circle.fill" : (isPaused ? "play.circle.fill" : "play.circle.fill"))
                                .font(.title2)  // Standardized size
                            
                            Text("Preview")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isPlaying || isPaused ? Color.blue.opacity(0.15) : Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Show progress bar when playing
                    if isPlaying || isPaused {
                        VStack(spacing: 4) {
                            ProgressView(value: AudioService.shared.playbackProgress)
                                .tint(.blue)
                            
                            HStack {
                                Text(isPlaying ? "Playing preview..." : "Preview paused")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("(plays once)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Button {
                onRecord()
            } label: {
                HStack {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .blue)
                    
                    Text(isRecording ? "Stop Recording" : (hasRecording ? "Re-record" : "Start Recording"))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isRecording {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.red)
                    Text("Recording...")
                        .foregroundColor(.secondary)
                }
            } else if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing audio...")
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct AddEditScriptView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditScriptView(script: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}