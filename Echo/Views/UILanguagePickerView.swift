import SwiftUI

struct UILanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    // Available UI languages for the app
    private var languages: [(String, String)] {
        [
            ("system", NSLocalizedString("language.system_default", comment: "")),
            ("en", "English"),
            ("zh-Hans", "简体中文"),
            ("zh-Hant", "繁體中文"),
            ("es", "Español"),
            ("fr", "Français"),
            ("de", "Deutsch"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("it", "Italiano"),
            ("pt", "Português"),
            ("ru", "Русский"),
            ("nl", "Nederlands"),
            ("sv", "Svenska"),
            ("nb", "Norsk"),
            ("da", "Dansk"),
            ("pl", "Polski"),
            ("tr", "Türkçe")
        ]
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(languages, id: \.0) { code, name in
                    Button {
                        selectedLanguage = code
                        // Apply language change immediately
                        if code == "system" {
                            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                        } else {
                            UserDefaults.standard.set([code], forKey: "AppleLanguages")
                        }
                        UserDefaults.standard.synchronize()
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
            .navigationTitle(NSLocalizedString("picker.display_language", comment: ""))
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

struct UILanguagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        UILanguagePickerView(selectedLanguage: .constant("system"))
    }
}