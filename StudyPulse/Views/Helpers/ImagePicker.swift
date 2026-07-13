//
//  ImagePicker.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//
//  UIImagePickerController 的 SwiftUI 包装:支持相册 / 相机两种来源。
//  SwiftUI wrapper around `UIImagePickerController`; supports both
//  photo library and camera as the source type.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// `UIImagePickerController` 的 SwiftUI 包装。
/// SwiftUI wrapper around `UIImagePickerController`.
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    /// 来源(相册 / 相机)。相机在不可用时自动降级为相册。
    /// Source (library / camera). Falls back to library when the camera is unavailable.
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    /// 选图后的可选回调(binding + closure 同时给出,调用方可二选一)
    /// Optional callback after picking (binding + closure both exposed; caller picks one).
    var onImagePicked: ((UIImage?) -> Void)? = nil
    @Binding var image: UIImage?
    
    init(sourceType: UIImagePickerController.SourceType = .photoLibrary,
         image: Binding<UIImage?>,
         onImagePicked: ((UIImage?) -> Void)? = nil) {
        self.sourceType = sourceType
        self._image = image
        self.onImagePicked = onImagePicked
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImagePicked?(uiImage)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
