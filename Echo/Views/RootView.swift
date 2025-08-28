//
//  RootView.swift
//  Echo
//
//  Ultra-lightweight root view that renders instantly without any dependencies
//

import SwiftUI
import CoreData

struct RootView: View {
    @State private var phase: AppPhase = .showingSamples
    
    enum AppPhase: Equatable {
        case showingSamples
        case loadingCoreData
        case ready(PersistenceController)
        
        static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
            switch (lhs, rhs) {
            case (.showingSamples, .showingSamples),
                 (.loadingCoreData, .loadingCoreData):
                return true
            case (.ready(_), .ready(_)):
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        switch phase {
        case .showingSamples, .loadingCoreData:
            // Show sample cards instantly - this renders in first frame
            NavigationView {
                StaticSampleCardsView(onlyShowSamples: true)
                    .navigationTitle("")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            if phase == .loadingCoreData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
            }
            .onAppear {
                // Track UI ready as soon as sample cards appear
                if phase == .showingSamples {
                    AppLaunchOptimizer.LaunchMetrics.uiReady = Date()
                    print("✅ Sample cards visible - UI Ready at \(AppLaunchOptimizer.LaunchMetrics.uiReady!.timeIntervalSince(AppLaunchOptimizer.LaunchMetrics.appInitStart))s")
                    
                    // Start loading Core Data after UI is visible
                    phase = .loadingCoreData
                    Task.detached(priority: .background) {
                        await loadCoreData()
                    }
                }
            }
            
        case .ready(let controller):
            // Full app with Core Data ready
            ContentView()
                .environment(\.managedObjectContext, controller.container.viewContext)
                .environmentObject(controller)
                .transition(.opacity)
                .onAppear {
                    #if DEBUG
                    AppLaunchOptimizer.LaunchMetrics.fullyLoaded = Date()
                    AppLaunchOptimizer.LaunchMetrics.printReport()
                    #endif
                }
        }
    }
    
    @MainActor
    private func loadCoreData() async {
        print("🔄 Starting Core Data initialization...")
        
        // Do ALL heavy lifting in background
        let controller = await Task.detached(priority: .background) {
            // Apply simulator warning fixes
            #if DEBUG
            SimulatorWarningFixes.configure()
            #endif
            
            // Create persistence controller
            let pc = PersistenceController()
            
            // Load stores
            let inMemory = false
            let iCloudEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? false
            await pc.loadStores(inMemory: inMemory, iCloudEnabled: iCloudEnabled)
            
            // Track Core Data ready
            AppLaunchOptimizer.LaunchMetrics.coreDataReady = Date()
            print("✅ Core Data ready at \(AppLaunchOptimizer.LaunchMetrics.coreDataReady!.timeIntervalSince(AppLaunchOptimizer.LaunchMetrics.appInitStart))s")
            
            return pc
        }.value
        
        // Perform app setup on main thread
        EchoApp.performDeferredAppSetup()
        
        // Transition to full app
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .ready(controller)
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}