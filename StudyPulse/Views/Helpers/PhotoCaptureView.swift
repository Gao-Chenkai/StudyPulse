//
//  PhotoCaptureView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  纯相机版图片选择器(sourceType 永远 .camera)。
//  用于错题图片拍摄等强相机场景。
//
//  Camera-only variant of `ImagePicker` (source type is always `.camera`).
//  Used for mistake-note photo capture, where the camera is required.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

/// 纯相机版图片选择器。
/// Camera-only image picker.
struct PhotoCaptureView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var capturedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoCaptureView
        
        init(_ parent: PhotoCaptureView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.capturedImage = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
