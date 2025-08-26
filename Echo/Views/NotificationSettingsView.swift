import SwiftUI
import CoreData

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @AppStorage("maxNotificationCards") private var maxNotificationCards = 1
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        predicate: NSPredicate(format: "notificationEnabled == YES")
    ) private var notificationEnabledScripts: FetchedResults<SelftalkScript>
    
    @State private var showingCardSelection = false
    @State private var cardsToDisable: Set<UUID> = []
    @State private var previousMaxCards = 1
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("notifications.max_cards", comment: "Maximum cards with notifications"))
                            Spacer()
                            Stepper(value: $maxNotificationCards, in: 1...5) {
                                Text("\(maxNotificationCards)")
                                    .foregroundColor(.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                        
                        if maxNotificationCards > 1 {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.footnote)
                                Text(NSLocalizedString("notifications.burden_warning", comment: "Too many notifications can become burdensome"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(NSLocalizedString("notifications.global_settings", comment: "Global Settings"))
                } footer: {
                    Text(NSLocalizedString("notifications.max_cards_footer", comment: "Limit how many cards can send notifications"))
                }
                
                Section {
                    if notificationEnabledScripts.isEmpty {
                        Text(NSLocalizedString("notifications.no_cards_enabled", comment: "No cards have notifications enabled"))
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(notificationEnabledScripts) { script in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(script.scriptText)
                                    .lineLimit(2)
                                    .font(.subheadline)
                                
                                HStack {
                                    if !script.tagsArray.isEmpty {
                                        Text(script.tagsArray.map { $0.name }.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(getFrequencyText(script.notificationFrequency ?? "medium"))
                                        .font(.caption)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text(String(format: NSLocalizedString("notifications.enabled_cards", comment: "Enabled Cards (%d)"), notificationEnabledScripts.count))
                }
                
                if !notificationPermissionRequested {
                    Section {
                        Button {
                            requestNotificationPermission()
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge")
                                Text(NSLocalizedString("notifications.request_permission", comment: "Enable Notifications"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("notifications.settings_title", comment: "Notification Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        dismiss()
                    }
                }
            }
            .onChange(of: maxNotificationCards) { newValue in
                handleMaxCardsChange(from: previousMaxCards, to: newValue)
                previousMaxCards = newValue
            }
            .onAppear {
                previousMaxCards = maxNotificationCards
            }
            .sheet(isPresented: $showingCardSelection) {
                CardSelectionView(
                    cardsToDisable: $cardsToDisable,
                    maxAllowed: maxNotificationCards,
                    onConfirm: disableSelectedCards
                )
            }
        }
    }
    
    private func getFrequencyText(_ frequency: String) -> String {
        switch frequency {
        case "high":
            return NSLocalizedString("notifications.frequency.high", comment: "")
        case "low":
            return NSLocalizedString("notifications.frequency.low", comment: "")
        default:
            return NSLocalizedString("notifications.frequency.medium", comment: "")
        }
    }
    
    private func handleMaxCardsChange(from oldValue: Int, to newValue: Int) {
        guard newValue < oldValue else { return }
        
        let enabledCount = notificationEnabledScripts.count
        if enabledCount > newValue {
            // Need to disable some cards
            showingCardSelection = true
        }
    }
    
    private func disableSelectedCards() {
        for script in notificationEnabledScripts {
            if cardsToDisable.contains(script.id) {
                script.notificationEnabled = false
                script.notificationEnabledAt = nil
            }
        }
        
        do {
            try viewContext.save()
            cardsToDisable.removeAll()
        } catch {
            print("Error disabling notifications: \(error)")
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    notificationPermissionRequested = true
                }
            } catch {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
}

// MARK: - Card Selection View for Disabling Notifications

struct CardSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @Binding var cardsToDisable: Set<UUID>
    let maxAllowed: Int
    let onConfirm: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SelftalkScript.createdAt, ascending: false)],
        predicate: NSPredicate(format: "notificationEnabled == YES")
    ) private var notificationEnabledScripts: FetchedResults<SelftalkScript>
    
    private var numberToSelect: Int {
        notificationEnabledScripts.count - maxAllowed
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Text(String(format: NSLocalizedString("notifications.select_to_disable", comment: "Select %d cards to disable notifications"), numberToSelect))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                
                List(notificationEnabledScripts) { script in
                    HStack {
                        Image(systemName: cardsToDisable.contains(script.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(cardsToDisable.contains(script.id) ? .red : .secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(script.scriptText)
                                .lineLimit(2)
                                .font(.subheadline)
                            
                            if !script.tagsArray.isEmpty {
                                Text(script.tagsArray.map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection(for: script.id)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("notifications.select_cards", comment: "Select Cards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.done", comment: "")) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(cardsToDisable.count != numberToSelect)
                }
            }
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if cardsToDisable.contains(id) {
            cardsToDisable.remove(id)
        } else {
            if cardsToDisable.count < numberToSelect {
                cardsToDisable.insert(id)
            }
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}