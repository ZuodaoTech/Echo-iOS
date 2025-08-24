import SwiftUI

struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    // Available languages for transcription
    private let languages = [
        ("en-US", "English"),
        ("zh-CN", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)"),
        ("es-ES", "Spanish"),
        ("fr-FR", "French"),
        ("de-DE", "German"),
        ("ja-JP", "Japanese"),
        ("ko-KR", "Korean"),
        ("it-IT", "Italian"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("ru-RU", "Russian"),
        ("ar-SA", "Arabic"),
        ("hi-IN", "Hindi"),
        ("id-ID", "Indonesian"),
        ("nl-NL", "Dutch")
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
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LanguagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        LanguagePickerView(selectedLanguage: .constant("en-US"))
    }
}