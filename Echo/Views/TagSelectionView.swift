import SwiftUI
import CoreData

struct TagSelectionView: View {
    @Binding var selectedTags: Set<Tag>
    var currentScript: SelftalkScript? = nil  // Optional: the script being edited
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Tag.sortOrder, ascending: true),
            NSSortDescriptor(keyPath: \Tag.name, ascending: true)
        ],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>
    
    @State private var showingNewTagAlert = false
    @State private var newTagName = ""
    @State private var searchText = ""
    @State private var showingNowLimitAlert = false
    @State private var scriptsWithNowTag: [SelftalkScript] = []
    @State private var tagToEdit: Tag? = nil
    
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return Array(allTags)
        }
        return allTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tags...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Selected tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(selectedTags.filter { !$0.isFault && $0.managedObjectContext != nil }), id: \.id) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                selectedTags.remove(tag)
                            } onLongPress: {
                                if !tag.isNowTag {  // Don't allow editing the Now tag
                                    tagToEdit = tag
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Available tags
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 8)
                ], spacing: 8) {
                    // Add new tag button
                    Button {
                        showingNewTagAlert = true
                    } label: {
                        Label(NSLocalizedString("tag.new", comment: ""), systemImage: "plus.circle.fill")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(15)
                    }
                    
                    // Existing tags
                    ForEach(filteredTags, id: \.id) { tag in
                        if !selectedTags.contains(tag) {
                            TagChip(tag: tag, isSelected: false) {
                                handleTagSelection(tag)
                            } onLongPress: {
                                if !tag.isNowTag {  // Don't allow editing the Now tag
                                    tagToEdit = tag
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .alert("New Tag", isPresented: $showingNewTagAlert) {
            TextField("Tag name", text: $newTagName)
            Button("Cancel", role: .cancel) {
                newTagName = ""
            }
            Button("Add") {
                createNewTag()
            }
        }
        .sheet(item: $tagToEdit) { tag in
            TagEditView(tag: tag)
        }
        .onAppear {
            // Clean up any deleted tags from selectedTags
            selectedTags = selectedTags.filter { !$0.isFault && $0.managedObjectContext != nil }
        }
        .onChange(of: allTags.count) { _ in
            // Clean up when tags are deleted
            selectedTags = selectedTags.filter { !$0.isFault && $0.managedObjectContext != nil }
        }
    }
    
    private func handleTagSelection(_ tag: Tag) {
        // Check if this is the "Now" tag and if limit would be exceeded
        if tag.isNowTag {
            let maxNowCards = UserDefaults.standard.integer(forKey: "maxNowCards")
            let effectiveMax = maxNowCards > 0 ? maxNowCards : 3 // Default to 3
            
            // Fetch all scripts with the Now tag
            let request: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
            request.predicate = NSPredicate(format: "ANY tags == %@", tag)
            
            if let scripts = try? viewContext.fetch(request) {
                // Filter out the current script if we're editing one
                let otherScripts = scripts.filter { $0.id != currentScript?.id }
                
                if otherScripts.count >= effectiveMax {
                    // Show picker to remove from another card
                    scriptsWithNowTag = otherScripts
                    showingNowLimitAlert = true
                    return
                }
            }
        }
        
        selectedTags.insert(tag)
    }
    
    private func createNewTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Use the new findOrCreateNormalized method which handles duplicates
        let tag = Tag.findOrCreateNormalized(name: trimmedName, in: viewContext)
        
        do {
            if viewContext.hasChanges {
                try viewContext.save()
            }
            // Add to selection if it's a new tag or user is explicitly adding it
            selectedTags.insert(tag)
        } catch {
            print("Failed to create/save tag: \(error)")
        }
        
        newTagName = ""
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        // Check if tag is valid before rendering
        if !tag.isFault && tag.managedObjectContext != nil {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(.footnote)
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                tag.isNowTag ? 
                    (isSelected ? Color.orange : Color.yellow.opacity(0.3)) :
                    (isSelected ? Color.blue : Color.gray.opacity(0.2))
            )
            .foregroundColor(
                tag.isNowTag ?
                    (isSelected ? .white : Color.orange) :
                    (isSelected ? .white : .primary)
            )
            .cornerRadius(15)
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
            .onLongPressGesture {
                onLongPress?()
            }
        } else {
            EmptyView()
        }
    }
}

struct TagSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TagSelectionView(selectedTags: .constant(Set<Tag>()))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}