//
//  AvatarView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/7.
//

import SwiftUI

// MARK: - 头像显示组件
struct AvatarView: View {
    let username: String
    let avatarData: Data?
    var size: CGFloat = 80
    var showBorder: Bool = true
    
    /// 根据用户名生成稳定的颜色
    private var backgroundColor: Color {
        let colors: [Color] = [
            .blue, .purple, .pink, .red, .orange,
            .yellow, .green, .mint, .teal, .cyan, .indigo
        ]
        let hash = abs(username.hashValue)
        return colors[hash % colors.count]
    }
    
    /// 提取用户名的首字符（支持中文和英文）
    private var initial: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstChar = trimmed.first {
            return String(firstChar).uppercased()
        }
        return "?"
    }
    
    var body: some View {
        Group {
            if let data = avatarData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            backgroundColor.opacity(0.8),
                            backgroundColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Text(initial)
                        .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Group {
                if showBorder {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 头像选择器 Sheet
struct AvatarPickerSheet: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var avatarData: Data?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 头像预览
                AvatarView(
                    username: dataManager.profile.username,
                    avatarData: avatarData,
                    size: 140
                )
                .padding(.top, 32)
                
                Text("Tap below to change your avatar".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Button(action: {
                        imagePickerSourceType = .photoLibrary
                        showingImagePicker = true
                    }) {
                        Label("Choose from Library".localized(), systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button(action: {
                            imagePickerSourceType = .camera
                            showingImagePicker = true
                        }) {
                            Label("Take Photo".localized(), systemImage: "camera")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }

                    if dataManager.profile.avatarFileName != nil {
                        Button(action: removeAvatar) {
                            Label("Remove Avatar".localized(), systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .adaptiveMaxWidth(480)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Avatar".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAvatar()
                    }
                    .bold()
                }
            }
            .onAppear {
                avatarData = dataManager.loadAvatar()
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: imagePickerSourceType, image: .constant(nil)) { image in
                    if let image = image,
                       let resized = resizeImage(image, targetSize: CGSize(width: 400, height: 400)),
                       let data = resized.jpegData(compressionQuality: 0.8) {
                        avatarData = data
                    }
                }
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    private func saveAvatar() {
        if let data = avatarData {
            if let filename = dataManager.saveAvatar(data) {
                dataManager.profile.avatarFileName = filename
                dataManager.saveProfile()
            }
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func removeAvatar() {
        if let filename = dataManager.profile.avatarFileName {
            dataManager.deleteAvatar(filename: filename)
            dataManager.profile.avatarFileName = nil
            dataManager.saveProfile()
            avatarData = nil
        }
    }
}

#Preview {
    AvatarView(
        username: "Student",
        avatarData: nil,
        size: 100
    )
}
