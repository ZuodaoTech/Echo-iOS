//
//  RootView.swift
//  Echo
//
//  Root view that handles app initialization and welcome flow
//

import SwiftUI
import CoreData

struct RootView: View {
    @State private var phase: AppPhase = .loading
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showingWelcome = false
    
    enum AppPhase: Equatable {
        case loading                          // Loading Core Data
        case ready(PersistenceController)     // Full app ready
        
        static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.ready(_), .ready(_)):
                return true
            default:
                return false
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                switch phase {
                case .loading:
                    // Simple loading screen while Core Data initializes
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.accentColor)
                            
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onAppear {
                        // Track UI ready
                        AppLaunchOptimizer.LaunchMetrics.uiReady = Date()
                        print("✅ First frame rendered - UI Ready at \(AppLaunchOptimizer.LaunchMetrics.uiReady!.timeIntervalSince(AppLaunchOptimizer.LaunchMetrics.appInitStart))s")
                        
                        // Check if we should show welcome
                        if !hasSeenWelcome && !showingWelcome {
                            // Show welcome immediately for first-time users
                            withAnimation(.spring()) {
                                showingWelcome = true
                            }
                        }
                        
                        // Start loading Core Data immediately
                        Task.detached(priority: .background) {
                            await loadCoreData()
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
            
            // Welcome overlay (shows on top of content)
            if showingWelcome {
                WelcomeOverlay(isPresented: $showingWelcome)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(1)
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
            await pc.loadStores(inMemory: inMemory)
            
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