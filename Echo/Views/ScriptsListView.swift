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
    
    private var filteredScripts: [SelftalkScript] {
        if let category = selectedCategory {
            return scripts.filter { $0.category == category }
        }
        return Array(scripts)
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
                                },
                                onDelete: {
                                    // Delete is now handled in edit view
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
                AddEditScriptView(script: script)
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