# AddEditScriptView Refactoring Plan

## Current State Analysis

### Statistics
- **Total Lines**: 1422 lines
- **State Variables**: 61 @State properties
- **View Body**: 500+ lines (124-631)
- **Business Logic**: Mixed throughout view
- **Direct Core Data Access**: Multiple locations

### Key Problems
1. **Single Responsibility Violation**: View handles UI, business logic, Core Data, audio services
2. **State Explosion**: 61 state variables making debugging difficult
3. **Untestable**: Business logic embedded in view
4. **Performance**: Large view body causes SwiftUI compilation issues

## Proposed Architecture

```
AddEditScriptView (Thin View Layer)
    ├── AddEditScriptViewModel (Business Logic)
    │   ├── ScriptDataService (Core Data)
    │   ├── AudioCoordinator (Audio)
    │   └── ValidationService (Rules)
    │
    └── Child Views (UI Components)
        ├── ScriptTextSection
        ├── RecordingSection
        ├── ScriptSettingsSection
        ├── TagSelectionSection
        └── NotificationSection
```

## Implementation Phases

### Phase 1: Extract ViewModel (Priority: HIGH)
**Goal**: Move all business logic out of view
**Time Estimate**: 2-3 hours

#### Step 1.1: Create AddEditScriptViewModel
```swift
class AddEditScriptViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var scriptText = ""
    @Published var selectedTags: Set<Tag> = []
    @Published var repetitions: Int16 = 3
    @Published var intervalSeconds: Double = 2.0
    @Published var privateModeEnabled = true
    @Published var notificationEnabled = false
    
    // State management
    @Published var viewState: ViewState = .idle
    @Published var validationError: ValidationError?
    
    // Services
    private let dataService: ScriptDataService
    private let audioService: AudioCoordinator
    private let validator: ScriptValidator
    
    // Methods
    func save() async throws
    func delete() async throws
    func validate() -> ValidationResult
    func startRecording() async throws
    func stopRecording() async throws
}
```

#### Step 1.2: Define State Enum
```swift
enum ViewState {
    case idle
    case recording(progress: TimeInterval)
    case processing
    case saving
    case error(Error)
}
```

### Phase 2: Decompose into Child Views (Priority: HIGH)
**Goal**: Break down 500+ line view body
**Time Estimate**: 2 hours

#### Components to Extract:
1. **ScriptTextSection** (lines 127-201)
   - TextEditor
   - Character counter
   - Guidance UI

2. **RecordingSection** (lines 204-337)
   - Recording button
   - Audio player
   - Waveform/progress
   - Transcription display

3. **ScriptSettingsSection** (lines 340-387)
   - Repetitions picker
   - Interval slider
   - Private mode toggle

4. **TagSelectionSection** (lines 390-410)
   - Tag display
   - Tag picker integration

5. **NotificationSection** (lines 413-447)
   - Notification toggle
   - Frequency picker

### Phase 3: Create Service Layer (Priority: MEDIUM)
**Goal**: Abstract Core Data operations
**Time Estimate**: 1-2 hours

#### ScriptDataService
```swift
protocol ScriptDataService {
    func create(_ model: ScriptModel) async throws -> SelftalkScript
    func update(_ script: SelftalkScript, with model: ScriptModel) async throws
    func delete(_ script: SelftalkScript) async throws
    func fetch(id: UUID) async throws -> SelftalkScript?
}
```

### Phase 4: Consolidate State Management (Priority: MEDIUM)
**Goal**: Reduce 61 state variables to ~10
**Time Estimate**: 1 hour

#### State Consolidation:
- Group related states into objects
- Use single source of truth
- Remove redundant tracking

### Phase 5: Add Unit Tests (Priority: LOW)
**Goal**: Test extracted business logic
**Time Estimate**: 2 hours

#### Test Coverage:
- ViewModel logic
- Validation rules
- Service layer
- State transitions

## Migration Strategy

### Step-by-Step Migration:
1. Create new components alongside existing code
2. Gradually move functionality to new components
3. Update parent view to use new components
4. Remove old code once verified working
5. Add tests for new components

### Backward Compatibility:
- Maintain same UI/UX
- Preserve all existing functionality
- No breaking changes to data model

## Success Metrics

### Performance:
- [ ] Reduce compilation time by 50%+
- [ ] Reduce view body to <200 lines
- [ ] Improve app launch time

### Code Quality:
- [ ] 80%+ test coverage for business logic
- [ ] No direct Core Data access in views
- [ ] Clear separation of concerns

### Maintainability:
- [ ] New features take 50% less time
- [ ] Bugs easier to locate and fix
- [ ] Onboarding new developers faster

## Risk Mitigation

### Potential Risks:
1. **Breaking existing functionality**
   - Mitigation: Comprehensive testing, gradual migration

2. **Performance regression**
   - Mitigation: Profile before/after, optimize as needed

3. **State synchronization issues**
   - Mitigation: Single source of truth, clear data flow

## Timeline

- **Week 1**: Phase 1-2 (ViewModel + Child Views)
- **Week 2**: Phase 3-4 (Services + State Management)
- **Week 3**: Phase 5 + Testing + Polish

## Next Steps

1. Review and approve plan
2. Create feature branch
3. Begin Phase 1 implementation
4. Regular code reviews at each phase

---

*Created by Nancy (李楠)*
*Date: 2025-01-09*