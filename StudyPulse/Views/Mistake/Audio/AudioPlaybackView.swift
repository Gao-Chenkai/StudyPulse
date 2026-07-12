//
//  AudioPlaybackView.swift
//  StudyPulse
//
//  Created for Voice Memos feature.
//

import SwiftUI

struct AudioPlaybackView: View {
    let audioFileName: String
    let onDelete: (() -> Void)?
    
    @StateObject private var manager = VoiceMemoManager()
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if manager.isPlaying {
                    manager.pauseAudio()
                } else {
                    manager.playAudio(filename: audioFileName)
                }
            } label: {
                Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
            }
            .tint(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: manager.duration > 0 ? manager.currentTime / manager.duration : 0)
                    .progressViewStyle(.linear)
                
                HStack {
                    Text(timeString(from: manager.currentTime))
                    Spacer()
                    Text(timeString(from: manager.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundColor(.secondary)
            }
            
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    manager.stopAudio()
                    AudioStorage.delete(filename: audioFileName)
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            manager.loadAudio(filename: audioFileName)
        }
        .onDisappear {
            manager.stopAudio()
        }
    }
    
    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
