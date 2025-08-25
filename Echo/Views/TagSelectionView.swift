import SwiftUI
import CoreData

struct TagSelectionView: View {
    @Binding var selectedTags: Set<Tag>
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>
    
    @State private var showingNewTagAlert = false
    @State private var newTagName = ""
    @State private var searchText = ""
    
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
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                selectedTags.remove(tag)
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
                        Label("New Tag", systemImage: "plus.circle.fill")
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
                                selectedTags.insert(tag)
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
    }
    
    private func createNewTag() {
        let trimmedName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if tag already exists
        if allTags.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            // Tag exists, just add it to selection
            if let existingTag = allTags.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
                selectedTags.insert(existingTag)
            }
        } else {
            // Create new tag
            let newTag = Tag.create(name: trimmedName, in: viewContext)
            do {
                try viewContext.save()
                selectedTags.insert(newTag)
            } catch {
                print("Failed to create tag: \(error)")
            }
        }
        
        newTagName = ""
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TagSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        TagSelectionView(selectedTags: .constant(Set<Tag>()))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}