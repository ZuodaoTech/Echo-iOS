import SwiftUI

struct CardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Default Settings
    @AppStorage("privacyModeDefault") private var privacyModeDefault = true
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
    
    @State private var showingPrivacyModeInfo = false
    
    var body: some View {
        NavigationView {
            List {
                // Card Defaults Section
                Section(NSLocalizedString("settings.card_defaults", comment: "")) {
                    Toggle(isOn: $privacyModeDefault) {
                        HStack {
                            Text(NSLocalizedString("settings.privacy_mode.title", comment: ""))
                            Button {
                                showingPrivacyModeInfo = true
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
                        Stepper("\(defaultRepetitions)", value: $defaultRepetitions, in: 1...10)
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
            .alert(NSLocalizedString("settings.privacy_mode.title", comment: ""), isPresented: $showingPrivacyModeInfo) {
                Button(NSLocalizedString("action.got_it", comment: ""), role: .cancel) { }
            } message: {
                Text(NSLocalizedString("settings.privacy_mode.alert.message", comment: ""))
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
}

struct CardSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CardSettingsView()
    }
}