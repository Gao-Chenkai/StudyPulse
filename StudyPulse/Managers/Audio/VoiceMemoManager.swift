//
//  VoiceMemoManager.swift
//  StudyPulse
//
//  Created for Voice Memos feature.
//

import Foundation
import Combine
import AVFoundation
import os

/// Manages recording and playback of voice memos.
@MainActor
final class VoiceMemoManager: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    private let logger = Logger(subsystem: "com.chenkai.gao.studypulse", category: "VoiceMemoManager")
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var isPaused = false
    
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    
    @Published var hasPermission = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    var currentFileName: String?
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            self.hasPermission = true
        case .denied:
            self.hasPermission = false
        case .undetermined:
            session.requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    self?.hasPermission = allowed
                }
            }
        @unknown default:
            self.hasPermission = false
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard hasPermission else {
            logger.error("No permission to record audio")
            return
        }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            let filename = AudioStorage.generateFileName()
            let url = AudioStorage.url(for: filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            self.currentFileName = filename
            self.isRecording = true
            self.isPaused = false
            self.currentTime = 0.0
            
            startTimer()
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func pauseRecording() {
        guard isRecording else { return }
        audioRecorder?.pause()
        isPaused = true
        stopTimer()
    }
    
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        audioRecorder?.record()
        isPaused = false
        startTimer()
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        isPaused = false
        stopTimer()
        
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false)
    }
    
    func cancelRecording() {
        stopRecording()
        if let filename = currentFileName {
            AudioStorage.delete(filename: filename)
            currentFileName = nil
        }
    }
    
    // MARK: - Playback
    
    func loadAudio(filename: String) {
        let url = AudioStorage.url(for: filename)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            self.duration = audioPlayer?.duration ?? 0.0
            self.currentTime = 0.0
            self.currentFileName = filename
        } catch {
            logger.error("Failed to load audio for playback: \(error.localizedDescription)")
        }
    }
    
    func playAudio(filename: String) {
        if currentFileName != filename || audioPlayer == nil {
            loadAudio(filename: filename)
        }
        
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        self.currentTime = 0.0
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        self.currentTime = time
    }
    
    // MARK: - Delegates
    
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopTimer()
        }
    }
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0.0
            self.stopTimer()
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isRecording {
                    self.currentTime = self.audioRecorder?.currentTime ?? 0.0
                } else if self.isPlaying {
                    self.currentTime = self.audioPlayer?.currentTime ?? 0.0
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
