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
    @State private var transcriptionLanguage = "en-US"  // Default to English instead of auto
    @State private var notificationEnabled = false
    @State private var notificationFrequency = "medium"
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var isRecording = false
    @State private var hasRecording = false
    @State private var isProcessingAudio = false
    @State private var transcriptCheckTimer: Timer? = nil
    @State private var isRetranscribing = false
    @State private var showingMicPermissionAlert = false
    @State private var showingPrivacyAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasSavedOnDismiss = false
    
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
                
                if isEditing {
                    Section("Recording") {
                        // Transcription Language Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Transcription Language", selection: $transcriptionLanguage) {
                                Text("English").tag("en-US")
                                Text("Chinese (Simplified)").tag("zh-CN")
                                Text("Chinese (Traditional)").tag("zh-TW")
                                Text("Spanish").tag("es-ES")
                                Text("French").tag("fr-FR")
                                Text("German").tag("de-DE")
                                Text("Japanese").tag("ja-JP")
                                Text("Korean").tag("ko-KR")
                                Text("Portuguese").tag("pt-BR")
                                Text("Russian").tag("ru-RU")
                                Text("Italian").tag("it-IT")
                                Text("Dutch").tag("nl-NL")
                                Text("Arabic").tag("ar-SA")
                                Text("Hindi").tag("hi-IN")
                            }
                            .onChange(of: transcriptionLanguage) { newValue in
                                // Save language preference and re-transcribe if there's an existing recording
                                if let script = script {
                                    let oldLanguage = script.transcriptionLanguage
                                    script.transcriptionLanguage = newValue
                                    
                                    do {
                                        try viewContext.save()
                                        
                                        // If there's a recording and language changed, re-transcribe
                                        if script.hasRecording && oldLanguage != newValue {
                                            retranscribeWithNewLanguage(script: script, language: newValue)
                                        }
                                    } catch {
                                        print("Failed to save transcription language: \(error)")
                                    }
                                }
                            }
                            .disabled(isRetranscribing) // Disable picker during re-transcription
                            
                            if #available(iOS 16, *) {
                                // iOS 16+ has automatic punctuation
                            } else {
                                Text("Tip: Say 'period', 'comma', or 'question mark' for punctuation")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        RecordingButton(
                            isRecording: $isRecording,
                            hasRecording: hasRecording,
                            isProcessing: isProcessingAudio || audioService.isProcessingRecording,
                            recordingDuration: script?.formattedDuration ?? "",
                            isPlaying: isPlaying,
                            isPaused: isPaused,
                            onRecord: handleRecording,
                            onDelete: deleteRecording,
                            onPlay: handlePlayPreview
                        )
                        
                        // Show transcript if available or re-transcribing
                        if hasRecording && (isRetranscribing || (script?.transcribedText != nil && !(script?.transcribedText?.isEmpty ?? true))) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Transcript", systemImage: "text.quote")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if isRetranscribing {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Re-transcribing...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if let transcript = script?.transcribedText, !transcript.isEmpty {
                                    Text(transcript)
                                        .font(.footnote)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.systemGray6))
                                        )
                                    
                                    HStack {
                                        Button {
                                            UIPasteboard.general.string = transcript
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "doc.on.doc")
                                                    .imageScale(.small)
                                                Text("Copy")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            if let script = script {
                                                scriptText = transcript
                                                script.scriptText = transcript
                                                do {
                                                    try viewContext.save()
                                                } catch {
                                                    print("Failed to update script text: \(error)")
                                                }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.up.doc")
                                                    .imageScale(.small)
                                                Text("Use as Script")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                    
                    // Notification Settings
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                        .onChange(of: notificationEnabled) { newValue in
                            if let script = script {
                                if newValue {
                                    // Check if we need to disable oldest notification
                                    checkAndEnforceNotificationLimit()
                                    script.notificationEnabledAt = Date()
                                } else {
                                    script.notificationEnabledAt = nil
                                }
                                script.notificationEnabled = newValue
                                do {
                                    try viewContext.save()
                                    if newValue {
                                        scheduleNotifications(for: script)
                                    } else {
                                        cancelNotifications(for: script)
                                    }
                                } catch {
                                    print("Failed to save notification setting: \(error)")
                                }
                            }
                        }
                    
                    if notificationEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Frequency", selection: $notificationFrequency) {
                                Text("High (1-2 times/hour)").tag("high")
                                Text("Medium (every 2 hours)").tag("medium")
                                Text("Low (1-2 times/day)").tag("low")
                            }
                            .pickerStyle(.menu)
                            .onChange(of: notificationFrequency) { newValue in
                                if let script = script {
                                    script.notificationFrequency = newValue
                                    do {
                                        try viewContext.save()
                                        // Reschedule with new frequency
                                        scheduleNotifications(for: script)
                                    } catch {
                                        print("Failed to save notification frequency: \(error)")
                                    }
                                }
                            }
                            
                            Text("Notifications only during daytime (8 AM - 9 PM)")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            setupInitialValues()
            // Check if this script is currently being processed
            if let script = script {
                isProcessingAudio = audioService.isProcessing(script: script)
            }
        }
        .onChange(of: audioService.processingScriptIds) { processingIds in
            // Check if our script's processing state changed
            if let script = script {
                isProcessingAudio = processingIds.contains(script.id)
                // If processing just completed for our script
                if !isProcessingAudio && hasRecording == false {
                    hasRecording = script.hasRecording
                }
            }
        }
        .onChange(of: audioService.isProcessingRecording) { isProcessing in
            // When processing completes, update hasRecording and start checking for transcript
            if !isProcessing && !audioService.isRecording {
                if let script = script {
                    hasRecording = script.hasRecording
                    
                    // Start a timer to check for transcript updates
                    transcriptCheckTimer?.invalidate()
                    transcriptCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                        // Force Core Data to refresh
                        viewContext.refresh(script, mergeChanges: true)
                        
                        // Stop checking after transcript appears or 10 seconds
                        if script.transcribedText != nil && !script.transcribedText!.isEmpty {
                            timer.invalidate()
                            transcriptCheckTimer = nil
                            print("Transcript detected in UI: \(script.transcribedText?.prefix(30) ?? "")")
                        } else if timer.fireDate.timeIntervalSinceNow < -10 {
                            timer.invalidate()
                            transcriptCheckTimer = nil
                            print("Transcript check timeout")
                        }
                    }
                }
            }
        }
        .onDisappear {
            transcriptCheckTimer?.invalidate()
            transcriptCheckTimer = nil
            // Stop any ongoing re-transcription
            isRetranscribing = false
        }
    }
    
    private func setupInitialValues() {
        if let script = script {
            scriptText = script.scriptText
            selectedCategory = script.category
            repetitions = script.repetitions
            intervalSeconds = script.intervalSeconds
            privacyModeEnabled = script.privacyModeEnabled
            notificationEnabled = script.notificationEnabled
            notificationFrequency = script.notificationFrequency ?? "medium"
            // If script has "auto" or nil, default to English
            if let lang = script.transcriptionLanguage, lang != "auto" {
                transcriptionLanguage = lang
            } else {
                transcriptionLanguage = "en-US"
            }
            hasRecording = script.hasRecording
        }
    }
    
    
    private func handleDone() {
        // Save and dismiss
        if saveScript() {
            hasSavedOnDismiss = true
            dismiss()
        }
    }
    
    private func autoSave() {
        // Stop recording if in progress
        if isRecording {
            audioService.stopRecording()
            isRecording = false
        }
        
        // Only save if we haven't already saved via Done button
        if !hasSavedOnDismiss {
            // Silently save changes if valid
            _ = saveScript()
        }
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
            existingScript.transcriptionLanguage = transcriptionLanguage
            existingScript.updatedAt = Date()
        } else if !trimmedText.isEmpty {
            // Create new script only if there's content
            let newScript = SelftalkScript.create(
                scriptText: trimmedText,
                category: selectedCategory,
                repetitions: repetitions,
                intervalSeconds: intervalSeconds,
                privacyMode: privacyModeEnabled,
                in: viewContext
            )
            newScript.transcriptionLanguage = transcriptionLanguage
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
    
    private func retranscribeWithNewLanguage(script: SelftalkScript, language: String) {
        guard script.hasRecording else { return }
        
        // Prevent multiple concurrent re-transcriptions
        guard !isRetranscribing else { 
            print("Re-transcription already in progress, skipping")
            return 
        }
        
        // Clear existing transcript and start re-transcription
        isRetranscribing = true
        script.transcribedText = nil
        
        // Add a small delay to let the file system settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Get the audio processing service through the coordinator
            let processingService = AudioProcessingService(fileManager: AudioFileManager())
            
            processingService.transcribeRecording(for: script.id, languageCode: language) { transcription in
                DispatchQueue.main.async {
                    // Ensure we're still in re-transcribing state (could have been cancelled)
                    guard self.isRetranscribing else { return }
                    
                    if let transcription = transcription {
                        script.transcribedText = transcription
                        do {
                            try self.viewContext.save()
                            print("Re-transcription completed with new language: \(language)")
                        } catch {
                            print("Failed to save re-transcription: \(error)")
                        }
                    } else {
                        print("Re-transcription failed for language: \(language)")
                    }
                    self.isRetranscribing = false
                }
            }
        }
    }
    
    private func handleRecording() {
        guard let script = script else { return }
        
        // Don't allow recording if already processing
        if isProcessingAudio {
            return
        }
        
        if isRecording {
            audioService.stopRecording()
            isRecording = false
            // Don't set hasRecording immediately - wait for processing
        } else {
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
    
    // MARK: - Notification Helper Methods
    
    private func checkAndEnforceNotificationLimit() {
        // Fetch all scripts with notifications enabled, sorted by when they were enabled
        let request: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        request.predicate = NSPredicate(format: "notificationEnabled == YES AND id != %@", script?.id as CVarArg? ?? UUID() as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "notificationEnabledAt", ascending: true)]
        
        do {
            let scriptsWithNotifications = try viewContext.fetch(request)
            
            // If there are already 3 or more scripts with notifications, disable the oldest
            if scriptsWithNotifications.count >= 3 {
                if let oldestScript = scriptsWithNotifications.first {
                    oldestScript.notificationEnabled = false
                    oldestScript.notificationEnabledAt = nil
                    cancelNotifications(for: oldestScript)
                    print("Disabled notifications for oldest script: \(oldestScript.scriptText.prefix(20))...")
                }
            }
        } catch {
            print("Failed to check notification limit: \(error)")
        }
    }
    
    private func scheduleNotifications(for script: SelftalkScript) {
        NotificationManager.shared.scheduleNotifications(for: script)
    }
    
    private func cancelNotifications(for script: SelftalkScript) {
        NotificationManager.shared.cancelNotifications(for: script)
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