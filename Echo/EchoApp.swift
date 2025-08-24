//
//  EchoApp.swift
//  Echo
//
//  Created by joker on 8/23/25.
//

import SwiftUI
import AVFoundation
import UserNotifications

@main
struct EchoApp: App {
    @StateObject private var persistenceController = PersistenceController.shared

    init() {
        // Configure audio session early to avoid warnings
        configureAudioSession()
        
        // Configure notification center
        configureNotifications()
        
        // Apply simulator warning fixes
        #if DEBUG
        SimulatorWarningFixes.configure()
        #endif
        
        // Listen for iCloud sync toggle changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RestartCoreDataForICloud"),
            object: nil,
            queue: .main
        ) { notification in
            // Note: In production, you might want to restart the Core Data stack
            // For now, we'll just log the change
            if let enabled = notification.userInfo?["enabled"] as? Bool {
                print("iCloud sync toggled: \(enabled)")
                // The Persistence controller already handles this in its init
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Early configuration helps avoid factory warnings
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
        } catch {
            print("Early audio session configuration failed: \(error)")
        }
    }
    
    private func configureNotifications() {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
}