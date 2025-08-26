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
        // Track launch start time
        AppLaunchOptimizer.LaunchMetrics.appInitStart = Date()
        
        // Only apply language preference if changed from system default
        if let appLanguage = UserDefaults.standard.string(forKey: "appLanguage"), appLanguage != "system" {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
            // Remove unnecessary synchronize() call - it's automatic now
        }
        
        // Defer non-critical initialization to background
        Task.detached {
            // Set default language preferences on first launch
            if UserDefaults.standard.object(forKey: "defaultTranscriptionLanguage") == nil {
                let defaultLanguage = LocalizationHelper.shared.getDefaultTranscriptionLanguage()
                UserDefaults.standard.set(defaultLanguage, forKey: "defaultTranscriptionLanguage")
            }
            
            // Configure audio session after launch
            await EchoApp.configureAudioSessionAsync()
        }
        
        // Configure notification center (lightweight)
        configureNotifications()
        
        // Apply simulator warning fixes
        #if DEBUG
        SimulatorWarningFixes.configure()
        #endif
        
        // Perform deferred initialization
        AppLaunchOptimizer.performDeferredInitialization()
        
        // Defer notification observer setup
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: Notification.Name("RestartCoreDataForICloud"),
                object: nil,
                queue: .main
            ) { notification in
                if let enabled = notification.userInfo?["enabled"] as? Bool {
                    print("iCloud sync toggled: \(enabled)")
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Refresh permission states when app becomes active
                    refreshPermissionStates()
                }
        }
    }
    
    private func refreshPermissionStates() {
        // Refresh notification permissions
        NotificationManager.shared.refreshPermissionState()
        // AudioSessionManager permissions are refreshed via AudioCoordinator
        // which checks permissions on each recording attempt
    }
    
    private static func configureAudioSessionAsync() async {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    private func configureNotifications() {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
}
