import SwiftUI

struct BackupSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("settings.icloud_sync", comment: ""))
                            Text(NSLocalizedString("settings.icloud_sync_desc", comment: ""))
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
                            Text(NSLocalizedString("settings.icloud_sync.info", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.sync", comment: ""))
                }
                
                // Import/Export functionality removed
            }
            .navigationTitle(NSLocalizedString("settings.backup_sync", comment: ""))
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

struct BackupSyncView_Previews: PreviewProvider {
    static var previews: some View {
        BackupSyncView()
    }
}