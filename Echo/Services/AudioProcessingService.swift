import AVFoundation
import Accelerate
import Speech

/// Service for processing audio files (trimming silence, normalizing, etc.)
final class AudioProcessingService {
    
    // MARK: - Properties
    
    private let fileManager: AudioFileManager
    private var currentRecognitionTask: SFSpeechRecognitionTask?
    
    // MARK: - Constants
    
    private enum Constants {
        static let silenceThreshold: Float = 0.01  // Amplitude threshold for silence
        static let minimumSilenceDuration: TimeInterval = 0.3  // Minimum silence to trim
        static let minimumAudioDuration: TimeInterval = 0.5  // Don't process very short recordings
    }
    
    // MARK: - Initialization
    
    init(fileManager: AudioFileManager) {
        self.fileManager = fileManager
    }
    
    // MARK: - Public Methods
    
    /// Check the status of speech recognition availability
    func checkSpeechRecognitionStatus() -> (available: Bool, onDevice: Bool, message: String) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        guard let recognizer = recognizer else {
            return (false, false, "Speech recognition not available for English (US)")
        }
        
        if !recognizer.isAvailable {
            return (false, false, "Speech recognition temporarily unavailable. Please check Settings > General > Keyboard > Enable Dictation")
        }
        
        var onDeviceAvailable = false
        var message = "✅ Speech recognition available"
        
        if #available(iOS 13, *) {
            if recognizer.supportsOnDeviceRecognition {
                onDeviceAvailable = true
                message += "\n✅ On-device dictation ready (offline capable)"
            } else {
                message += "\n⚠️ On-device dictation not available. To enable:\n"
                message += "1. Settings > General > Keyboard > Enable Dictation\n"
                message += "2. Download language pack in Dictation Languages\n"
                message += "3. Restart the app"
            }
        }
        
        return (true, onDeviceAvailable, message)
    }
    
    /// Process audio file: trim silence and optimize for voice
    func processRecording(for scriptId: UUID, completion: @escaping (Bool) -> Void) {
        let audioURL = fileManager.audioURL(for: scriptId)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("AudioProcessing: File doesn't exist")
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            do {
                // Load the audio file
                let audioFile = try AVAudioFile(forReading: audioURL)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                
                // Don't process very short recordings
                let duration = Double(frameCount) / format.sampleRate
                if duration < Constants.minimumAudioDuration {
                    print("AudioProcessing: Recording too short to process (\(duration)s)")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Read audio data
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("AudioProcessing: Failed to create buffer")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                try audioFile.read(into: buffer)
                buffer.frameLength = frameCount
                
                // Find trim points
                let (startFrame, endFrame) = self.findTrimPoints(in: buffer)
                
                // Check if trimming is needed
                if startFrame == 0 && endFrame == frameCount {
                    print("AudioProcessing: No trimming needed")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Create trimmed audio
                let trimmedLength = endFrame - startFrame
                guard trimmedLength > 0 else {
                    print("AudioProcessing: Audio is all silence")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                // Save trimmed audio
                let success = self.saveTrimmedAudio(
                    from: buffer,
                    startFrame: startFrame,
                    endFrame: endFrame,
                    to: audioURL,
                    format: format
                )
                
                let trimmedDuration = Double(trimmedLength) / format.sampleRate
                print("AudioProcessing: Trimmed from \(String(format: "%.2f", duration))s to \(String(format: "%.2f", trimmedDuration))s")
                
                DispatchQueue.main.async {
                    completion(success)
                }
                
            } catch {
                print("AudioProcessing error: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Transcribe audio file to text using Speech framework
    func transcribeRecording(for scriptId: UUID, languageCode: String? = nil, completion: @escaping (String?) -> Void) {
        // Check if speech recognition is available
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            // Request authorization if not determined
            if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                SFSpeechRecognizer.requestAuthorization { status in
                    if status == .authorized {
                        self.transcribeRecording(for: scriptId, languageCode: languageCode, completion: completion)
                    } else {
                        print("Speech recognition not authorized")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
            } else {
                print("Speech recognition not available")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
            return
        }
        
        // Use the original unprocessed audio file for transcription
        // This file maintains the original AAC format that Speech Recognition can read
        let audioURL = fileManager.originalAudioURL(for: scriptId)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Transcription: Audio file doesn't exist")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Create recognizer based on language preference
        var recognizer: SFSpeechRecognizer?
        
        if let languageCode = languageCode {
            // Use specified language
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode))
            if recognizer == nil {
                print("Speech recognizer not available for \(languageCode), trying en-US as fallback")
                recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            }
        } else {
            // No language specified, default to English
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        guard let recognizer = recognizer else {
            print("Speech recognizer not available")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Check i 请去qf recognizer is available
        guard recognizer.isAvailable else {
            print("Speech recognizer is not available at this time")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Verify the audio file is accessible and valid before attempting transcription
        do {
            // Try to create an AVAudioFile to verify format compatibility
            let audioFile = try AVAudioFile(forReading: audioURL)
            print("Audio file validated: format=\(audioFile.fileFormat), duration=\(Double(audioFile.length) / audioFile.fileFormat.sampleRate)s")
        } catch {
            print("Audio file validation failed - cannot open for transcription: \(error)")
            // This is likely error -11829 "Cannot Open"
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Add small delay to ensure file is fully written and accessible
        Thread.sleep(forTimeInterval: 0.2)
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        
        // Configure for self-talk/dictation with punctuation
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        // Enable automatic punctuation and capitalization (iOS 16+)
        if #available(iOS 16, *) {
            request.addsPunctuation = true
        }
        
        // Try to use on-device recognition if available for better privacy and reliability
        if #available(iOS 13, *) {
            if recognizer.supportsOnDeviceRecognition {
                // Try on-device first, but don't require it
                request.requiresOnDeviceRecognition = false  // Set to true if you want to force on-device only
                print("Speech recognition: On-device recognition available")
            } else {
                request.requiresOnDeviceRecognition = false
                print("Speech recognition: Using network-based recognition (on-device not available)")
            }
        }
        
        // Cancel any existing recognition task
        currentRecognitionTask?.cancel()
        currentRecognitionTask = nil
        
        // Add timeout handling
        var timeoutWorkItem: DispatchWorkItem?
        
        // Timeout after 30 seconds
        timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.currentRecognitionTask?.cancel()
            self?.currentRecognitionTask = nil
            print("Transcription timeout - cancelling task")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWorkItem!)
        
        // Perform recognition
        currentRecognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Cancel timeout if we get a response
            timeoutWorkItem?.cancel()
            
            if let error = error {
                // Ignore certain common but non-critical errors
                let errorCode = (error as NSError).code
                let errorDomain = (error as NSError).domain
                
                // Log the specific error for debugging
                print("Speech recognition error - Domain: \(errorDomain), Code: \(errorCode)")
                
                // Handle specific error codes
                switch errorCode {
                case 1101:
                    // Local recognition not available - this is expected when dictation isn't downloaded
                    print("Note: Local speech recognition not available (Error 1101). Using network-based recognition.")
                case 1107:
                    // Another common transient error
                    print("Transient recognition error 1107 - may still have results")
                case 209, 203:
                    // Network or service errors
                    print("Network/service error \(errorCode) - checking for partial results")
                default:
                    print("Speech recognition error: \(error.localizedDescription)")
                }
                
                // Check if we got any results despite the error
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    if !transcription.isEmpty {
                        print("Transcription completed despite error: \(transcription.prefix(50))...")
                        DispatchQueue.main.async {
                            completion(transcription)
                        }
                        return
                    }
                }
                
                // Check if we at least got partial results before error
                if let result = result, !result.bestTranscription.formattedString.isEmpty {
                    let transcription = result.bestTranscription.formattedString
                    print("Using partial transcription before error: \(transcription.prefix(50))...")
                    DispatchQueue.main.async {
                        completion(transcription)
                    }
                    return
                }
                
                print("Transcription error (code: \(errorCode)): \(error.localizedDescription)")
                self?.currentRecognitionTask = nil
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let result = result, result.isFinal {
                var transcription = result.bestTranscription.formattedString
                
                // Apply basic punctuation if not available from iOS 16+
                if #available(iOS 16, *) {
                    // iOS 16+ should have punctuation already
                } else {
                    transcription = self?.addBasicPunctuation(to: transcription) ?? transcription
                }
                
                print("Transcription successful: \(transcription.prefix(50))...")
                self?.currentRecognitionTask = nil
                DispatchQueue.main.async {
                    completion(transcription)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Add basic punctuation to transcribed text
    private func addBasicPunctuation(to text: String) -> String {
        var result = text
        
        // Capitalize first letter
        if !result.isEmpty {
            result = result.prefix(1).capitalized + result.dropFirst()
        }
        
        // Add period at the end if no punctuation exists
        let lastChar = result.last
        if let lastChar = lastChar,
           ![".", "!", "?", ",", ";", ":"].contains(String(lastChar)) {
            result += "."
        }
        
        // Capitalize after sentence endings (basic approach)
        result = result.replacingOccurrences(of: ". ", with: ".\n")
            .split(separator: "\n")
            .map { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    return trimmed.prefix(1).capitalized + trimmed.dropFirst()
                }
                return String(sentence)
            }
            .joined(separator: " ")
        
        return result
    }
    
    private func findTrimPoints(in buffer: AVAudioPCMBuffer) -> (start: AVAudioFramePosition, end: AVAudioFramePosition) {
        guard let channelData = buffer.floatChannelData else {
            return (0, AVAudioFramePosition(buffer.frameLength))
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // Analyze first channel for simplicity
        let samples = channelData[0]
        
        // Find start point (first non-silence)
        var startFrame = 0
        for i in 0..<frameLength {
            if abs(samples[i]) > Constants.silenceThreshold {
                startFrame = max(0, i - Int(buffer.format.sampleRate * 0.1)) // Keep 0.1s before speech
                break
            }
        }
        
        // Find end point (last non-silence)
        var endFrame = frameLength
        for i in stride(from: frameLength - 1, through: 0, by: -1) {
            if abs(samples[i]) > Constants.silenceThreshold {
                endFrame = min(frameLength, i + Int(buffer.format.sampleRate * 0.1)) // Keep 0.1s after speech
                break
            }
        }
        
        // Ensure we have valid range
        if startFrame >= endFrame {
            return (0, AVAudioFramePosition(frameLength))
        }
        
        return (AVAudioFramePosition(startFrame), AVAudioFramePosition(endFrame))
    }
    
    private func saveTrimmedAudio(
        from buffer: AVAudioPCMBuffer,
        startFrame: AVAudioFramePosition,
        endFrame: AVAudioFramePosition,
        to url: URL,
        format: AVAudioFormat
    ) -> Bool {
        
        // Create temporary URL for new file
        let tempURL = url.appendingPathExtension("tmp")
        
        do {
            // IMPORTANT: Use AAC format settings for Speech Recognition compatibility
            // This matches the original recording format
            let outputSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // Create output file with AAC format
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: outputSettings)
            
            // Calculate trimmed length
            let trimmedLength = AVAudioFrameCount(endFrame - startFrame)
            
            // Create buffer for trimmed audio
            guard let trimmedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: trimmedLength) else {
                return false
            }
            
            // Copy trimmed audio data
            if let inputChannelData = buffer.floatChannelData,
               let outputChannelData = trimmedBuffer.floatChannelData {
                
                for channel in 0..<Int(format.channelCount) {
                    let inputSamples = inputChannelData[channel]
                    let outputSamples = outputChannelData[channel]
                    
                    // Copy samples from start to end
                    for i in 0..<Int(trimmedLength) {
                        outputSamples[i] = inputSamples[Int(startFrame) + i]
                    }
                }
                
                trimmedBuffer.frameLength = trimmedLength
                
                // Write to file
                try outputFile.write(from: trimmedBuffer)
                
                // IMPORTANT: Close the file to ensure all data is written
                // AVAudioFile doesn't have an explicit close, but we can ensure it's released
                // by setting it to nil in a defer block
            }
            
            // Give the file system time to finish writing
            Thread.sleep(forTimeInterval: 0.1)
            
            // Verify the temp file was created properly
            if FileManager.default.fileExists(atPath: tempURL.path) {
                let tempFileSize = (try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64) ?? 0
                print("AudioProcessing: Temp file size: \(tempFileSize) bytes")
                
                // Replace original with trimmed version
                try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: tempURL, to: url)
                
                // Verify final file
                let finalFileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                print("AudioProcessing: Final file size: \(finalFileSize) bytes")
                
                return finalFileSize > 0
            } else {
                print("AudioProcessing: Temp file was not created")
                return false
            }
            
        } catch {
            print("Failed to save trimmed audio: \(error)")
            // Clean up temp file if it exists
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return false
    }
}
