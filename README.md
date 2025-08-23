# Echo - Self-Talk Practice App for iOS

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2015.6+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" />
  <img src="https://img.shields.io/badge/SwiftUI-3.0-green.svg" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" />
</p>

## 📱 Overview

Echo is a powerful self-talk practice app designed to help users build positive habits through personalized affirmation scripts and voice recordings. The app empowers users to create, record, and playback their own motivational scripts with customizable repetition patterns.

### ✨ Key Features

- **📝 Script Management**: Create and organize personalized self-talk scripts with categories
- **🎙 Voice Recording**: Record your own voice reading each script for authentic practice
- **🔄 Smart Repetition**: Customize repetition count (1-10x) and intervals (1-3 seconds)
- **🎧 Privacy Mode**: Automatic playback protection - requires headphones to prevent accidental public playback
- **📊 Progress Tracking**: Monitor your practice sessions with play counts and timestamps
- **🌍 Multi-language Transcription**: Automatic speech-to-text in multiple languages (English, Chinese, Spanish, French, etc.)
- **⚡ Audio Processing**: Automatic silence trimming and audio optimization

## 🚀 Getting Started

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- iOS 15.6+ deployment target
- Swift 5.0

### Installation

1. Clone the repository:
```bash
git clone https://github.com/xiaolai/echo-ios.git
cd Echo-iOS
```

2. Open the project in Xcode:
```bash
open Echo.xcodeproj
```

3. Select your development team in the project settings

4. Build and run (⌘R)

## 🏗 Architecture

The app follows MVVM architecture with SwiftUI and Core Data:

```
Echo/
├── Models/           # Core Data models (SelftalkScript, Category)
├── Views/            # SwiftUI views
│   ├── ScriptsListView.swift
│   ├── AddEditScriptView.swift
│   └── Components/
├── Services/         # Audio services layer
│   ├── AudioCoordinator.swift    # Main audio orchestrator
│   ├── RecordingService.swift    # Recording management
│   ├── PlaybackService.swift     # Playback control
│   ├── AudioProcessingService.swift  # Transcription & processing
│   └── AudioFileManager.swift    # File operations
└── Utilities/        # Helper functions and extensions
```

### 🎵 Audio Architecture

The audio system uses a coordinator pattern with specialized services:

- **AudioCoordinator**: Singleton orchestrator managing all audio operations
- **RecordingService**: Handles AVAudioRecorder and recording state
- **PlaybackService**: Manages AVAudioPlayer with repetition logic
- **AudioProcessingService**: Silence trimming and speech-to-text transcription
- **AudioSessionManager**: Audio session configuration and privacy mode detection
- **AudioFileManager**: File system operations for recordings

## 🔧 Core Technologies

- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Persistent storage for scripts and categories
- **AVFoundation**: Audio recording and playback
- **Speech Framework**: On-device and cloud transcription
- **Combine**: Reactive data flow and state management

## 📝 Features in Detail

### Privacy Mode 🔒
Automatically detects audio output route and prevents playback through speakers. Users must connect headphones/earphones to play recordings, protecting privacy.

### Smart Audio Processing 🎛
- Automatic silence trimming at beginning/end of recordings
- Dual-file system: keeps original for transcription, processed for playback
- Format optimization for Speech Recognition compatibility

### Multi-language Support 🌐
- Transcription available in 10+ languages
- Language-specific punctuation handling
- Automatic capitalization for Western languages

## 🧪 Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
xcodebuild test -scheme "Echo" -sdk iphonesimulator

# Run specific test suite
xcodebuild test -scheme "Echo" -only-testing:EchoTests/AudioFileManagerTests
```

### Test Coverage
- **Unit Tests**: Audio services, Core Data models, business logic (~70%)
- **UI Tests**: Main user flows, recording, playback (~50%)
- **Integration Tests**: End-to-end scenarios

## 🛠 Development

### Building

```bash
# Debug build
xcodebuild -scheme "Echo" -configuration Debug build

# Release build
xcodebuild -scheme "Echo" -configuration Release build
```

### Code Style

The project uses SwiftLint for code consistency. Rules are defined in `.swiftlint.yml`.

## 📚 Documentation

- [CLAUDE.md](CLAUDE.md) - Detailed development guide and architecture documentation
- [API Documentation](docs/api.md) - Service layer API reference (coming soon)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Xiaolai** - [GitHub](https://github.com/xiaolai)

## 🙏 Acknowledgments

- Built with SwiftUI and love for self-improvement
- Special thanks to all contributors and testers
- Powered by Apple's Speech Recognition framework

---

<p align="center">
Made with ❤️ for personal growth and positive self-talk practice
</p>