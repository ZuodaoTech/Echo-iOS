# Echo iOS Development Log

## 2025-09-01
**Focus**: Claude Code workflow setup - no Echo iOS app changes today
**Added**: AI agents (Dylon, Wayne), devlog command, dev-log.md for concise history
**Decision**: Agents have no write permissions, Nancy checks dev log daily
**Result**: Improved development workflow for future efficiency

## 2025-08-31
**Changed**: Localization from "Default Language" to "Transcripting Language"
**Removed**: iCloud sync temporarily (will reimplement with better architecture)
**Decision**: Focus on local storage stability first, cloud sync later
**Result**: More stable app, eliminated sync-related crashes

## 2025-08-28
**Fixed**: Crash when clicking Add New Card button, Core Data initialization issues
**Added**: Lazy initialization for audio services, welcome screen with localization
**Decision**: Initialize services only when needed, not at app launch
**Result**: Faster app launch (instant rendering), reduced memory footprint

## 2025-08-27
**Added**: 19 language localizations, randomized card colors, auto-stop playback
**Fixed**: CloudKit query errors, audio session race conditions, permission handling
**Decision**: Use proper state management, thread-safe operations
**Result**: Stable audio playback, no race conditions

## 2025-08-26
**Removed**: Category system (replaced with Tags), "Now" special tag
**Added**: Tag management system, 60-second recording limit, hidden developer menu
**Decision**: Simplify organization with tags only, prevent overly long recordings
**Result**: Cleaner UI, more flexible organization

## 2025-08-25
**Added**: Complete tag system with editing and deletion
**Fixed**: Tag deletion crashes, localization issues
**Decision**: Long press for tag editing, native language display
**Result**: Intuitive tag management, better internationalization

## Key Architecture Decisions
- **9-Service Audio Architecture**: Clear separation of concerns
- **Core Data**: Local storage only (for now), lazy loading
- **Audio Format**: AAC, 44.1kHz, mono, 60-second limit
- **Privacy Mode**: Default ON, disable only with headphones
- **No External Dependencies**: Pure Apple frameworks only