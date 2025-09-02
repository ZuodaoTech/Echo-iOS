import AVFoundation
import Accelerate

/// Service for voice enhancement and noise reduction
final class VoiceEnhancementService {
    
    // MARK: - Singleton
    
    static let shared = VoiceEnhancementService()
    
    private init() {}
    
    // MARK: - Configuration Properties
    
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "voiceEnhancementEnabled")
    }
    
    private var normalizationLevel: Float {
        Float(UserDefaults.standard.double(forKey: "normalizationLevel").isZero ? 
              0.9 : UserDefaults.standard.double(forKey: "normalizationLevel"))
    }
    
    private var compressionThreshold: Float {
        Float(UserDefaults.standard.double(forKey: "compressionThreshold").isZero ? 
              0.5 : UserDefaults.standard.double(forKey: "compressionThreshold"))
    }
    
    private var compressionRatio: Float {
        Float(UserDefaults.standard.double(forKey: "compressionRatio").isZero ? 
              0.3 : UserDefaults.standard.double(forKey: "compressionRatio"))
    }
    
    private var highPassCutoff: Float {
        Float(UserDefaults.standard.double(forKey: "highPassCutoff").isZero ? 
              0.95 : UserDefaults.standard.double(forKey: "highPassCutoff"))
    }
    
    private var noiseGateThreshold: Float {
        Float(UserDefaults.standard.double(forKey: "noiseGateThreshold").isZero ? 
              0.02 : UserDefaults.standard.double(forKey: "noiseGateThreshold"))
    }
    
    private var noiseReductionStrength: Float {
        Float(UserDefaults.standard.double(forKey: "noiseReductionStrength").isZero ? 
              0.8 : UserDefaults.standard.double(forKey: "noiseReductionStrength"))
    }
    
    // MARK: - Public Methods
    
    /// Process audio file with voice enhancement
    func processAudioFile(at audioURL: URL, completion: @escaping (Bool) -> Void) {
        guard isEnabled else {
            print("VoiceEnhancement: Disabled, skipping processing")
            completion(true)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            do {
                // Load audio file
                let audioFile = try AVAudioFile(forReading: audioURL)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                
                // Create buffer for entire audio
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                    print("VoiceEnhancement: Failed to create buffer")
                    completion(false)
                    return
                }
                
                try audioFile.read(into: buffer)
                buffer.frameLength = frameCount
                
                // Apply enhancement to each channel
                if let floatChannelData = buffer.floatChannelData {
                    for channel in 0..<Int(format.channelCount) {
                        let samples = floatChannelData[channel]
                        let sampleCount = Int(frameCount)
                        
                        print("VoiceEnhancement: Processing channel \(channel) with \(sampleCount) samples")
                        print("VoiceEnhancement: Settings - Norm=\(self.normalizationLevel), Compress=\(self.compressionThreshold), HPF=\(self.highPassCutoff), NoiseGate=\(self.noiseGateThreshold)")
                        
                        // Enhancement pipeline:
                        // 1. Adaptive noise reduction (NEW)
                        self.applyAdaptiveNoiseReduction(samples: samples, frameCount: sampleCount)
                        
                        // 2. High-pass filter to remove rumble
                        self.applyHighPassFilter(samples: samples, frameCount: sampleCount, cutoff: self.highPassCutoff)
                        
                        // 3. Dynamic range compression
                        self.applyCompression(samples: samples, frameCount: sampleCount,
                                            threshold: self.compressionThreshold,
                                            ratio: self.compressionRatio)
                        
                        // 4. Normalize volume
                        self.normalizeAudio(samples: samples, frameCount: sampleCount,
                                          targetLevel: self.normalizationLevel)
                    }
                }
                
                // Save enhanced audio
                let tempURL = audioURL.appendingPathExtension("enhanced")
                try? FileManager.default.removeItem(at: tempURL)
                
                let outputFile = try AVAudioFile(forWriting: tempURL, 
                                                settings: audioFile.fileFormat.settings)
                try outputFile.write(from: buffer)
                
                // Replace original with enhanced version
                try FileManager.default.removeItem(at: audioURL)
                try FileManager.default.moveItem(at: tempURL, to: audioURL)
                
                print("VoiceEnhancement: Successfully applied enhancement")
                completion(true)
                
            } catch {
                print("VoiceEnhancement: Failed - \(error)")
                completion(false)
            }
        }
    }
    
    // MARK: - Enhancement Algorithms
    
    /// Apply adaptive noise reduction based on detected noise floor
    private func applyAdaptiveNoiseReduction(samples: UnsafeMutablePointer<Float>, 
                                            frameCount: Int) {
        // Step 1: Analyze audio to find noise floor
        let noiseFloor = detectNoiseFloor(samples: samples, frameCount: frameCount)
        print("VoiceEnhancement: Detected noise floor at \(noiseFloor)")
        
        // Step 2: Apply smooth gating based on noise floor
        let gateThreshold = noiseFloor * 1.5  // 50% above noise floor
        let reductionFactor = 1.0 - noiseReductionStrength  // How much to reduce (0.2 = reduce to 20%)
        
        // Process in small windows for smoother gating
        let windowSize = 128
        var windowIndex = 0
        
        while windowIndex < frameCount {
            let windowEnd = min(windowIndex + windowSize, frameCount)
            let windowLength = windowEnd - windowIndex
            
            // Calculate window RMS
            var windowRMS: Float = 0
            vDSP_rmsqv(&samples[windowIndex], 1, &windowRMS, vDSP_Length(windowLength))
            
            // Apply smooth reduction if below threshold
            if windowRMS < gateThreshold {
                // Calculate smooth reduction factor based on how far below threshold
                let ratio = windowRMS / gateThreshold
                let smoothFactor = reductionFactor + (ratio * (1.0 - reductionFactor))
                
                // Apply reduction to window
                var factor = Float(smoothFactor)
                vDSP_vsmul(&samples[windowIndex], 1, &factor, 
                          &samples[windowIndex], 1, vDSP_Length(windowLength))
            }
            
            windowIndex += windowSize
        }
    }
    
    /// Detect noise floor by analyzing quietest parts of audio
    private func detectNoiseFloor(samples: UnsafeMutablePointer<Float>, 
                                 frameCount: Int) -> Float {
        // Analyze audio in 10ms windows
        let sampleRate: Float = 48000  // Assuming 48kHz
        let windowSize = Int(sampleRate * 0.01)  // 10ms windows
        let windowCount = frameCount / windowSize
        
        guard windowCount > 0 else {
            return noiseGateThreshold  // Fallback to manual threshold
        }
        
        // Calculate RMS for each window
        var windowRMSValues = [Float](repeating: 0, count: windowCount)
        
        for i in 0..<windowCount {
            let startIndex = i * windowSize
            var rms: Float = 0
            vDSP_rmsqv(&samples[startIndex], 1, &rms, vDSP_Length(windowSize))
            windowRMSValues[i] = rms
        }
        
        // Sort and find the 10th percentile (quietest 10%)
        windowRMSValues.sort()
        let percentile10Index = max(0, windowCount / 10)
        let estimatedNoiseFloor = windowRMSValues[percentile10Index]
        
        // Use manual threshold as minimum
        return max(estimatedNoiseFloor, noiseGateThreshold)
    }
    
    /// Apply high-pass filter to remove low-frequency rumble
    private func applyHighPassFilter(samples: UnsafeMutablePointer<Float>, 
                                    frameCount: Int, 
                                    cutoff: Float) {
        // Simple first-order high-pass filter
        // y[n] = α * (y[n-1] + x[n] - x[n-1])
        // where α = cutoff coefficient (0.90-0.98)
        
        var previousInput: Float = 0
        var previousOutput: Float = 0
        
        for i in 0..<frameCount {
            let currentInput = samples[i]
            let currentOutput = cutoff * (previousOutput + currentInput - previousInput)
            samples[i] = currentOutput
            
            previousInput = currentInput
            previousOutput = currentOutput
        }
    }
    
    /// Apply dynamic range compression
    private func applyCompression(samples: UnsafeMutablePointer<Float>, 
                                 frameCount: Int,
                                 threshold: Float,
                                 ratio: Float) {
        // ratio is actually the inverse (0.3 means 3.3:1 compression)
        
        for i in 0..<frameCount {
            let sample = samples[i]
            let absSample = abs(sample)
            
            if absSample > threshold {
                // Apply compression to parts above threshold
                let excess = absSample - threshold
                let compressedExcess = excess * ratio
                let newMagnitude = threshold + compressedExcess
                
                // Preserve sign
                samples[i] = sample > 0 ? newMagnitude : -newMagnitude
            }
        }
    }
    
    /// Normalize audio to target level
    private func normalizeAudio(samples: UnsafeMutablePointer<Float>, 
                               frameCount: Int,
                               targetLevel: Float) {
        // Find peak value
        var maxValue: Float = 0
        vDSP_maxmgv(samples, 1, &maxValue, vDSP_Length(frameCount))
        
        // Only normalize if not already at target level
        if maxValue > 0 && maxValue < targetLevel {
            var scale = targetLevel / maxValue
            vDSP_vsmul(samples, 1, &scale, samples, 1, vDSP_Length(frameCount))
        }
    }
}