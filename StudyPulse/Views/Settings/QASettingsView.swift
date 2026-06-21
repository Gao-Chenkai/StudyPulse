
 //
 //  QASettingsView.swift
 //  StudyPulse
 //

 import SwiftUI

 // MARK: - QA Item

 struct QAItem: Identifiable {
     let id = UUID()
     let question: String
     let answer: String
     let icon: String
 }

 // MARK: - Predefined FAQ

 extension QAItem {
     static let allFAQs: [QAItem] = [
         QAItem(
             question: "How does StudyPulse track my grades?".localized(),
             answer: "StudyPulse stores all grade data locally on your device as JSON files. You can add scores, rankings, importance levels, and even attach a photo of your graded paper. Grades are organized by subject and can be viewed in trend charts over time.".localized(),
             icon: "chart.bar.fill"
         ),
         QAItem(
             question: "What is HRV and why does it matter for studying?".localized(),
             answer: "Heart Rate Variability (HRV) measures the variation in time between heartbeats, reflecting your nervous system's recovery state. A higher HRV generally means better recovery and readiness for focused study. StudyPulse uses a 14-day HRV baseline from Apple Watch to classify your readiness as excellent, normal, or low, and provides personalized study suggestions.".localized(),
             icon: "heart.text.square.fill"
         ),
         QAItem(
             question: "How do I export my data?".localized(),
             answer: "Go to Settings > Data Management and tap Export. StudyPulse supports CSV export for grades, mistakes, exams, and comprehensive exams. The exported file can be shared via AirDrop, email, or any other sharing extension on your device.".localized(),
             icon: "square.and.arrow.up.fill"
         ),
         QAItem(
             question: "Where is my data stored?".localized(),
             answer: "All your data is stored locally on your device in the app's Documents folder. Grade photos and avatar images are saved as separate files. StudyPulse does not upload any of your data to external servers. If HealthKit is enabled, HRV and other health signals are read directly from Apple Health and remain on your device.".localized(),
             icon: "internaldrive.fill"
         ),
         QAItem(
             question: "Does StudyPulse sync across devices?".localized(),
             answer: "Currently StudyPulse stores data locally on each device and does not support iCloud sync. Data backup and transfer between devices must be done manually via CSV export-import or by copying the Documents folder. Cross-device sync is a planned feature for a future update.".localized(),
             icon: "icloud.slash.fill"
         ),
         QAItem(
             question: "How do I add a mistake note with photos?".localized(),
             answer: "Tap the Mistakes tab, then tap the + button to create a new mistake note. Each mistake has four editable sections: Question, Reason, Wrong Solution, and Correct Solution. In each section, you can add a photo (camera or photo library) and OCR will automatically extract text from the image. You can also write or edit the text manually and format it with Markdown.".localized(),
             icon: "camera.fill"
         ),
         QAItem(
             question: "What education systems does StudyPulse support?".localized(),
             answer: "StudyPulse supports 15+ education systems including: Mainland China (National, Zhejiang, Shanghai), Taiwan, Hong Kong, Singapore, UK (IGCSE, A-Level), IB DP, US (AP, SAT, ACT), GRE/GMAT, and TOEFL/IELTS. You can select your education system in Settings > Profile, and subject full scores will be configured automatically.".localized(),
             icon: "globe"
         ),
         QAItem(
             question: "Can I customize my home dashboard?".localized(),
             answer: "Yes! Go to Settings > Appearance & Layout > Home Layout to reorder and toggle dashboard cards. You can enable or disable HRV status, quick actions, trend chart, upcoming exams, recent grades, daily quote, and more.".localized(),
             icon: "rectangle.3.group.fill"
         )
     ]
 }

 // MARK: - QA Settings View

 struct QASettingsView: View {
     var body: some View {
         List {
             Section {
                 // Header
                 VStack(spacing: 12) {
                     ZStack {
                         RoundedRectangle(cornerRadius: 22, style: .continuous)
                             .fill(Color.blue.opacity(0.18))
                         Image(systemName: "questionmark.circle.fill")
                             .font(.system(size: 56, weight: .regular))
                             .foregroundColor(.blue)
                     }
                     .frame(width: 110, height: 110)
 
                     Text("Frequently Asked Questions".localized())
                         .font(.system(size: 22, weight: .semibold))
                         .foregroundColor(.primary)
 
                     Text("Answers to common questions about using StudyPulse.".localized())
                         .font(.system(size: 14))
                         .foregroundColor(.secondary)
                         .multilineTextAlignment(.center)
                         .fixedSize(horizontal: false, vertical: true)
                 }
                 .frame(maxWidth: .infinity)
                 .padding(.vertical, 24)
                 .padding(.horizontal, 16)
                 .background(
                     RoundedRectangle(cornerRadius: 20, style: .continuous)
                         .fill(Color(.systemBackground))
                 )
                 .listRowInsets(EdgeInsets())
                 .listRowBackground(Color.clear)
             }
 
                 ForEach(QAItem.allFAQs) { item in
                     QARow(item: item)
                         .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                 }
         }
         .listStyle(.insetGrouped)
         .background(Color(.systemGroupedBackground))
         .navigationTitle("FAQ".localized())
         .navigationBarTitleDisplayMode(.inline)
     }
 }

 // MARK: - Expandable QA Row

 struct QARow: View {
     let item: QAItem
     @State private var isExpanded = false

     var body: some View {
         DisclosureGroup(isExpanded: $isExpanded) {
             Text(item.answer)
                 .font(.system(size: 14))
                 .foregroundColor(.secondary)
                 .fixedSize(horizontal: false, vertical: true)
                 .padding(.top, 8)
                 .padding(.leading, 4)
         } label: {
             HStack(spacing: 12) {
                 ZStack {
                     RoundedRectangle(cornerRadius: 8, style: .continuous)
                         .fill(Color.blue.opacity(0.12))
                     Image(systemName: item.icon)
                         .font(.system(size: 16, weight: .semibold))
                         .foregroundColor(.blue)
                 }
                 .frame(width: 30, height: 30)

                 Text(item.question)
                     .font(.system(size: 15, weight: .medium))
                     .foregroundColor(.primary)
             }
         }
         .padding(.vertical, 6)
     }
 }
