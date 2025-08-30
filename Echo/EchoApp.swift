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
    init() {
        // Track launch start time
        AppLaunchOptimizer.LaunchMetrics.appInitStart = Date()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()  // Root view handles initialization and welcome
                .environmentObject(AudioCoordinator.shared)  // Inject as environment object
        }
    }
    
    // These methods will be called from RootView after Core Data is ready
    static func performDeferredAppSetup() {
        // Apply language preference if changed from system default
        if let appLanguage = UserDefaults.standard.string(forKey: "appLanguage"), appLanguage != "system" {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
        
        // Configure notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Perform other deferred initialization
        AppLaunchOptimizer.performDeferredInitialization()
        
        // Setup background tasks
        Task.detached(priority: .background) {
            // Set default language preferences on first launch
            if UserDefaults.standard.object(forKey: "defaultTranscriptionLanguage") == nil {
                await Task {
                    let defaultLanguage = LocalizationHelper.shared.getDefaultTranscriptionLanguage()
                    UserDefaults.standard.set(defaultLanguage, forKey: "defaultTranscriptionLanguage")
                }.value
            }
            
            // Configure audio session after launch (only if user has recorded before)
            if UserDefaults.standard.bool(forKey: "hasRecordedBefore") {
                await configureAudioSessionAsync()
            }
        }
        
        // Setup notification observer for iCloud changes
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: Notification.Name("RestartCoreDataForICloud"),
                object: nil,
                queue: .main
            ) { notification in
                if let enabled = notification.userInfo?["enabled"] as? Bool {
                    #if DEBUG
                    SecureLogger.debug("iCloud sync toggled: \(enabled)")
                    #endif
                    
                    // Restart Core Data with new iCloud configuration
                    Task {
                        await PersistenceController.shared.restartForICloudToggle()
                    }
                }
            }
        }
    }
    
    private static func configureAudioSessionAsync() async {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Initial setup with defaultToSpeaker for playback, removed during recording
            try audioSession.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
        } catch {
            SecureLogger.error("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    static func refreshPermissionStates() {
        // Refresh notification permissions
        NotificationManager.shared.refreshPermissionState()
        // AudioSessionManager permissions are refreshed via AudioCoordinator
        // which checks permissions on each recording attempt
    }
}
