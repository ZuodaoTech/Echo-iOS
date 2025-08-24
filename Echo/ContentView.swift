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
                    Label("Cards", systemImage: "rectangle.stack")
                }
                .tag(0)
            
            MeView()
                .tabItem {
                    Label("Me", systemImage: "person.circle")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}