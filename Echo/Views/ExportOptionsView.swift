import SwiftUI
import CoreData

struct ExportOptionsView: View {
    @Binding var exportProgress: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)]
    ) private var scripts: FetchedResults<SelftalkScript>
    
    @State private var includeAudio = true
    @State private var exportFormat: ExportService.ExportFormat = .bundle
    @State private var selectedScripts = Set<UUID>()
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showingError = false
    @State private var selectAll = true
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Toggle("Include Audio Files", isOn: $includeAudio)
                        .disabled(exportFormat == .textOnly)
                    
                    Picker("Format", selection: $exportFormat) {
                        Text("Echo Bundle").tag(ExportService.ExportFormat.bundle)
                        Text("Plain Text").tag(ExportService.ExportFormat.textOnly)
                        Text("JSON").tag(ExportService.ExportFormat.json)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if exportFormat == .bundle && includeAudio {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.footnote)
                            Text("Audio files will increase export size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Export Options")
                }
                
                Section {
                    HStack {
                        Text("Select Scripts")
                        Spacer()
                        Button(selectAll ? "Deselect All" : "Select All") {
                            if selectAll {
                                selectedScripts.removeAll()
                            } else {
                                selectedScripts = Set(scripts.map { $0.id })
                            }
                            selectAll.toggle()
                        }
                        .font(.caption)
                    }
                    
                    ForEach(scripts) { script in
                        HStack {
                            Image(systemName: selectedScripts.contains(script.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedScripts.contains(script.id) ? .accentColor : .secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(script.scriptText)
                                    .lineLimit(2)
                                    .font(.subheadline)
                                
                                HStack {
                                    if let category = script.category {
                                        Text(category.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if script.audioFilePath != nil {
                                        Image(systemName: "mic.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedScripts.contains(script.id) {
                                selectedScripts.remove(script.id)
                            } else {
                                selectedScripts.insert(script.id)
                            }
                        }
                    }
                } header: {
                    Text("Scripts (\(selectedScripts.count) selected)")
                }
            }
            .navigationTitle("Export Scripts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        performExport()
                    }
                    .disabled(selectedScripts.isEmpty)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportError ?? "An unknown error occurred")
            }
        }
        .onAppear {
            // Select all scripts by default
            selectedScripts = Set(scripts.map { $0.id })
        }
    }
    
    private func performExport() {
        let exportService = ExportService()
        let scriptsToExport = scripts.filter { selectedScripts.contains($0.id) }
        
        do {
            let url = try exportService.exportScripts(
                scriptsToExport,
                includeAudio: includeAudio && exportFormat != .textOnly,
                format: exportFormat
            )
            
            exportURL = url
            exportProgress = "\(scriptsToExport.count) scripts exported"
            showingShareSheet = true
            
        } catch {
            exportError = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}