# Echo iOS - Bug Fix Prompts Collection

## How to Use These Prompts
Each prompt is crafted to give me precise context and clear success criteria. Copy and paste them exactly as written for best results.

---

## 🔴 Phase 1: Critical Crashes (System Stabilization)

### Prompt 1.1: Fix All Force Unwrapping Issues
```
Create a new branch called "fix/critical-crashes" and fix all 3 force unwrapping issues:
1. Persistence.swift:90 - preview container force unwrap
2. AudioProcessingService.swift:519 - language code force unwrap after nil check
3. AddEditScriptView.swift:494 - transcribed text force unwrap

Replace all force unwrapping with safe optional binding. After fixing, verify the app builds without warnings and test that preview mode works, transcription completes, and transcript checking doesn't crash.
```

### Prompt 1.2: Verify Crash Fixes
```
Run a comprehensive test of the crash fixes:
1. Build and run the app in preview mode
2. Test transcription with different languages (nil, Chinese, English)
3. Create a script and wait for transcription to complete
Report any remaining crashes with stack traces.
```

---

## 🟠 Phase 2: Memory Management (Resource Optimization)

### Prompt 2.1: Fix Timer Memory Leaks
```
Fix all timer-related memory leaks by adding proper cleanup:
1. Add deinit methods to PlaybackService, RecordingService with timer invalidation
2. Fix AddEditScriptView transcriptCheckTimer cleanup in onDisappear
3. Ensure all timers use [weak self] in closures
4. Add cleanup for all DispatchWorkItem instances

Verify no retain cycles exist and all timers are properly invalidated.
```

### Prompt 2.2: Fix Audio Resource Leaks
```
Audit and fix all audio resource management:
1. Ensure all AVAudioPlayer instances are set to nil after use
2. Ensure all AVAudioRecorder instances are properly released
3. Add cleanup in service deinit methods
4. Verify audio files are closed properly after operations

Test by recording and playing multiple times, checking memory doesn't increase.
```

---

## 🟡 Phase 3: Core Data Threading (Data Integrity)

### Prompt 3.1: Fix Core Data Thread Safety
```
Fix all Core Data threading violations:
1. Find all Core Data save operations not wrapped in context.perform
2. Wrap all saves in proper context.perform or performAndWait blocks
3. Ensure all Core Data fetches happen on the correct queue
4. Fix the defensive checks in ScriptCard by addressing root deletion issues

Specifically fix AudioCoordinator.swift lines 139, 143 and any similar patterns.
Test with rapid create/edit/delete operations.
```

### Prompt 3.2: Fix @Published Thread Safety
```
Ensure all @Published property updates happen on main thread:
1. Audit all @Published properties in service classes
2. Wrap all updates in DispatchQueue.main.async with [weak self]
3. Consider using @MainActor for properties that should only update on main
4. Fix any direct assignments from background threads

Test UI consistency during background operations.
```

---

## 🔵 Phase 4: File Operations (System Resilience)

### Prompt 4.1: Add File Operation Error Handling
```
Add comprehensive error handling to all file operations:
1. Wrap all FileManager operations in proper do-catch blocks
2. Add specific handling for common errors (file not found, disk full, permissions)
3. Implement retry logic for transient failures
4. Add user-facing error messages for unrecoverable failures

Focus on AudioFileManager.swift and AudioProcessingService.swift.
Test with disk full and missing file scenarios.
```

### Prompt 4.2: Move File Operations Off Main Thread
```
Move all file operations to background queues:
1. Find all FileManager.default calls on main thread
2. Wrap in Task.detached or DispatchQueue.global blocks
3. Update UI on main thread after completion
4. Add progress indicators for long operations

Test that UI remains responsive during file operations.
```

---

## 🟢 Phase 5: User Experience (Interaction Design)

### Prompt 5.1: Add Input Validation
```
Implement comprehensive input validation:
1. Add validation for empty scripts in AddEditScriptView.saveScript
2. Prevent saving cards with only whitespace
3. Add character limit validation with user feedback
4. Validate audio recording minimum duration

Show appropriate alerts for validation failures.
Test all edge cases for script creation.
```

### Prompt 5.2: Add Progress Indicators
```
Add progress feedback for all long operations:
1. Add processing indicator for transcription
2. Add progress for audio processing/trimming
3. Add sync progress for iCloud operations
4. Add recording time remaining indicator

Ensure users always know when the app is working.
```

### Prompt 5.3: Localize Error Messages
```
Fix all hardcoded error strings:
1. Create LocalizedError enum for all error types
2. Move all error strings to Localizable.strings
3. Update error handling to use localized messages
4. Ensure both English and Chinese translations exist

Test with Chinese language setting.
```

---

## ⚡ Phase 6: Race Conditions (System Coordination)

### Prompt 6.1: Implement Audio Session State Machine
```
Create proper state management for audio sessions:
1. Define AudioSessionState enum (idle, recording, playing, transitioning)
2. Implement state machine in AudioSessionManager
3. Prevent invalid state transitions
4. Add mutex/lock for state changes

Test rapid switching between recording and playback.
```

### Prompt 6.2: Fix Permission Race Conditions
```
Fix all permission-related race conditions:
1. Implement async/await for permission flows
2. Ensure sequential permission checking
3. Add proper completion handlers
4. Cache permission states appropriately

Focus on NotificationManager and AudioSessionManager.
Test with permissions in various states.
```

### Prompt 6.3: Fix Session ID Races
```
Fix all session identifier race conditions:
1. Capture session IDs in closures before async operations
2. Validate session ID hasn't changed in completion handlers
3. Cancel orphaned operations when session changes
4. Add session validation throughout PlaybackService

Test with rapid play/stop operations.
```

---

## 🎯 Comprehensive Testing

### Prompt 7.1: Integration Testing
```
Run comprehensive integration tests:
1. Create 10 cards with recordings rapidly
2. Play multiple cards with repetitions
3. Delete cards while playing
4. Edit cards during transcription
5. Test with airplane mode on/off
6. Test with low memory conditions
7. Switch between apps during recording

Report any issues with detailed reproduction steps.
```

### Prompt 7.2: Memory Leak Testing
```
Use Instruments to verify all memory leaks are fixed:
1. Profile the app with Leaks instrument
2. Record and play 20 times
3. Create and delete 20 cards
4. Check for abandoned memory
5. Verify memory returns to baseline

Provide screenshot of Instruments showing no leaks.
```

---

## 📝 Commit and Documentation

### Prompt 8.1: Commit Fixes
```
Review all changes and create a comprehensive commit:
1. Ensure all changes follow Swift best practices
2. Verify no regression in existing functionality
3. Update version number to reflect bug fixes
4. Commit with message: "Fix critical bugs: crashes, memory leaks, threading issues (19 bugs resolved)"

Prepare for merge to main branch after final testing.
```

### Prompt 8.2: Update Documentation
```
Update project documentation:
1. Add comments for complex fixes
2. Update CLAUDE.md with resolved issues
3. Document any new patterns introduced
4. Create brief release notes for fixes

Ensure future developers understand the changes.
```

---

## 🚀 Production Readiness

### Final Validation Prompt:
```
Perform final production readiness check:
1. Build release configuration
2. Test on physical device (not simulator)
3. Verify all 19 bugs are resolved
4. Check system health metrics
5. Validate no performance regression
6. Merge fix branch to main
7. Tag release as v0.2.3-bugfix

Confirm system health score improved from 65/100 to 95/100.
```

---

## Best Practices in These Prompts:

1. **Specific Locations**: Exact files and line numbers
2. **Clear Scope**: Each prompt has defined boundaries
3. **Validation Criteria**: How to verify success
4. **Progressive Complexity**: Build on previous fixes
5. **Safety First**: Work in branches, test thoroughly
6. **Context Preservation**: Each prompt is self-contained

Start with Phase 1 prompts and work systematically through each phase. Don't skip phases as later fixes may depend on earlier ones.