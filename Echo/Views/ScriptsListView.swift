import SwiftUI
import CoreData

struct ScriptsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Lazy initialize AudioCoordinator only when needed
    @StateObject private var audioService = AudioCoordinator.shared
    
    // FetchRequests - only executed when this view is created (Core Data ready)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        animation: .default
    )
    private var scripts: FetchedResults<SelftalkScript>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>
    
    @State private var selectedTags: Set<Tag> = []
    @State private var showingAddScript = false
    @State private var scriptToEdit: SelftalkScript?
    @State private var showingFilterSheet = false
    @State private var deletingScriptIds = Set<UUID>()  // Track scripts being deleted
    @State private var hasSetInitialFilter = false
    
    private var filteredScripts: [SelftalkScript] {
        scripts.filter { script in
            // CRITICAL: Filter out scripts that are being deleted
            guard !deletingScriptIds.contains(script.id) else {
                return false
            }
            
            // Apply tag filter if any tags are selected
            if !selectedTags.isEmpty {
                let scriptTags = Set(script.tagsArray)
                // Show scripts that have at least one of the selected tags
                return !selectedTags.intersection(scriptTags).isEmpty
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Simple view - Core Data is guaranteed to be ready
                if scripts.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(filteredScripts, id: \.id) { script in
                            ScriptCard(
                                script: script,
                                onEdit: {
                                    audioService.stopPlayback()  // Stop any playing audio
                                    scriptToEdit = script
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        audioService.stopPlayback()  // Stop any playing audio
                        showingAddScript = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddScript) {
                AddEditScriptView(script: nil)
            }
            .sheet(item: $scriptToEdit) { script in
                AddEditScriptView(
                    script: script,
                    onDelete: { scriptId in
                        deleteScript(withId: scriptId)
                    }
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                TagFilterSheet(
                    allTags: Array(allTags),
                    selectedTags: $selectedTags
                )
            }
        }
        .onAppear {
            // Check first launch status before any setup
            let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            
            // Note: Sample data is now created in PersistenceController.importSamplesIfNeeded()
            // No need to call setupInitialData() anymore
            setupInitialFilter(isFirstLaunch: isFirstLaunch)
        }
        .onChange(of: selectedTags) { newTags in
            // Save selected tags for next launch
            let tagIds = newTags.map { $0.id.uuidString }
            UserDefaults.standard.set(tagIds, forKey: "lastSelectedTagIds")
        }
    }
    
    private func setupInitialFilter(isFirstLaunch: Bool) {
        guard !hasSetInitialFilter else { return }
        hasSetInitialFilter = true
        
        if !isFirstLaunch {
            // Not first launch - restore last filter if saved
            if let savedTagIds = UserDefaults.standard.array(forKey: "lastSelectedTagIds") as? [String] {
                let tagIds = savedTagIds.compactMap { UUID(uuidString: $0) }
                let matchingTags = allTags.filter { tagIds.contains($0.id) }
                selectedTags = Set(matchingTags)
            }
        }
        // First launch - default to All (empty set)
    }
    
    private func cleanupAfterDeletion(_ scriptId: UUID) {
        // Clear any lingering references to prevent crashes
        #if DEBUG
        print("  🧹 Cleaning up references for deleted script...")
        #endif
        
        // Clear from audio service if it was playing
        if audioService.currentPlayingScriptId == scriptId {
            audioService.stopPlayback()  // Extra safety
        }
        
        // Clear from processing IDs if present
        audioService.processingScriptIds.remove(scriptId)
    }
    
    private func deleteScript(withId scriptId: UUID) {
        #if DEBUG
        print("🗑️ ScriptsListView: Starting safe deletion for script ID: \(scriptId)")
        #endif
        
        // CRITICAL STEP 1: Remove from UI immediately by marking as deleting
        // This causes filteredScripts to exclude it, destroying the ScriptCard
        #if DEBUG
        print("  🎯 Removing script from UI first...")
        #endif
        deletingScriptIds.insert(scriptId)
        
        // Clear the edit sheet reference if it's this script
        if scriptToEdit?.id == scriptId {
            scriptToEdit = nil
        }
        
        // STEP 2: Wait for UI to update and destroy the ScriptCard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            #if DEBUG
            print("  ⏳ UI updated, proceeding with deletion...")
            #endif
            
            // Fetch the script fresh from Core Data
            let fetchRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", scriptId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let scripts = try self.viewContext.fetch(fetchRequest)
                guard let script = scripts.first else {
                    #if DEBUG
                    print("  ❌ Script not found with ID: \(scriptId)")
                    #endif
                    // Remove from deleting set since it doesn't exist
                    self.deletingScriptIds.remove(scriptId)
                    return
                }
                
                // Cache necessary data before deletion
                let scriptText = String(script.scriptText.prefix(50))
                let hasRecording = script.hasRecording
                let notificationEnabled = script.notificationEnabled
                
                #if DEBUG
                print("  📝 Deleting script from database: \(scriptText)...")
                #endif
                
                // Step 3: Stop any active audio operations
                if self.audioService.currentPlayingScriptId == scriptId {
                    #if DEBUG
                    print("  ⏸️ Stopping playback...")
                    #endif
                    self.audioService.stopPlayback()
                }
                
                // Step 4: Clean up external resources
                
                // 4a. Cancel notifications if enabled
                if notificationEnabled {
                    #if DEBUG
                    print("  🔔 Cancelling notifications...")
                    #endif
                    NotificationManager.shared.cancelNotifications(for: script)
                }
                
                // 4b. Delete audio files if they exist
                if hasRecording {
                    #if DEBUG
                    print("  🎵 Deleting audio files...")
                    #endif
                    self.audioService.deleteRecording(for: script)
                }
                
                // Step 5: Delete from Core Data
                #if DEBUG
                print("  💾 Deleting from database...")
                #endif
                self.viewContext.delete(script)
                
                // Step 6: Save the context
                try self.viewContext.save()
                
                #if DEBUG
                print("  ✅ Successfully deleted script: \(scriptText)")
                #endif
                
                // Step 7: Complete cleanup of all references
                self.cleanupAfterDeletion(scriptId)
                
                // Step 8: Remove from deleting set
                self.deletingScriptIds.remove(scriptId)
                
            } catch {
                #if DEBUG
                print("  ❌ Failed to delete script: \(error.localizedDescription)")
                #endif
                // Remove from deleting set to show the script again
                self.deletingScriptIds.remove(scriptId)
            }
        }
    }
    
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.quote")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(NSLocalizedString("empty.no_cards", comment: ""))
                .font(.title2)
                .fontWeight(.medium)
            
            Text(NSLocalizedString("empty.tap_to_create", comment: ""))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct TagFilterSheet: View {
    let allTags: [Tag]
    @Binding var selectedTags: Set<Tag>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selected tags at top
                if !selectedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(selectedTags), id: \.id) { tag in
                                TagChip(tag: tag, isSelected: true) {
                                    selectedTags.remove(tag)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGray6))
                    
                    Divider()
                }
                
                List {
                    Section {
                        Button {
                            selectedTags.removeAll()
                        } label: {
                            HStack {
                                Text(NSLocalizedString("filter.all_cards", comment: ""))
                                Spacer()
                                if selectedTags.isEmpty {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Section(NSLocalizedString("filter.tags_section", comment: "")) {
                        ForEach(allTags, id: \.id) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(tag.scriptCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("filter.title", comment: ""))
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

struct ScriptsListView_Previews: PreviewProvider {
    static var previews: some View {
        ScriptsListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
