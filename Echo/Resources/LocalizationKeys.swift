import Foundation

// Centralized localization keys for type safety and consistency
enum L10n {
    
    // MARK: - Navigation & Titles
    enum Navigation {
        static let cards = "navigation.cards"
        static let me = "navigation.me"
        static let newScript = "navigation.new_script"
        static let editScript = "navigation.edit_script"
    }
    
    // MARK: - Categories
    enum Category {
        static let breakingBadHabits = "category.breaking_bad_habits"
        static let buildingGoodHabits = "category.building_good_habits"
        static let appropriatePositivity = "category.appropriate_positivity"
        static let personalGrowth = "category.personal_growth"
        static let dailyAffirmations = "category.daily_affirmations"
        static let selectCategory = "category.select"
        static let addNew = "category.add_new"
    }
    
    // MARK: - Script Card
    enum ScriptCard {
        static let playCount = "script.play_count"
        static let transcript = "script.transcript"
        static let recording = "script.recording"
        static let noRecording = "script.no_recording"
        static let repetitions = "script.repetitions"
        static let interval = "script.interval"
        static let privateMode = "script.private_mode"
        static let deleteScript = "script.delete"
        static let deleteConfirmTitle = "script.delete.confirm.title"
        static let deleteConfirmMessage = "script.delete.confirm.message"
    }
    
    // MARK: - Settings
    enum Settings {
        static let defaultSettings = "settings.default_settings"
        static let scriptPreferences = "settings.script_preferences"
        static let transcription = "settings.transcription"
        static let recording = "settings.recording"
        static let backupSync = "settings.backup_sync"
        static let about = "settings.about"
        static let support = "settings.support"
        
        static let privateModeTitle = "settings.private_mode.title"
        static let privateModeInfo = "settings.private_mode.info"
        static let privateModeAlertTitle = "settings.private_mode.alert.title"
        static let privateModeAlertMessage = "settings.private_mode.alert.message"
        
        static let characterGuidance = "settings.character_guidance"
        static let recommendedLength = "settings.recommended_length"
        static let whenExceeded = "settings.when_exceeded"
        static let justWarn = "settings.just_warn"
        static let showTipOnly = "settings.show_tip_only"
        static let characterGuidanceInfo = "settings.character_guidance.info"
        
        static let defaultLanguage = "settings.default_language"
        static let voiceEnhancement = "settings.voice_enhancement"
        static let voiceEnhancementDesc = "settings.voice_enhancement.desc"
        static let autoTrimSilence = "settings.auto_trim_silence"
        static let autoTrimSilenceDesc = "settings.auto_trim_silence.desc"
        static let trimSensitivity = "settings.trim_sensitivity"
        
        static let iCloudSync = "settings.icloud_sync"
        static let iCloudSyncDesc = "settings.icloud_sync.desc"
        static let iCloudSyncInfo = "settings.icloud_sync.info"
        static let exportScripts = "settings.export_scripts"
        static let importScripts = "settings.import_scripts"
        
        static let version = "settings.version"
        static let build = "settings.build"
        static let rateOnGitHub = "settings.rate_github"
        static let contactSupport = "settings.contact_support"
    }
    
    // MARK: - Recording
    enum Recording {
        static let startRecording = "recording.start"
        static let stopRecording = "recording.stop"
        static let reRecord = "recording.re_record"
        static let recordingSaved = "recording.saved"
        static let deleteRecording = "recording.delete"
        static let preview = "recording.preview"
        static let playingPreview = "recording.playing_preview"
        static let previewPaused = "recording.preview_paused"
        static let playsOnce = "recording.plays_once"
        static let processing = "recording.processing"
        static let listening = "recording.listening"
        static let speaking = "recording.speaking"
        static let transcribing = "recording.transcribing"
        static let reTranscribing = "recording.re_transcribing"
        static let microphoneAccess = "recording.microphone_access"
        static let microphoneAccessMessage = "recording.microphone_access.message"
    }
    
    // MARK: - Character Guidance
    enum CharacterGuidance {
        static let trimCharacters = "guidance.trim_characters"
        static let scriptOver = "guidance.script_over"
        static let scriptLong = "guidance.script_long"
        static let enterScript = "guidance.enter_script"
    }
    
    // MARK: - Notifications
    enum Notifications {
        static let enable = "notifications.enable"
        static let frequency = "notifications.frequency"
        static let frequencyHigh = "notifications.frequency.high"
        static let frequencyMedium = "notifications.frequency.medium"
        static let frequencyLow = "notifications.frequency.low"
        static let daytimeOnly = "notifications.daytime_only"
    }
    
    // MARK: - Common Actions
    enum Actions {
        static let done = "action.done"
        static let cancel = "action.cancel"
        static let delete = "action.delete"
        static let add = "action.add"
        static let save = "action.save"
        static let ok = "action.ok"
        static let gotIt = "action.got_it"
        static let copy = "action.copy"
        static let useAsScript = "action.use_as_script"
        static let share = "action.share"
        static let edit = "action.edit"
    }
    
    // MARK: - Errors
    enum Errors {
        static let title = "error.title"
        static let saveError = "error.save"
        static let databaseError = "error.database"
        static let restartApp = "error.restart_app"
        static let tryAgain = "error.try_again"
        static let importError = "error.import"
        static let exportError = "error.export"
    }
    
    // MARK: - Time Units
    enum Time {
        static let seconds = "time.seconds"
        static let timesPerHour = "time.times_per_hour"
        static let everyHours = "time.every_hours"
        static let timesPerDay = "time.times_per_day"
    }
    
    // MARK: - Sensitivity Levels
    enum Sensitivity {
        static let low = "sensitivity.low"
        static let medium = "sensitivity.medium"
        static let high = "sensitivity.high"
        static let lowDesc = "sensitivity.low.desc"
        static let mediumDesc = "sensitivity.medium.desc"
        static let highDesc = "sensitivity.high.desc"
    }
}

// MARK: - Sample Scripts Keys
enum SampleScripts {
    static let smoking = "sample.smoking"
    static let bedtime = "sample.bedtime"
    static let mistakes = "sample.mistakes"
}