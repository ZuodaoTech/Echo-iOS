import SwiftUI

struct MeView: View {
    @AppStorage("privacyModeDefault") private var privacyModeDefault = true
    @AppStorage("defaultRepetitions") private var defaultRepetitions = 3
    @AppStorage("defaultInterval") private var defaultInterval = 2.0
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    @AppStorage("voiceEnhancementEnabled") private var voiceEnhancementEnabled = true
    @AppStorage("autoTrimSilence") private var autoTrimSilence = true
    @AppStorage("silenceTrimSensitivity") private var silenceTrimSensitivity = "medium"
    
    @State private var showingLanguagePicker = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Default Settings") {
                    Toggle("Privacy Mode", isOn: $privacyModeDefault)
                    
                    HStack {
                        Text("Repetitions")
                        Spacer()
                        Stepper("\(defaultRepetitions)", value: $defaultRepetitions, in: 1...10)
                    }
                    
                    HStack {
                        Text("Interval")
                        Spacer()
                        Text("\(defaultInterval, specifier: "%.1f")s")
                            .foregroundColor(.secondary)
                        Stepper("", value: $defaultInterval, in: 0.5...5.0, step: 0.5)
                            .labelsHidden()
                    }
                }
                
                Section("Transcription") {
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            Text("Default Language")
                            Spacer()
                            Text(languageDisplayName(for: defaultTranscriptionLanguage))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("Recording") {
                    Toggle(isOn: $voiceEnhancementEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Enhancement")
                            Text("Reduces background noise and echo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $autoTrimSilence) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Trim Silence")
                            Text("Remove silence at start and end")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if autoTrimSilence {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trim Sensitivity")
                                .font(.subheadline)
                            
                            Picker("Sensitivity", selection: $silenceTrimSensitivity) {
                                Text("Low").tag("low")
                                Text("Medium").tag("medium")
                                Text("High").tag("high")
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
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button {
                        if let url = URL(string: "https://github.com/xiaolai/Echo-iOS") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star")
                            Text("Rate on GitHub")
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "mailto:support@echo.app") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                    }
                } header: {
                    Text("Support")
                }
            }
            .navigationTitle("")
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView(selectedLanguage: $defaultTranscriptionLanguage)
            }
        }
    }
    
    private var sensitivityDescription: String {
        switch silenceTrimSensitivity {
        case "low":
            return "Keeps more natural pauses"
        case "high":
            return "Aggressive silence removal"
        default:
            return "Balanced trimming"
        }
    }
    
    private func languageDisplayName(for code: String) -> String {
        // Map language codes to display names
        switch code {
        case "en-US": return "English"
        case "zh-CN": return "Chinese (Simplified)"
        case "zh-TW": return "Chinese (Traditional)"
        case "es-ES": return "Spanish"
        case "fr-FR": return "French"
        case "de-DE": return "German"
        case "ja-JP": return "Japanese"
        case "ko-KR": return "Korean"
        case "it-IT": return "Italian"
        case "pt-BR": return "Portuguese (Brazil)"
        case "ru-RU": return "Russian"
        case "ar-SA": return "Arabic"
        case "hi-IN": return "Hindi"
        case "id-ID": return "Indonesian"
        case "nl-NL": return "Dutch"
        default: return Locale.current.localizedString(forLanguageCode: code) ?? code
        }
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}