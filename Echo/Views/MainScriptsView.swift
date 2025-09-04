//
//  MainScriptsView.swift
//  Echo
//
//  Wrapper view that manages Core Data readiness
//

import SwiftUI
import CoreData

struct MainScriptsView: View {
    @EnvironmentObject var persistenceController: PersistenceController
    
    var body: some View {
        Group {
            switch persistenceController.dataLoadingState {
            case .staticSamples:
                // Show static samples instantly
                NavigationView {
                    StaticSampleCardsView()
                        .navigationTitle("")
                }
                
            case .transitioningToCore:
                // Brief loading state during transition
                NavigationView {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(NSLocalizedString("loading.cards", comment: "Loading your cards..."))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .navigationTitle("")
                }
                
            case .coreDataReady:
                // Only create ScriptsListView when Core Data is ready
                ScriptsListView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                
            case .error(let message):
                // Error state with retry option
                NavigationView {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("error.load_cards", comment: "Unable to load cards"))
                            .font(.headline)
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button(NSLocalizedString("action.show_sample_cards", comment: "Show Sample Cards")) {
                            persistenceController.dataLoadingState = .staticSamples
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .navigationTitle("")
                }
            }
        }
    }
}