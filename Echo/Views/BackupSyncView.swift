import SwiftUI
import UniformTypeIdentifiers

struct BackupSyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // iCloud sync toggle - preserved for UI but non-functional
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    
    // Export/Import managers - will be initialized in init
    @StateObject private var exportManager: ExportManager
    @StateObject private var importManager: ImportManager
    
    init() {
        // Create managers without accessing PersistenceController.shared
        // We'll use the viewContext from environment instead
        _exportManager = StateObject(wrappedValue: ExportManager(context: nil))
        _importManager = StateObject(wrappedValue: ImportManager(context: nil))
    }
    
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
    @State private var pendingImportURL: URL?  // Store the URL for finalizing import
    
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
            .overlay {
                // Show progress during import/export
                if exportManager.isExporting || importManager.isImporting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text(exportManager.isExporting ? 
                                NSLocalizedString("Exporting...", comment: "") : 
                                NSLocalizedString("Importing...", comment: ""))
                                .foregroundColor(.white)
                                .font(.headline)
                            
                            if exportManager.isExporting && exportManager.exportProgress > 0 {
                                ProgressView(value: exportManager.exportProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .frame(width: 200)
                            } else if importManager.isImporting && importManager.importProgress > 0 {
                                ProgressView(value: importManager.importProgress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                    .frame(width: 200)
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.gray.opacity(0.9))
                        )
                    }
                }
            }
        }
        .onAppear {
            // Set the context from environment
            exportManager.setContext(viewContext)
            importManager.setContext(viewContext)
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
                types: [UTType.json, UTType(filenameExtension: "zip")!, UTType(filenameExtension: "archive")!],
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
            // Store the URL for later use in finalizeImport
            await MainActor.run {
                pendingImportURL = url
            }
            
            let preview = try await importManager.previewImport(from: url)
            await MainActor.run {
                showingImportPreview = true
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
                showingAlert = true
                pendingImportURL = nil  // Clear on error
            }
        }
    }
    
    private func finalizeImport(with resolution: ImportConflictResolution) async {
        guard let url = pendingImportURL else {
            await MainActor.run {
                alertMessage = NSLocalizedString("No import file selected", comment: "")
                showingAlert = true
            }
            return
        }
        
        do {
            // Perform the actual import
            let result = try await importManager.performImport(from: url, resolution: resolution)
            
            // Save Core Data changes
            try viewContext.save()
            
            // Show success message with details
            await MainActor.run {
                var message = NSLocalizedString("Import completed successfully", comment: "")
                message += "\n"
                if result.imported > 0 {
                    message += String(format: NSLocalizedString("Imported: %d scripts", comment: ""), result.imported)
                }
                if result.updated > 0 {
                    message += "\n" + String(format: NSLocalizedString("Updated: %d scripts", comment: ""), result.updated)
                }
                if result.skipped > 0 {
                    message += "\n" + String(format: NSLocalizedString("Skipped: %d scripts", comment: ""), result.skipped)
                }
                if !result.failed.isEmpty {
                    message += "\n" + String(format: NSLocalizedString("Failed: %d scripts", comment: ""), result.failed.count)
                }
                
                alertMessage = message
                showingAlert = true
                
                // Clean up
                pendingImportURL = nil
                
                // Clean up temporary file if it exists
                if url.path.contains("tmp") || url.path.contains("Temp") {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = NSLocalizedString("Import failed", comment: "") + ": \(error.localizedDescription)"
                showingAlert = true
                pendingImportURL = nil
            }
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
                // Access the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    // Create a temporary copy that we can access
                    let fileManager = FileManager.default
                    let tempURL = fileManager.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    
                    do {
                        // Remove existing file if any
                        try? fileManager.removeItem(at: tempURL)
                        // Copy to temporary location
                        try fileManager.copyItem(at: url, to: tempURL)
                        // Stop accessing the original
                        url.stopAccessingSecurityScopedResource()
                        // Use the temporary copy
                        parent.onPick(tempURL)
                    } catch {
                        url.stopAccessingSecurityScopedResource()
                        print("Error copying file: \(error)")
                        // Still try to use the original URL
                        parent.onPick(url)
                    }
                } else {
                    // If we can't access as security-scoped, try directly
                    parent.onPick(url)
                }
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