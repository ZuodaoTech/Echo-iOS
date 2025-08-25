import SwiftUI
import UniformTypeIdentifiers

struct BackupSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    @State private var showingExportOptions = false
    @State private var showingDocumentPicker = false
    @State private var exportProgress: String?
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    
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
                
                Section {
                    Button {
                        showingExportOptions = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(NSLocalizedString("settings.export_scripts", comment: ""))
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
                            Text(NSLocalizedString("settings.import_scripts", comment: ""))
                        }
                    }
                } header: {
                    Text(NSLocalizedString("settings.backup", comment: ""))
                }
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
            .alert(NSLocalizedString("import.complete_title", comment: ""), isPresented: $showingImportAlert) {
                Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
            } message: {
                Text(importAlertMessage)
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
}

struct BackupSyncView_Previews: PreviewProvider {
    static var previews: some View {
        BackupSyncView()
    }
}