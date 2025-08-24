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
    let persistenceController = PersistenceController.shared

    init() {
        // Configure audio session early to avoid warnings
        configureAudioSession()
        
        // Configure notification center
        configureNotifications()
        
        // Apply simulator warning fixes
        #if DEBUG
        SimulatorWarningFixes.configure()
        #endif
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