//
//  HRVOnboardingView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/19.
//
//  Education screen: explains HRV, privacy, and requests consent
//
import SwiftUI
import HealthKit

struct HRVOnboardingView: View {
    @EnvironmentObject var hrvManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var isAuthorizing = false
    @State private var authorizationError: String? = nil

    private let totalPages = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i <= currentPage ? Color.blue : Color(.systemGray4))
                            .frame(width: i == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 32)

                TabView(selection: $currentPage) {
                    pageWhatIsHRV.tag(0)
                    pagePrivacyFirst.tag(1)
                    pageConsent.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back".localized()) {
                            withAnimation { currentPage -= 1 }
                        }
                    }
                    Spacer()
                    if currentPage < totalPages - 1 {
                        Button("Next".localized()) {
                            withAnimation { currentPage += 1 }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            enableHRV()
                        } label: {
                            if isAuthorizing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Enable HRV".localized())
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isAuthorizing)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip".localized()) {
                        hrvManager.hrvOnboardingCompleted = true
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .alert("HealthKit Access".localized(), isPresented: Binding(
                get: { authorizationError != nil },
                set: { if !$0 { authorizationError = nil } }
            )) {
                Button("Open Settings".localized()) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel".localized(), role: .cancel) {}
            } message: {
                Text(authorizationError ?? "")
            }
        }
    }

    // MARK: - Page 1: What is HRV
    private var pageWhatIsHRV: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red.gradient)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("What is HRV?".localized())
                    .font(.title2.bold())

                Text("Heart Rate Variability (HRV) measures the tiny variations in time between each heartbeat. It's a scientifically validated indicator of your autonomic nervous system — essentially, how well your body is recovering from stress, exercise, and daily life.".localized())
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    bulletRow("High HRV → well-rested, ready to learn".localized(), color: .green)
                    bulletRow("Low HRV → stressed, fatigued, needs recovery".localized(), color: .orange)
                }

                calloutBox(
                    icon: "lightbulb.fill",
                    color: .yellow,
                    text: "Your HRV is personal — StudyPulse builds your own baseline over 7-14 days, so recommendations are tailored to you, not a population average.".localized()
                )
            }
            .padding(24)
        }
    }

    // MARK: - Page 2: Privacy
    private var pagePrivacyFirst: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "hand.raised.slash.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.gradient)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Your Data Stays on Your Device".localized())
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 16) {
                    privacyRow("lock.shield.fill", "HRV data is read directly from Apple Health".localized(), "We never see or store it ourselves".localized())
                    privacyRow("iphone.gen3", "All processing happens on your device".localized(), "No data is sent to any server".localized())
                    privacyRow("xmark.shield.fill", "You can disable HRV anytime in Settings".localized(), "Access is revoked instantly".localized())
                }

                calloutBox(
                    icon: "checkmark.shield.fill",
                    color: .green,
                    text: "StudyPulse only reads HRV from HealthKit with your explicit permission. We do not write any data.".localized()
                )
            }
            .padding(24)
        }
    }

    // MARK: - Page 3: Summary & Consent
    private var pageConsent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple.gradient)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Text("Ready to Get Started?".localized())
                    .font(.title2.bold())

                Text("When you enable HRV monitoring, StudyPulse will:".localized())
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    bulletRow("Compare today's HRV to your personal 14-day baseline".localized(), color: .purple)
                    bulletRow("Show a readiness card on your Dashboard".localized(), color: .purple)
                    bulletRow("Add personalized study suggestions based on your recovery state".localized(), color: .purple)
                }

                calloutBox(
                    icon: "applewatch",
                    color: .gray,
                    text: "You need an Apple Watch that tracks HRV. Data appears in Health automatically after wearing it to sleep for a few nights.".localized()
                )
            }
            .padding(24)
        }
    }

    // MARK: - Helpers
    private func bulletRow(_ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
        }
    }

    private func privacyRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func calloutBox(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(text)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Enable action
    private func enableHRV() {
        isAuthorizing = true
        authorizationError = nil
        Task {
            let granted = await hrvManager.requestAuthorization()
            isAuthorizing = false
            if granted {
                hrvManager.hrvOnboardingCompleted = true
                await hrvManager.refreshReadiness()
                dismiss()
            } else {
                authorizationError = "HealthKit access was denied. You can enable it later in the iOS Settings app under Privacy → Health → StudyPulse.".localized()
            }
        }
    }
}

#Preview {
    HRVOnboardingView()
        .environmentObject(HealthKitManager.shared)
}
