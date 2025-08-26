import SwiftUI

struct MeView: View {
    @State private var showingLanguageSettings = false
    @State private var showingCardSettings = false
    @State private var showingBackupSync = false
    @State private var showingAboutSupport = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        showingLanguageSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.language_settings", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingCardSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.stack")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.card_settings", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingBackupSync = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.backup_sync", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingAboutSupport = true
                    } label: {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 25)
                            Text(NSLocalizedString("settings.about_support", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("")
            .sheet(isPresented: $showingLanguageSettings) {
                LanguageSettingsView()
            }
            .sheet(isPresented: $showingCardSettings) {
                CardSettingsView()
            }
            .sheet(isPresented: $showingBackupSync) {
                BackupSyncView()
            }
            .sheet(isPresented: $showingAboutSupport) {
                AboutSupportView()
            }
        }
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}