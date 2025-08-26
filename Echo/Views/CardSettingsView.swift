import SwiftUI
import CoreData

struct CardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Default Settings
    @AppStorage("privateModeDefault") private var privateModeDefault = true
    @AppStorage("defaultRepetitions") private var defaultRepetitions = 3
    @AppStorage("defaultInterval") private var defaultInterval = 2.0
    
    // Card Preferences
    @AppStorage("characterGuidanceEnabled") private var characterGuidanceEnabled = true
    @AppStorage("characterLimit") private var characterLimit = 140
    @AppStorage("limitBehavior") private var limitBehavior = "warn"
    
    // Recording Settings
    @AppStorage("voiceEnhancementEnabled") private var voiceEnhancementEnabled = true
    @AppStorage("autoTrimSilence") private var autoTrimSilence = true
    @AppStorage("silenceTrimSensitivity") private var silenceTrimSensitivity = "medium"
    
    // Notification Settings
    @AppStorage("maxNotificationCards") private var maxNotificationCards = 1
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    
    // Tag Settings
    @AppStorage("maxNowCards") private var maxNowCards = 3
    @AppStorage("autoCleanupUnusedTags") private var autoCleanupUnusedTags = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        predicate: NSPredicate(format: "notificationEnabled == YES")
    ) private var notificationEnabledScripts: FetchedResults<SelftalkScript>
    
    @State private var showingPrivateModeInfo = false
    @State private var showingCardSelection = false
    @State private var cardsToDisable: Set<UUID> = []
    @State private var previousMaxCards = 1
    
    var body: some View {
        NavigationView {
            List {
                // Card Defaults Section
                Section(NSLocalizedString("settings.card_defaults", comment: "")) {
                    Toggle(isOn: $privateModeDefault) {
                        HStack {
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
                    
                    HStack {
                        Text(NSLocalizedString("script.repetitions", comment: ""))
                        Spacer()
                        Text("\(defaultRepetitions)")
                            .foregroundColor(.secondary)
                        Stepper("", value: $defaultRepetitions, in: 1...10)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text(NSLocalizedString("script.interval", comment: ""))
                        Spacer()
                        Text("\(defaultInterval, specifier: "%.1f")s")
                            .foregroundColor(.secondary)
                        Stepper("", value: $defaultInterval, in: 0.5...5.0, step: 0.5)
                            .labelsHidden()
                    }
                    
                    Toggle(NSLocalizedString("settings.character_guidance", comment: ""), isOn: $characterGuidanceEnabled)
                    
                    if characterGuidanceEnabled {
                        HStack {
                            Text(NSLocalizedString("settings.recommended_length", comment: ""))
                            Spacer()
                            Text("\(characterLimit) \(NSLocalizedString("chars", comment: ""))")
                                .foregroundColor(.secondary)
                            Stepper("", value: $characterLimit, in: 100...300, step: 20)
                                .labelsHidden()
                        }
                        
                        Picker(NSLocalizedString("settings.when_exceeded", comment: ""), selection: $limitBehavior) {
                            Text(NSLocalizedString("settings.just_warn", comment: "")).tag("warn")
                            Text(NSLocalizedString("settings.show_tip_only", comment: "")).tag("tip")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("settings.character_guidance.info", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Recording Settings Section
                Section(NSLocalizedString("settings.recording", comment: "")) {
                    Toggle(isOn: $voiceEnhancementEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("settings.voice_enhancement", comment: ""))
                            Text(NSLocalizedString("settings.voice_enhancement.desc", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $autoTrimSilence) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("settings.auto_trim_silence", comment: ""))
                            Text(NSLocalizedString("settings.auto_trim_silence.desc", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if autoTrimSilence {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("settings.trim_sensitivity", comment: ""))
                                .font(.subheadline)
                            
                            Picker(NSLocalizedString("picker.sensitivity", comment: ""), selection: $silenceTrimSensitivity) {
                                Text(NSLocalizedString("sensitivity.low", comment: "")).tag("low")
                                Text(NSLocalizedString("sensitivity.medium", comment: "")).tag("medium")
                                Text(NSLocalizedString("sensitivity.high", comment: "")).tag("high")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(sensitivityDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Notification Settings Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("notifications.max_cards", comment: "Maximum cards with notifications"))
                            Spacer()
                            Text("\(maxNotificationCards)")
                                .foregroundColor(.secondary)
                            Stepper("", value: $maxNotificationCards, in: 1...5)
                                .labelsHidden()
                        }
                        
                        if maxNotificationCards > 1 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.footnote)
                                Text(NSLocalizedString("notifications.burden_warning", comment: "Too many notifications can become burdensome"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if notificationEnabledScripts.count > 0 {
                        Text(String(format: NSLocalizedString("notifications.enabled_cards", comment: "Enabled Cards (%d)"), notificationEnabledScripts.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("notifications.settings_title", comment: ""))
                } footer: {
                    Text(NSLocalizedString("notifications.max_cards_footer", comment: ""))
                }
                
                // Tag Settings Section
                Section {
                    HStack {
                        Text(NSLocalizedString("tag.max_now_cards", comment: ""))
                        Spacer()
                        Text("\(maxNowCards)")
                            .foregroundColor(.secondary)
                        Stepper("", value: $maxNowCards, in: 1...5)
                            .labelsHidden()
                    }
                    
                    Toggle(NSLocalizedString("tag.auto_cleanup", comment: ""), isOn: $autoCleanupUnusedTags)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("The 'Now' tag helps you focus on your current priorities. Limiting the number of cards with this tag ensures focus.")
                }
            }
            .navigationTitle(NSLocalizedString("settings.card_settings", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .alert(NSLocalizedString("settings.private_mode.title", comment: ""), isPresented: $showingPrivateModeInfo) {
                Button(NSLocalizedString("action.got_it", comment: ""), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("settings.private_mode.alert.message", comment: ""))
            }
            .onChange(of: maxNotificationCards) { newValue in
                handleMaxCardsChange(from: previousMaxCards, to: newValue)
                previousMaxCards = newValue
            }
            .onAppear {
                previousMaxCards = maxNotificationCards
            }
            .sheet(isPresented: $showingCardSelection) {
                NotificationCardSelectionView(
                    cardsToDisable: $cardsToDisable,
                    maxAllowed: maxNotificationCards,
                    onConfirm: disableSelectedCards
                )
            }
        }
    }
    
    private var sensitivityDescription: String {
        switch silenceTrimSensitivity {
        case "low":
            return NSLocalizedString("sensitivity.low.desc", comment: "")
        case "high":
            return NSLocalizedString("sensitivity.high.desc", comment: "")
        default:
            return NSLocalizedString("sensitivity.medium.desc", comment: "")
        }
    }
    
    private func handleMaxCardsChange(from oldValue: Int, to newValue: Int) {
        guard newValue < oldValue else { return }
        
        let enabledCount = notificationEnabledScripts.count
        if enabledCount > newValue {
            // Need to disable some cards
            showingCardSelection = true
        }
    }
    
    private func disableSelectedCards() {
        for script in notificationEnabledScripts {
            if cardsToDisable.contains(script.id) {
                script.notificationEnabled = false
                script.notificationEnabledAt = nil
            }
        }
        
        do {
            try viewContext.save()
            cardsToDisable.removeAll()
        } catch {
            print("Error disabling notifications: \(error)")
        }
    }
}

// MARK: - Card Selection View for Disabling Notifications

private struct NotificationCardSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var cardsToDisable: Set<UUID>
    let maxAllowed: Int
    let onConfirm: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        predicate: NSPredicate(format: "notificationEnabled == YES")
    ) private var notificationEnabledScripts: FetchedResults<SelftalkScript>
    
    private var numberToSelect: Int {
        notificationEnabledScripts.count - maxAllowed
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(String(format: NSLocalizedString("notifications.select_to_disable", comment: "Select %d cards to disable notifications"), numberToSelect))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                
                List(notificationEnabledScripts) { script in
                    HStack {
                        Image(systemName: cardsToDisable.contains(script.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(cardsToDisable.contains(script.id) ? .red : .secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(script.scriptText)
                                .lineLimit(2)
                                .font(.subheadline)
                            
                            if !script.tagsArray.isEmpty {
                                Text(script.tagsArray.map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(for: script.id)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("notifications.select_cards", comment: "Select Cards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(cardsToDisable.count != numberToSelect)
                }
            }
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if cardsToDisable.contains(id) {
            cardsToDisable.remove(id)
        } else {
            if cardsToDisable.count < numberToSelect {
                cardsToDisable.insert(id)
            }
        }
    }
}

struct CardSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CardSettingsView()
    }
}