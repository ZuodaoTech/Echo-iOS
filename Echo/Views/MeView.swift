import SwiftUI
import CloudKit
import CoreData

struct MeView: View {
    // Language Settings
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    
    // Card Defaults
    @AppStorage("privateModeDefault") private var privateModeDefault = true
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
    @AppStorage("maxNowCards") private var maxNowCards = 3
    @AppStorage("autoCleanupUnusedTags") private var autoCleanupUnusedTags = false
    
    // Sync Settings
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
    @State private var showingClearICloudAlert = false
    @State private var showingClearLocalDataAlert = false
    @State private var showingRemoveDuplicatesAlert = false
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
                    HStack {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25)
                        Text(NSLocalizedString("settings.max_now_cards", comment: ""))
                        Spacer()
                        Text("\(maxNowCards)")
                            .foregroundColor(.secondary)
                        Stepper("", value: $maxNowCards, in: 1...10)
                            .labelsHidden()
                    }
                    
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
                            }
                            Text(NSLocalizedString("settings.icloud_sync_desc", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: iCloudSyncEnabled) { newValue in
                        // Restart Core Data container when toggling iCloud
                        NotificationCenter.default.post(
                            name: Notification.Name("RestartCoreDataForICloud"),
                            object: nil,
                            userInfo: ["enabled": newValue]
                        )
                    }
                    
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
                        if let url = URL(string: "https://github.com/xiaolai/Echo-iOS") {
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
                        if let url = URL(string: "mailto:support@echo.app") {
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
                        Text("🛠️ Developer Tools")
                    } footer: {
                        Text("⚠️ Display Language requires app restart to take effect.")
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
                    
                    // MARK: - Destructive Actions Section
                    Section {
                        // Clear iCloud Data
                        Button {
                            showingClearICloudAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "icloud.slash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 25)
                                Text("Clear iCloud Data")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        
                        // Clear Local Data
                        Button {
                            showingClearLocalDataAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 25)
                                Text("Clear All Local Data")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                        
                        // Remove Duplicates
                        Button {
                            showingRemoveDuplicatesAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                                    .frame(width: 25)
                                Text("Remove Duplicate Tags & Cards")
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        }
                    } header: {
                        Text("⚠️ Destructive Actions")
                    } footer: {
                        Text("These actions are destructive and cannot be undone.")
                            .font(.caption)
                    }
                    
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
            .alert("Clear iCloud Data?", isPresented: $showingClearICloudAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearICloudData()
                }
            } message: {
                Text("This will remove all Echo data from iCloud. Local data will remain intact.")
            }
            .alert("Clear All Local Data?", isPresented: $showingClearLocalDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    clearAllLocalData()
                }
            } message: {
                Text("This will delete ALL scripts, recordings, and tags. This cannot be undone!")
            }
            .alert("Remove Duplicates?", isPresented: $showingRemoveDuplicatesAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeDuplicates()
                }
            } message: {
                Text("This will merge duplicate tags and remove duplicate scripts with the same content.")
            }
            .alert("Operation Complete", isPresented: $showingDevActionResult) {
                Button("OK", role: .cancel) { }
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
    
    private func clearICloudData() {
        Task {
            let container = CKContainer(identifier: "iCloud.xiaolai.Echo")
            let privateDB = container.privateCloudDatabase
            
            // Record types to delete
            let recordTypes = ["CD_SelftalkScript", "CD_Tag"]
            
            var totalDeleted = 0
            var errors: [String] = []
            
            for recordType in recordTypes {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                
                do {
                    let records = try await privateDB.records(matching: query)
                    let recordIds = records.matchResults.compactMap { _, result in
                        try? result.get().recordID
                    }
                    
                    for recordId in recordIds {
                        do {
                            try await privateDB.deleteRecord(withID: recordId)
                            totalDeleted += 1
                        } catch {
                            errors.append(error.localizedDescription)
                        }
                    }
                } catch {
                    errors.append("\(recordType): \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                if errors.isEmpty {
                    devActionMessage = "Successfully deleted \(totalDeleted) records from iCloud."
                } else {
                    devActionMessage = "Deleted \(totalDeleted) records. Errors: \(errors.prefix(3).joined(separator: ", "))"
                }
                showingDevActionResult = true
            }
        }
    }
    
    private func clearAllLocalData() {
        // First, fetch all scripts to delete audio files
        let scriptRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        
        do {
            let scripts = try viewContext.fetch(scriptRequest)
            
            // Delete all audio files
            for script in scripts {
                if let audioPath = script.audioFilePath {
                    let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("Recordings")
                        .appendingPathComponent(audioPath)
                    try? FileManager.default.removeItem(at: fileURL)
                }
                viewContext.delete(script)
            }
            
            // Delete all tags
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            let tags = try viewContext.fetch(tagRequest)
            for tag in tags {
                viewContext.delete(tag)
            }
            
            // Save context
            try viewContext.save()
            
            // Clear all UserDefaults
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                UserDefaults.standard.synchronize()
            }
            
            devActionMessage = "Successfully deleted \(scripts.count) scripts and \(tags.count) tags."
            showingDevActionResult = true
            
        } catch {
            devActionMessage = "Failed to clear data: \(error.localizedDescription)"
            showingDevActionResult = true
        }
    }
    
    private func removeDuplicates() {
        // Remove duplicate tags
        Tag.cleanupDuplicateTags(in: viewContext)
        var tagCount = 0 // We'll update this if the method returns a count
        
        // Remove duplicate scripts (same content)
        let scriptRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
        scriptRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        var scriptCount = 0
        do {
            let allScripts = try viewContext.fetch(scriptRequest)
            var scriptsByContent: [String: [SelftalkScript]] = [:]
            
            for script in allScripts {
                let key = script.scriptText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                scriptsByContent[key, default: []].append(script)
            }
            
            for (_, scripts) in scriptsByContent where scripts.count > 1 {
                // Keep the first (oldest) script
                for duplicateScript in scripts.dropFirst() {
                    // Delete audio file if exists
                    if let audioPath = duplicateScript.audioFilePath {
                        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                            .appendingPathComponent("Recordings")
                            .appendingPathComponent(audioPath)
                        try? FileManager.default.removeItem(at: fileURL)
                    }
                    viewContext.delete(duplicateScript)
                    scriptCount += 1
                }
            }
            
            if scriptCount > 0 {
                try viewContext.save()
            }
            
            devActionMessage = "Removed \(tagCount) duplicate tags and \(scriptCount) duplicate scripts."
            showingDevActionResult = true
            
        } catch {
            devActionMessage = "Error: \(error.localizedDescription)"
            showingDevActionResult = true
        }
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
