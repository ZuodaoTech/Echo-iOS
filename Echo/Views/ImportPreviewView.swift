//
//  ImportPreviewView.swift
//  Echo
//
//  Preview and conflict resolution for import
//

import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    let onConfirm: (ImportConflictResolution) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolution: ImportConflictResolution = .smartMerge
    
    var body: some View {
        NavigationView {
            List {
                // Backup Info Section
                Section {
                    HStack {
                        Text(NSLocalizedString("import.backup_date", comment: "Backup Date"))
                        Spacer()
                        Text(preview.backupMetadata.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("import.device", comment: "Device"))
                        Spacer()
                        Text(preview.backupMetadata.deviceName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("import.version", comment: "Version"))
                        Spacer()
                        Text(preview.backupMetadata.appVersion)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("import.backup_info", comment: "Backup Information"))
                }
                
                // Content Summary Section
                Section {
                    if preview.scriptsToImport > 0 {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text(String(format: NSLocalizedString("import.new_scripts", comment: "%d new scripts"), preview.scriptsToImport))
                        }
                    }
                    
                    if preview.scriptsToUpdate > 0 {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(.orange)
                            Text(String(format: NSLocalizedString("import.update_scripts", comment: "%d scripts to update"), preview.scriptsToUpdate))
                        }
                    }
                    
                    if preview.newTags > 0 {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.blue)
                            Text(String(format: NSLocalizedString("import.new_tags", comment: "%d new tags"), preview.newTags))
                        }
                    }
                    
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.gray)
                        Text(String(format: NSLocalizedString("import.total_size", comment: "Total size: %.1f MB"), Double(preview.estimatedSize) / 1_048_576))
                    }
                } header: {
                    Text(NSLocalizedString("import.content", comment: "Content"))
                }
                
                // Conflict Resolution Section
                if !preview.conflicts.isEmpty {
                    Section {
                        Picker(NSLocalizedString("import.resolution", comment: "Resolution"), selection: $selectedResolution) {
                            Text(NSLocalizedString("import.smart_merge", comment: "Smart Merge (Recommended)"))
                                .tag(ImportConflictResolution.smartMerge)
                            Text(NSLocalizedString("import.keep_existing", comment: "Keep Existing"))
                                .tag(ImportConflictResolution.keepExisting)
                            Text(NSLocalizedString("import.replace_existing", comment: "Replace Existing"))
                                .tag(ImportConflictResolution.replaceExisting)
                            Text(NSLocalizedString("import.duplicate", comment: "Create Duplicates"))
                                .tag(ImportConflictResolution.mergeDuplicate)
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        ForEach(preview.conflicts.prefix(5), id: \.imported.id) { conflict in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(conflict.imported.scriptText.prefix(50)) + "...")
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                switch conflict.reason {
                                case .sameID:
                                    Label(NSLocalizedString("import.conflict_same", comment: "Same script exists"), systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                case .similarContent(let similarity):
                                    Label(String(format: NSLocalizedString("import.conflict_similar", comment: "%.0f%% similar"), similarity * 100), systemImage: "doc.on.doc.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        
                        if preview.conflicts.count > 5 {
                            Text(String(format: NSLocalizedString("import.more_conflicts", comment: "And %d more..."), preview.conflicts.count - 5))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text(NSLocalizedString("import.conflicts", comment: "Conflicts"))
                    } footer: {
                        Text(resolutionDescription)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("import.preview_title", comment: "Import Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        onCancel()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.import", comment: "Import")) {
                        onConfirm(selectedResolution)
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
    
    private var resolutionDescription: String {
        switch selectedResolution {
        case .smartMerge:
            return NSLocalizedString("import.smart_merge_desc", comment: "Keeps newer versions and merges play counts")
        case .keepExisting:
            return NSLocalizedString("import.keep_existing_desc", comment: "Skips scripts that already exist")
        case .replaceExisting:
            return NSLocalizedString("import.replace_existing_desc", comment: "Overwrites existing scripts with imported versions")
        case .mergeDuplicate:
            return NSLocalizedString("import.duplicate_desc", comment: "Creates new copies with '(Imported)' suffix")
        }
    }
}

struct ImportPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        let metadata = BackupMetadata()
        let preview = ImportPreview(
            backupMetadata: metadata,
            scriptsToImport: 10,
            scriptsToUpdate: 3,
            scriptsToSkip: 2,
            newTags: 5,
            conflicts: [],
            estimatedSize: 5_242_880
        )
        
        ImportPreviewView(
            preview: preview,
            onConfirm: { _ in },
            onCancel: { }
        )
    }
}