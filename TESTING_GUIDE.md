# Echo iOS - Testing Guide

## Manual Testing Checklist

### Prerequisites
1. Open Echo.xcodeproj in Xcode
2. Select iPhone simulator (iPhone 15 Pro or newer)
3. Build and run the app (Cmd+R)

### 1. iCloud Sync Testing

#### Enable iCloud Sync
- [ ] Navigate to Me tab
- [ ] Find "Backup & Sync" section
- [ ] Toggle "iCloud Sync" ON
- [ ] Verify info message appears: "Text and settings sync automatically. Audio files remain local."
- [ ] Check console for: "iCloud sync toggled: true"

#### Test Sync Functionality
- [ ] Create a new script in Cards tab
- [ ] Add script text: "Test iCloud sync"
- [ ] Set repetitions and interval
- [ ] Save the script
- [ ] Check if script appears in list
- [ ] Note: Actual sync requires CloudKit container setup in Apple Developer account

### 2. Export Functionality Testing

#### Export All Scripts
- [ ] Go to Me tab → "Backup & Sync" section
- [ ] Tap "Export Scripts"
- [ ] Verify Export Options screen appears
- [ ] Check that all scripts are selected by default
- [ ] Toggle "Include Audio Files" ON/OFF
- [ ] Select format: Echo Bundle / Plain Text / JSON
- [ ] Tap "Export" button
- [ ] Verify share sheet appears
- [ ] Save to Files app or share via AirDrop

#### Export Single Script
- [ ] Go to Cards tab
- [ ] Long press on any script card
- [ ] Select "Share" from context menu
- [ ] Verify share sheet appears with .echo file
- [ ] Save or share the file

#### Test Export Formats
- [ ] **Echo Bundle (.echo)**: Should create a bundle with manifest, scripts, categories
- [ ] **Plain Text (.txt)**: Should create readable text file with all script information
- [ ] **JSON (.json)**: Should create structured JSON with all metadata

### 3. Import Functionality Testing

#### Import Echo Bundle
- [ ] Go to Me tab → "Backup & Sync" section
- [ ] Tap "Import Scripts"
- [ ] Select a previously exported .echo file
- [ ] Verify import completion alert shows
- [ ] Check that imported scripts appear in Cards tab
- [ ] Verify categories are preserved

#### Test Import Formats
- [ ] Import .echo bundle file
- [ ] Import .json file
- [ ] Import .txt file (basic import)

#### Test Conflict Resolution
- [ ] Export a script
- [ ] Modify the script text in the app
- [ ] Import the previously exported file
- [ ] Verify script is skipped (default behavior)
- [ ] Check console for conflict messages

### 4. UI Components Testing

#### Me Tab - Backup & Sync Section
- [ ] iCloud Sync toggle works
- [ ] Info message displays when enabled
- [ ] Export Scripts button is clickable
- [ ] Import Scripts button is clickable
- [ ] Export progress indicator shows (if applicable)

#### Export Options View
- [ ] Script list displays correctly
- [ ] Select/Deselect All button works
- [ ] Individual script selection works
- [ ] Format picker (segmented control) works
- [ ] Include Audio toggle works
- [ ] Export button enables/disables based on selection
- [ ] Cancel button dismisses view

#### Script Card Context Menu
- [ ] Long press shows context menu
- [ ] Edit option works
- [ ] Share option works
- [ ] Delete Recording option appears (if recording exists)

### 5. Error Handling Testing

#### Export Errors
- [ ] Try exporting with no scripts selected
- [ ] Verify error alert appears

#### Import Errors
- [ ] Try importing invalid file format
- [ ] Verify error message appears
- [ ] Try importing corrupted bundle
- [ ] Verify graceful error handling

### 6. Performance Testing

#### Large Dataset
- [ ] Create 50+ scripts
- [ ] Test export performance
- [ ] Test import performance
- [ ] Verify UI remains responsive

#### Memory Usage
- [ ] Monitor memory during export/import
- [ ] Check for memory leaks
- [ ] Verify temporary files are cleaned up

## Verification Steps

### Build Verification
```bash
# Build the project
xcodebuild -scheme "Echo" -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Check for warnings/errors
xcodebuild -scheme "Echo" -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build 2>&1 | grep -E "(warning:|error:)"
```

### Run in Simulator
```bash
# Boot simulator
xcrun simctl boot "iPhone 15 Pro"

# Build and install
xcodebuild -scheme "Echo" -sdk iphonesimulator -derivedDataPath build

# Launch app
xcrun simctl launch booted xiaolai.Echo
```

### Console Monitoring
While testing, monitor the console for:
- CloudKit sync messages
- Export/import progress
- Error messages
- Memory warnings

## Expected Behaviors

### iCloud Sync
- Scripts created on one device should appear on others (text only)
- Audio recordings remain local to each device
- Changes sync automatically when online
- Offline changes sync when connection restored

### Export
- Creates timestamped files
- Preserves all metadata
- Audio files included only when selected
- Share sheet provides all iOS sharing options

### Import
- Detects and handles duplicates
- Preserves categories and relationships
- Shows clear success/error messages
- Doesn't overwrite without user consent

## Known Limitations

1. **iCloud Sync**: Requires valid Apple Developer account with CloudKit container
2. **Audio Sync**: Not implemented to conserve bandwidth
3. **Conflict Resolution**: Currently only "skip" strategy is implemented
4. **File Size**: Large audio files may take time to export/import

## Troubleshooting

### iCloud Sync Not Working
1. Check CloudKit container configuration
2. Verify iCloud is signed in on device
3. Check network connectivity
4. Review console for CloudKit errors

### Export/Import Issues
1. Ensure sufficient storage space
2. Check file permissions
3. Verify bundle integrity
4. Review error messages

### UI Not Updating
1. Force quit and restart app
2. Check Core Data save operations
3. Verify main thread updates
4. Review console for exceptions

## Test Coverage Report

- ✅ Core Data CloudKit configuration
- ✅ Export service with multiple formats
- ✅ Import service with conflict handling
- ✅ UI components and navigation
- ✅ Error handling and validation
- ⚠️ Actual CloudKit sync (requires Apple Developer setup)
- ⚠️ Large file handling (needs real device testing)

---

*Last Updated: 2025-08-25*
*Version: 0.2.0*