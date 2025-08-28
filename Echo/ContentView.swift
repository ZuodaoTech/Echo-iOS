
//
//  ContentView.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var persistenceController: PersistenceController
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
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
