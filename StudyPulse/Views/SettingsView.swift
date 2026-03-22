//
//  SettingsView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/3/21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingProfileEdit = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("User Information")) {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(dataManager.profile.username)
                    }
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        Text("\(dataManager.profile.age)")
                    }
                    
                    HStack {
                        Text("Education Level")
                        Spacer()
                        Text(dataManager.profile.educationLevel)
                    }
                }
                
                Section(header: Text("Academic Info")) {
                    HStack {
                        Text("Education System")
                        Spacer()
                        Text(dataManager.profile.educationSystem)
                    }
                    
                    HStack {
                        Text("Region")
                        Spacer()
                        Text(dataManager.profile.region)
                    }
                    
                    NavigationLink("Edit Subjects") {
                        EditSubjectsView()
                    }
                }
                
                Section(header: Text("Appearance")) {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text(dataManager.profile.theme)
                    }
                }
                
                Section {
                    Button("Edit Profile") {
                        showingProfileEdit = true
                    }
                    
                    Button("About StudyPulse") {
                        showingAbout = true
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingProfileEdit) {
                ProfileEditView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
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
                    Toggle(subject.name, isOn: $subject.enabled)
                }
            }
            .navigationTitle("Edit Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                dataManager.saveProfile()
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
                    TextField("Username", text: $username)
                    
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $age, formatter: NumberFormatter())
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Academic Info")) {
                    TextField("Education Level", text: $educationLevel)
                    TextField("Education System", text: $educationSystem)
                    TextField("Region", text: $region)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $theme) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                    .pickerStyle(MenuPickerStyle())
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
                theme = dataManager.profile.theme
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
                        dataManager.profile.theme = theme
                        
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
                    
                    Text("Version beta0.1")
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
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
