import AVFoundation
import Accelerate
import Speech

/// Service for processing audio files (trimming silence, normalizing, etc.)
final class AudioProcessingService {
    
    // MARK: - Properties
    
    private let fileManager: AudioFileManager
    
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
    func transcribeRecording(for scriptId: UUID, completion: @escaping (String?) -> Void) {
        // Check if speech recognition is available
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            // Request authorization if not determined
            if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                SFSpeechRecognizer.requestAuthorization { status in
                    if status == .authorized {
                        self.transcribeRecording(for: scriptId, completion: completion)
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
        
        let audioURL = fileManager.audioURL(for: scriptId)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Transcription: Audio file doesn't exist")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Create recognizer for user's locale
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) else {
            print("Speech recognizer not available for current locale")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        // Create recognition request
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        
        // Configure for self-talk/dictation
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        // Use on-device recognition if available (iOS 13+)
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        
        // Perform recognition
        recognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Transcription error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            if let result = result, result.isFinal {
                let transcription = result.bestTranscription.formattedString
                print("Transcription successful: \(transcription.prefix(50))...")
                DispatchQueue.main.async {
                    completion(transcription)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func findTrimPoints(in buffer: AVAudioPCMBuffer) -> (start: AVAudioFramePosition, end: AVAudioFramePosition) {
        guard let channelData = buffer.floatChannelData else {
            return (0, AVAudioFramePosition(buffer.frameLength))
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
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
            // Create output file
            let outputFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            
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
                
                // Replace original with trimmed version
                try? FileManager.default.removeItem(at: url)
                try FileManager.default.moveItem(at: tempURL, to: url)
                
                return true
            }
            
        } catch {
            print("Failed to save trimmed audio: \(error)")
            // Clean up temp file if it exists
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        return false
    }
}