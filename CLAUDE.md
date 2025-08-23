# CLAUDE.md - Echo iOS Development Guide

## Introduction & Overview

**ECHO** is a self-talk app that helps users build positive habits through personalized selftalk scripts and their respective voice recordings.

### Core Principles for iOS Development

- **SwiftUI First**: Modern declarative UI framework
- **Core Data**: For persistent storage (replacing SharedPreferences)
- **AVFoundation**: For audio recording and playback
- **UserNotifications**: For local notifications
- **Combine**: For reactive programming and data flow
- **MVVM Architecture**: Clear separation of concerns

## Key Features Implementation

### 1. Selftalk Scripts Management
- Create, edit, and delete script cards
- Organize scripts into categories
- Customizable script parameters:
  - Prompts (Selftalk scripts)
  - Repetitions (how many times to repeat)
  - Individual audio recording per script card

### 2. Script Card Audio Features
Each script card contains:
- **Recording Button**: Record personal voice for this specific script
- **Playback Button**: Play the recorded audio
- **Privacy Mode**: Automatically prevents playback when earphones/headphones are not connected
  - Protects users from accidental public playback
  - Shows visual indicator when privacy mode is active
- **Playback Controls**: 
  - Play/Pause
  - Speed adjustment (0.5x, 1x, 1.5x, 2x)
  - Progress indicator

### 3. Progress Tracking
- Daily practice streaks
- Visual progress indicators
- Statistics and insights
- Completion tracking per script

### 4. Notifications
- Daily practice reminders
- Customizable notification schedules
- Smart reminder timing based on usage patterns

## Technical Guidelines

### SwiftUI Best Practices
```swift
// Use @StateObject for view models
@StateObject private var viewModel = ScriptsViewModel()

// Use @EnvironmentObject for shared state
@EnvironmentObject var audioService: AudioService

// Prefer computed properties for derived state
var isPlaybackActive: Bool {
    audioService.isPlaying && currentScript != nil
}
```

### Core Data Setup
```swift
// Use @FetchRequest for data queries
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Script.createdAt, ascending: false)],
    animation: .default
)
private var scripts: FetchedResults<Script>
```

### Audio Handling
```swift
// Privacy Mode Implementation
func checkPrivacyMode() -> Bool {
    let currentRoute = AVAudioSession.sharedInstance().currentRoute
    for output in currentRoute.outputs {
        let portType = output.portType
        if portType == .headphones || 
           portType == .bluetoothA2DP || 
           portType == .bluetoothHFP {
            return false // Earphones connected, allow playback
        }
    }
    return true // No earphones, privacy mode active
}
```

Key considerations:
- Always check microphone permissions before recording
- Handle audio session interruptions gracefully
- Implement proper cleanup in view lifecycle
- Check audio route before playback (privacy mode)
- Each script maintains its own audio file reference in Core Data

### Error Handling
- Use Result types for async operations
- Provide user-friendly error messages
- Log errors for debugging

## Development Workflow

### Build & Test Commands
```bash
# Build the project
xcodebuild -scheme "Echo" build

# Run tests
xcodebuild test -scheme "Echo" -destination 'platform=iOS Simulator,name=iPhone 15'

# Check for SwiftLint issues (if installed)
swiftlint
```

### Code Quality Checks
- SwiftLint for code style consistency
- Unit tests for business logic
- UI tests for critical user flows

## Platform-Specific Considerations

### iOS vs Android Mapping
| Android | iOS |
|---------|-----|
| SharedPreferences | UserDefaults / Core Data |
| MediaRecorder | AVAudioRecorder |
| MediaPlayer | AVAudioPlayer |
| AlarmManager | UNUserNotificationCenter |
| RecyclerView | List/LazyVStack |
| Fragment | View |
| ViewModel | ObservableObject |

### iOS-Specific Features
- **Live Activities**: Show recording status on lock screen
- **App Clips**: Quick access to specific scripts
- **Widgets**: Daily Selftalk widgets
- **Siri Shortcuts**: Voice-triggered playback

## Dependencies Management

### Swift Package Manager (SPM)
Preferred method for adding dependencies:
```swift
// In Xcode: File > Add Package Dependencies
// Common packages for Echo:
// - Lottie for animations
// - SwiftUICharts for progress visualization
```

### CocoaPods (if needed)
```ruby
# Podfile
platform :ios, '15.6'
use_frameworks!

target 'Echo' do
  # Add pods here if needed
end
```

## Testing Strategy

### Unit Tests
- Test Core Data models
- Test audio service logic (including privacy mode)
- Test notification scheduling

### UI Tests
- Test script creation flow
- Test recording and playback per script card
- Test privacy mode behavior
- Test settings changes

### Integration Tests
- Test data persistence
- Test audio file management
- Test notification delivery

## Performance Optimization

### Memory Management
- Use weak references in closures
- Clean up audio resources after each script
- Implement proper image caching

### Battery Optimization
- Minimize background activities
- Use efficient Core Data queries
- Batch notification scheduling

## Security & Privacy

### Data Protection
- Store audio files in app's documents directory
- Enable file protection for sensitive data
- Implement biometric authentication for private scripts

### Privacy Compliance
- Request permissions explicitly
- Provide clear privacy policy
- Handle user data deletion requests
- Privacy mode for audio playback (earphones requirement)

## Deployment Checklist

### Before Release
- [ ] Update version and build numbers
- [ ] Test on multiple device sizes
- [ ] Verify audio permissions handling
- [ ] Check notification permissions
- [ ] Test Core Data migrations
- [ ] Test privacy mode with various audio outputs
- [ ] Update App Store screenshots
- [ ] Prepare release notes

### App Store Requirements
- iOS 15.6+ deployment target
- Universal app (iPhone only initially)
- App icons for all required sizes
- Privacy policy URL
- App description and keywords

## Common Issues & Solutions

### Audio Recording Issues
```swift
// Always configure audio session before recording
try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
try AVAudioSession.sharedInstance().setActive(true)
```

### Privacy Mode Not Working
```swift
// Register for route change notifications
NotificationCenter.default.addObserver(
    self,
    selector: #selector(audioRouteChanged),
    name: AVAudioSession.routeChangeNotification,
    object: nil
)
```

### Core Data Migration
```swift
// Handle model versioning properly
// Create new model version before changing schema
// Implement lightweight migration when possible
```

### SwiftUI Performance
```swift
// Use lazy loading for lists
// Implement proper view identity
// Avoid unnecessary state updates
```

## Resources

### Documentation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)
- [AVFoundation Documentation](https://developer.apple.com/documentation/avfoundation)

### Tools
- Xcode 16.4+
- Swift 5.0+
- iOS Simulator
- Instruments for profiling

## Version History

### v0.1.0 (Current)
- Initial project setup
- Basic UI structure
- Core Data models
- Audio recording foundation
- Privacy mode implementation

---

*Last Updated: 2025-08-22*
*Author: @xiaolai*