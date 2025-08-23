import SwiftUI
import CoreData
import AVFoundation

struct AddEditScriptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService = AudioService.shared
    
    let script: SelftalkScript?
    
    @State private var scriptText = ""
    @State private var selectedCategory: Category?
    @State private var repetitions: Int16 = 3
    @State private var intervalSeconds: Double = 2.0
    @State private var privacyModeEnabled = true
    @State private var showingNewCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var isRecording = false
    @State private var showingMicPermissionAlert = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>
    
    private var isEditing: Bool {
        script != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Script") {
                    TextEditor(text: $scriptText)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if scriptText.isEmpty {
                                    Text("Enter your self-talk script here...")
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section("Settings") {
                    // Category Picker
                    HStack {
                        Text("Category")
                        Spacer()
                        Menu {
                            ForEach(categories, id: \.id) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    if selectedCategory == category {
                                        Label(category.name, systemImage: "checkmark")
                                    } else {
                                        Text(category.name)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button {
                                showingNewCategoryAlert = true
                            } label: {
                                Label("Add New Category...", systemImage: "plus")
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory?.name ?? "Select Category")
                                    .foregroundColor(selectedCategory == nil ? .secondary : .primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Repetitions Stepper
                    Stepper(value: $repetitions, in: 1...10) {
                        HStack {
                            Text("Repetitions")
                            Spacer()
                            Text("\(repetitions)x")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Privacy Mode Toggle
                    Toggle("Privacy Mode", isOn: $privacyModeEnabled)
                    
                    if privacyModeEnabled {
                        Text("Audio will only play when earphones are connected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isEditing {
                    Section("Recording") {
                        RecordingButton(
                            isRecording: $isRecording,
                            hasRecording: script?.hasRecording ?? false,
                            recordingDuration: script?.formattedDuration ?? "",
                            onRecord: handleRecording,
                            onDelete: deleteRecording
                        )
                        
                        if script?.hasRecording == true {
                            VStack(alignment: .leading, spacing: 8) {
                                // Interval slider
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pause between repetitions: \(String(format: "%.1f", intervalSeconds))s")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Slider(value: $intervalSeconds, in: 0...10, step: 0.5)
                                }
                                
                                // Duration info
                                HStack {
                                    Label("Total duration", systemImage: "clock")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(calculateTotalDuration())
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Script" : "New Script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveScript()
                    }
                    .disabled(scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("New Category", isPresented: $showingNewCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
                Button("Add") {
                    createNewCategory()
                }
            } message: {
                Text("Enter the name for your new category")
            }
            .alert("Microphone Access", isPresented: $showingMicPermissionAlert) {
                Button("OK") { }
            } message: {
                Text("Please grant microphone access in Settings to record audio")
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        if let script = script {
            scriptText = script.scriptText
            selectedCategory = script.category
            repetitions = script.repetitions
            intervalSeconds = script.intervalSeconds
            privacyModeEnabled = script.privacyModeEnabled
        }
    }
    
    private func calculateTotalDuration() -> String {
        guard let script = script, script.audioDuration > 0 else { return "—" }
        
        let totalAudioTime = Double(repetitions) * script.audioDuration
        let totalIntervalTime = Double(repetitions - 1) * intervalSeconds
        let total = totalAudioTime + totalIntervalTime
        
        let mins = Int(total) / 60
        let secs = Int(total) % 60
        
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private func saveScript() {
        let trimmedText = scriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if let existingScript = script {
            // Update existing script
            existingScript.scriptText = trimmedText
            existingScript.category = selectedCategory
            existingScript.repetitions = repetitions
            existingScript.intervalSeconds = intervalSeconds
            existingScript.privacyModeEnabled = privacyModeEnabled
            existingScript.updatedAt = Date()
        } else {
            // Create new script
            _ = SelftalkScript.create(
                scriptText: trimmedText,
                category: selectedCategory,
                repetitions: repetitions,
                privacyMode: privacyModeEnabled,
                in: viewContext
            )
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving script: \(error)")
        }
    }
    
    private func createNewCategory() {
        guard !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = newCategoryName
        category.createdAt = Date()
        category.sortOrder = Int32(categories.count)
        
        do {
            try viewContext.save()
            selectedCategory = category
            newCategoryName = ""
        } catch {
            print("Error creating category: \(error)")
        }
    }
    
    private func handleRecording() {
        guard let script = script else { return }
        
        if isRecording {
            audioService.stopRecording()
            isRecording = false
        } else {
            audioService.requestMicrophonePermission { granted in
                if granted {
                    do {
                        try audioService.startRecording(for: script)
                        isRecording = true
                    } catch {
                        print("Recording error: \(error)")
                    }
                } else {
                    showingMicPermissionAlert = true
                }
            }
        }
    }
    
    private func deleteRecording() {
        guard let script = script else { return }
        audioService.deleteRecording(for: script)
    }
}

struct RecordingButton: View {
    @Binding var isRecording: Bool
    let hasRecording: Bool
    let recordingDuration: String
    let onRecord: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if hasRecording && !isRecording {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recording saved")
                            .foregroundColor(.secondary)
                        if !recordingDuration.isEmpty {
                            Text(recordingDuration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        onDelete()
                    } label: {
                        Text("Delete")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Button {
                onRecord()
            } label: {
                HStack {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(isRecording ? .red : .blue)
                    
                    Text(isRecording ? "Stop Recording" : (hasRecording ? "Re-record" : "Start Recording"))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isRecording {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.red)
                    Text("Recording...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AddEditScriptView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditScriptView(script: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}