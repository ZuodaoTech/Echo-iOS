//
//  ContentView.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScriptsListView()
                .tabItem {
                    Image(systemName: "rectangle.stack")
                }
                .tag(0)
            
            MeView()
                .tabItem {
                    Image(systemName: "person.circle")
                }
                .tag(1)
        }
        .onAppear {
            // Track when UI is ready
            AppLaunchOptimizer.LaunchMetrics.uiReady = Date()
            
            #if DEBUG
            // Print launch performance report in debug
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppLaunchOptimizer.LaunchMetrics.fullyLoaded = Date()
                AppLaunchOptimizer.LaunchMetrics.printReport()
            }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}