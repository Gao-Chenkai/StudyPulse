//
//  VoiceMemoRecordingSheet.swift
//  StudyPulse
//
//  Created for Voice Memos feature.
//

import SwiftUI

struct VoiceMemoRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = VoiceMemoManager()
    
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Text(timeString(from: manager.currentTime))
                    .font(.system(size: 64, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .padding(.top, 40)
                
                if !manager.hasPermission {
                    Text("请在设置中允许麦克风权限。".localized())
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                
                HStack(spacing: 40) {
                    if manager.isRecording || manager.isPaused || manager.currentFileName != nil {
                        Button(role: .destructive) {
                            manager.cancelRecording()
                            dismiss()
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                        .tint(.red)
                    }
                    
                    Button {
                        if manager.isRecording {
                            if manager.isPaused {
                                manager.resumeRecording()
                            } else {
                                manager.pauseRecording()
                            }
                        } else if manager.currentFileName == nil {
                            manager.startRecording()
                        }
                    } label: {
                        Image(systemName: manager.isRecording && !manager.isPaused ? "pause.circle.fill" : "record.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                    }
                    .tint(manager.isRecording && !manager.isPaused ? .orange : .red)
                    .disabled(!manager.hasPermission)
                    
                    if manager.isRecording || manager.isPaused || manager.currentFileName != nil {
                        Button {
                            manager.stopRecording()
                            if let filename = manager.currentFileName {
                                onSave(filename)
                            }
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                        .tint(.green)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("录音".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消".localized()) {
                        manager.cancelRecording()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(350)])
    }
    
    private func timeString(from time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}
