import SwiftUI

struct MeView: View {
    @AppStorage("privacyModeDefault") private var privacyModeDefault = true
    @AppStorage("defaultRepetitions") private var defaultRepetitions = 3
    @AppStorage("defaultInterval") private var defaultInterval = 2.0
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = Locale.current.languageCode ?? "en"
    @AppStorage("voiceEnhancementEnabled") private var voiceEnhancementEnabled = true
    
    var body: some View {
        NavigationView {
            List {
                Section("Recording") {
                    Toggle(isOn: $voiceEnhancementEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Voice Enhancement")
                            Text("Reduces background noise and echo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
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
                    HStack {
                        Text("Default Language")
                        Spacer()
                        Text(languageDisplayName(for: defaultTranscriptionLanguage))
                            .foregroundColor(.secondary)
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
        }
    }
    
    private func languageDisplayName(for code: String) -> String {
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}