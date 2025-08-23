//
//  ContentView.swift
//  Pando Echo
//
//  Created by joker on 8/23/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        ScriptsListView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}