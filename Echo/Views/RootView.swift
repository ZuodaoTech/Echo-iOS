//
//  RootView.swift
//  Echo
//
//  Ultra-lightweight root view that renders instantly without any dependencies
//

import SwiftUI
import CoreData

struct RootView: View {
    // Start with no persistence controller
    @State private var persistenceController: PersistenceController?
    @State private var showingFullApp = false
    @State private var hasStartedInit = false
    
    var body: some View {
        Group {
            if showingFullApp, let controller = persistenceController {
                // Full app with Core Data ready
                ContentView()
                    .environment(\.managedObjectContext, controller.container.viewContext)
                    .environmentObject(controller)
                    .transition(.opacity.combined(with: .scale(scale: 1.0)))
            } else {
                // Instant sample cards - NO dependencies, renders immediately!
                NavigationView {
                    StaticSampleCardsView(onlyShowSamples: true)
                        .navigationTitle("")
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                // Show loading indicator
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingFullApp)
        .onAppear {
            // Start Core Data initialization AFTER first frame renders
            if !hasStartedInit {
                hasStartedInit = true
                print("🚀 RootView appeared - starting deferred initialization")
                
                // Small delay to ensure first frame is completely rendered
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    Task {
                        await initializePersistenceInBackground()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh permission states when app becomes active
            if persistenceController != nil {
                EchoApp.refreshPermissionStates()
            }
        }
    }
    
    private func initializePersistenceInBackground() async {
        print("🔄 Starting Core Data initialization in background...")
        
        // Create and initialize PersistenceController
        let controller = await Task(priority: .background) { () -> PersistenceController in
            let pc = PersistenceController()
            
            // Wait for stores to load
            let inMemory = pc.container.persistentStoreDescriptions.first?.url == URL(fileURLWithPath: "/dev/null")
            let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
            
            await pc.loadStores(inMemory: inMemory, iCloudEnabled: iCloudEnabled)
            
            print("✅ Core Data fully initialized")
            return pc
        }.value
        
        // Perform deferred app setup
        await MainActor.run {
            EchoApp.performDeferredAppSetup()
        }
        
        // Add a small delay to ensure smooth transition
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Switch to full app
        await MainActor.run {
            print("🎯 Transitioning to full app")
            self.persistenceController = controller
            withAnimation {
                self.showingFullApp = true
            }
            
            // Track UI ready
            AppLaunchOptimizer.LaunchMetrics.uiReady = Date()
            
            #if DEBUG
            // Print launch performance report
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppLaunchOptimizer.LaunchMetrics.fullyLoaded = Date()
                AppLaunchOptimizer.LaunchMetrics.printReport()
            }
            #endif
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}