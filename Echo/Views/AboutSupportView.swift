import SwiftUI

struct AboutSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(NSLocalizedString("settings.about", comment: "")) {
                    HStack {
                        Text(NSLocalizedString("settings.version", comment: ""))
                        Spacer()
                        Text("0.2.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("settings.build", comment: ""))
                        Spacer()
                        Text("2")
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
                            Text(NSLocalizedString("settings.rate_github", comment: ""))
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "mailto:support@echo.app") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope")
                            Text(NSLocalizedString("settings.contact_support", comment: ""))
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.support", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("settings.about_support", comment: ""))
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

struct AboutSupportView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSupportView()
    }
}