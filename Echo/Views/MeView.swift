import SwiftUI
import CoreData

struct MeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
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
    
    // Audio trim parameters (Dev Tools)
    @AppStorage("voiceDetectionThreshold") private var voiceDetectionThreshold: Double = 0.15
    @AppStorage("trimBufferTime") private var trimBufferTime: Double = 0.15
    
    // Voice enhancement parameters (Dev Tools)
    @AppStorage("voiceEnhancementEnabled") private var voiceEnhancementEnabled: Bool = true
    @AppStorage("normalizationLevel") private var normalizationLevel: Double = 0.9  // 0.5-1.0
    @AppStorage("compressionThreshold") private var compressionThreshold: Double = 0.5  // 0.3-0.8
    @AppStorage("compressionRatio") private var compressionRatio: Double = 0.3  // 0.1-0.5 (inverse of ratio)
    @AppStorage("highPassCutoff") private var highPassCutoff: Double = 0.95  // 0.90-0.98
    
    // Noise reduction parameters (Dev Tools)
    @AppStorage("noiseGateThreshold") private var noiseGateThreshold: Double = 0.02  // 0.01-0.05
    @AppStorage("noiseReductionStrength") private var noiseReductionStrength: Double = 0.8  // 0.5-1.0
    @State private var lastSwipeTime = Date()
    @State private var devActionMessage = ""
    @State private var showingDevActionResult = false
    @State private var showingDeleteAllDataAlert = false
    
    enum SwipeDirection {
        case up, down, left, right
    }
    
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
                    
                    // Backup & Restore Navigation
                    NavigationLink(destination: BackupSyncView()) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.on.square")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.backup_restore", comment: "Backup & Restore"))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
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
                    
                    // MARK: - Audio Processing Parameters (Dev Only)
                    Section {
                        // Voice Detection Threshold
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "waveform.badge.mic")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text("Voice Detection Threshold")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(String(format: "%.2f", voiceDetectionThreshold))
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Slider(value: $voiceDetectionThreshold, in: 0.05...0.50, step: 0.01)
                                .padding(.horizontal, 35)
                            
                            Text("Lower = more sensitive (picks up quiet sounds)\nHigher = less sensitive (filters background noise)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 35)
                        }
                        .padding(.vertical, 4)
                        
                        // Trim Buffer Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "timer")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text("Trim Buffer Time")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(String(format: "%.2fs", trimBufferTime))
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Slider(value: $trimBufferTime, in: 0.05...0.50, step: 0.05)
                                .padding(.horizontal, 35)
                            
                            Text("Buffer time before/after detected speech\nShorter = tighter trimming, Longer = safer margins")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 35)
                        }
                        .padding(.vertical, 4)
                        
                        // Reset to defaults button
                        Button {
                            voiceDetectionThreshold = 0.15
                            trimBufferTime = 0.15
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 20))
                                    .frame(width: 25)
                                Text("Reset to Defaults")
                            }
                            .foregroundColor(.blue)
                        }
                    } header: {
                        Text("Audio Processing")
                    } footer: {
                        Text("Current settings: Threshold=\(String(format: "%.2f", voiceDetectionThreshold)), Buffer=\(String(format: "%.2fs", trimBufferTime))\nDefaults: Threshold=0.15, Buffer=0.15s")
                            .font(.caption)
                    }
                    
                    // MARK: - Voice Enhancement Parameters (Dev Only)
                    Section {
                        // Enhancement Toggle
                        Toggle(isOn: $voiceEnhancementEnabled) {
                            HStack {
                                Image(systemName: "waveform.and.magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(.primary)
                                    .frame(width: 25)
                                Text("Voice Enhancement")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        if voiceEnhancementEnabled {
                            // Normalization Level
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speaker.wave.3")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Normalization Level")
                                    Spacer()
                                    Text(String(format: "%.0f%%", normalizationLevel * 100))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $normalizationLevel, in: 0.5...1.0, step: 0.05)
                                    .padding(.horizontal, 35)
                                
                                Text("Target volume level (90% = balanced, 100% = maximum)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                            
                            // Compression Threshold
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Compression Threshold")
                                    Spacer()
                                    Text(String(format: "%.0f%%", compressionThreshold * 100))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $compressionThreshold, in: 0.3...0.8, step: 0.05)
                                    .padding(.horizontal, 35)
                                
                                Text("Volume level where compression starts\nLower = more compression, Higher = less compression")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                            
                            // Compression Ratio
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "slider.horizontal.below.square.filled.and.square")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Compression Strength")
                                    Spacer()
                                    Text(String(format: "%.0f:1", 1.0/compressionRatio))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $compressionRatio, in: 0.1...0.5, step: 0.05)
                                    .padding(.horizontal, 35)
                                
                                Text("How much to reduce loud parts\n10:1 = heavy, 3:1 = gentle, 2:1 = light")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                            
                            // High-Pass Filter
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "wind")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Rumble Filter")
                                    Spacer()
                                    Text(String(format: "%.0fHz", (1.0 - highPassCutoff) * 1000))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $highPassCutoff, in: 0.90...0.98, step: 0.01)
                                    .padding(.horizontal, 35)
                                
                                Text("Remove low-frequency noise (AC hum, rumble)\n50Hz = aggressive, 100Hz = moderate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                            
                            // Noise Gate Threshold
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speaker.slash")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Noise Floor Detection")
                                    Spacer()
                                    Text(String(format: "%.3f", noiseGateThreshold))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $noiseGateThreshold, in: 0.01...0.05, step: 0.005)
                                    .padding(.horizontal, 35)
                                
                                Text("Minimum threshold for noise detection\nLower = more sensitive, Higher = less sensitive")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                            
                            // Noise Reduction Strength
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "waveform.badge.minus")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primary)
                                        .frame(width: 25)
                                    Text("Noise Reduction Strength")
                                    Spacer()
                                    Text(String(format: "%.0f%%", noiseReductionStrength * 100))
                                        .foregroundColor(.secondary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                
                                Slider(value: $noiseReductionStrength, in: 0.5...1.0, step: 0.05)
                                    .padding(.horizontal, 35)
                                
                                Text("How much to reduce detected background noise\n80% = balanced, 100% = aggressive")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 35)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Reset voice enhancement to defaults
                        if voiceEnhancementEnabled {
                            Button {
                                normalizationLevel = 0.9
                                compressionThreshold = 0.5
                                compressionRatio = 0.3
                                highPassCutoff = 0.95
                                noiseGateThreshold = 0.02
                                noiseReductionStrength = 0.8
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 20))
                                        .frame(width: 25)
                                    Text("Reset Enhancement to Defaults")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    } header: {
                        Text("Voice Enhancement")
                    } footer: {
                        if voiceEnhancementEnabled {
                            Text("Processing: Noise Reduction→Filter→Compress→Normalize\nAdaptive noise floor detection + configurable reduction\nApplied after trimming, before transcription")
                                .font(.caption)
                        }
                    }
                    
                    // Developer tools section removed - iCloud operations no longer functional
                    
                    // MARK: - Data Management (Dev Only)
                    Section {
                        // Delete All Local Data
                        Button {
                            showingDeleteAllDataAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                                    .frame(width: 25)
                                Text(NSLocalizedString("dev.delete_all_data", comment: "Delete All Local Data"))
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("dev.data_management", comment: "Data Management"))
                    } footer: {
                        Text(NSLocalizedString("dev.delete_all_warning", comment: "Warning: This will permanently delete all scripts and recordings"))
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
            .alert(NSLocalizedString("dev.operation_complete", comment: "Operation Complete"), isPresented: $showingDevActionResult) {
                Button(NSLocalizedString("action.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(devActionMessage)
            }
            .alert(NSLocalizedString("dev.delete_all_title", comment: "Delete All Data"), isPresented: $showingDeleteAllDataAlert) {
                Button(NSLocalizedString("action.cancel", comment: "Cancel"), role: .cancel) { }
                Button(NSLocalizedString("action.delete", comment: "Delete"), role: .destructive) {
                    deleteAllLocalData()
                }
            } message: {
                Text(NSLocalizedString("dev.delete_all_confirm", comment: "This will permanently delete all scripts, recordings, and tags. This action cannot be undone."))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func deleteAllLocalData() {
        // Delete all scripts
        let scriptRequest = SelftalkScript.fetchRequest()
        if let scripts = try? viewContext.fetch(scriptRequest) {
            for script in scripts {
                // Delete audio file if it exists
                if let audioPath = script.audioFilePath {
                    try? FileManager.default.removeItem(atPath: audioPath)
                }
                viewContext.delete(script)
            }
        }
        
        // Delete all tags
        let tagRequest = Tag.fetchRequest()
        if let tags = try? viewContext.fetch(tagRequest) {
            for tag in tags {
                viewContext.delete(tag)
            }
        }
        
        // Save context
        do {
            try viewContext.save()
            devActionMessage = NSLocalizedString("dev.delete_all_success", comment: "All data has been deleted successfully")
            showingDevActionResult = true
        } catch {
            devActionMessage = NSLocalizedString("dev.delete_all_error", comment: "Error deleting data: ") + error.localizedDescription
            showingDevActionResult = true
        }
    }
    
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
