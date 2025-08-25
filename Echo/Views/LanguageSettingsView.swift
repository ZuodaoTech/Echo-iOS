import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("appLanguage") private var appLanguage = "system"
    @AppStorage("defaultTranscriptionLanguage") private var defaultTranscriptionLanguage = "en-US"
    
    @State private var showingUILanguagePicker = false
    @State private var showingTranscriptionLanguagePicker = false
    
    var body: some View {
        NavigationView {
            List {
                // App Display Language Section
                Section {
                    Button {
                        showingUILanguagePicker = true
                    } label: {
                        HStack {
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
                    
                    if appLanguage != "system" {
                        HStack {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("settings.restart_to_apply", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.app_language", comment: ""))
                }
                
                // Transcription Language Section
                Section {
                    Button {
                        showingTranscriptionLanguagePicker = true
                    } label: {
                        HStack {
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
                } header: {
                    Text(NSLocalizedString("settings.transcription", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("settings.language_settings", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingUILanguagePicker) {
                UILanguagePickerView(selectedLanguage: $appLanguage)
            }
            .sheet(isPresented: $showingTranscriptionLanguagePicker) {
                ImprovedLanguagePickerView(selectedLanguage: $defaultTranscriptionLanguage)
            }
        }
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
}

// Improved Language Picker with native language display
struct ImprovedLanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    // Available languages for transcription with native names
    private let languages = [
        ("en-US", "English"),
        ("zh-CN", "简体中文"),
        ("zh-TW", "繁體中文"),
        ("es-ES", "Español"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
        ("it-IT", "Italiano"),
        ("pt-BR", "Português"),
        ("ru-RU", "Русский"),
        ("nl-NL", "Nederlands"),
        ("sv-SE", "Svenska"),
        ("nb-NO", "Norsk"),
        ("da-DK", "Dansk"),
        ("pl-PL", "Polski"),
        ("tr-TR", "Türkçe"),
        ("ar-SA", "العربية"),
        ("hi-IN", "हिन्दी"),
        ("id-ID", "Bahasa Indonesia")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(languages, id: \.0) { code, name in
                    Button {
                        selectedLanguage = code
                        dismiss()
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedLanguage == code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("picker.select_language", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LanguageSettingsView()
    }
}