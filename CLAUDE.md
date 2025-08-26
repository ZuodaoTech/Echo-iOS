# CLAUDE.md - Echo iOS Development Guide

## IMPORTANT: Communication Language Principle

**ALWAYS respond in English regardless of the language used by the user.** Whether the user communicates in Chinese, Japanese, Spanish, or any other language, all responses must be in English. This ensures consistency in technical documentation, code comments, and development discussions.

## Overview

**Echo** is a self-talk habit-building iOS app that helps users practice personalized affirmations through voice recordings. Built with SwiftUI and following enterprise-grade architecture patterns, it emphasizes privacy, user experience, and audio quality.

### Key Features
- 📝 Create and manage personalized self-talk scripts
- 🎙️ High-quality voice recording for each script
- 🔒 Privacy Mode: Prevents accidental public playback
- 🌍 Multilingual transcription (15+ languages)
- 🔄 Configurable repetitions with intervals
- 📊 Progress tracking and statistics

## Architecture

### Technology Stack
- **UI Framework**: SwiftUI (iOS 15.6+)
- **Data Persistence**: Core Data
- **Audio Engine**: AVFoundation
- **Speech Recognition**: Speech Framework
- **Reactive Programming**: Combine
- **Architecture Pattern**: MVVM with Service Layer
- **Testing**: XCTest (Unit & UI Tests)
- **No External Dependencies**: Pure Apple frameworks

### Project Structure
```
Echo-iOS/
├── Echo/
│   ├── EchoApp.swift           # App entry point
│   ├── ContentView.swift       # Root navigation
│   ├── Persistence.swift       # Core Data setup
│   ├── Models/                 # Core Data entities
│   ├── Services/               # Service layer (7 services)
│   ├── Views/                  # SwiftUI views
│   └── Utilities/              # Helper functions
└── Tests/                      # Unit and UI tests
```

## Service Layer Architecture

The app uses a sophisticated 7-service architecture with clear separation of concerns:

### AudioCoordinator (Facade Pattern)
Central orchestrator for all audio operations:
```swift
class AudioCoordinator: ObservableObject {
    // Manages: Recording, Playback, Processing, File Operations
    // Published states for UI binding
    // Coordinates between all sub-services
}
```

### Service Responsibilities

| Service | Primary Responsibility | Key Features |
|---------|----------------------|--------------|
| **RecordingService** | Audio capture | AAC format, 44.1kHz, mono, real-time duration |
| **PlaybackService** | Audio playback | Repetitions, intervals, speed control, pause/resume |
| **AudioSessionManager** | System audio session | Privacy mode, interruption handling, route changes |
| **AudioFileManager** | File operations | CRUD operations, duration calculation, storage management |
| **AudioProcessingService** | Post-processing | Silence trimming, transcription, format validation |
| **AudioService** | Legacy wrapper | Backward compatibility interface |

## Core Data Model

### Entities

**SelftalkScript**
- `id`: UUID (primary key)
- `scriptText`: String (the self-talk content)
- `repetitions`: Int16 (1-10, default: 3)
- `intervalSeconds`: Double (pause between repetitions)
- `audioDuration`: Double (calculated from recording)
- `audioFilePath`: String? (path to m4a file)
- `privacyModeEnabled`: Bool (default: true)
- `transcribedText`: String? (speech-to-text result)
- `transcriptionLanguage`: String? (default: "auto")
- `createdAt`, `updatedAt`: Date
- `lastPlayedAt`: Date?
- `playCount`: Int32
- `category`: Relationship to Category

**Category**
- `id`: UUID
- `name`: String
- `sortOrder`: Int16
- `scripts`: One-to-many relationship

## Key Implementation Details

### Audio Recording Pipeline
```swift
// 1. Request microphone permission
// 2. Configure audio session for recording
// 3. Start recording with high quality settings
// 4. Stop and process recording
// 5. Trim silence automatically
// 6. Transcribe if language is set
// 7. Save to Core Data with metadata
```

### Privacy Mode Implementation
```swift
func checkPrivacyMode() -> Bool {
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    for output in currentRoute.outputs {
        if output.portType == .headphones || 
           output.portType == .bluetoothA2DP {
            return false // Earphones connected
        }
    }
    return true // Privacy mode active
}
```

### Transcription with Language Selection
```swift
// User-selectable languages in UI
// Auto-detect or specific language code
// Graceful fallback on errors
// Handle error 1101 without failing
```

## Development Commands

### Build & Test
```bash
# Build for simulator
xcodebuild -scheme "Echo" -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run unit tests
xcodebuild test -scheme "Echo" -destination 'platform=iOS Simulator,name=iPhone 15'

# Check code quality (if SwiftLint installed)
swiftlint
```

### Git Workflow

**IMPORTANT: Always create a new branch for new features or significant changes.**

```bash
# Feature development workflow (PREFERRED)
git checkout -b feature/your-feature-name
git add .
git commit -m "Your descriptive message"
git push origin feature/your-feature-name
# Then create pull request to merge into main

# For small fixes or updates only (after discussion)
git add .
git commit -m "Your descriptive message"
git push origin main
```

#### Branch Naming Conventions
- `feature/` - New features (e.g., `feature/character-limit`)
- `fix/` - Bug fixes (e.g., `fix/core-data-crash`)
- `refactor/` - Code refactoring (e.g., `refactor/audio-service`)
- `docs/` - Documentation updates (e.g., `docs/update-readme`)

## Common Issues & Solutions

### Issue: AVAudioPlayer shows 0 duration
**Solution**: The app now uses AVAsset as primary method with AVAudioPlayer fallback:
```swift
// Try AVAsset first (more reliable)
let asset = AVAsset(url: audioURL)
let duration = CMTimeGetSeconds(asset.duration)

// Fallback to AVAudioPlayer if needed
```

### Issue: Speech Recognition Error 1101
**Solution**: This error is handled gracefully - transcription often succeeds despite the error. The app:
- Accepts partial results when available
- Continues despite non-critical errors
- Provides timeout protection (30 seconds)

### Issue: Transcript not appearing
**Solution**: The app implements automatic refresh:
- Timer-based Core Data refresh after recording
- Force save to Core Data after transcription
- UI updates via published properties

### Issue: Recording file corruption
**Solution**: Enhanced file handling:
- Proper file closure after writing
- Thread.sleep for file system sync
- File size validation
- Temp file verification before replacement

## Performance Optimizations

### Memory Management
- Weak references in closures to prevent retain cycles
- Proper cleanup of audio resources
- Timer invalidation on view disappear

### File Operations
- Centralized in Documents/Recordings directory
- Automatic cleanup of orphaned files
- Efficient duration calculation with caching

### UI Responsiveness
- Async audio operations
- Progress indicators for long operations
- Real-time state updates via Combine

## Testing Strategy

### Unit Tests Coverage
- ✅ Audio service operations
- ✅ Core Data CRUD operations
- ✅ Privacy mode detection
- ✅ Repetition and interval logic
- ✅ File management operations

### UI Tests Coverage
- ✅ Script creation flow
- ✅ Recording and playback
- ✅ Settings changes
- ✅ Category management

### Manual Testing Checklist
- [ ] Test on various iOS versions (15.6+)
- [ ] Verify privacy mode with different audio outputs
- [ ] Test transcription in multiple languages
- [ ] Verify Core Data migration on updates
- [ ] Test interruption handling (calls, alarms)

## Deployment Checklist

### Before Release
- [ ] Update version and build numbers in project settings
- [ ] Test on physical devices (various models)
- [ ] Verify all audio permissions prompts
- [ ] Test fresh install and upgrade scenarios
- [ ] Validate Core Data migration if schema changed
- [ ] Update App Store metadata and screenshots

### App Store Requirements
- **Minimum iOS**: 15.6
- **Supported Devices**: iPhone only (initially)
- **Permissions Required**: Microphone, Speech Recognition
- **Privacy Policy**: Required for audio/speech data
- **App Category**: Health & Fitness or Productivity

## Best Practices

### Code Style
- Use computed properties for derived values
- Prefer `@StateObject` for view models
- Use `@EnvironmentObject` for shared services
- Follow Swift naming conventions
- Keep views focused (extract subviews)

### Audio Handling
- Always check permissions before operations
- Configure audio session appropriately
- Handle interruptions gracefully
- Clean up resources properly
- Validate file operations

### Core Data
- Use `@FetchRequest` for queries
- Save context only when needed
- Handle migration carefully
- Use background contexts for heavy operations
- Implement proper error handling

## Development Workflow Automation

### Auto-approval Configuration
The project is configured to automatically approve certain commands for efficiency.
Configuration is stored in `.claude/settings.json`.

#### Automatically Approved
- All `Bash` tool commands by default
- Build commands: `xcodebuild`, `swift build`, `swift test`
- Read-only git commands: `git status`, `git diff`, `git log`
- File inspection and navigation commands

#### Manual Confirmation Required
- `git commit` - Review commit messages
- `git push` - Confirm remote updates  
- `git pull` - Verify incoming changes
- `git merge` - Review merge operations

This maintains a balance between efficiency and control over critical operations.

## iCloud Sync & Export/Import

### iCloud Sync (Implemented)
The app now supports CloudKit-based iCloud sync for seamless data synchronization across devices:

#### Features
- **Automatic Sync**: Script text, settings, and metadata sync automatically
- **Audio Files Stay Local**: To conserve bandwidth, audio recordings remain device-specific
- **Toggle Control**: Users can enable/disable iCloud sync in Settings
- **Graceful Fallback**: If CloudKit fails, the app falls back to local storage

#### Implementation
```swift
// Core Data configured with NSPersistentCloudKitContainer
// CloudKit container: "iCloud.xiaolai.Echo"
// Entitlements: Echo.entitlements with CloudKit capability
```

### Export/Import System (Implemented)

#### Export Formats
1. **Echo Bundle (.echo)**: Complete export with optional audio files
2. **Plain Text (.txt)**: Simple text format for reading
3. **JSON (.json)**: Developer-friendly format for processing

#### Export Features
- **Selective Export**: Choose specific scripts to export
- **Audio Option**: Include/exclude audio recordings
- **Share Integration**: Direct sharing via iOS share sheet
- **Single Script Export**: Long-press context menu on script cards

#### Import Features
- **Multiple Formats**: Supports .echo, .json, and .txt files
- **Conflict Resolution**: Skip, replace, keep both, or merge duplicates
- **Smart Detection**: Identifies duplicates by ID or content
- **Category Preservation**: Maintains category relationships

### Export/Import Services

#### ExportService
- Creates bundles with manifest, scripts, categories, and settings
- Handles audio file packaging
- Supports multiple export formats
- Generates timestamped filenames

#### ImportService
- Validates bundle integrity
- Manages conflict resolution
- Preserves relationships
- Provides detailed import results

## Future Enhancements

### Planned Features
- [ ] Full audio sync via iCloud (bandwidth-aware)
- [ ] Widget for quick access to favorite scripts
- [ ] Apple Watch companion app
- [ ] Siri Shortcuts integration
- [ ] Audio effects and filters
- [ ] Social sharing (with privacy controls)

### Technical Improvements
- [ ] Migrate to async/await throughout
- [ ] Implement proper repository pattern
- [ ] Add analytics (privacy-respecting)
- [ ] Optimize for larger script collections
- [ ] Add comprehensive accessibility features

## Resources

### Apple Documentation
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)
- [AVFoundation Guide](https://developer.apple.com/documentation/avfoundation)
- [Speech Framework](https://developer.apple.com/documentation/speech)

### Project Links
- Repository: `/Users/joker/github/xiaolai/myprojects/pando/Echo-iOS`
- Bundle ID: `xiaolai.Echo`
- Development Team: G5AR6VCNMA

---

*Last Updated: 2025-08-26*
*Version: 0.2.2*
*Author: @xiaolai*