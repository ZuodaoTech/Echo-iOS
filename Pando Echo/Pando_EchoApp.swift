//
//  Pando_EchoApp.swift
//  Pando Echo
//
//  Created by joker on 8/23/25.
//

import SwiftUI

@main
struct Pando_EchoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
