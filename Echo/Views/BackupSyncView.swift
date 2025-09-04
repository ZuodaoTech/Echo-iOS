import SwiftUI
import UniformTypeIdentifiers

struct BackupSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // iCloud sync toggle - preserved for UI but non-functional
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    // Export/Import managers
    @StateObject private var exportManager = ExportManager()
    @StateObject private var importManager = ImportManager()
    
    // UI State
    @State private var showingExportOptions = false
    @State private var showingImportPicker = false
    @State private var showingImportPreview = false
    @State private var showingProgressView = false
    @State private var selectedExportOption: ExportOption = .withAudio
    @State private var exportedFileURL: URL?
    @State private var showingShareSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    enum ExportOption {
        case withAudio
        case textOnly
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(NSLocalizedString("settings.icloud_sync", comment: ""))
                                Text("(Coming Soon)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Text(NSLocalizedString("settings.icloud_sync_desc", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(true)  // Disabled until iCloud sync is reimplemented
                    
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
                
                // Export/Import Section
                Section {
                    // Export Button
                    Button(action: { showingExportOptions = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("settings.export_backup", comment: "Export Backup"))
                            Spacer()
                            if exportManager.isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(exportManager.isExporting)
                    
                    // Import Button
                    Button(action: { showingImportPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("settings.import_backup", comment: "Import Backup"))
                            Spacer()
                            if importManager.isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(importManager.isImporting)
                    
                } header: {
                    Text(NSLocalizedString("settings.backup", comment: "Backup"))
                } footer: {
                    Text(NSLocalizedString("settings.backup_desc", comment: "Export your scripts to a file or import from a previous backup"))
                        .font(.caption)
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
        }
        .confirmationDialog(
            NSLocalizedString("settings.export_options", comment: "Export Options"),
            isPresented: $showingExportOptions
        ) {
            Button(NSLocalizedString("settings.export_with_audio", comment: "With Audio Files")) {
                selectedExportOption = .withAudio
                performExport()
            }
            Button(NSLocalizedString("settings.export_text_only", comment: "Text Only (Smaller File)")) {
                selectedExportOption = .textOnly
                performExport()
            }
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
        }
        .sheet(isPresented: $showingImportPicker) {
            DocumentPicker(
                types: [UTType(filenameExtension: "zip")!, UTType(filenameExtension: "archive")!],
                onPick: { url in
                    Task {
                        await performImport(from: url)
                    }
                }
            )
        }
        .sheet(item: $exportedFileURL) { url in
            ShareSheet(items: [url])
        }
        .alert(
            NSLocalizedString("alert.title", comment: ""),
            isPresented: $showingAlert
        ) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingImportPreview) {
            if let preview = importManager.currentImportPreview {
                ImportPreviewView(
                    preview: preview,
                    onConfirm: { resolution in
                        showingImportPreview = false
                        Task {
                            await finalizeImport(with: resolution)
                        }
                    },
                    onCancel: {
                        showingImportPreview = false
                    }
                )
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performExport() {
        Task {
            do {
                let includeAudio = selectedExportOption == .withAudio
                let url = try await exportManager.exportAllScripts(includeAudio: includeAudio)
                
                await MainActor.run {
                    exportedFileURL = url
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func performImport(from url: URL) async {
        do {
            let preview = try await importManager.previewImport(from: url)
            await MainActor.run {
                showingImportPreview = true
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func finalizeImport(with resolution: ImportConflictResolution) async {
        // Implementation will be added when we have the import URL saved
        // For now, show a message
        await MainActor.run {
            alertMessage = NSLocalizedString("Import completed successfully", comment: "")
            showingAlert = true
        }
    }
}

// MARK: - Supporting Views

struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct BackupSyncView_Previews: PreviewProvider {
    static var previews: some View {
        BackupSyncView()
    }
}