import SwiftUI
import UniformTypeIdentifiers

struct MeView: View {
    @AppStorage("privacyModeDefault") private var privacyModeDefault = true
    @AppStorage("defaultRepetitions") private var defaultRepetitions = 3
    @AppStorage("defaultInterval") private var defaultInterval = 2.0
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    @AppStorage("voiceEnhancementEnabled") private var voiceEnhancementEnabled = true
    @AppStorage("autoTrimSilence") private var autoTrimSilence = true
    @AppStorage("silenceTrimSensitivity") private var silenceTrimSensitivity = "medium"
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    @State private var showingLanguagePicker = false
    @State private var showingExportOptions = false
    @State private var showingDocumentPicker = false
    @State private var exportProgress: String?
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showingPrivacyModeInfo = false
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            List {
                Section("Default Settings") {
                    HStack {
                        Toggle("Privacy Mode", isOn: $privacyModeDefault)
                        
                        Button {
                            showingPrivacyModeInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
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
                
                Section("Backup & Sync") {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                            Text("Sync scripts across your devices")
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
                                .foregroundColor(.blue)
                                .font(.footnote)
                            Text("Text and settings sync automatically. Audio files remain local.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showingExportOptions = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Scripts")
                            Spacer()
                            if let progress = exportProgress {
                                Text(progress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Scripts")
                        }
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
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView(exportProgress: $exportProgress)
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(
                    allowedContentTypes: [
                        UTType(filenameExtension: "echo") ?? .data,
                        .json,
                        .plainText
                    ]
                ) { url in
                    Task {
                        await handleImport(from: url)
                    }
                }
            }
            .alert("Import Complete", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importAlertMessage)
            }
            .alert("Privacy Mode", isPresented: $showingPrivacyModeInfo) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("When Privacy Mode is enabled, audio recordings will only play through connected earphones or headphones. This prevents accidental playback through speakers in public spaces.")
            }
        }
    }
    
    private func handleImport(from url: URL) async {
        let importService = ImportService()
        let result = await importService.importBundle(
            from: url,
            conflictResolution: .skip,
            context: viewContext
        )
        
        await MainActor.run {
            importAlertMessage = result.summary
            if !result.errors.isEmpty {
                importAlertMessage += "\n\nErrors:\n" + result.errors.joined(separator: "\n")
            }
            showingImportAlert = true
        }
    }
    
    private var sensitivityDescription: String {
        switch silenceTrimSensitivity {
        case "low":
            return "Needs louder voice • 0.5s buffer"
        case "high":
            return "Detects whispers • 0.15s buffer"
        default:
            return "Balanced detection • 0.3s buffer"
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