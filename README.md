# Echo - Your Personal Self-Talk Companion

<p align="center">
  <img src="icon.png" width="120" height="120" alt="Echo App Icon">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2015.6+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" />
  <img src="https://img.shields.io/badge/SwiftUI-5.0-green.svg" />
  <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" />
</p>

<p align="center">
  <b>Transform your inner dialogue with personalized affirmations</b>
</p>

## 🌟 What is Echo?

Echo is a beautifully crafted iOS app that helps you build positive habits through personalized self-talk scripts. Record your own affirmations, motivational speeches, or daily reminders in your own voice, then play them back with customizable repetition patterns to reinforce positive thinking.

## ✨ Key Features

### 📝 **Smart Script Management**
- Create unlimited personalized self-talk scripts
- Organize with colorful tags for easy categorization
- Beautiful card-based interface with randomized colors
- Quick search and filter capabilities

### 🎙️ **Professional Recording**
- High-quality audio recording (44.1kHz, AAC format)
- Automatic silence trimming for clean recordings
- 60-second recording limit for focused messages
- Advanced noise reduction for crystal-clear audio

### 🔄 **Intelligent Playback**
- Customizable repetitions (1-10 times per script)
- Adjustable intervals between repetitions (0-10 seconds)
- Auto-stop when playing different cards
- Background playback support

### 🔒 **Privacy First**
- **Private Mode**: Automatic speaker protection - requires headphones for playback
- Local storage - your recordings never leave your device
- Optional iCloud sync for backup across your devices

### 🌍 **Multilingual Support**
- Interface available in 15+ languages
- Speech-to-text transcription in multiple languages
- Smart language detection for transcription

### 📊 **Progress Tracking**
- Track play counts for each script
- Last played timestamps
- Visual progress indicators during playback

## 📱 Getting Started

### For Users

1. **Download from App Store** (Coming Soon)
2. Launch Echo and tap the "+" button to create your first script
3. Write your affirmation or motivational message
4. Tap the microphone to record in your own voice
5. Play back with your preferred repetition settings

### For Developers

#### Prerequisites
- macOS 13.0+
- Xcode 15.0+
- iOS Device or Simulator (iOS 15.6+)

#### Installation

```bash
# Clone the repository
git clone https://github.com/ZuodaoTech/Echo-iOS.git
cd Echo-iOS

# Open in Xcode
open Echo.xcodeproj

# Select your team and run
```

## 🎯 Use Cases

- **Morning Affirmations**: Start your day with positive self-talk
- **Confidence Building**: Reinforce empowering beliefs before important events
- **Habit Formation**: Create reminders for new habits you're building
- **Meditation & Mindfulness**: Record calming mantras for meditation
- **Language Learning**: Practice pronunciation with repetition
- **Goal Visualization**: Verbalize and reinforce your goals daily

## 🏗️ Technical Architecture

### Core Technologies
- **SwiftUI 5.0**: Modern declarative UI with smooth animations
- **Core Data + CloudKit**: Persistent storage with optional iCloud sync
- **AVFoundation**: Professional audio recording and playback
- **Speech Framework**: On-device transcription for privacy
- **Combine**: Reactive state management

### Service Architecture
```
AudioCoordinator (Facade Pattern)
├── RecordingService     - Audio capture & encoding
├── PlaybackService      - Playback with repetitions
├── AudioSessionManager  - Privacy mode & routing
├── AudioFileManager     - File operations
└── AudioProcessingService - Silence trimming & transcription
```

## 🔐 Privacy & Security

- **No Analytics**: Zero tracking or analytics
- **Local First**: All data stored locally on device
- **Private Mode**: Automatic speaker protection
- **iCloud Encryption**: Optional sync uses Apple's encrypted CloudKit
- **No Third-Party Services**: Pure Apple frameworks only

## 🎨 Recent Updates

### Version 0.3.0 (Latest)
- ✅ Dynamic card colors that refresh on each app launch
- ✅ Fixed CloudKit sync for iCloud data management
- ✅ Improved audio playback stability
- ✅ Added interval settings between repetitions
- ✅ Enhanced tag management system
- ✅ Performance optimizations for app launch

### Version 0.2.0
- ✅ Complete tag system implementation
- ✅ Private mode (formerly Privacy mode)
- ✅ 60-second recording limit with visual feedback
- ✅ Advanced noise reduction
- ✅ Automatic silence trimming

## 🛠️ Development Features

### Hidden Developer Menu
Swipe down-down-up on the Me tab to access:
- Performance metrics
- CloudKit sync status
- Debug options
- Data management tools

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### How to Contribute
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Creator**: [Xiaolai](https://github.com/xiaolai)
- **Contributors**: [View all contributors](https://github.com/ZuodaoTech/Echo-iOS/graphs/contributors)

## 🙏 Acknowledgments

- Built with SwiftUI and dedication to mental wellness
- Inspired by the power of positive self-talk
- Thanks to all our beta testers and contributors

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/ZuodaoTech/Echo-iOS/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ZuodaoTech/Echo-iOS/discussions)
- **Email**: support@zuodao.tech

---

<p align="center">
  <b>Echo</b> - Amplify your inner voice<br>
  Made with ❤️ for personal growth
</p>