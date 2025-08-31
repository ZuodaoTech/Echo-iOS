import SwiftUI
import CoreData

struct MeView: View {
    // Language Settings
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    
    // Card Defaults
    @AppStorage("privateModeDefault") private var privateModeDefault = false
    @AppStorage("defaultRepetitions") private var defaultRepetitions = 3
    @AppStorage("defaultInterval") private var defaultInterval = 2.0
    
    // Card Preferences
    @AppStorage("characterGuidanceEnabled") private var characterGuidanceEnabled = true
    @AppStorage("characterLimit") private var characterLimit = 140
    @AppStorage("limitBehavior") private var limitBehavior = "warn"
    
    // Notification Settings
    @AppStorage("maxNotificationCards") private var maxNotificationCards = 1
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    
    // Tag Settings
    @AppStorage("autoCleanupUnusedTags") private var autoCleanupUnusedTags = true
    
    // Sync Settings - preserved for UI but non-functional
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    // State for pickers
    @State private var showingUILanguagePicker = false
    @State private var showingTranscriptionLanguagePicker = false
    @State private var showingPrivateModeInfo = false
    @State private var showingCardSelection = false
    @State private var cardsToDisable: Set<UUID> = []
    @State private var previousMaxCards = 1
    
    // Dev section state
    @State private var showDevSection = false
    @State private var swipeSequence: [SwipeDirection] = []
    @State private var lastSwipeTime = Date()
    @State private var devActionMessage = ""
    @State private var showingDevActionResult = false
    
    enum SwipeDirection {
        case up, down, left, right
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        predicate: NSPredicate(format: "notificationEnabled == YES")
    ) private var notificationEnabledScripts: FetchedResults<SelftalkScript>
    
    // App Version Info
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Card Defaults Section
                Section {
                    // Transcription Language
                    Button {
                        showingTranscriptionLanguagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "mic.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.default_language", comment: ""))
                            Spacer()
                            Text(transcriptionLanguageDisplayName(for: defaultTranscriptionLanguage))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    // Private Mode
                    Toggle(isOn: $privateModeDefault) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.private_mode.title", comment: ""))
                            Button {
                                showingPrivateModeInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Repetitions
                    HStack {
                        Image(systemName: "repeat")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25)
                        Text(NSLocalizedString("script.repetitions", comment: ""))
                        Spacer()
                        Text("\(defaultRepetitions)")
                            .foregroundColor(.secondary)
                        Stepper("", value: $defaultRepetitions, in: 1...10)
                            .labelsHidden()
                    }
                    
                    // Interval
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25)
                        Text(NSLocalizedString("script.interval", comment: ""))
                        Spacer()
                        Text(String(format: "%.1fs", defaultInterval))
                            .foregroundColor(.secondary)
                        Stepper("", value: $defaultInterval, in: 0.5...10, step: 0.5)
                            .labelsHidden()
                    }
                    
                } header: {
                    Text(NSLocalizedString("settings.card_defaults", comment: ""))
                }
                
                // MARK: - Tag Settings Section
                Section {
                    Toggle(isOn: $autoCleanupUnusedTags) {
                        HStack {
                            Image(systemName: "trash.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.auto_cleanup_tags", comment: ""))
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.tags", comment: ""))
                } footer: {
                    Text(NSLocalizedString("settings.tags.footer", comment: ""))
                        .font(.caption)
                }
                
                // MARK: - Notification Section
                Section {
                    HStack {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25)
                        Text(NSLocalizedString("settings.max_notification_cards", comment: ""))
                        Spacer()
                        Text("\(maxNotificationCards)")
                            .foregroundColor(.secondary)
                        Stepper("", value: $maxNotificationCards, in: 0...5) { _ in
                            handleMaxNotificationCardsChange()
                        }
                        .labelsHidden()
                    }
                    
                    if notificationEnabledScripts.count > 0 {
                        Text(String(format: NSLocalizedString("settings.notification_cards_count", comment: ""), notificationEnabledScripts.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("settings.notifications", comment: ""))
                } footer: {
                    if maxNotificationCards > 0 {
                        Text(NSLocalizedString("settings.notification_cards.footer", comment: ""))
                            .font(.caption)
                    }
                }
                
                // MARK: - Data & Sync Section
                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "icloud")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text(NSLocalizedString("settings.icloud_sync", comment: ""))
                                Text("(Coming Soon)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Text(NSLocalizedString("settings.icloud_sync_desc", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(true)  // Disabled until iCloud sync is reimplemented
                    
                    if iCloudSyncEnabled {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                                .font(.footnote)
                            Text(NSLocalizedString("settings.icloud_sync.info", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.sync", comment: ""))
                }
                
                // MARK: - About & Support Section
                Section {
                    // Version Info
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25)
                        Text(NSLocalizedString("settings.version", comment: ""))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    // GitHub
                    Button {
                        if let url = URL(string: "https://github.com/ZuodaoTech/Echo-iOS") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.rate_github", comment: ""))
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    // Contact Support
                    Button {
                        if let url = URL(string: "mailto:support@echopro.app") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.contact_support", comment: ""))
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Text(NSLocalizedString("settings.about", comment: ""))
                }
                
                // Empty section for spacing after About
                if !showDevSection {
                    Section {
                        Color.clear
                            .frame(height: 100)
                            .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.clear)
                    .listSectionSeparator(.hidden)
                }
                
                // MARK: - Developer Section (Hidden)
                if showDevSection {
                    Section {
                        // App Display Language (moved here)
                        Button {
                            showingUILanguagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text(NSLocalizedString("settings.display_language", comment: ""))
                                Spacer()
                                Text(uiLanguageDisplayName(for: appLanguage))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text(NSLocalizedString("dev.title", comment: "Developer Tools title"))
                    } footer: {
                        Text(NSLocalizedString("dev.warning", comment: "Display language warning"))
                            .font(.caption)
                    }
                    
                    // MARK: - Card Preferences Section (Dev Only)
                    Section {
                        // Character Limit
                        Toggle(isOn: $characterGuidanceEnabled) {
                            HStack {
                                Image(systemName: "character.cursor.ibeam")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text(NSLocalizedString("settings.character_guidance", comment: ""))
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if characterGuidanceEnabled {
                            HStack {
                                Text(NSLocalizedString("settings.character_limit", comment: ""))
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("", selection: $characterLimit) {
                                    Text("70").tag(70)
                                    Text("140").tag(140)
                                    Text("280").tag(280)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                            
                            HStack {
                                Text(NSLocalizedString("settings.limit_behavior", comment: ""))
                                    .foregroundColor(.primary)
                                Spacer()
                                Picker("", selection: $limitBehavior) {
                                    Text(NSLocalizedString("settings.limit_behavior.warn", comment: "")).tag("warn")
                                    Text(NSLocalizedString("settings.limit_behavior.strict", comment: "")).tag("strict")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 180)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("settings.card_preferences", comment: ""))
                    }
                    
                    // Developer tools section removed - iCloud operations no longer functional
                    
                    // Empty section for spacing
                    Section {
                        Color.clear
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.clear)
                    .listSectionSeparator(.hidden)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 30) // Lowered from 50 for easier detection
                    .onEnded { value in
                        handleSwipe(value: value)
                    }
            )
//            .navigationTitle(NSLocalizedString("tab.me", comment: ""))
            .sheet(isPresented: $showingUILanguagePicker) {
                UILanguagePickerView(selectedLanguage: $appLanguage)
            }
            .sheet(isPresented: $showingTranscriptionLanguagePicker) {
                ImprovedLanguagePickerView(selectedLanguage: $defaultTranscriptionLanguage)
            }
            .alert(NSLocalizedString("settings.private_mode.title", comment: ""), isPresented: $showingPrivateModeInfo) {
                Button(NSLocalizedString("action.got_it", comment: ""), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("settings.private_mode.alert.message", comment: ""))
            }
            .alert(NSLocalizedString("dev.operation_complete", comment: "Operation Complete"), isPresented: $showingDevActionResult) {
                Button(NSLocalizedString("action.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(devActionMessage)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleSwipe(value: DragGesture.Value) {
        let verticalMovement = value.translation.height
        let horizontalMovement = value.translation.width
        
        // Determine swipe direction (horizontal swipes are easier to detect with lower threshold)
        let direction: SwipeDirection
        if abs(horizontalMovement) > abs(verticalMovement) {
            // Prioritize horizontal swipes
            direction = horizontalMovement > 0 ? .right : .left
        } else {
            // Vertical swipes
            direction = verticalMovement > 0 ? .down : .up
        }
        
        // Log swipe detection
        print("🎮 Swipe detected: \(direction)")
        
        // Check if it's been more than 2 seconds since last swipe (reset sequence)
        if Date().timeIntervalSince(lastSwipeTime) > 2 {
            if !swipeSequence.isEmpty {
                print("⏰ Swipe sequence timeout - resetting")
            }
            swipeSequence = []
        }
        
        // Add to sequence
        swipeSequence.append(direction)
        lastSwipeTime = Date()
        
        // Log current sequence
        let sequenceString = swipeSequence.map { 
            switch $0 {
            case .up: return "↑"
            case .down: return "↓"
            case .left: return "←"
            case .right: return "→"
            }
        }.joined(separator: " ")
        print("📝 Current sequence: \(sequenceString)")
        
        // Check for the Konami code: left, left, right
        if swipeSequence.count >= 3 {
            let recentSwipes = Array(swipeSequence.suffix(3))
            if recentSwipes == [.left, .left, .right] {
                // Toggle dev section with haptic feedback
                showDevSection.toggle()
                if showDevSection {
                    print("🎉 KONAMI CODE DETECTED! Developer mode activated")
                } else {
                    print("🔒 KONAMI CODE DETECTED! Developer mode deactivated")
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                swipeSequence = [] // Reset sequence
            }
        }
        
        // Keep only last 10 swipes to prevent memory issues
        if swipeSequence.count > 10 {
            swipeSequence = Array(swipeSequence.suffix(10))
        }
    }
    
    private func handleMaxNotificationCardsChange() {
        // Simplified version without card selection dialog
        // TODO: Add proper notification card management if needed
        previousMaxCards = maxNotificationCards
    }
    
    private func uiLanguageDisplayName(for code: String) -> String {
        switch code {
        case "system": return NSLocalizedString("language.system_default", comment: "")
        case "en": return "English"
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        case "es": return "Español"
        case "fr": return "Français"
        case "de": return "Deutsch"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "it": return "Italiano"
        case "pt": return "Português"
        case "ru": return "Русский"
        case "nl": return "Nederlands"
        case "sv": return "Svenska"
        case "nb": return "Norsk"
        case "da": return "Dansk"
        case "pl": return "Polski"
        case "tr": return "Türkçe"
        default: return code
        }
    }
    
    private func transcriptionLanguageDisplayName(for code: String) -> String {
        switch code {
        case "en-US": return "English"
        case "zh-CN": return "简体中文"
        case "zh-TW": return "繁體中文"
        case "es-ES": return "Español"
        case "fr-FR": return "Français"
        case "de-DE": return "Deutsch"
        case "ja-JP": return "日本語"
        case "ko-KR": return "한국어"
        case "it-IT": return "Italiano"
        case "pt-BR": return "Português"
        case "ru-RU": return "Русский"
        case "nl-NL": return "Nederlands"
        case "sv-SE": return "Svenska"
        case "nb-NO": return "Norsk"
        case "da-DK": return "Dansk"
        case "pl-PL": return "Polski"
        case "tr-TR": return "Türkçe"
        case "ar-SA": return "العربية"
        case "hi-IN": return "हिन्दी"
        case "id-ID": return "Bahasa Indonesia"
        default: return code
        }
    }
    
    // MARK: - Dev Section Functions
    
    private func removeDuplicates() async {
        // Clean up duplicate tags
        Tag.cleanupDuplicateTags(in: viewContext)
        
        // Note: Script deduplication removed with iCloud sync removal
        devActionMessage = "Duplicate tags have been cleaned up."
        showingDevActionResult = true
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
