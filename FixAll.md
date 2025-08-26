# Echo iOS - Bug Fix Plan

## Overview
This document outlines all identified bugs in the Echo iOS codebase and provides a systematic plan for fixing them. Bugs are prioritized by severity and grouped by related functionality for efficient fixing.

**Total Bugs Identified:** 19  
**Estimated Total Fix Time:** 7-11 hours  
**Recommended Approach:** Fix in phases, test after each phase

---

## Phase 1: Critical Crashes (1-2 hours)
**Goal:** Prevent app crashes and data loss  
**Testing:** Run app on device, test preview mode, test transcription

### 🔴 Critical Bugs to Fix

#### Bug #1: Force Unwrapping in Preview Context
- **File:** `Echo/Persistence.swift:90`
- **Current:** `container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")`
- **Fix:** 
  ```swift
  if let firstDescription = container.persistentStoreDescriptions.first {
      firstDescription.url = URL(fileURLWithPath: "/dev/null")
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #2: Force Unwrapping Language Code
- **File:** `Echo/Services/AudioProcessingService.swift:519`
- **Current:** `if languageCode == nil || (!languageCode!.hasPrefix("zh")...`
- **Fix:**
  ```swift
  if languageCode == nil || !(languageCode?.hasPrefix("zh") ?? false || 
                               languageCode?.hasPrefix("ja") ?? false || 
                               languageCode?.hasPrefix("ko") ?? false)
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #3: Force Unwrapping Transcript
- **File:** `Echo/Views/AddEditScriptView.swift:494`
- **Current:** `if script.transcribedText != nil && !script.transcribedText!.isEmpty`
- **Fix:**
  ```swift
  if let transcribedText = script.transcribedText, !transcribedText.isEmpty {
  ```
- **Status:** [ ] Fixed [ ] Tested

---

## Phase 2: Memory Leaks & Resource Management (2-3 hours)
**Goal:** Fix timer leaks and resource cleanup  
**Testing:** Use Instruments to verify no leaks, test background/foreground transitions

### 🟠 High Priority Memory Issues

#### Bug #4: Timer Memory Leaks
- **Files to Fix:**
  - [ ] `PlaybackService.swift` - Add deinit with timer cleanup
  - [ ] `RecordingService.swift` - Add deinit with timer cleanup  
  - [ ] `AddEditScriptView.swift` - Add onDisappear timer cleanup
- **Implementation:**
  ```swift
  deinit {
      progressTimer?.invalidate()
      intervalTimer?.invalidate() 
      completionTimer?.invalidate()
      nextRepetitionWorkItem?.cancel()
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #5: Audio Resources Not Released
- **Files:** All audio services
- **Fix:** Ensure AVAudioPlayer/Recorder set to nil after use
- **Status:** [ ] Fixed [ ] Tested

---

## Phase 3: Core Data Threading (2-3 hours)
**Goal:** Fix Core Data thread safety and race conditions  
**Testing:** Stress test with rapid create/delete operations

### 🟠 Threading Violations

#### Bug #6: Core Data Context on Wrong Thread
- **File:** `Echo/Services/AudioCoordinator.swift:139,143`
- **Fix:** Use context.perform for all saves:
  ```swift
  if let context = script.managedObjectContext {
      context.perform {
          do {
              try context.save()
          } catch {
              print("Failed to save: \(error)")
          }
      }
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #7: @Published Updates from Background
- **Files:** All service classes
- **Fix:** Ensure all @Published updates on main queue:
  ```swift
  DispatchQueue.main.async { [weak self] in
      self?.isPlaying = true
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #8: Defensive Core Data Checks
- **File:** `ScriptCard.swift` and others
- **Root Cause:** Fix deletion flow to remove references before Core Data deletion
- **Status:** [ ] Analyzed [ ] Fixed [ ] Tested

---

## Phase 4: File Operations & Error Recovery (1-2 hours)
**Goal:** Add proper error handling for file operations  
**Testing:** Test with full disk, corrupted files, missing permissions

### 🟡 File System Issues

#### Bug #9: No Error Recovery for File Operations
- **File:** `AudioFileManager.swift`
- **Fix:** Add do-catch with specific error handling:
  ```swift
  do {
      if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.removeItem(at: url)
      }
  } catch CocoaError.fileNoSuchFile {
      // File already gone, that's okay
  } catch {
      print("Failed to remove file: \(error)")
      // Add retry or user notification
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #10: File Operations on Main Thread
- **All FileManager calls**
- **Fix:** Move to background queue:
  ```swift
  Task.detached {
      let exists = FileManager.default.fileExists(atPath: path)
      await MainActor.run {
          // Update UI
      }
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

---

## Phase 5: User Experience Fixes (1-2 hours)
**Goal:** Fix UX issues and add missing validations  
**Testing:** Test empty states, edge cases, error scenarios

### 🟢 UX Issues

#### Bug #11: Empty Script Save
- **File:** `AddEditScriptView.swift:595-615`
- **Fix:** Add validation:
  ```swift
  guard !scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      showingEmptyScriptAlert = true
      return
  }
  ```
- **Status:** [ ] Fixed [ ] Tested

#### Bug #12: No Progress Indicators
- **Add to:** Transcription, processing, sync operations
- **Implementation:** Add `@Published var operationProgress: (current: Int, total: Int)?`
- **Status:** [ ] Fixed [ ] Tested

#### Bug #13: Error Messages Not Localized
- **File:** `AudioService.swift:15-30`
- **Fix:** Create LocalizedError enum
- **Status:** [ ] Fixed [ ] Tested

---

## Phase 6: Race Conditions & Edge Cases (2-3 hours)
**Goal:** Fix remaining race conditions and edge cases  
**Testing:** Stress test with rapid state changes

### ⚡ Race Conditions

#### Bug #14: Audio Session Configuration Race
- **File:** `AudioSessionManager.swift`
- **Fix:** Add state machine for session management
- **Status:** [ ] Fixed [ ] Tested

#### Bug #15: Notification Permission Race
- **File:** `NotificationManager.swift:42-49`
- **Fix:** Use async/await for permission flow
- **Status:** [ ] Fixed [ ] Tested

#### Bug #16: Playback Session ID Race
- **File:** `PlaybackService.swift:340-344`
- **Fix:** Capture session ID in closure
- **Status:** [ ] Fixed [ ] Tested

#### Bug #17: CloudKit Sync State Race
- **File:** `Persistence.swift:76-79`
- **Fix:** Add synchronization for iCloud state
- **Status:** [ ] Fixed [ ] Tested

---

## Testing Checklist

### After Each Phase:
- [ ] Build succeeds without warnings
- [ ] App launches without crashes
- [ ] Basic recording and playback work
- [ معمول Core Data saves work
- [ ] No console errors during normal use

### Final Testing:
- [ ] Test on physical device (not just simulator)
- [ ] Test with airplane mode (offline)
- [ ] Test with low storage
- [ ] Test with denied permissions
- [ ] Memory leak check with Instruments
- [ ] Stress test with 100+ scripts
- [ ] Test background/foreground transitions
- [ ] Test during phone calls
- [ ] Test with Bluetooth audio devices

---

## Step-by-Step Implementation Guide

### Step 1: Fix Critical Crashes (1-2 hours)
- Fix all force unwrapping issues (Bugs #1, #2, #3)
- Test: App should not crash in preview mode or during transcription
- ✅ Must pass before proceeding

### Step 2: Fix Memory Leaks (2-3 hours)
- Add deinit methods to all services with timers
- Clean up timer references in views
- Test with Instruments: No memory leaks
- ✅ Must show stable memory usage

### Step 3: Fix Core Data Threading (2-3 hours)
- Wrap all Core Data saves in context.perform
- Ensure @Published updates on main queue
- Test: Rapid create/delete operations
- ✅ No Core Data crashes

### Step 4: Fix File Operations (1-2 hours)
- Add proper error handling to all file operations
- Move file checks to background queue
- Test: Full disk scenario, missing files
- ✅ Graceful error handling

### Step 5: Fix User Experience Issues (1-2 hours)
- Add empty script validation
- Add progress indicators
- Localize error messages
- Test: Edge cases and error scenarios
- ✅ Clear user feedback for all actions

### Step 6: Fix Race Conditions (2-3 hours)
- Implement audio session state machine
- Fix notification permission flow
- Capture session IDs properly
- Test: Rapid state changes
- ✅ No race condition crashes

### Step 7: Comprehensive Testing (2 hours)
- Run through complete testing checklist
- Test on physical device
- Verify all fixes are working together
- ✅ Ready for production

---

## Success Metrics

### Must Have (Before Release):
- Zero crashes in normal use
- No memory leaks
- All Core Data operations thread-safe
- Proper error handling for all user actions

### Should Have:
- Progress indicators for long operations
- Localized error messages
- Retry logic for network operations
- Comprehensive input validation

### Nice to Have:
- Performance optimizations
- Advanced error recovery
- Detailed logging system
- Analytics for crash reporting

---

## Notes

### High Risk Areas:
- Core Data threading (most crashes come from here)
- Timer lifecycle (memory leaks)
- File operations (data loss potential)

### Quick Wins:
- Force unwrap fixes (prevents crashes)
- Empty validation (improves UX)
- Timer cleanup (prevents leaks)

### Requires More Investigation:
- CloudKit sync reliability
- Audio session interruption handling
- Background mode behavior

---

## Code Review Checklist

Before considering bugs fixed:
- [ ] No force unwrapping (!, as!, try!)
- [ ] All timers have cleanup code
- [ ] Core Data operations use proper threading
- [ ] File operations have error handling
- [ ] @Published updates on main queue
- [ ] User inputs validated
- [ ] Permissions checked before use
- [ ] Resources properly released

---

## Post-Fix Requirements

### Documentation Updates:
- [ ] Update CLAUDE.md with fixed issues
- [ ] Add inline comments for complex fixes
- [ ] Document any new error handling patterns

### Testing Documentation:
- [ ] Create test cases for each fixed bug
- [ ] Document reproduction steps for verification
- [ ] Add regression test checklist

---

*Last Updated: 2025-08-26*  
*Total Bugs: 19*  
*Estimated Fix Time: 7-11 hours*  
*Priority: Start with Phase 1 immediately*