//
//  RootView.swift
//  Echo
//
//  Ultra-lightweight root view that renders instantly without any dependencies
//

import SwiftUI
import CoreData

struct RootView: View {
    @State private var phase: AppPhase = .instant
    @State private var hardcodedSamples: [StaticSampleCard] = []
    @State private var localizedSamples: [StaticSampleCard] = []
    
    enum AppPhase: Equatable {
        case instant                          // Show something immediately
        case showingSamples                   // Show proper sample cards
        case loadingCoreData                  // Loading Core Data
        case ready(PersistenceController)     // Full app ready
        
        static func == (lhs: AppPhase, rhs: AppPhase) -> Bool {
            switch (lhs, rhs) {
            case (.instant, .instant),
                 (.showingSamples, .showingSamples),
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
        case .instant:
            // INSTANT render - no localization, no NavigationView, just cards!
            InstantSampleView(samples: hardcodedSamples)
                .onAppear {
                    // Track UI ready IMMEDIATELY
                    AppLaunchOptimizer.LaunchMetrics.uiReady = Date()
                    print("✅ First frame rendered - UI Ready at \(AppLaunchOptimizer.LaunchMetrics.uiReady!.timeIntervalSince(AppLaunchOptimizer.LaunchMetrics.appInitStart))s")
                    
                    // Start loading everything else after first frame
                    Task {
                        await loadLocalizedSamples()
                    }
                }
            
        case .showingSamples, .loadingCoreData:
            // Now show proper UI with navigation
            NavigationView {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(localizedSamples) { sample in
                            StaticCardView(sample: sample)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
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
                if phase == .showingSamples {
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
    
    init() {
        // Create hardcoded samples IMMEDIATELY - no localization!
        self.hardcodedSamples = [
            StaticSampleCard(
                id: StaticSampleCard.smokingSampleID,
                scriptText: "I never smoke, because it stinks, and I hate being controlled.",
                category: "Breaking Bad Habits",
                repetitions: 3,
                intervalSeconds: 1.0
            ),
            StaticSampleCard(
                id: StaticSampleCard.bedtimeSampleID,
                scriptText: "I wind down by 10 PM, and I'm in bed by 11 PM.",
                category: "Building Good Habits",
                repetitions: 3,
                intervalSeconds: 1.0
            ),
            StaticSampleCard(
                id: StaticSampleCard.mistakesSampleID,
                scriptText: "Making mistakes is the best way for me to learn, so I view each one as a valuable lesson.",
                category: "Appropriate Positivity",
                repetitions: 3,
                intervalSeconds: 1.0
            )
        ]
    }
    
    @MainActor
    private func loadLocalizedSamples() async {
        // Small delay to ensure first frame is painted
        try? await Task.sleep(nanoseconds: 16_000_000) // One frame
        
        // Now load localized samples
        localizedSamples = StaticSampleProvider.shared.getSamples()
        
        // Transition to proper UI
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .showingSamples
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

/// Ultra-light view for instant rendering - NO NavigationView, NO localization
struct InstantSampleView: View {
    let samples: [StaticSampleCard]
    
    var body: some View {
        // Simple ZStack with basic styling - renders INSTANTLY
        ZStack {
            Color(.systemBackground)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Empty space for navigation bar
                    Color.clear.frame(height: 44)
                    
                    ForEach(samples) { sample in
                        InstantCardView(sample: sample)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Simplified card for instant rendering
struct InstantCardView: View {
    let sample: StaticSampleCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category - plain text, no localization
            Text(sample.category)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Script text
            Text(sample.scriptText)
                .font(.body)
                .lineLimit(3)
            
            // Bottom row - simplified
            HStack {
                Text("\(sample.repetitions)x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(String(format: "%.1f", sample.intervalSeconds))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}