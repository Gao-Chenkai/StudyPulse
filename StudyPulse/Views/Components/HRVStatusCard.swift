//
//  HRVStatusCard.swift
//  StudyPulse
//
//  Dashboard card showing recovery readiness as a 4-axis radar / polygon
//  chart (HRV, heart rate, recovery sleep, respiratory rate) and an
//  integrated study suggestion derived from the same signals.
//
import SwiftUI
import Charts

// MARK: - HRV Status Card
struct HRVStatusCard: View {
    @ObservedObject var hrvManager = HealthKitManager.shared
    @EnvironmentObject var dataManager: DataManager
    @State private var animateIn = false

    var body: some View {
        if hrvManager.hrvEnabled && hrvManager.hrvOnboardingCompleted {
            VStack(alignment: .leading, spacing: 14) {
                header

                if hrvManager.hrvDetailLevel != .suggestionOnly {
                    let radar = BodyRadarValues.compute(
                        hrv: hrvManager.readiness,
                        body: hrvManager.bodyStatus,
                        baselines: hrvManager.personalBaselines,
                        age: dataManager.profile.age
                    )
                    BodyRadarChart(values: radar)
                        .frame(height: 220)
                        .padding(.vertical, 4)
                }

                if hrvManager.hrvDetailLevel == .chartAndData {
                    axisValuesRow
                }

                suggestionRow
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.secondarySystemGroupedBackground))
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accent.opacity(0.25), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    animateIn = true
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(accent.gradient)
                .font(.title3)
            Text("Recovery Radar".localized())
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
            readinessBadge
        }
    }

    // MARK: - Axis values row
    /// Numeric readout for each of the four radar dimensions.
    /// Shown only at the highest detail level. The workout slot is
    /// rendered as a 3-ring fitness ring instead of a plain text tile.
    private var axisValuesRow: some View {
        let radar = BodyRadarValues.compute(
            hrv: hrvManager.readiness,
            body: hrvManager.bodyStatus,
            baselines: hrvManager.personalBaselines,
            age: dataManager.profile.age
        )
        return HStack(spacing: 10) {
            axisTile(
                title: "HRV",
                value: radar.hrvValueText,
                color: radar.hrvColor
            )
            axisTile(
                title: "Heart Rate".localized(),
                value: radar.heartRateValueText,
                color: radar.heartRateColor
            )
            axisTile(
                title: "Recovery Sleep".localized(),
                value: radar.sleepValueText,
                color: radar.sleepColor
            )
            workoutTile(
                minutes: hrvManager.bodyStatus.exerciseMinutesToday
            )
            axisTile(
                title: "Respiratory".localized(),
                value: radar.respiratoryValueText,
                color: radar.respiratoryColor
            )
        }
    }

    private func axisTile(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    /// Workout tile — small 3-ring fitness ring in the same visual
    /// language as the iOS Activity rings.
    private func workoutTile(minutes: Double?) -> some View {
        let goal = 30.0
        let progress = min(1.0, (minutes ?? 0) / goal)
        let color = FitnessRingView.colorFor(progress: progress)
        return VStack(spacing: 3) {
            FitnessRingView(progress: progress, lineWidth: 3.5, size: 26)
                .frame(width: 26, height: 26)
            Text(String(format: "%.0f min", minutes ?? 0))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Workout".localized())
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Integrated suggestion row
    /// Re-uses the multi-dimensional algorithm so the suggestion on this
    /// card matches the one in the Study Suggestions card. Both are
    /// calibrated against the user's 30-day personal baseline and
    /// their age-adjusted reference range.
    private var suggestionRow: some View {
        Group {
            if let suggestion = StudyReadinessAlgorithm.recommend(
                hrvEnabled: hrvManager.hrvEnabled,
                hrvOnboardingCompleted: hrvManager.hrvOnboardingCompleted,
                isAuthorized: hrvManager.isAuthorized,
                hrv: hrvManager.readiness,
                bodyStatus: hrvManager.bodyStatus,
                baselines: hrvManager.personalBaselines,
                age: dataManager.profile.age
            ) {
                integratedSuggestionView(suggestion)
            } else if hrvManager.readiness.category == .insufficient {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(hrvManager.readiness.suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !hrvManager.readiness.suggestion.isEmpty {
                Text(hrvManager.readiness.suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func integratedSuggestionView(_ s: StudySuggestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(s.color.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: s.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(s.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(s.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(s.color.opacity(0.08))
        )
    }

    // MARK: - Computed Properties
    private var accent: Color {
        switch hrvManager.readiness.category {
        case .excellent: return .green
        case .normal: return .blue
        case .low: return .orange
        case .insufficient, .noAuthorization, .queryFailed: return .secondary
        }
    }

    private var readinessBadge: some View {
        Text(badgeLabel)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent.opacity(0.15)))
            .foregroundColor(accent)
    }

    private var badgeLabel: String {
        switch hrvManager.readiness.category {
        case .excellent: return "Excellent".localized()
        case .normal: return "Normal".localized()
        case .low: return "Low".localized()
        case .insufficient: return "Collecting".localized()
        case .noAuthorization: return "-"
        case .queryFailed: return "Error".localized()
        }
    }
}

// MARK: - Body Radar Values

/// Normalized values (0-1) for the 5 radar axes, plus the raw value
/// strings and per-axis colors used by the card UI.
struct BodyRadarValues {
    let hrv: Double          // 0-1
    let heartRate: Double    // 0-1
    let sleep: Double        // 0-1
    let exercise: Double     // 0-1  (today's workout, 30 min = 1.0)
    let respiratory: Double  // 0-1

    var all: [Double] { [hrv, heartRate, sleep, exercise, respiratory] }

    // Per-axis text (raw, un-normalized)
    let hrvValueText: String
    let heartRateValueText: String
    let sleepValueText: String
    let exerciseValueText: String
    let respiratoryValueText: String

    // Per-axis colors (bad → good: red → orange → blue → green)
    let hrvColor: Color
    let heartRateColor: Color
    let sleepColor: Color
    let exerciseColor: Color
    let respiratoryColor: Color

    /// Build radar values from the current `HRVReadiness` and
    /// `BodyStatus`. Each axis is normalized to 0-1 using the
    /// personal 30-day baseline (when there are ≥ 7 samples) or
    /// the age-adjusted reference range; missing data is treated as
    /// neutral (0.5) so the polygon doesn't collapse.
    static func compute(
        hrv: HRVReadiness,
        body: BodyStatus,
        baselines: PersonalBaselines = .empty,
        age: Int? = nil
    ) -> BodyRadarValues {
        let ageRef = age.map(AgeReference.compute) ?? .adult

        // HRV uses its own 14/30-day Z-score path (already exposed on
        // HRVReadiness). It does not need a personal baseline lookup
        // here because `readiness` is recomputed with its own.
        let hrvScore: Double = {
            if let z = hrv.zScore { return clamp((z + 2) / 4) }
            return 0.5
        }()
        let hrvText: String = hrv.todayHRV.map {
            String(format: "%.0f ms", $0)
        } ?? "--"

        // The remaining four signals are calibrated against the
        // personal 30-day baseline (preferred) or the age reference.
        // Sleep is calibrated against RESTORATIVE sleep (deep N3 +
        // REM), not total hours in bed — total hours determine the
        // user-facing quality label, but only deep+REM is the
        // recovery-load signal.
        let hrCal      = StudyReadinessAlgorithm.calibrated(
            value: body.restingHeartRate,
            baseline: baselines.restingHeartRate,
            range: ageRef.restingHeartRate)
        let sleepCal   = StudyReadinessAlgorithm.calibrated(
            value: body.restorativeSleepHours,
            baseline: baselines.restorativeSleepHours,
            range: ageRef.restorativeSleepHours)
        let rrCal      = StudyReadinessAlgorithm.calibrated(
            value: body.respiratoryRate,
            baseline: baselines.respiratoryRate,
            range: ageRef.respiratoryRate)
        let exerciseCal = StudyReadinessAlgorithm.calibrated(
            value: body.exerciseMinutesToday,
            baseline: baselines.exerciseMinutes,
            range: ageRef.exerciseMinutes)

        let hrText      = body.restingHeartRate.map {
            String(format: "%.0f bpm", $0)
        } ?? "--"
        // The tile shows restorative sleep (deep+REM) as the primary
        // value, with the total hours in parentheses for context.
        let sleepText: String = {
            guard let r = body.restorativeSleepHours else { return "--" }
            let total = body.lastNightSleepHours
            let totalStr = total.map { String(format: "·%.1fh", $0) } ?? ""
            return String(format: "%.1fh", r) + totalStr
        }()
        let rrText      = body.respiratoryRate.map {
            String(format: "%.0f", $0)
        } ?? "--"
        let exerciseText = body.exerciseMinutesToday.map {
            String(format: "%.0f m", $0)
        } ?? "--"

        return BodyRadarValues(
            hrv: hrvScore,
            heartRate: hrCal.score,
            sleep: sleepCal.score,
            exercise: exerciseCal.score,
            respiratory: rrCal.score,
            hrvValueText: hrvText,
            heartRateValueText: hrText,
            sleepValueText: sleepText,
            exerciseValueText: exerciseText,
            respiratoryValueText: rrText,
            hrvColor: colorFor(score: hrvScore),
            heartRateColor: colorFor(score: hrCal.score),
            sleepColor: colorFor(score: sleepCal.score),
            exerciseColor: colorFor(score: exerciseCal.score),
            respiratoryColor: colorFor(score: rrCal.score)
        )
    }

    private static func clamp(_ x: Double) -> Double {
        max(0, min(1, x))
    }

    private static func colorFor(score: Double) -> Color {
        switch score {
        case ..<0.34: return .red
        case ..<0.5:  return .orange
        case ..<0.75: return .blue
        default:      return .green
        }
    }
}

// MARK: - Body Radar Chart (polygon)

/// 5-axis radar / polygon chart. Pure SwiftUI `Path`s — no Charts
/// framework dependency for the radar itself. Each axis has its own
/// color so the data points and labels are easy to associate.
struct BodyRadarChart: View {
    let values: BodyRadarValues

    private let dimensionCount = 5
    private let axisLabels: [String] = [
        "HRV",
        "Heart Rate".localized(),
        "Recovery Sleep".localized(),
        "Workout".localized(),
        "Respiratory".localized()
    ]
    private let axisColors: [Color] = [.purple, .pink, .indigo, .green, .cyan]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Reserve 22% of the radius for outside labels.
            let maxRadius = size / 2 * 0.78

            ZStack {
                // Concentric grid polygons (25 / 50 / 75 / 100%).
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    polygonPath(center: center,
                                radius: maxRadius * CGFloat(level),
                                count: dimensionCount)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }

                // Axis lines from center to each label.
                ForEach(0..<dimensionCount, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointAt(
                            angle: angleFor(index: i),
                            radius: maxRadius,
                            from: center))
                    }
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }

                // Filled data polygon (gradient).
                dataPolygonPath(center: center, radius: maxRadius)
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.45),
                                 Color.purple.opacity(0.18)],
                        startPoint: .top, endPoint: .bottom))

                // Data polygon outline.
                dataPolygonPath(center: center, radius: maxRadius)
                    .stroke(
                        LinearGradient(colors: [.blue, .purple],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )

                // Per-axis data point + label.
                ForEach(0..<dimensionCount, id: \.self) { i in
                    let p = pointAt(
                        angle: angleFor(index: i),
                        radius: maxRadius * CGFloat(values.all[i]),
                        from: center
                    )
                    Circle()
                        .fill(axisColors[i])
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .position(p)

                    let labelPoint = pointAt(
                        angle: angleFor(index: i),
                        radius: maxRadius * 1.18,
                        from: center
                    )
                    Text(axisLabels[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(axisColors[i])
                        .position(labelPoint)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - Geometry helpers
    /// Start at the top (12 o'clock) and go clockwise. With 5 axes this
    /// puts HRV at the top, Heart Rate on the right, Recovery Sleep at
    /// the bottom-right, Workout at the bottom-left, and Respiratory on
    /// the left.
    private func angleFor(index: Int) -> Angle {
        .degrees(Double(index) * 360.0 / Double(dimensionCount) - 90)
    }

    private func pointAt(angle: Angle, radius: CGFloat, from center: CGPoint) -> CGPoint {
        let rad = CGFloat(angle.radians)
        return CGPoint(
            x: center.x + cos(rad) * radius,
            y: center.y + sin(rad) * radius
        )
    }

    private func polygonPath(center: CGPoint, radius: CGFloat, count: Int) -> Path {
        Path { path in
            for i in 0..<count {
                let p = pointAt(angle: angleFor(index: i), radius: radius, from: center)
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }

    /// Connect the five radar data points, each at its own radius
    /// (maxRadius × normalized value) along its axis direction.
    private func dataPolygonPath(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for i in 0..<dimensionCount {
                let p = pointAt(
                    angle: angleFor(index: i),
                    radius: radius * CGFloat(values.all[i]),
                    from: center
                )
                if i == 0 { path.move(to: p) }
                else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }
}

// MARK: - Fitness Ring View

/// iOS Activity-ring style concentric progress ring. Single ring when
/// `progress` is supplied (green color, gradients to red as the
/// progress falls). Designed to be small (≈ 24-30 pt) so it fits as
/// the workout axis tile in the recovery-radar card.
struct FitnessRingView: View {
    let progress: Double      // 0-1
    var lineWidth: CGFloat = 4
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: lineWidth)

            // Foreground progress
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
        .frame(width: size, height: size)
    }

    private var gradientColors: [Color] {
        switch progress {
        case ..<0.34: return [.red, .orange]
        case ..<0.7:  return [.orange, .yellow]
        case ..<1.0:  return [.green, .mint]
        default:      return [.mint, .green]
        }
    }

    /// Color used by the surrounding tile to match the ring state.
    static func colorFor(progress: Double) -> Color {
        switch progress {
        case ..<0.34: return .red
        case ..<0.7:  return .orange
        case ..<1.0:  return .blue
        default:      return .green
        }
    }
}
