Project: Echo - iOS

## Overview
Echo is a sophisticated iOS application that enables users to experience subliminal evolution driven by their own voice. The app allows users to create personalized audio scripts, record them in their own voice, and play them back with customizable repetition patterns. Built with SwiftUI and designed for iOS 15.6+, Echo leverages advanced audio processing, Core Data persistence, and iCloud synchronization to deliver a seamless personal growth experience.

## Technology Stack
- Language: Swift 5.9
- Framework: SwiftUI 5.0
- Database: Core Data with CloudKit integration
- Testing: No test suite currently implemented
- Audio: AVFoundation, Speech Recognition Framework, Accelerate Framework
- Localization: 17 languages supported
- Platform: iOS 15.6+ (Universal app for iPhone and iPad)

## Architecture Decisions
- Pattern: MVVM (Model-View-ViewModel) with SwiftUI's built-in data flow
- State Management: Combine + @Published properties with ObservableObject pattern
- API Style: Local data persistence with Core Data, no external API dependencies
- Audio Architecture: Coordinator pattern with specialized services (AudioCoordinator manages Recording, Playback, Processing, Session, and File services)
- Data Flow: Unidirectional data flow with @EnvironmentObject and @StateObject
- Persistence: Core Data with automatic iCloud sync via CloudKit
- Navigation: NavigationView with programmatic navigation support

## Coding Standards
- Style Guide: Swift API Design Guidelines
- Naming Conventions:
  - Views: Descriptive names ending with "View" (e.g., AddEditScriptView, ScriptsListView)
  - Services: Functionality-based with "Service" or "Manager" suffix (e.g., AudioService, NotificationManager)
  - Models: Core Data entities (SelftalkScript, Tag) with extensions for computed properties
  - Utilities: Helper classes with descriptive names (e.g., LocalizationHelper, FileOperationHelper)
- File Organization:
  - `/Views`: All SwiftUI views and view components
  - `/Models`: Core Data models and data structures
  - `/Services`: Business logic and service layers
  - `/Utilities`: Helper classes and extensions
  - `/Resources`: Localization and configuration files
  - Localization files organized by language code (e.g., en.lproj, zh-Hans.lproj)
- Commit Format: Conventional commits with prefixes (fix:, feat:, etc.)

## Business Rules
- **Recording Limits**: Maximum 60-second recordings to maintain focus and clarity
- **Audio Processing**: Automatic silence trimming and noise reduction applied to all recordings
- **Playback Repetitions**: Configurable from 1-10 repetitions per script
- **Interval Control**: Adjustable pause between repetitions (0-3 seconds)
- **Private Mode**: Requires headphones for playback when enabled (privacy protection)
- **Tag System**: Scripts can have multiple tags for organization and filtering
- **Notification System**: Optional reminders for script playback with customizable frequency
- **Data Deduplication**: Automatic detection and management of duplicate scripts
- **iCloud Sync**: Optional synchronization across devices using CloudKit
- **Audio Formats**: AAC format at 44.1kHz for optimal quality and compatibility

## Development Workflow
- Branch Strategy: Main branch with feature branches
- Review Process: Pull requests reviewed before merging to main
- Testing Requirements: Currently no automated tests (opportunity for improvement)
- Build System: Xcode project with standard Apple build pipeline
- Deployment Target: iOS 15.6 minimum, optimized for iOS 18.5
- Code Signing: Requires Apple Developer account for device testing

## Performance Requirements
- Response Time: 
  - App launch: < 2 seconds (optimized with AppLaunchOptimizer)
  - Recording start: Immediate with permission granted
  - Playback initiation: < 500ms
  - Script creation/editing: Instant UI response
- Scalability:
  - Supports unlimited scripts (Core Data optimized queries)
  - Efficient memory management for audio files
  - Background audio processing to prevent UI blocking
- Device Support:
  - iPhone: All models supporting iOS 15.6+
  - iPad: Universal app with adaptive layouts
  - Audio: Supports built-in speakers, headphones, Bluetooth audio

## Security Requirements
- Authentication: No user authentication required (local app)
- Authorization: 
  - Microphone permission for recording
  - Speech recognition permission for transcription
  - Notification permission for reminders
- Data Protection:
  - Audio files stored in app's document directory
  - Core Data encryption when device is locked
  - Private mode enforces headphone-only playback
  - No network requests or external data sharing
  - iCloud sync uses Apple's secure CloudKit infrastructure

## Key Features & Components

### Core Components
- **AudioCoordinator**: Central hub managing all audio operations
- **PersistenceController**: Core Data stack management with CloudKit integration
- **NotificationManager**: Handles local notifications and reminders
- **LocalizationHelper**: Manages multi-language support and translations

### Main Views
- **RootView**: App entry point managing initialization and welcome flow
- **ScriptsListView**: Main interface displaying script cards with search/filter
- **AddEditScriptView**: Comprehensive script creation and editing interface
- **MeView**: Settings hub with developer menu (Konami code: ← ← →)
- **ScriptCard**: Reusable component for script display with playback controls

### Audio Services
- **RecordingService**: High-quality audio capture with real-time monitoring
- **PlaybackService**: Multi-repetition playback with interval management
- **AudioProcessingService**: Silence trimming, noise reduction, transcription
- **AudioSessionManager**: System audio session configuration and routing
- **AudioFileManager**: File system operations for audio storage

## Developer Features
- Hidden developer menu accessible via swipe gesture (← ← →) in Me tab
- Comprehensive logging for debugging audio operations
- Static sample cards for preview and demo purposes
- Simulator warning fixes for development environment

## Notes

- Designed for personal growth and self-improvement use cases
- Optimized for one-handed use with card-based interface
- Supports both light and dark mode with system preference
- Audio continues in background when app is minimized
- Automatic audio session management for interruption handling
- Smart deduplication prevents accidental duplicate scripts
- Colorful card system with automatic color assignment for visual organization
