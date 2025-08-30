import Foundation
import Combine
import AVFoundation
@testable import Echo

// MARK: - Mock AudioFileManager
class MockAudioFileManager: AudioFileManager {
    
    // Mock state
    var mockFiles: [UUID: URL] = [:]
    var mockOriginalFiles: [UUID: URL] = [:]
    var mockFileDurations: [UUID: TimeInterval] = [:]
    var mockFileExists: [UUID: Bool] = [:]
    var shouldThrowError: AudioServiceError?
    
    // Call tracking
    var audioURLCalls: [UUID] = []
    var deleteRecordingCalls: [UUID] = []
    var audioFileExistsCalls: [UUID] = []
    var getAudioDurationCalls: [UUID] = []
    
    override func audioURL(for scriptId: UUID) -> URL {
        audioURLCalls.append(scriptId)
        
        if let url = mockFiles[scriptId] {
            return url
        }
        
        // Return mock URL
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("\(scriptId.uuidString).m4a")
    }
    
    override func originalAudioURL(for scriptId: UUID) -> URL {
        if let url = mockOriginalFiles[scriptId] {
            return url
        }
        
        // Return mock original URL
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("\(scriptId.uuidString)_original.m4a")
    }
    
    override func audioFileExists(for scriptId: UUID) -> Bool {
        audioFileExistsCalls.append(scriptId)
        return mockFileExists[scriptId] ?? false
    }
    
    override func deleteRecording(for scriptId: UUID) throws {
        deleteRecordingCalls.append(scriptId)
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockFiles.removeValue(forKey: scriptId)
        mockOriginalFiles.removeValue(forKey: scriptId)
        mockFileExists[scriptId] = false
    }
    
    override func getAudioDuration(for scriptId: UUID) -> TimeInterval? {
        getAudioDurationCalls.append(scriptId)
        return mockFileDurations[scriptId]
    }
    
    // Helper methods for testing
    func setMockFile(for scriptId: UUID, url: URL, duration: TimeInterval) {
        mockFiles[scriptId] = url
        mockFileDurations[scriptId] = duration
        mockFileExists[scriptId] = true
    }
    
    func reset() {
        mockFiles.removeAll()
        mockOriginalFiles.removeAll()
        mockFileDurations.removeAll()
        mockFileExists.removeAll()
        shouldThrowError = nil
        
        audioURLCalls.removeAll()
        deleteRecordingCalls.removeAll()
        audioFileExistsCalls.removeAll()
        getAudioDurationCalls.removeAll()
    }
}

// MARK: - Mock AudioSessionManager
class MockAudioSessionManager: AudioSessionManager {
    
    // Mock state
    var mockCurrentState: AudioSessionState = .idle
    var mockMicrophonePermissionGranted = true
    var mockPrivateModeActive = false
    var shouldThrowError: AudioServiceError?
    
    // Call tracking
    var configureForRecordingCalls: [(Bool)] = []
    var configureForPlaybackCalls: [(Bool)] = []
    var transitionToCalls: [AudioSessionState] = []
    var requestMicrophonePermissionCalls: Int = 0
    
    override var currentState: AudioSessionState {
        return mockCurrentState
    }
    
    override var isMicrophonePermissionGranted: Bool {
        return mockMicrophonePermissionGranted
    }
    
    @Published override var privateModeActive: Bool {
        get { mockPrivateModeActive }
        set { mockPrivateModeActive = newValue }
    }
    
    override func configureForRecording(enhancedProcessing: Bool) throws {
        configureForRecordingCalls.append(enhancedProcessing)
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockCurrentState = .recording
    }
    
    override func configureForPlayback(privateModeEnabled: Bool) throws {
        configureForPlaybackCalls.append(privateModeEnabled)
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockCurrentState = .playback
    }
    
    override func transitionTo(_ newState: AudioSessionState) {
        transitionToCalls.append(newState)
        mockCurrentState = newState
    }
    
    override func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        requestMicrophonePermissionCalls += 1
        DispatchQueue.global().async {
            completion(self.mockMicrophonePermissionGranted)
        }
    }
    
    override func checkPrivateMode() {
        // Mock implementation - no actual check needed
    }
    
    // Helper methods for testing
    func reset() {
        mockCurrentState = .idle
        mockMicrophonePermissionGranted = true
        mockPrivateModeActive = false
        shouldThrowError = nil
        
        configureForRecordingCalls.removeAll()
        configureForPlaybackCalls.removeAll()
        transitionToCalls.removeAll()
        requestMicrophonePermissionCalls = 0
    }
}

// MARK: - Mock RecordingService
class MockRecordingService: RecordingService {
    
    // Mock state
    private var mockIsRecording = false
    private var mockRecordingDuration: TimeInterval = 0
    private var mockCurrentScriptId: UUID?
    private var mockVoiceActivityLevel: Float = 0
    var shouldThrowError: AudioServiceError?
    var mockTrimTimestamps: (start: TimeInterval, end: TimeInterval)?
    
    // Call tracking
    var startRecordingCalls: [UUID] = []
    var stopRecordingCalls: Int = 0
    var stopRecordingAsyncCalls: Int = 0
    var getTrimTimestampsCalls: Int = 0
    
    override var isRecording: Bool {
        return mockIsRecording
    }
    
    override var recordingDuration: TimeInterval {
        return mockRecordingDuration
    }
    
    override var currentRecordingScriptId: UUID? {
        return mockCurrentScriptId
    }
    
    override var voiceActivityLevel: Float {
        return mockVoiceActivityLevel
    }
    
    override func startRecording(for scriptId: UUID) throws {
        startRecordingCalls.append(scriptId)
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockIsRecording = true
        mockCurrentScriptId = scriptId
        mockRecordingDuration = 0
    }
    
    override func stopRecording(completion: ((UUID, TimeInterval) -> Void)?) {
        stopRecordingAsyncCalls += 1
        
        let scriptId = mockCurrentScriptId ?? UUID()
        let duration = mockRecordingDuration
        
        mockIsRecording = false
        mockCurrentScriptId = nil
        mockRecordingDuration = 0
        
        DispatchQueue.global().async {
            completion?(scriptId, duration)
        }
    }
    
    @discardableResult
    override func stopRecording() -> (scriptId: UUID, duration: TimeInterval)? {
        stopRecordingCalls += 1
        
        let result = (scriptId: mockCurrentScriptId ?? UUID(), duration: mockRecordingDuration)
        
        mockIsRecording = false
        mockCurrentScriptId = nil
        mockRecordingDuration = 0
        
        return result
    }
    
    override func getTrimTimestamps() -> (start: TimeInterval, end: TimeInterval)? {
        getTrimTimestampsCalls += 1
        return mockTrimTimestamps
    }
    
    override func isRecording(scriptId: UUID) -> Bool {
        return mockIsRecording && mockCurrentScriptId == scriptId
    }
    
    // Helper methods for testing
    func setMockRecording(isRecording: Bool, scriptId: UUID?, duration: TimeInterval = 0, voiceLevel: Float = 0) {
        mockIsRecording = isRecording
        mockCurrentScriptId = scriptId
        mockRecordingDuration = duration
        mockVoiceActivityLevel = voiceLevel
    }
    
    func reset() {
        mockIsRecording = false
        mockRecordingDuration = 0
        mockCurrentScriptId = nil
        mockVoiceActivityLevel = 0
        shouldThrowError = nil
        mockTrimTimestamps = nil
        
        startRecordingCalls.removeAll()
        stopRecordingCalls = 0
        stopRecordingAsyncCalls = 0
        getTrimTimestampsCalls = 0
    }
}

// MARK: - Mock PlaybackService
class MockPlaybackService: PlaybackService {
    
    // Mock state
    private var mockIsPlaying = false
    private var mockIsPaused = false
    private var mockIsInPlaybackSession = false
    private var mockCurrentPlayingScriptId: UUID?
    private var mockPlaybackProgress: Double = 0
    private var mockCurrentRepetition = 0
    private var mockTotalRepetitions = 0
    private var mockIsInInterval = false
    private var mockIntervalProgress: Double = 0
    var shouldThrowError: AudioServiceError?
    
    // Call tracking
    var startPlaybackCalls: [(UUID, Int, TimeInterval, Bool)] = []
    var pausePlaybackCalls: Int = 0
    var resumePlaybackCalls: Int = 0
    var stopPlaybackCalls: Int = 0
    var setPlaybackSpeedCalls: [Float] = []
    
    override var isPlaying: Bool {
        return mockIsPlaying
    }
    
    override var isPaused: Bool {
        return mockIsPaused
    }
    
    override var isInPlaybackSession: Bool {
        return mockIsInPlaybackSession
    }
    
    override var currentPlayingScriptId: UUID? {
        return mockCurrentPlayingScriptId
    }
    
    override var playbackProgress: Double {
        return mockPlaybackProgress
    }
    
    override var currentRepetition: Int {
        return mockCurrentRepetition
    }
    
    override var totalRepetitions: Int {
        return mockTotalRepetitions
    }
    
    override var isInInterval: Bool {
        return mockIsInInterval
    }
    
    override var intervalProgress: Double {
        return mockIntervalProgress
    }
    
    override func startPlayback(scriptId: UUID, repetitions: Int, intervalSeconds: TimeInterval, privateModeEnabled: Bool) throws {
        startPlaybackCalls.append((scriptId, repetitions, intervalSeconds, privateModeEnabled))
        
        if let error = shouldThrowError {
            throw error
        }
        
        mockIsPlaying = true
        mockIsInPlaybackSession = true
        mockCurrentPlayingScriptId = scriptId
        mockTotalRepetitions = repetitions
        mockCurrentRepetition = 1
    }
    
    override func pausePlayback() {
        pausePlaybackCalls += 1
        mockIsPlaying = false
        mockIsPaused = true
    }
    
    override func resumePlayback() {
        resumePlaybackCalls += 1
        mockIsPlaying = true
        mockIsPaused = false
    }
    
    override func stopPlayback() {
        stopPlaybackCalls += 1
        mockIsPlaying = false
        mockIsPaused = false
        mockIsInPlaybackSession = false
        mockCurrentPlayingScriptId = nil
        mockPlaybackProgress = 0
        mockCurrentRepetition = 0
        mockTotalRepetitions = 0
    }
    
    override func setPlaybackSpeed(_ speed: Float) {
        setPlaybackSpeedCalls.append(speed)
    }
    
    // Helper methods for testing
    func setMockPlaybackState(
        isPlaying: Bool,
        isPaused: Bool = false,
        isInSession: Bool = false,
        scriptId: UUID? = nil,
        progress: Double = 0,
        currentRep: Int = 0,
        totalReps: Int = 0
    ) {
        mockIsPlaying = isPlaying
        mockIsPaused = isPaused
        mockIsInPlaybackSession = isInSession
        mockCurrentPlayingScriptId = scriptId
        mockPlaybackProgress = progress
        mockCurrentRepetition = currentRep
        mockTotalRepetitions = totalReps
    }
    
    func reset() {
        mockIsPlaying = false
        mockIsPaused = false
        mockIsInPlaybackSession = false
        mockCurrentPlayingScriptId = nil
        mockPlaybackProgress = 0
        mockCurrentRepetition = 0
        mockTotalRepetitions = 0
        mockIsInInterval = false
        mockIntervalProgress = 0
        shouldThrowError = nil
        
        startPlaybackCalls.removeAll()
        pausePlaybackCalls = 0
        resumePlaybackCalls = 0
        stopPlaybackCalls = 0
        setPlaybackSpeedCalls.removeAll()
    }
}

// MARK: - Mock AudioProcessingService
class MockAudioProcessingService: AudioProcessingService {
    
    // Mock state
    var shouldThrowError: AudioServiceError?
    var mockProcessingSuccess = true
    var mockTranscription: String?
    
    // Call tracking
    var processRecordingCalls: [(UUID, (start: TimeInterval, end: TimeInterval)?)] = []
    var transcribeRecordingCalls: [(UUID, String)] = []
    
    override func processRecording(
        for scriptId: UUID,
        trimTimestamps: (start: TimeInterval, end: TimeInterval)?,
        completion: @escaping (Bool) -> Void
    ) {
        processRecordingCalls.append((scriptId, trimTimestamps))
        
        DispatchQueue.global().async {
            completion(self.mockProcessingSuccess)
        }
    }
    
    override func transcribeRecording(
        for scriptId: UUID,
        languageCode: String,
        completion: @escaping (String?) -> Void
    ) {
        transcribeRecordingCalls.append((scriptId, languageCode))
        
        DispatchQueue.global().async {
            completion(self.mockTranscription)
        }
    }
    
    // Helper methods for testing
    func reset() {
        shouldThrowError = nil
        mockProcessingSuccess = true
        mockTranscription = nil
        
        processRecordingCalls.removeAll()
        transcribeRecordingCalls.removeAll()
    }
}