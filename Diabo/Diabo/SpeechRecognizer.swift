import Foundation
import Speech
import AVFoundation

/// A robust speech recognizer that converts voice to text without crashing
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permissionGranted = false
    @Published var errorMessage: String?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    private var hasInstalledTap = false
    
    init() {
        // Don't request permission on init - do it lazily when user taps mic
    }
    
    /// Request speech recognition permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.permissionGranted = true
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    self.permissionGranted = false
                    self.errorMessage = "Speech recognition permission denied"
                    print("Speech recognition permission denied")
                    completion(false)
                @unknown default:
                    self.permissionGranted = false
                    completion(false)
                }
            }
        }
    }
    
    /// Start recording and transcribing speech
    func startRecording() {
        // Clear any previous error
        errorMessage = nil
        
        // Request permission first if not already granted
        if !permissionGranted {
            requestPermission { [weak self] granted in
                if granted {
                    self?.beginRecordingSession()
                } else {
                    self?.errorMessage = "Please enable speech recognition in Settings"
                }
            }
        } else {
            beginRecordingSession()
        }
    }
    
    private func beginRecordingSession() {
        // Stop speaking if recording starts
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Cancel any existing task
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Stop audio engine if running
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove existing tap if present
        let inputNode = audioEngine.inputNode
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to setup audio"
            }
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to create recognition request"
            }
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.cleanupRecording()
            }
        }
        
        // Install tap on input node
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Check if format is valid (non-zero sample rate)
        guard recordingFormat.sampleRate > 0 else {
            print("Invalid audio format - sample rate is 0")
            DispatchQueue.main.async {
                self.errorMessage = "Microphone not available"
            }
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasInstalledTap = true
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.transcript = ""
                self.isRecording = true
            }
        } catch {
            print("audioEngine couldn't start: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start recording"
            }
            cleanupRecording()
        }
    }
    
    /// Stop recording
    func stopRecording() {
        cleanupRecording()
    }
    
    private func cleanupRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        
        let inputNode = audioEngine.inputNode
        if hasInstalledTap {
            inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    /// Speak text using text-to-speech
    func speak(_ text: String) {
        // Don't speak while recording
        guard !isRecording else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 0.9
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playback, mode: .default)
        try? audioSession.setActive(true)
        
        synthesizer.speak(utterance)
    }
}
