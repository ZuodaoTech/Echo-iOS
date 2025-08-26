import SwiftUI
import CoreData
import AVFoundation
import UIKit

// Preference key for dynamic height calculation
struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct AddEditScriptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService = AudioCoordinator.shared
    
    let script: SelftalkScript?
    let onDelete: ((UUID) -> Void)?  // Callback with script ID only (safer)
    
    @State private var scriptText = ""
    @State private var selectedTags: Set<Tag> = []
    @State private var repetitions: Int16 = 3
    @State private var intervalSeconds: Double = 2.0
    @State private var privateModeEnabled = true
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    @State private var transcriptionLanguage = ""
    @State private var notificationEnabled = false
    @State private var notificationFrequency = "medium"
    @State private var isRecording = false
    @State private var hasRecording = false
    @State private var isProcessingAudio = false
    @State private var transcriptCheckTimer: Timer? = nil
    @State private var isRetranscribing = false
    @State private var showingMicPermissionAlert = false
    @State private var showingPrivateAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var hasSavedOnDismiss = false
    
    // Character guidance
    @AppStorage("characterGuidanceEnabled") private var characterGuidanceEnabled = true
    @AppStorage("characterLimit") private var characterLimit = 140
    @AppStorage("limitBehavior") private var limitBehavior = "warn"
    @State private var textEditorHeight: CGFloat = 120
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>
    
    // Custom initializer to make onDelete optional
    init(script: SelftalkScript? = nil, onDelete: ((UUID) -> Void)? = nil) {
        self.script = script
        self.onDelete = onDelete
    }
    
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
                Section(NSLocalizedString("script.label", comment: "")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            // Invisible text for height calculation
                            Text(scriptText.isEmpty ? "Placeholder\nPlaceholder\nPlaceholder\nPlaceholder\nPlaceholder\nPlaceholder" : scriptText)
                                .font(.body)
                                .opacity(0)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: ViewHeightKey.self,
                                            value: geometry.size.height
                                        )
                                    }
                                )
                            
                            TextEditor(text: $scriptText)
                                .frame(minHeight: 120, maxHeight: max(120, min(textEditorHeight, 240)))
                                .overlay(
                                    Group {
                                        if scriptText.isEmpty {
                                            Text(NSLocalizedString("guidance.enter_script", comment: ""))
                                                .foregroundColor(.secondary)
                                                .padding(.top, 8)
                                                .padding(.leading, 4)
                                                .allowsHitTesting(false)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        .onPreferenceChange(ViewHeightKey.self) { height in
                            textEditorHeight = height + 16 // Add padding
                        }
                        
                        // Character counter and guidance
                        if characterGuidanceEnabled {
                            HStack {
                                // Visual progress indicator
                                HStack(spacing: 2) {
                                    ForEach(0..<10, id: \.self) { index in
                                        Rectangle()
                                            .fill(characterCounterColor(for: index))
                                            .frame(width: 15, height: 4)
                                            .cornerRadius(2)
                                    }
                                }
                                
                                Spacer()
                                
                                // Character count
                                Text("\(scriptText.count)/\(characterLimit)")
                                    .font(.caption)
                                    .foregroundColor(characterCounterTextColor)
                            }
                            
                            // Tip based on character count
                            if scriptText.count > characterLimit && limitBehavior == "warn" {
                                HStack {
                                    Image(systemName: "lightbulb")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(characterGuidanceTip)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                if isEditing {
                    Section(NSLocalizedString("script.recording", comment: "")) {
                        // Transcription Language Picker
                        VStack(alignment: .leading, spacing: 4) {
                            Picker(NSLocalizedString("settings.transcription", comment: ""), selection: $transcriptionLanguage) {
                                Text("English").tag("en-US")
                                Text("中文 (简体)").tag("zh-CN")
                                Text("中文 (繁體)").tag("zh-TW")
                                Text("Español").tag("es-ES")
                                Text("Français").tag("fr-FR")
                                Text("Deutsch").tag("de-DE")
                                Text("日本語").tag("ja-JP")
                                Text("한국어").tag("ko-KR")
                                Text("Português").tag("pt-BR")
                                Text("Русский").tag("ru-RU")
                                Text("Italiano").tag("it-IT")
                                Text("Nederlands").tag("nl-NL")
                                Text("Svenska").tag("sv-SE")
                                Text("Norsk").tag("nb-NO")
                                Text("Dansk").tag("da-DK")
                                Text("Polski").tag("pl-PL")
                                Text("Türkçe").tag("tr-TR")
                                Text("العربية").tag("ar-SA")
                                Text("हिन्दी").tag("hi-IN")
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
                                Text(NSLocalizedString("recording.punctuation_tip", comment: ""))
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
                            voiceActivityLevel: audioService.voiceActivityLevel,
                            onRecord: handleRecording,
                            onDelete: deleteRecording,
                            onPlay: handlePlayPreview
                        )
                        
                        // Show transcript if available or re-transcribing
                        if hasRecording && (isRetranscribing || (script?.transcribedText != nil && !(script?.transcribedText?.isEmpty ?? true))) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label(NSLocalizedString("script.transcript", comment: ""), systemImage: "text.quote")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    if isRetranscribing {
                                        Spacer()
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text(NSLocalizedString("recording.re_transcribing", comment: ""))
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
                                                Text(NSLocalizedString("action.copy", comment: ""))
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
                                                Text(NSLocalizedString("action.use_as_script", comment: ""))
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
                
                Section(NSLocalizedString("settings.default_settings", comment: "")) {
                    // Tag Selection
                    NavigationLink {
                        TagSelectionView(selectedTags: $selectedTags, currentScript: script)
                            .navigationTitle(NSLocalizedString("tag.select", comment: ""))
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text(NSLocalizedString("tag.label", comment: ""))
                            Spacer()
                            if selectedTags.isEmpty {
                                Text(NSLocalizedString("tag.none", comment: ""))
                                    .foregroundColor(.secondary)
                            } else {
                                Text(String(format: NSLocalizedString("tag.count_selected", comment: ""), selectedTags.count))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Repetitions Stepper
                    Stepper(value: $repetitions, in: 1...10) {
                        HStack {
                            Text(NSLocalizedString("script.repetitions", comment: ""))
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
                    
                    // Private Mode Toggle
                    Toggle(isOn: $privateModeEnabled) {
                        HStack {
                            Text(NSLocalizedString("script.private_mode", comment: ""))
                            Button {
                                showingPrivateAlert = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .onChange(of: privateModeEnabled) { newValue in
                        // Apply private mode change immediately
                        if let script = script {
                            script.privateModeEnabled = newValue
                            do {
                                try viewContext.save()
                            } catch {
                                print("Failed to save private mode change: \(error)")
                            }
                        }
                    }
                    
                    // Notification Settings
                    Toggle(NSLocalizedString("notifications.enable", comment: ""), isOn: $notificationEnabled)
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
                            Picker(NSLocalizedString("notifications.frequency", comment: ""), selection: $notificationFrequency) {
                                Text(NSLocalizedString("notifications.frequency.high", comment: "")).tag("high")
                                Text(NSLocalizedString("notifications.frequency.medium", comment: "")).tag("medium")
                                Text(NSLocalizedString("notifications.frequency.low", comment: "")).tag("low")
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
                            
                            Text(NSLocalizedString("notifications.daytime_only", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Delete Script Section - only show for existing scripts
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(NSLocalizedString("script.delete", comment: ""))
                                    .fontWeight(.medium)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? NSLocalizedString("navigation.edit_script", comment: "") : NSLocalizedString("navigation.new_script", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
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
            .alert(NSLocalizedString("recording.microphone_access", comment: ""), isPresented: $showingMicPermissionAlert) {
                Button(NSLocalizedString("action.ok", comment: "")) { }
            } message: {
                Text(NSLocalizedString("recording.microphone_access.message", comment: ""))
            }
            .alert(NSLocalizedString("settings.private_mode.title", comment: ""), isPresented: $showingPrivateAlert) {
                Button(NSLocalizedString("action.got_it", comment: ""), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("settings.private_mode.alert.message", comment: ""))
            }
            .alert(NSLocalizedString("script.delete.confirm.title", comment: ""), isPresented: $showingDeleteAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
                Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                    performDeletion()
                }
            } message: {
                Text(NSLocalizedString("script.delete.confirm.message", comment: ""))
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingErrorAlert) {
                Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
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
            selectedTags = Set(script.tagsArray)
            repetitions = script.repetitions
            intervalSeconds = script.intervalSeconds
            privateModeEnabled = script.privateModeEnabled
            notificationEnabled = script.notificationEnabled
            notificationFrequency = script.notificationFrequency ?? "medium"
            // Always use the default transcription language from Me Settings
            transcriptionLanguage = defaultTranscriptionLanguage
            hasRecording = script.hasRecording
        } else {
            // For new scripts, also use the default from Me Settings
            transcriptionLanguage = defaultTranscriptionLanguage
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
            // Update tags
            if let currentTags = existingScript.tags as? Set<Tag> {
                for tag in currentTags {
                    existingScript.removeFromTags(tag)
                }
            }
            for tag in selectedTags {
                existingScript.addToTags(tag)
            }
            existingScript.repetitions = repetitions
            existingScript.intervalSeconds = intervalSeconds
            existingScript.privateModeEnabled = privateModeEnabled
            existingScript.transcriptionLanguage = transcriptionLanguage
            existingScript.updatedAt = Date()
        } else if !trimmedText.isEmpty {
            // Create new script only if there's content
            let newScript = SelftalkScript.create(
                scriptText: trimmedText,
                repetitions: repetitions,
                intervalSeconds: intervalSeconds,
                privateMode: privateModeEnabled,
                in: viewContext
            )
            // Add selected tags
            for tag in selectedTags {
                newScript.addToTags(tag)
            }
            newScript.transcriptionLanguage = transcriptionLanguage
        }
        
        do {
            // Check if we have persistent stores
            if viewContext.persistentStoreCoordinator?.persistentStores.isEmpty ?? true {
                print("Warning: No persistent stores available")
                errorMessage = "Database not ready. Please restart the app."
                showingErrorAlert = true
                return false
            }
            
            if viewContext.hasChanges {
                try viewContext.save()
                print("Successfully saved script to Core Data")
            }
            return true
        } catch {
            print("Core Data save error: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Check if it's the persistent store error
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain {
                if nsError.code == 134030 { // NSManagedObjectContextSaveError
                    errorMessage = "Unable to save. Please restart the app."
                } else if nsError.code == 134060 { // NSPersistentStoreInvalidTypeError
                    errorMessage = "Database error. Please restart the app."
                } else {
                    errorMessage = "Failed to save script: \(error.localizedDescription)"
                }
            } else {
                errorMessage = "Failed to save script. Please try again."
            }
            
            showingErrorAlert = true
            return false
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
    
    private func performDeletion() {
        guard let script = script else { return }
        
        // Cache the script ID before dismissing (critical for safety)
        let scriptId = script.id
        let scriptPreview = String(script.scriptText.prefix(50))
        
        print("🗑️ Starting deletion process for script: \(scriptPreview)...")
        
        // CRITICAL: Dismiss the view FIRST to destroy all UI references
        dismiss()
        
        // Call the deletion callback after a small delay to ensure UI has settled
        if let onDelete = onDelete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("  📤 Calling deletion callback for script ID: \(scriptId)")
                onDelete(scriptId)
            }
        } else {
            print("  ⚠️ No deletion callback provided")
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
            } catch AudioServiceError.privateModeActive {
                showingPrivateAlert = true
            } catch {
                // Preview playback error
            }
        }
    }
    
    // MARK: - Character Guidance Helper Methods
    
    private func characterCounterColor(for index: Int) -> Color {
        let progress = Double(scriptText.count) / Double(characterLimit)
        let segmentThreshold = Double(index + 1) / 10.0
        
        if progress >= segmentThreshold {
            if scriptText.count <= characterLimit {
                // Within limit - green to yellow gradient
                if progress < 0.7 {
                    return .green
                } else if progress < 0.9 {
                    return .yellow
                } else {
                    return .orange
                }
            } else {
                // Over limit - red
                return .red
            }
        } else {
            // Not filled yet
            return Color(.systemGray5)
        }
    }
    
    private var characterCounterTextColor: Color {
        let count = scriptText.count
        if count <= characterLimit * 70 / 100 {
            return .secondary
        } else if count <= characterLimit {
            return .orange
        } else {
            return .red
        }
    }
    
    private var characterGuidanceTip: String {
        let overCount = scriptText.count - characterLimit
        if overCount <= 20 {
            return "Consider trimming \(overCount) characters for better memorability"
        } else if overCount <= 50 {
            return "Script is \(overCount) characters over. Try to be more concise"
        } else {
            return "Script is quite long."
        }
    }
    
    // MARK: - Notification Helper Methods
    
    private func checkAndEnforceNotificationLimit() {
        let maxNotificationCards = UserDefaults.standard.integer(forKey: "maxNotificationCards")
        let limit = maxNotificationCards > 0 ? maxNotificationCards : 1 // Default to 1 if not set
        
        // Fetch all scripts with notifications enabled, sorted by when they were enabled
        let request: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        request.predicate = NSPredicate(format: "notificationEnabled == YES AND id != %@", script?.id as CVarArg? ?? UUID() as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "notificationEnabledAt", ascending: true)]
        
        do {
            let scriptsWithNotifications = try viewContext.fetch(request)
            
            // If we're at or over the limit, disable the oldest
            if scriptsWithNotifications.count >= limit {
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
    let voiceActivityLevel: Float
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
                            Text(NSLocalizedString("recording.saved", comment: ""))
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
                            Text(NSLocalizedString("action.delete", comment: ""))
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
                            
                            Text(NSLocalizedString("recording.preview", comment: ""))
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
                                Text(isPlaying ? NSLocalizedString("recording.playing_preview", comment: "") : NSLocalizedString("recording.preview_paused", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(NSLocalizedString("recording.plays_once", comment: ""))
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
                    
                    Text(isRecording ? NSLocalizedString("recording.stop", comment: "") : (hasRecording ? NSLocalizedString("recording.re_record", comment: "") : NSLocalizedString("recording.start", comment: "")))
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
                let duration = Int(AudioCoordinator.shared.recordingDuration)
                let remainingTime = max(0, 60 - duration)
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.red)
                        Text(voiceActivityLevel > 0.1 ? NSLocalizedString("recording.speaking", comment: "") : NSLocalizedString("recording.listening", comment: ""))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Duration display with warning color
                        Text("\(duration)s / 60s")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(remainingTime <= 10 ? .orange : (remainingTime <= 5 ? .red : .secondary))
                    }
                    
                    // Voice activity indicator
                    GeometryReader { geometry in
                        HStack(spacing: 2) {
                            ForEach(0..<20) { index in
                                Rectangle()
                                    .fill(voiceActivityLevel > Float(index) / 20.0 ? Color.green : Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width / 22, height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 4)
                    }
                    .frame(height: 4)
                    .padding(.horizontal)
                    
                    // Warning message when approaching limit
                    if remainingTime <= 10 && remainingTime > 0 {
                        Text(String(format: NSLocalizedString("recording.time_warning", comment: ""), remainingTime))
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if remainingTime == 0 {
                        Text(NSLocalizedString("recording.max_duration_reached", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } else if isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(NSLocalizedString("recording.processing", comment: ""))
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
