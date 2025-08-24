import SwiftUI
import CoreData

struct ScriptsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioService = AudioCoordinator.shared
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        animation: .default
    )
    private var scripts: FetchedResults<SelftalkScript>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>
    
    @State private var selectedCategory: Category?
    @State private var showingAddScript = false
    @State private var scriptToEdit: SelftalkScript?
    @State private var showingFilterSheet = false
    @State private var deletingScriptIds = Set<UUID>()  // Track scripts being deleted
    
    private var filteredScripts: [SelftalkScript] {
        scripts.filter { script in
            // CRITICAL: Filter out scripts that are being deleted
            guard !deletingScriptIds.contains(script.id) else {
                return false
            }
            
            // Apply category filter if selected
            if let category = selectedCategory {
                return script.category == category
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
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
            .navigationTitle("Scripts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if let category = selectedCategory {
                                Text(category.name)
                                    .font(.caption)
                            }
                        }
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
                CategoryFilterSheet(
                    categories: Array(categories),
                    selectedCategory: $selectedCategory
                )
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        // Always remove duplicates first
        Category.removeDuplicateCategories(context: viewContext)
        
        // Check if this is first launch
        let hasLaunchedKey = "hasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            // First launch - create default categories and sample scripts
            Category.createDefaultCategories(context: viewContext)
            createSampleScripts()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        } else if categories.isEmpty {
            // Not first launch but no categories - just create categories
            Category.createDefaultCategories(context: viewContext)
        }
    }
    
    private func createSampleScripts() {
        // Wait for categories to be created
        do {
            try viewContext.save()
            
            // Fetch the newly created categories
            let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
            let allCategories = try viewContext.fetch(categoryRequest)
            
            // Sample 1: Breaking Bad Habits
            if let breakingBadHabits = allCategories.first(where: { $0.name == "Breaking Bad Habits" }) {
                _ = SelftalkScript.create(
                    scriptText: "I never smoke, because it stinks, and I hate being controlled.",
                    category: breakingBadHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
            
            // Sample 2: Building Good Habits
            if let buildingGoodHabits = allCategories.first(where: { $0.name == "Building Good Habits" }) {
                _ = SelftalkScript.create(
                    scriptText: "I always go to bed before 10 p.m., because it's healthier, and I love waking up with a great deal of energy.",
                    category: buildingGoodHabits,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
            
            // Sample 3: Appropriate Positivity
            if let appropriatePositivity = allCategories.first(where: { $0.name == "Appropriate Positivity" }) {
                _ = SelftalkScript.create(
                    scriptText: "I made a few mistakes, but I also did several things well. Mistakes are a normal part of learning, and I can use them as an opportunity to improve. Most people are likely focused on the overall effort or result, not just the small errors.",
                    category: appropriatePositivity,
                    repetitions: 3,
                    privacyMode: true,
                    in: viewContext
                )
            }
            
            try viewContext.save()
        } catch {
            print("Error creating sample scripts: \(error)")
        }
    }
    
    private func cleanupAfterDeletion(_ scriptId: UUID) {
        // Clear any lingering references to prevent crashes
        print("  🧹 Cleaning up references for deleted script...")
        
        // Clear from audio service if it was playing
        if audioService.currentPlayingScriptId == scriptId {
            audioService.stopPlayback()  // Extra safety
        }
        
        // Clear from processing IDs if present
        audioService.processingScriptIds.remove(scriptId)
    }
    
    private func deleteScript(withId scriptId: UUID) {
        print("🗑️ ScriptsListView: Starting safe deletion for script ID: \(scriptId)")
        
        // CRITICAL STEP 1: Remove from UI immediately by marking as deleting
        // This causes filteredScripts to exclude it, destroying the ScriptCard
        print("  🎯 Removing script from UI first...")
        deletingScriptIds.insert(scriptId)
        
        // Clear the edit sheet reference if it's this script
        if scriptToEdit?.id == scriptId {
            scriptToEdit = nil
        }
        
        // STEP 2: Wait for UI to update and destroy the ScriptCard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("  ⏳ UI updated, proceeding with deletion...")
            
            // Fetch the script fresh from Core Data
            let fetchRequest: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", scriptId as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let scripts = try self.viewContext.fetch(fetchRequest)
                guard let script = scripts.first else {
                    print("  ❌ Script not found with ID: \(scriptId)")
                    // Remove from deleting set since it doesn't exist
                    self.deletingScriptIds.remove(scriptId)
                    return
                }
                
                // Cache necessary data before deletion
                let scriptText = String(script.scriptText.prefix(50))
                let hasRecording = script.hasRecording
                let notificationEnabled = script.notificationEnabled
                
                print("  📝 Deleting script from database: \(scriptText)...")
                
                // Step 3: Stop any active audio operations
                if self.audioService.currentPlayingScriptId == scriptId {
                    print("  ⏸️ Stopping playback...")
                    self.audioService.stopPlayback()
                }
                
                // Step 4: Clean up external resources
                
                // 4a. Cancel notifications if enabled
                if notificationEnabled {
                    print("  🔔 Cancelling notifications...")
                    NotificationManager.shared.cancelNotifications(for: script)
                }
                
                // 4b. Delete audio files if they exist
                if hasRecording {
                    print("  🎵 Deleting audio files...")
                    self.audioService.deleteRecording(for: script)
                }
                
                // Step 5: Delete from Core Data
                print("  💾 Deleting from database...")
                self.viewContext.delete(script)
                
                // Step 6: Save the context
                try self.viewContext.save()
                
                print("  ✅ Successfully deleted script: \(scriptText)")
                
                // Step 7: Complete cleanup of all references
                self.cleanupAfterDeletion(scriptId)
                
                // Step 8: Remove from deleting set
                self.deletingScriptIds.remove(scriptId)
                
            } catch {
                print("  ❌ Failed to delete script: \(error.localizedDescription)")
                // Remove from deleting set to show the script again
                self.deletingScriptIds.remove(scriptId)
                // TODO: Show error alert to user
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
            
            Text("No Scripts Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap the + button to create your first self-talk script")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct CategoryFilterSheet: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        selectedCategory = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("All Scripts")
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section("Categories") {
                    ForEach(categories, id: \.id) { category in
                        Button {
                            selectedCategory = category
                            dismiss()
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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