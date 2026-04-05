import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var currentPlayingFilename: String?
    
    private var timer: Timer?
    
    override init() {
        super.init()
    }
    
    func requestPermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                print("Microphone permission: \(allowed)")
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                print("Microphone permission: \(allowed)")
            }
        }
    }
    
    func startRecording(filename: String) -> URL? {
        // Stop any playback before recording
        if isPlaying {
            stopPlaying()
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let url = getDocumentsDirectory().appendingPathComponent(filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            isRecording = true
            startTimer()
            print("Recording started at \(url.path)")
            return url
        } catch {
            print("Recording failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()
    }
    
    func startPlaying(filename: String) {
        // Stop previous if playing
        if isPlaying {
            stopPlaying()
        }
        // Stop recording if active
        if isRecording {
            stopRecording()
        }
        
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        // Check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("Audio file not found: \(url.path)")
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Deactivate first to reset state if needed
            try? audioSession.setActive(false)
            
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            currentPlayingFilename = filename
            print("Playing audio: \(url.path)")
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
        currentPlayingFilename = nil
    }
    
    func deleteRecording(filename: String) {
        if currentPlayingFilename == filename {
            stopPlaying()
        }
        
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            try FileManager.default.removeItem(at: url)
            print("Deleted recording: \(filename)")
        } catch {
            print("Could not delete recording: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }
    
    // MARK: - Delegates
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentPlayingFilename = nil
    }
}

