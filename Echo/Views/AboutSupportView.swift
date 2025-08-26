import SwiftUI

struct AboutSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    // App Version Info
    private var appVersionNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private var appBuildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(NSLocalizedString("settings.about", comment: "")) {
                    HStack {
                        Text(NSLocalizedString("settings.version", comment: ""))
                        Spacer()
                        Text(appVersionNumber)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("settings.build", comment: ""))
                        Spacer()
                        Text(appBuildNumber)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button {
                        if let url = URL(string: "https://github.com/ZuoDaoTech/Echo-iOS") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "star")
                            Text(NSLocalizedString("settings.rate_github", comment: ""))
                        }
                    }
                    
                    Button {
                        if let url = URL(string: "mailto:support@echopro.app") {
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
