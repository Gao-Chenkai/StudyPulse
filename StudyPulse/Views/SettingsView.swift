//
//  SettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI
import UserNotifications 

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingProfileEdit = false
    @State private var showingSubjectsEdit = false
    @State private var showingAbout = false
    @State private var showingCopyright = false
    
    @State private var showingTestAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("User Information")) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        Text("Username")
                            .foregroundColor(.primary)
                            .lineLimit(1) // 👈 关键：限制为一行
                        Spacer()
                        Text(dataManager.profile.username)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                            .frame(width: 30) // 固定宽度，防止图标挤压文字
                        Text("Age")
                            .foregroundColor(.primary)
                            .lineLimit(1) // 关键：限制为一行
                        Spacer()
                        Text("\(dataManager.profile.age)")
                    }
                    
                    HStack {
                        Image(systemName: "graduationcap")
                            .foregroundColor(.green)
                            .frame(width: 30)            // 固定宽度，防止图标挤压文字
                        Text("Education Level")
                            .foregroundColor(.primary)
                            .lineLimit(1) // 关键：限制为一行
                        Spacer()
                        Text(dataManager.profile.educationLevel)
                    }
                }
                
                Section(header: Text("Academic Info")) {
                    HStack {
                        Image(systemName: "building.columns")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        Text("Education System")
                        Spacer()
                        Text(dataManager.profile.educationSystem)
                    }
                    
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Region")
                        Spacer()
                        Text(dataManager.profile.region)
                    }
                    
                }
                
                Section(header: Text("Edit")) {
                    Button("Edit Profile") {
                        showingProfileEdit = true
                    }
                    
                    Button("Edit Subjects") {
                        showingSubjectsEdit = true
                    }
                    
//                    NavigationLink("Edit Subjects") {
//                        EditSubjectsView()
//                    }
                }
                
                Section(header: Text("About")) {
//                    Button("About StudyPulse") {
//                        showingAbout = true
//                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Button("About StudyPulse") {
                            showingAbout = true
                        }.foregroundColor(.black)
                    }
                    
//                    Button("Copyright") {
//                        showingCopyright = true
//                    }.foregroundColor(.black)
                    
                    HStack {
                        Image(systemName: "checkmark.shield")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        Button("Copyright") {
                            showingCopyright = true
                        }.foregroundColor(.black)
                    }
                    
//                    Button("Send Test Notification in 5 Seconds") {
//                        sendTestNotification()
//                        showingTestAlert = true
//                    }
                    
                    HStack {
                        Image(systemName: "message")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        Button("Send Test Notification in 5 Seconds") {
                            sendTestNotification()
                            showingTestAlert = true
                        }.foregroundColor(.black)
                    }

                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingSubjectsEdit) {
                EditSubjectsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingCopyright) {
                CopyrightView()
            }
            .alert("Test Notification Sent", isPresented: $showingTestAlert) {
                Button("OK") { }
            } message: {
                Text("Check your notification center in 5 seconds!")
            }
        }
    }
    
    private func sendTestNotification() {
        print("🚀 开始发送暴力测试通知...")
        
        let center = UNUserNotificationCenter.current()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "🚨 强制测试"
        content.body = "这是第 \(Int.random(in: 1000...9999)) 号测试"
        content.subtitle = "如果看到这行字，说明通知到了"
        content.badge = 1
        content.sound = .defaultCritical
        
        // 设置触发器（5秒后触发）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        // 创建唯一标识符
        let identifier = "FORCE_TEST_\(UUID().uuidString)"
        print("🔑 使用 ID: \(identifier)")
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // 移除所有待处理的通知请求
        center.removeAllPendingNotificationRequests()
        
        // 添加新的通知请求
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("ERROR发送失败: \(error.localizedDescription)")
                    self.showingTestAlert = true
                } else {
                    print("SUCCESS发送成功！查看主屏幕图标角标或等待5秒")
                    self.showingTestAlert = true
                }
            }
        }
    }
}

struct EditSubjectsView: View {
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach($dataManager.subjects) { $subject in
                    Toggle(subject.name.localized(), isOn: $subject.enabled)
                }
            }
            .navigationTitle("Edit Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                dataManager.saveProfile()
                dataManager.saveSubjects()
            }
        }
    }
}

struct ProfileEditView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var username = ""
    @State private var age = 0
    @State private var educationLevel = ""
    @State private var educationSystem = ""
    @State private var region = ""
    @State private var theme = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Info")) {
//                    TextField("Username", text: $username)
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        Text("Username")
                        Spacer()
                        // 直接使用 text: 绑定字符串，不要加 formatter
                        TextField("Username", text: $username)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.pink)
                            .frame(width: 30) // 固定宽度，防止图标挤压文字
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $age, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Academic Info")) {
//                    TextField("Education Level", text: $educationLevel)
                    Picker("Education Level", selection: $educationLevel) {
                        Text("Primary School")
                            .tag("Primary School")
                        Text("Middle School")
                            .tag("Middle School")
                        Text("High School")
                            .tag("High School")
                    }
                    
                    HStack {
                        Text("Education System")
                        TextField("Education System", text: $educationSystem)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Region", selection: $region) {
                        Text("China")
                            .tag("China")
                        Text("US")
                            .tag("US")
                        Text("UK")
                            .tag("UK")
                    }

                }
                                
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                username = dataManager.profile.username
                age = dataManager.profile.age
                educationLevel = dataManager.profile.educationLevel
                educationSystem = dataManager.profile.educationSystem
                region = dataManager.profile.region
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dataManager.profile.username = username
                        dataManager.profile.age = age
                        dataManager.profile.educationLevel = educationLevel
                        dataManager.profile.educationSystem = educationSystem
                        dataManager.profile.region = region
                        
                        dataManager.saveProfile()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("StudyPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version beta 0.0.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("About StudyPulse")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("StudyPulse is a comprehensive learning management application designed to help students track their academic performance, analyze trends, and manage their study materials effectively.")
                        
                        Text("Features:")
                        Text("- Track grades across multiple subjects")
                        Text("- Visualize progress with interactive charts")
                        Text("- Manage mistake collections with detailed analysis")
                        Text("- Personalized learning recommendations")
                        Text("- Support for photo uploads for exam papers and mistakes")
                    }
                    .padding()
                    
                    Link("Click to View the Repository on Github", destination: URL(string: "https://github.com/Gao-Chenkai/StudyPulse")!)
                        .font(.body)
                        .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CopyrightView: View {
    // 1. 状态管理：控制是否显示协议全文弹窗
    @State private var showLicenseSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    // --- 头部图标 ---
                    Image(systemName: "graduationcap.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding(.top, 20)
                    
                    // --- 应用名称 ---
                    Text("StudyPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version beta0.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // --- 开发者信息 ---
                    VStack(spacing: 8) {
                        Text("Developed by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("高陈恺 | Gao Chenkai")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    // --- 版权与协议区域 ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Copyright & License")
                            .font(.headline)
                        
                        // 👇 2. 可点击的协议名称按钮
                        Button(action: {
                            withAnimation {
                                showLicenseSheet.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.orange)
                                Text("CC BY-NC-SA 4.0")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue) // 蓝色表示可点击
                                
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle()) // 去除默认点击效果
                        
                        // --- 协议简述 ---
                        VStack(alignment: .leading, spacing: 6) {
                            Text("This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                                    
                            Text("本作品采用 知识共享 署名-非商业性使用-相同方式共享 4.0 国际许可协议 进行许可。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                                    
                            Divider()
                                .padding(.vertical, 4)
                                                    
                            // 核心限制条件
                            Group {
                                Label("Attribution (署名)", systemImage: "person.circle")
                                Label("Non-Commercial (非商业性使用)", systemImage: "slash.circle")
                                Label("ShareAlike (相同方式共享)", systemImage: "arrow.2.squarepath")
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // --- 底部描述 ---
                    Text("StudyPulse helps students track performance and manage study materials.\nStudyPulse 助力学生追踪学业表现并管理学习资料。")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .font(.callout)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Copyright")
            .navigationBarTitleDisplayMode(.inline)
            
            // 👇 3. 绑定弹窗 (Sheet)
            .sheet(isPresented: $showLicenseSheet) {
                LicenseDetailView()
            }
        }
    }
}

// --- 新增：协议全文详情视图 ---
struct LicenseDetailView: View {
    @Environment(\.dismiss) var dismiss // 用于关闭弹窗
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 标题
                    Text("Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    // 中文部分
                    SectionHeader(title: "许可协议正文 (中文摘要)")
                    Text("""
                    本作品采用 知识共享 署名-非商业性使用-相同方式共享 4.0 国际许可协议 进行许可。
                    
                    您可以自由地：
                    • 共享 — 在任何媒介以任何形式复制、发行本作品
                    • 演绎 — 修改、转换或以本作品为基础进行创作
                    
                    惟须遵守下列条件：
                    • 署名 — 您必须给出适当的署名，提供指向本许可协议的链接，同时标明是否（对原始作品）作了修改。您可以用任何合理的方式来署名，但是不得以任何方式暗示许可人为您或您的使用背书。
                    • 非商业性使用 — 您不得将本作品用于商业目的。
                    • 相同方式共享 — 如果您再混合、转换或者基于本作品进行创作，您必须基于与原先许可协议相同的许可协议分发您的作品。
                    
                    没有附加限制 — 您不得适用法律术语或者技术措施从而限制其他人做许可协议允许的事情。
                    """)
                    .font(.body)
                    .foregroundColor(.primary)
                    
                    Divider()
                    
                    // 英文部分
                    SectionHeader(title: "Legal Code (English Summary)")
                    Text("""
                    You are free to:
                    • Share — copy and redistribute the material in any medium or format
                    • Adapt — remix, transform, and build upon the material
                    
                    Under the following terms:
                    • Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
                    • NonCommercial — You may not use the material for commercial purposes.
                    • ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
                    
                    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.
                    """)
                    .font(.body)
                    .foregroundColor(.primary)
                    
                    // 官方链接
                    Link("Click to View Full Legal Code in Browser", destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/4.0/")!)
                        .font(.body)
                        .padding(.top, 10)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("License Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 辅助视图：章节标题
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.top, 10)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataManager())
}
