import SwiftUI
import CoreData
import Combine

/// ViewModel for AddEditScriptView - handles all business logic and state management
class AddEditScriptViewModel: ObservableObject {
    // MARK: - View State
    enum ViewState: Equatable {
        case idle
        case recording
        case processing
        case saving
        case error(String)
    }
    
    // MARK: - Validation Error
    enum ValidationError: LocalizedError {
        case emptyScript
        case scriptTooShort(minLength: Int)
        case scriptTooLong(maxLength: Int)
        case exceedsCharacterLimit(limit: Int)
        case audioTooShort
        case audioTooLong
        case audioProcessing
        case recordingInProgress
        
        var errorDescription: String? {
            switch self {
            case .emptyScript:
                return NSLocalizedString("validation.empty_script", comment: "")
            case .scriptTooShort(let minLength):
                return String(format: NSLocalizedString("validation.script_too_short", comment: ""), minLength)
            case .scriptTooLong(let maxLength):
                return String(format: NSLocalizedString("validation.script_too_long", comment: ""), maxLength)
            case .exceedsCharacterLimit(let limit):
                return String(format: NSLocalizedString("validation.exceeds_character_limit", comment: ""), limit)
            case .audioTooShort:
                return NSLocalizedString("validation.audio_too_short", comment: "")
            case .audioTooLong:
                return NSLocalizedString("validation.audio_too_long", comment: "")
            case .audioProcessing:
                return NSLocalizedString("validation.audio_processing", comment: "")
            case .recordingInProgress:
                return NSLocalizedString("validation.recording_in_progress", comment: "")
            }
        }
    }
    
    // MARK: - Published Properties
    @Published var viewState: ViewState = .idle
    @Published var scriptText = ""
    @Published var selectedTags: Set<Tag> = []
    @Published var repetitions: Int16 = 3
    @Published var intervalSeconds: Double = 2.0
    @Published var privateModeEnabled = true
    @Published var transcriptionLanguage = ""
    @Published var notificationEnabled = false
    @Published var notificationFrequency = "medium"
    
    // Recording states
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var isProcessingAudio = false
    @Published var isRetranscribing = false
    
    // MARK: - Constants
    private enum Constants {
        static let minimumScriptLength = 1
        static let maximumScriptLength = 500
        static let minimumAudioDuration: TimeInterval = 1.0
        static let maximumAudioDuration: TimeInterval = 60.0
    }
    
    // MARK: - Dependencies
    private let viewContext: NSManagedObjectContext
    private let audioService: AudioCoordinator
    private let script: SelftalkScript?
    
    // MARK: - User Defaults
    private var characterGuidanceEnabled: Bool {
        UserDefaults.standard.bool(forKey: "characterGuidanceEnabled")
    }
    
    private var characterLimit: Int {
        UserDefaults.standard.integer(forKey: "characterLimit")
    }
    
    private var limitBehavior: String {
        UserDefaults.standard.string(forKey: "limitBehavior") ?? "warn"
    }
    
    private var defaultRepetitions: Int16 {
        Int16(UserDefaults.standard.integer(forKey: "defaultRepetitions"))
    }
    
    private var defaultInterval: Double {
        UserDefaults.standard.double(forKey: "defaultInterval")
    }
    
    private var privateModeDefault: Bool {
        UserDefaults.standard.bool(forKey: "privateModeDefault")
    }
    
    private var defaultTranscriptionLanguage: String {
        UserDefaults.standard.string(forKey: "defaultTranscriptionLanguage") ?? "en-US"
    }
    
    // MARK: - Computed Properties
    var isEditing: Bool {
        script != nil
    }
    
    var isPlaying: Bool {
        audioService.isPlaying && audioService.currentPlayingScriptId == script?.id
    }
    
    var isPaused: Bool {
        audioService.isPaused && audioService.currentPlayingScriptId == script?.id
    }
    
    var canSave: Bool {
        viewState != .saving && viewState != .processing && !isProcessingAudio && !audioService.isProcessingRecording
    }
    
    // MARK: - Initialization
    init(script: SelftalkScript? = nil, context: NSManagedObjectContext) {
        self.script = script
        self.viewContext = context
        self.audioService = AudioCoordinator.shared
        
        setupInitialValues()
    }
    
    // MARK: - Setup
    private func setupInitialValues() {
        if let script = script {
            // Edit mode - load existing values
            scriptText = script.scriptText
            repetitions = script.repetitions
            intervalSeconds = script.intervalSeconds
            privateModeEnabled = script.privateModeEnabled
            transcriptionLanguage = script.transcriptionLanguage ?? defaultTranscriptionLanguage
            notificationEnabled = script.notificationEnabled
            notificationFrequency = script.notificationFrequency ?? "medium"
            hasRecording = script.hasRecording
            
            // Load tags
            if let tags = script.tags as? Set<Tag> {
                selectedTags = tags
            }
        } else {
            // Add mode - use defaults
            repetitions = defaultRepetitions
            intervalSeconds = defaultInterval
            privateModeEnabled = privateModeDefault
            transcriptionLanguage = defaultTranscriptionLanguage
        }
    }
    
    // MARK: - Validation
    func validateScript() -> ValidationError? {
        let trimmedText = scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Allow empty text if there's a recording
        if trimmedText.isEmpty {
            if hasRecording {
                return nil  // Valid: recording-only script
            } else {
                return .emptyScript
            }
        }
        
        // Check minimum length
        if trimmedText.count < Constants.minimumScriptLength {
            return .scriptTooShort(minLength: Constants.minimumScriptLength)
        }
        
        // Check maximum length
        if trimmedText.count > Constants.maximumScriptLength {
            return .scriptTooLong(maxLength: Constants.maximumScriptLength)
        }
        
        // Check against character limit if enforced
        if characterGuidanceEnabled && limitBehavior == "prevent" && trimmedText.count > characterLimit {
            return .exceedsCharacterLimit(limit: characterLimit)
        }
        
        return nil
    }
    
    func validateAudioRecording() -> ValidationError? {
        // Only validate if there's supposed to be a recording
        guard hasRecording, let script = script else {
            return nil // No recording required for new scripts
        }
        
        // Check audio duration
        let duration = script.audioDuration
        if duration > 0 {  // Only validate if there's a duration
            if duration < Constants.minimumAudioDuration {
                return .audioTooShort
            }
            
            if duration > Constants.maximumAudioDuration {
                return .audioTooLong
            }
        }
        
        return nil
    }
    
    // MARK: - Save
    func save() async throws {
        // Validate first
        if let error = validateScript() {
            throw error
        }
        
        if let error = validateAudioRecording() {
            throw error
        }
        
        viewState = .saving
        
        do {
            let trimmedText = scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let existingScript = script {
                // Update existing script
                updateExistingScript(existingScript, with: trimmedText)
            } else {
                // Create new script
                createNewScript(with: trimmedText)
            }
            
            if viewContext.hasChanges {
                try viewContext.save()
            }
            
            viewState = .idle
        } catch {
            viewState = .error(error.localizedDescription)
            throw error
        }
    }
    
    private func updateExistingScript(_ script: SelftalkScript, with text: String) {
        let placeholderText = NSLocalizedString("script.recording_only_placeholder", comment: "")
        
        if script.scriptText == placeholderText && !text.isEmpty {
            script.scriptText = text
        } else if text.isEmpty && hasRecording {
            script.scriptText = placeholderText
        } else {
            script.scriptText = text.isEmpty ? script.scriptText : text
        }
        
        // Update tags
        if let currentTags = script.tags as? Set<Tag> {
            for tag in currentTags {
                script.removeFromTags(tag)
            }
        }
        for tag in selectedTags {
            script.addToTags(tag)
        }
        
        script.repetitions = repetitions
        script.intervalSeconds = intervalSeconds
        script.privateModeEnabled = privateModeEnabled
        script.transcriptionLanguage = transcriptionLanguage
        script.notificationEnabled = notificationEnabled
        script.notificationFrequency = notificationFrequency
        script.updatedAt = Date()
    }
    
    private func createNewScript(with text: String) {
        let placeholderText = NSLocalizedString("script.recording_only_placeholder", comment: "")
        let scriptTextToSave = text.isEmpty ? placeholderText : text
        
        let newScript = SelftalkScript.create(
            scriptText: scriptTextToSave,
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
        newScript.notificationEnabled = notificationEnabled
        newScript.notificationFrequency = notificationFrequency
    }
    
    // MARK: - Recording Management
    func startRecording() async throws {
        viewState = .recording
        isRecording = true
        // Recording logic will be handled by AudioCoordinator
        // This is just state management
    }
    
    func stopRecording() {
        isRecording = false
        viewState = .processing
        isProcessingAudio = true
    }
    
    func deleteRecording() {
        hasRecording = false
        // Additional cleanup if needed
    }
}