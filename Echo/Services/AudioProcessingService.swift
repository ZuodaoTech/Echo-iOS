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
        // Optimized for noisy environments
        static let silenceThreshold: Float = 0.02  // Low sensitivity - filters noise better
        static let minimumSilenceDuration: TimeInterval = 0.3  // Minimum silence to trim
        static let minimumAudioDuration: TimeInterval = 0.5  // Don't process very short recordings
        
        static func getThreshold() -> Float {
            return silenceThreshold  // Use low sensitivity for noise filtering
        }
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
    func processRecording(for scriptId: UUID, trimTimestamps: (start: TimeInterval, end: TimeInterval)? = nil, completion: @escaping (Bool) -> Void) {
        // Auto-trim is always enabled now
        // Check if we have trim timestamps from real-time voice detection
        if let timestamps = trimTimestamps {
            #if DEBUG
            print("AudioProcessing: Using real-time voice detection timestamps")
            #endif
            #if DEBUG
            print("AudioProcessing: Will trim from \(timestamps.start)s to \(timestamps.end)s")
            #endif
            
            // Use the timestamp-based trimming (much simpler!)
            trimAudioWithTimestamps(scriptId: scriptId, startTime: timestamps.start, endTime: timestamps.end, completion: completion)
            return
        }
        
        #if DEBUG
        print("AudioProcessing: Starting buffer-based silence trimming (fallback method)")
        #endif
        #if DEBUG
        print("AudioProcessing: Using optimized settings for noise filtering")
        #endif
        
        let audioURL = fileManager.audioURL(for: scriptId)
        let originalURL = fileManager.originalAudioURL(for: scriptId)
        
        // Move all file operations to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            // First, copy the recorded file to original (for transcription) on background thread
            do {
                if FileManager.default.fileExists(atPath: originalURL.path) {
                    try FileManager.default.removeItem(at: originalURL)
                }
                try FileManager.default.copyItem(at: audioURL, to: originalURL)
                #if DEBUG
                print("AudioProcessing: Saved original copy for transcription")
                #endif
            } catch {
                #if DEBUG
                print("AudioProcessing: Failed to save original copy: \(error)")
                #endif
            }
            
            guard FileManager.default.fileExists(atPath: audioURL.path) else {
                #if DEBUG
                print("AudioProcessing: File doesn't exist")
                #endif
                DispatchQueue.main.async {
                    completion(false)
                }
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
                    #if DEBUG
                    print("AudioProcessing: Recording too short to process (\(duration)s)")
                    #endif
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Read audio data
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    #if DEBUG
                    print("AudioProcessing: Failed to create buffer")
                    #endif
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                try audioFile.read(into: buffer)
                buffer.frameLength = frameCount
                
                // Find trim points
                let (startFrame, endFrame) = self.findTrimPoints(in: buffer)
                
                #if DEBUG
                print("AudioProcessing: Trim points found - Start: \(startFrame)/\(frameCount), End: \(endFrame)/\(frameCount)")
                #endif
                #if DEBUG
                print("AudioProcessing: Will trim \(Double(startFrame)/format.sampleRate)s from start, \(Double(Int64(frameCount) - endFrame)/format.sampleRate)s from end")
                #endif
                
                // Check if trimming is needed
                if startFrame == 0 && endFrame == frameCount {
                    #if DEBUG
                    print("AudioProcessing: No trimming needed (audio starts and ends with sound)")
                    #endif
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Create trimmed audio
                let trimmedLength = endFrame - startFrame
                guard trimmedLength > 0 else {
                    #if DEBUG
                    print("AudioProcessing: Audio is all silence")
                    #endif
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
                #if DEBUG
                print("AudioProcessing: Trimmed from \(String(format: "%.2f", duration))s to \(String(format: "%.2f", trimmedDuration))s")
                #endif
                
                DispatchQueue.main.async {
                    completion(success)
                }
                
            } catch {
                #if DEBUG
                print("AudioProcessing error: \(error)")
                #endif
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
                        #if DEBUG
                        print("Speech recognition not authorized")
                        #endif
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
            } else {
                #if DEBUG
                print("Speech recognition not available")
                #endif
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
            #if DEBUG
            print("Transcription: Audio file doesn't exist")
            #endif
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
                #if DEBUG
                print("Speech recognizer not available for \(languageCode), trying en-US as fallback")
                #endif
                recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            }
        } else {
            // No language specified, default to English
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        guard let recognizer = recognizer else {
            #if DEBUG
            print("Speech recognizer not available")
            #endif
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Check if recognizer is available
        guard recognizer.isAvailable else {
            #if DEBUG
            print("Speech recognizer is not available at this time")
            #endif
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Verify the audio file is accessible and valid before attempting transcription
        do {
            // Try to create an AVAudioFile to verify format compatibility
            let audioFile = try AVAudioFile(forReading: audioURL)
            #if DEBUG
            print("Audio file validated: format=\(audioFile.fileFormat), duration=\(Double(audioFile.length) / audioFile.fileFormat.sampleRate)s")
            #endif
        } catch {
            #if DEBUG
            print("Audio file validation failed - cannot open for transcription: \(error)")
            #endif
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
                #if DEBUG
                print("Speech recognition: On-device recognition available")
                #endif
            } else {
                request.requiresOnDeviceRecognition = false
                #if DEBUG
                print("Speech recognition: Using network-based recognition (on-device not available)")
                #endif
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
            #if DEBUG
            print("Transcription timeout - cancelling task")
            #endif
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
                #if DEBUG
                print("Speech recognition error - Domain: \(errorDomain), Code: \(errorCode)")
                #endif
                
                // Handle specific error codes
                switch errorCode {
                case 1101:
                    // Local recognition not available - this is expected when dictation isn't downloaded
                    #if DEBUG
                    print("Note: Local speech recognition not available (Error 1101). Using network-based recognition.")
                    #endif
                case 1107:
                    // Another common transient error
                    #if DEBUG
                    print("Transient recognition error 1107 - may still have results")
                    #endif
                case 209, 203:
                    // Network or service errors
                    #if DEBUG
                    print("Network/service error \(errorCode) - checking for partial results")
                    #endif
                default:
                    #if DEBUG
                    print("Speech recognition error: \(error.localizedDescription)")
                    #endif
                }
                
                // Check if we got any results despite the error
                if let result = result {
                    var transcription = result.bestTranscription.formattedString
                    if !transcription.isEmpty {
                        // Apply punctuation even to partial results
                        let languageUsed = languageCode ?? "en-US"
                        transcription = self?.ensureProperPunctuation(to: transcription, languageCode: languageUsed) ?? transcription
                        #if DEBUG
                        print("Transcription completed despite error: \(transcription.prefix(50))...")
                        #endif
                        DispatchQueue.main.async {
                            completion(transcription)
                        }
                        return
                    }
                }
                
                #if DEBUG
                print("Transcription error (code: \(errorCode)): \(error.localizedDescription)")
                #endif
                self?.currentRecognitionTask = nil
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let result = result, result.isFinal {
                var transcription = result.bestTranscription.formattedString
                
                // Always apply punctuation cleanup regardless of iOS version
                // iOS 16+ adds some punctuation but may miss end punctuation
                let languageUsed = languageCode ?? "en-US"
                transcription = self?.ensureProperPunctuation(to: transcription, languageCode: languageUsed) ?? transcription
                
                #if DEBUG
                print("Transcription successful: \(transcription.prefix(50))...")
                #endif
                self?.currentRecognitionTask = nil
                DispatchQueue.main.async {
                    completion(transcription)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Trim audio using timestamps from real-time voice detection
    private func trimAudioWithTimestamps(scriptId: UUID, startTime: TimeInterval, endTime: TimeInterval, completion: @escaping (Bool) -> Void) {
        let audioURL = fileManager.audioURL(for: scriptId)
        let originalURL = fileManager.originalAudioURL(for: scriptId)
        
        // Save original for transcription with proper error handling
        do {
            // Check disk space before copying
            try FileOperationHelper.checkAvailableDiskSpace()
            
            // Copy file with retry logic
            try FileOperationHelper.copyFile(from: audioURL, to: originalURL)
            #if DEBUG
            print("AudioProcessing: Saved original copy for transcription")
            #endif
        } catch let error as AudioServiceError {
            #if DEBUG
            print("AudioProcessing: Failed to save original - \(error.errorDescription ?? "")")
            #endif
            // Continue processing even if original copy fails
        } catch {
            #if DEBUG
            print("AudioProcessing: Failed to save original: \(error)")
            #endif
        }
        
        // Use AVAsset for time-based trimming
        let asset = AVAsset(url: audioURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        
        guard let session = exportSession else {
            #if DEBUG
            print("AudioProcessing: Failed to create export session")
            #endif
            completion(false)
            return
        }
        
        // Configure trimming time range
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 1000)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)
        
        session.timeRange = timeRange
        session.outputFileType = .m4a
        
        // Create temp file for trimmed audio
        let tempURL = audioURL.appendingPathExtension("trimmed")
        try? FileManager.default.removeItem(at: tempURL)
        session.outputURL = tempURL
        
        // Export trimmed audio
        session.exportAsynchronously {
            switch session.status {
            case .completed:
                // Replace original with trimmed version using proper error handling
                do {
                    // Delete original file
                    try FileOperationHelper.deleteFile(at: audioURL)
                    
                    // Move trimmed file to original location with retry
                    try FileOperationHelper.moveFile(from: tempURL, to: audioURL)
                    
                    // Validate the new file
                    try self.fileManager.validateAudioFile(for: scriptId)
                    
                    let duration = CMTimeGetSeconds(asset.duration)
                    let trimmedDuration = endTime - startTime
                    #if DEBUG
                    print("AudioProcessing: Successfully trimmed from \(duration)s to \(trimmedDuration)s")
                    #endif
                    
                    // Apply voice enhancement using dedicated service
                    VoiceEnhancementService.shared.processAudioFile(at: audioURL) { enhanced in
                        if enhanced {
                            #if DEBUG
                            print("AudioProcessing: Voice enhancement completed")
                            #endif
                        } else {
                            #if DEBUG
                            print("AudioProcessing: Voice enhancement failed, keeping trimmed audio")
                            #endif
                        }
                        DispatchQueue.main.async {
                            completion(true)
                        }
                    }
                } catch let error as AudioServiceError {
                    #if DEBUG
                    print("AudioProcessing: File operation failed - \(error.errorDescription ?? "")")
                    #endif
                    
                    // Try to recover by keeping the original file
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                    
                    DispatchQueue.main.async {
                        completion(false)
                    }
                } catch {
                    #if DEBUG
                    print("AudioProcessing: Failed to replace file: \(error)")
                    #endif
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
                
            case .failed:
                #if DEBUG
                print("AudioProcessing: Export failed: \(session.error?.localizedDescription ?? "Unknown error")")
                #endif
                DispatchQueue.main.async {
                    completion(false)
                }
                
            default:
                #if DEBUG
                print("AudioProcessing: Export status: \(session.status)")
                #endif
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Ensure proper punctuation and formatting for transcribed text
    private func ensureProperPunctuation(to text: String, languageCode: String?) -> String {
        // First trim any whitespace
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If empty, return as is
        guard !result.isEmpty else { return result }
        
        // Define punctuation sets for different languages
        let westernPunctuation = CharacterSet(charactersIn: ".!?,;:")
        let chinesePunctuation = CharacterSet(charactersIn: "。！？，；：、")
        let japanesePunctuation = CharacterSet(charactersIn: "。！？、")
        
        // Determine which punctuation set to use based on language
        let punctuationSet: CharacterSet
        let defaultEndPunctuation: String
        
        if let langCode = languageCode {
            if langCode.hasPrefix("zh") {
                // Chinese
                punctuationSet = chinesePunctuation.union(westernPunctuation)
                defaultEndPunctuation = "。"
            } else if langCode.hasPrefix("ja") {
                // Japanese
                punctuationSet = japanesePunctuation.union(westernPunctuation)
                defaultEndPunctuation = "。"
            } else {
                // Western languages
                punctuationSet = westernPunctuation
                defaultEndPunctuation = "."
            }
        } else {
            // Default to western
            punctuationSet = westernPunctuation
            defaultEndPunctuation = "."
        }
        
        // Check if the text ends with punctuation
        if let lastChar = result.last {
            // Check if last character is punctuation
            if let lastCharScalar = lastChar.unicodeScalars.first {
                if !punctuationSet.contains(lastCharScalar) {
                // Add appropriate punctuation based on content
                // If it looks like a question (contains question words), add question mark
                let lowercased = result.lowercased()
                if lowercased.contains("what") || lowercased.contains("when") || 
                   lowercased.contains("where") || lowercased.contains("who") ||
                   lowercased.contains("why") || lowercased.contains("how") ||
                   lowercased.contains("?") || lowercased.contains("吗") ||
                   lowercased.contains("呢") || lowercased.contains("什么") {
                    result += defaultEndPunctuation == "。" ? "？" : "?"
                } else {
                    result += defaultEndPunctuation
                }
                }
            }
        }
        
        // Capitalize first letter for western languages
        let isAsianLanguage = languageCode?.hasPrefix("zh") ?? false || 
                              languageCode?.hasPrefix("ja") ?? false || 
                              languageCode?.hasPrefix("ko") ?? false
        if languageCode == nil || !isAsianLanguage {
            if let firstChar = result.first, firstChar.isLowercase {
                result = result.prefix(1).uppercased() + result.dropFirst()
            }
            
            // Capitalize after sentence endings
            let sentences = result.replacingOccurrences(of: ". ", with: ".\n")
                .replacingOccurrences(of: "! ", with: "!\n")
                .replacingOccurrences(of: "? ", with: "?\n")
                .split(separator: "\n")
            
            result = sentences.map { sentence in
                let trimmed = sentence.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && trimmed.first?.isLowercase == true {
                    return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
                }
                return String(trimmed)
            }.joined(separator: " ")
        }
        
        return result
    }
    
    private func findTrimPoints(in buffer: AVAudioPCMBuffer) -> (start: AVAudioFramePosition, end: AVAudioFramePosition) {
        guard let channelData = buffer.floatChannelData else {
            return (0, AVAudioFramePosition(buffer.frameLength))
        }
        
        let frameLength = Int(buffer.frameLength)
        let threshold = Constants.getThreshold()
        #if DEBUG
        print("AudioProcessing: Using threshold: \(threshold) for noise filtering")
        #endif
        
        // Analyze first channel for simplicity
        let samples = channelData[0]
        
        // Find start point (first non-silence)
        var startFrame = 0
        for i in 0..<frameLength {
            if abs(samples[i]) > threshold {
                startFrame = max(0, i - Int(buffer.format.sampleRate * 0.1)) // Keep 0.1s before speech
                break
            }
        }
        
        // Find end point (last non-silence)
        var endFrame = frameLength
        for i in stride(from: frameLength - 1, through: 0, by: -1) {
            if abs(samples[i]) > threshold {
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
                AVSampleRateKey: 48000,  // Match recording sample rate
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue  // Maximum quality
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
                #if DEBUG
                print("AudioProcessing: Temp file size: \(tempFileSize) bytes")
                #endif
                
                // Replace original with trimmed version
                try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: tempURL, to: url)
                
                // Verify final file
                let finalFileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                #if DEBUG
                print("AudioProcessing: Final file size: \(finalFileSize) bytes")
                #endif
                
                return finalFileSize > 0
            } else {
                #if DEBUG
                print("AudioProcessing: Temp file was not created")
                #endif
                return false
            }
            
        } catch {
            #if DEBUG
            print("Failed to save trimmed audio: \(error)")
            #endif
            // Clean up temp file if it exists
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return false
    }
}
