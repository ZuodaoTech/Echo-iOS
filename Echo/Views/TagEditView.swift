import SwiftUI
import CoreData

struct TagEditView: View {
    let tag: Tag
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var tagName: String = ""
    @State private var showingDeleteAlert = false
    @State private var scriptsUsingTag: Int = 0
    @State private var tagToDelete: Tag? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("tag.edit", comment: ""))) {
                    TextField(NSLocalizedString("tag.label", comment: ""), text: $tagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button(role: .destructive) {
                        // Check how many scripts use this tag
                        let request: NSFetchRequest<SelftalkScript> = SelftalkScript.fetchRequest()
                        request.predicate = NSPredicate(format: "ANY tags == %@", tag)
                        scriptsUsingTag = (try? viewContext.count(for: request)) ?? 0
                        showingDeleteAlert = true
                    } label: {
                        Label(NSLocalizedString("action.delete", comment: ""), systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tag.edit", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.save", comment: "")) {
                        saveChanges()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            tagName = tag.name
        }
        .alert(NSLocalizedString("tag.delete.confirm.title", comment: ""), isPresented: $showingDeleteAlert) {
            Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                deleteTag()
            }
        } message: {
            if scriptsUsingTag > 0 {
                Text(String(format: NSLocalizedString("tag.delete.confirm.message", comment: ""), scriptsUsingTag))
            } else {
                Text(NSLocalizedString("tag.delete.confirm.empty", comment: ""))
            }
        }
    }
    
    private func saveChanges() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if tag still exists and is not faulted
        guard !tag.isFault && tag.managedObjectContext != nil else {
            dismiss()
            return
        }
        
        tag.name = trimmedName
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to save tag changes: \(error)")
            #endif
        }
    }
    
    private func deleteTag() {
        // Store the tag for deletion
        tagToDelete = tag
        
        // Dismiss the view first
        dismiss()
        
        // Delete after a small delay to ensure view is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let tagToDelete = tagToDelete,
                  !tagToDelete.isFault,
                  tagToDelete.managedObjectContext != nil else { return }
            
            viewContext.delete(tagToDelete)
            
            do {
                try viewContext.save()
            } catch {
                #if DEBUG
                print("Failed to delete tag: \(error)")
                #endif
            }
        }
    }
}

struct TagEditView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let tag = Tag.create(name: "Sample Tag", in: context)
        
        return TagEditView(tag: tag)
            .environment(\.managedObjectContext, context)
    }
}