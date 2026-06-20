# StudyPulse — AI Agent Guide

> Complete developer guide for AI agents working on the **StudyPulse** iOS app.

---

## 1. Quick Reference

| Item              | Details                                                     |
|-------------------|-------------------------------------------------------------|
| Platform          | iOS 18.6+ (iPhone & iPad)                                   |
| Language          | Swift 6.0                                                   |
| Architecture      | MVVM + `@EnvironmentObject`                                 |
| IDE               | Xcode 26.x                                                  |
| Device Family     | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)            |
| Concurrency       | Swift 6 strict, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |
| Dependencies      | WSOnBoarding, swift-markdown-ui, NetworkImage, cmark-gfm (SPM) |
| Storage           | JSON files in `~/Documents/` + separate image files         |
| App Group         | `group.com.chenkai.gao.studypulse`                          |
| Localizations     | en, zh-Hans, zh-Hant, ja, ko (`*.lproj/Localizable.strings`)|
| Charts            | SwiftUI `Charts` framework                                  |
| OCR               | `Vision` framework (`VNRecognizeTextRequest`)               |
| Calendar          | `EventKit`                                                  |
| Health            | `HealthKit` (HRV / SDNN readiness)                          |
| Widget            | WidgetKit sources present (target not yet wired in pbxproj)|
| Bundle ID         | `Gao.Chenkai.StudyPulse`                                    |
| iPad Layout       | `Views/Helpers/iPadLayout.swift` + custom `NavigationSplitView` in `ContentView.swift` |

---

## 2. Project Overview

**StudyPulse** is an iOS study management app built with SwiftUI. It helps
students track grades, manage mistakes, schedule exams, sync with HealthKit
for HRV-based readiness, and analyse learning trends. It supports many global
education systems (CN, UK, IB, AP, SAT, ACT, A-Level, IGCSE, DSE, etc.).

Differentiators:
- **HRV readiness** card on Home (Apple Watch SDNN, 14-day baseline, Z-score).
- **Customizable Home layout** (drag-to-reorder, per-card on/off, persisted).
- **Unregistered-exam reminder** card (3–7 day window after an exam).
- **Multi-language** with `.localized()` extension over `Localizable.strings`.
- **Native iPad sidebar** via `NavigationSplitView` + adaptive content widths.
- **WidgetKit** sources are committed; widget target still needs to be added
  to the Xcode project (see §14).

---

## 3. Repository Layout

```
StudyPulse/                            # Xcode project root
├── StudyPulse.xcodeproj/              # Xcode project (one target: StudyPulse)
│
├── StudyPulse/                        # Main app target sources
│   ├── StudyPulseApp.swift            # @main entry, NotificationCoordinator, scene setup
│   ├── StudyPulse.entitlements        # HealthKit entitlement
│   ├── Assets.xcassets/               # AccentColor, AppIcon (StudyPulseIcon)
│   │
│   ├── Models/                        # Plain data structs (Codable, nonisolated)
│   │   ├── DataModels.swift           # Subject, Grade, MistakeNote, Exam, comprehensiveExam, UserProfile
│   │   ├── AppPreferences.swift       # Persisted app prefs (language + color scheme)
│   │   └── HomeLayoutPreference.swift # Home card order + enabled flags, UserDefaults persisted
│   │
│   ├── Managers/                      # @MainActor / nonisolated service layer
│   │   ├── DataManager.swift          # @MainActor ObservableObject + DataFileIO (nonisolated enum)
│   │   ├── AppEnvironmentManager.swift# Global language + theme
│   │   ├── AppStyle.swift             # App visual style helpers
│   │   ├── CalendarManager.swift      # EventKit integration
│   │   ├── DataExportManager.swift    # CSV export for grades / mistakes / exams
│   │   ├── EducationConfig.swift      # Global education systems (CN/UK/IB/AP/SAT/ACT/...)
│   │   ├── ExamWidgetData.swift       # Widget data DTO + AppGroupConfig + WidgetDataStore
│   │   ├── HealthKitManager.swift     # HRV (SDNN) readiness, baseline, daily history
│   │   ├── ImageCache.swift           # NSCache + thumbnail (nonisolated)
│   │   ├── OCRManager.swift           # Vision text recognition
│   │   ├── StringsLocalized.swift     # String.localized() helper
│   │   ├── SubjectInfo.swift          # Display names + colour + max-score fallback
│   │   └── WidgetDataSyncManager.swift# App Group sync (encode + write)
│   │
│   ├── Views/                         # SwiftUI screens
│   │   ├── ContentView.swift          # AppTab enum + iPhoneTabLayout + iPadSidebarLayout (NavigationSplitView)
│   │   ├── HomeView.swift             # Dashboard (welcome, stats, dynamic cards, daily quote, charts)
│   │   ├── TrendsView.swift           # Per-subject trends + "needs attention" alerts
│   │   ├── MistakeView.swift          # Mistake list + suggested review + search
│   │   ├── ExamView.swift             # Single + comprehensive exam lists
│   │   ├── SettingsView.swift         # Profile, prefs, academic info, data, about
│   │   ├── PreferencesView.swift      # Language + appearance
│   │   ├── HomeLayoutSettingsView.swift# Reorder + toggle Home cards
│   │   ├── HRVOnboardingView.swift    # 3-page HRV explainer + consent + HealthKit auth
│   │   ├── AddGradeView.swift         # Modal: add a grade
│   │   ├── NewExamSetView.swift       # Modal: add an exam (single or comprehensive)
│   │   ├── NewMistakeSetView.swift    # Modal: new mistake with photo + OCR
│   │   ├── ExamDetailView.swift       # Single exam detail + related mistakes
│   │   ├── ExamDetailEditView.swift   # Edit exam
│   │   ├── MistakeDetailEditView.swift# 4-section mistake editor with OCR
│   │   ├── SubjectScoreCard.swift     # Reusable subject score card
│   │   │
│   │   ├── Admin/                     # Developer / power-user data admin
│   │   │   └── DataAdminView.swift    # Lists grades/exams/mistakes with bulk actions
│   │   │
│   │   ├── Components/                # Reusable building blocks
│   │   │   ├── GradeChartView.swift
│   │   │   ├── HRVStatusCard.swift    # Home HRV card (3 detail levels)
│   │   │   └── SubjectPickerView.swift
│   │   │
│   │   ├── Helpers/                   # View-level helpers
│   │   │   ├── AvatarView.swift       # First-letter fallback
│   │   │   ├── ImagePicker.swift      # Photo library / camera
│   │   │   ├── PhotoCaptureView.swift # Camera capture
│   │   │   ├── ScoreColor.swift       # Proportional score → colour
│   │   │   ├── ZoomableImageView.swift# Pinch-to-zoom
│   │   │   └── iPadLayout.swift      # adaptiveMaxWidth, AdaptiveHStack, AdaptiveGridColumns, adaptiveCardPadding
│   │   │
│   │   └── OnBoarding/
│   │       └── WelcomeConfig.swift    # WSOnBoarding welcome config
│   │
│   ├── Extensions/                    # Cross-cutting extensions
│   │   ├── ColorExtensions.swift
│   │   └── DateExtensions.swift
│   │
│   └── NotificationsControl/
│       └── ExamPrepareNotifications.swift # Local notification scheduling
│
├── StudyPulseWidget/                  # WidgetKit sources (NOT yet a build target)
│   ├── ExamWidget.swift               # Widget definition
│   ├── ExamWidgetData.swift           # Widget data model
│   ├── ExamWidgetEntry.swift          # Timeline entry
│   ├── ExamWidgetProvider.swift       # Timeline provider
│   ├── ExamWidgetViews.swift          # S/M/L widget UI
│   ├── StudyPulseWidgetBundle.swift   # @main bundle
│   ├── Info.plist
│   └── Assets.xcassets/               # AccentColor, AppIcon, WidgetBackground
│
├── TestData/                          # Sample CSVs + generators
│   ├── README.md
│   ├── grades_sample.csv
│   ├── mistakes_sample.csv
│   ├── single_exams_sample.csv
│   ├── comprehensive_exams_sample.csv
│   ├── exams_sample.csv
│   ├── simple_test.csv
│   ├── generate_test_data.py
│   ├── check_csv.py
│   ├── TestDataGenerator.swift
│   ├── TestParser.swift
│   └── test_import.swift
│
├── en.lproj/Localizable.strings
├── zh-Hans.lproj/Localizable.strings
├── zh-Hant.lproj/Localizable.strings
├── ja.lproj/Localizable.strings
├── ko.lproj/Localizable.strings
│
├── AGENTS.md                          # This file
├── CODE_WIKI.md                       # English wiki
├── CODE_WIKI_CN.md                    # Chinese wiki
├── README.md
├── LICENSE                            # CC BY-NC-SA 4.0
└── scripts/build.sh                   # Bash build helper (xcodebuild)
```

---

## 4. Architecture

```
+-------------------------------------------------------------------------+
|                          StudyPulse iOS App                              |
+-------------------------------------------------------------------------+
|  Presentation (SwiftUI, MainActor)                                      |
|  +-------------------------------------------------------------------+  |
|  |  ContentView                                                     |  |
|  |   |- iPhoneTabLayout   (TabView, 5 tabs)                         |  |
|  |   |- iPadSidebarLayout (NavigationSplitView, sidebar list)       |  |
|  |  Tabs: Home / Trends / Mistakes / Exams / Settings               |  |
|  +-------------------------------------------------------------------+  |
|             |  @EnvironmentObject                                      |
|             v                                                           |
|  +-------------------------------------------------------------------+  |
|  |  HomeView  | TrendsView | MistakeView | ExamView | SettingsView  |  |
|  |  + dynamic cards driven by HomeLayoutPreference                  |  |
|  |  + HRVStatusCard, UnregisteredExamsReminderCard,                 |  |
|  |    QuickActionsCard, StudySuggestionsCard, ChartSectionView,     |  |
|  |    UpcomingExamsSection, DailyQuoteCard, RecentGradesSection     |  |
|  +-------------------------------------------------------------------+  |
|             |                                                           |
|             v                                                           |
|  +-------------------------------------------------------------------+  |
|  |  Modal sheets                                                    |  |
|  |   AddGradeView | NewExamSetView | NewMistakeSetView              |  |
|  |   MistakeDetailEditView | ExamDetailEditView                     |  |
|  |   HRVOnboardingView | HomeLayoutSettingsView                     |  |
|  |   DataAdminView                                                   |  |
|  +-------------------------------------------------------------------+  |
|                                                                         |
|  Business / Service Layer (MainActor unless noted)                      |
|  +-------------------------------------------------------------------+  |
|  | DataManager  (@MainActor ObservableObject)                        |  |
|  |   - grades, subjects, mistakeSets, examSets, comprehensiveExams  |  |
|  |   - profile                                                       |  |
|  |   - asyncInit() / save* / load*Async / load*                      |  |
|  |   - saveGradeImage / loadGradeImage / deleteGradeImage            |  |
|  |   - saveAvatar / loadAvatar / deleteAvatar                        |  |
|  |   - applySmartSubjectRecommendation(stage:regionCode:)           |  |
|  |   - fullScore(for:) / displayName(for:)                           |  |
|  |                                                                   |  |
|  | AppEnvironmentManager (@MainActor ObservableObject, singleton)    |  |
|  |   - preferences: AppPreferences (Codable, UserDefaults)           |  |
|  |   - effectiveColorScheme / setLanguage / setColorScheme           |  |
|  |                                                                   |  |
|  | HealthKitManager (@MainActor ObservableObject, singleton)         |  |
|  |   - hrvEnabled / hrvOnboardingCompleted / isAuthorized           |  |
|  |   - readiness: HRVReadiness (Z-score + category + suggestion)     |  |
|  |   - dailyHRVHistory / lastSampleCount / hrvDetailLevel            |  |
|  |   - enable() / disable() / refreshReadiness()                     |  |
|  |                                                                   |  |
|  | CalendarManager (EventKit)                                        |  |
|  | DataExportManager (CSV; @MainActor enum)                          |  |
|  | OCRManager (Vision; .accurate, zh-Hans + en)                     |  |
|  | ImageCache (nonisolated class, NSCache, 50 entries, 300px thumb)  |  |
|  | EducationConfig (nonisolated enum)                                |  |
|  | SubjectInfo (display names + colour fallback)                     |  |
|  | WidgetDataSyncManager (encode exams → App Group)                  |  |
|  +-------------------------------------------------------------------+  |
|                                                                         |
|  Data Layer                                                             |
|  +-------------------------------------------------------------------+  |
|  |  Models: Subject, Grade, MistakeNote, Exam, comprehensiveExam,    |  |
|  |          UserProfile, AppPreferences, HomeLayoutPreference        |  |
|  |          (all Codable + nonisolated, value types)                 |  |
|  +-------------------------------------------------------------------+  |
|             |                                                           |
|             v                                                           |
|  +-------------------------------------------------------------------+  |
|  |  Persistence                                                     |  |
|  |   ~/Documents/                                                   |  |
|  |     profile.json, grades.json, mistakes.json, exams.json,         |  |
|  |     comprehensiveExams.json, subjects.json                        |  |
|  |     images/avatar_*.jpg, grade_*.jpg                              |  |
|  |   UserDefaults: appPreferences, homeLayoutPreference,             |  |
|  |                 hrv_enabled, hrv_onboarding_completed,            |  |
|  |                 hrv_detail_level                                  |  |
|  |   App Group UserDefaults: widgetUpcomingExams                     |  |
|  +-------------------------------------------------------------------+  |
|                                                                         |
|  Extensions / Notifications                                             |
|  +-------------------------------------------------------------------+  |
|  | ColorExtensions, DateExtensions, StringsLocalized                 |  |
|  | ExamPrepareNotifications  (UNUserNotificationCenter, [1,3,5,10,30]|  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 5. Module Dependency Graph

```
+------------+        +-------------------+
|  Views     |        |  StudyPulseWidget  |
| ContentView|        |  ExamWidget        |
| HomeView   |        |  ExamWidgetViews   |
| TrendsView |        |  ExamWidgetProvider|
| MistakeView|        |  ExamWidgetEntry   |
| ExamView   |        |  ExamWidgetData    |
| ...        |        +---------+---------+
+-----+------+                  |
      |  (@EnvironmentObject)  | (App Group UserDefaults)
      v                         v
+-----+--------------------+   +----------------------+
| DataManager (MainActor)  |   | WidgetDataSyncManager|
| AppEnvironmentManager    |   | WidgetDataStore      |
| HealthKitManager         |   +----------------------+
+-----+--------------------+
      |
      v
+-----+----------------+  +----------------+
| CalendarManager       |  | OCRManager     |
| DataExportManager     |  | ImageCache     |
| ExamPrepareNotif.     |  | EducationConfig|
+-----+----------------+  +----------------+
      |
      v
+--------------------------+
| Models (Codable structs) |
+--------------------------+
```

---

## 6. Navigation Flow

```
StudyPulseApp  (@main)
  |- sets NotificationCoordinator as UNUserNotificationCenter.delegate
  |- requests notification authorization
  |- calls AppEnvironmentManager.shared.applyLanguageOnLaunch()
  |- .task { dataManager.asyncInit() }
       v
ContentView
  |- iPhone:  TabView (5 tabs)
  |- iPad:    NavigationSplitView with sidebar list (5 items)
       |
       v
  HomeView ──────► AddGradeView (sheet)
       │           NewExamSetView / NewMistakeSetView
       │           HomeLayoutSettingsView
       │
       ├─ HRVStatusCard          ──► HRVOnboardingView (first-time)
       ├─ UnregisteredExamsReminderCard ──► AddGradeView (pre-filled)
       ├─ QuickActionsCard       ──► AddGradeView / NewExamSetView / NewMistakeSetView
       ├─ StudySuggestionsCard
       ├─ ChartSectionView
       ├─ UpcomingExamsSection   ──► ExamDetailView
       ├─ DailyQuoteCard
       └─ RecentGradesSection

  TrendsView  ──► per-subject detail
  MistakeView ──► MistakeDetailEditView  (4 sections + OCR)
  ExamView    ──► ExamDetailView ──► ExamDetailEditView
  SettingsView ──► PreferencesView, EditSubjects, ProfileEdit,
                   DataAdminView, About, Copyright
```

---

## 7. Data Layer

### 7.1 DataManager

`@MainActor` `ObservableObject`, exposed as `@EnvironmentObject` to every view.

Published properties:
- `grades: [Grade]`
- `subjects: [Subject]`
- `mistakeSets: [MistakeNote]`
- `examSets: [Exam]`
- `comprehensiveExamSets: [comprehensiveExam]`
- `profile: UserProfile`

Lifecycle:
- `init()` — synchronous eager loads (back-compat).
- `asyncInit()` — background `Task.detached` then `MainActor.run` to mutate
  `@Published` properties; also migrates inline `Grade.image` data to files
  in `images/grade_{UUID}.jpg`.

Persistence files in `~/Documents/`:
`profile.json`, `grades.json`, `mistakes.json`, `exams.json`,
`comprehensiveExams.json`, `subjects.json`.

`DataFileIO` is a `nonisolated enum` (thread-safe file I/O):
- `getDocsDir()`, `getImagesDir()`
- `load<T: Codable>(url:decoder:) -> T?`

Image storage:
- Avatars: `images/avatar_{uuid}.jpg`
- Grade snapshots: `images/grade_{uuid}.jpg` (migrated from inline `Data`).

### 7.2 Data Persistence Flow

```
[App launch]
StudyPulseApp
  └─ .task { dataManager.asyncInit() }
       └─ Task.detached(priority: .userInitiated)
            ├─ DataFileIO.load profile.json
            ├─ DataFileIO.load grades.json  (migrate inline image -> file)
            ├─ DataFileIO.load mistakes.json
            ├─ DataFileIO.load exams.json (ISO8601 dates)
            ├─ DataFileIO.load comprehensiveExams.json (ISO8601 dates)
            └─ DataFileIO.load subjects.json
       └─ MainActor.run { assign @Published; initializeDefaultSubjects() }

[Edit]
View -> DataManager.save*()  -> JSONEncoder -> ~/Documents/{file}.json
WidgetDataSyncManager.syncExamsToWidget() -> App Group UserDefaults
```

### 7.3 Key Models

| Model             | Notes                                                                  |
|-------------------|------------------------------------------------------------------------|
| `Subject`         | `name`, `displayName`, `enabled`, `fullScore` (customizable)           |
| `Grade`           | `subject`, `score`, `rawScore?`, `ranking?`, `importance (1..5)`, `image?` (legacy), `imageFileName?`, `date`, `examName`, `fullScore?` |
| `MistakeNote`     | `title`, `subject`, `originalQuestion`, `source`, `date`, `errorReason`, `wrongSolution`, `correctSolution`, per-section `…Images: [Data]` |
| `Exam`            | single-subject — `subject: String`                                    |
| `comprehensiveExam` | multi-subject — `subject: [String]`                                 |
| `UserProfile`     | username, real name, age, gender, school/grade/class/studentId, enrollment/exam years, educationStage, regionCode, theme, avatar, target school/score, selectedSubjects |
| `AppPreferences`  | `appLanguage: String?`, `colorScheme: ColorSchemeOption` (UserDefaults) |
| `HomeLayoutPreference` | ordered `items: [HomeCardItem]` (type + enabled), persisted in UserDefaults, merges on schema changes |

---

## 8. HRV / HealthKit Subsystem

```
+-----------------------------+
|  HealthKitManager (singleton)|
|  - hrvEnabled                |
|  - hrvOnboardingCompleted    |
|  - isAuthorized              |
|  - readiness: HRVReadiness   |
|  - dailyHRVHistory           |
|  - lastSampleCount           |
|  - hrvDetailLevel            |
+-----------------------------+
       |  read
       v
+------------------+      +------------------+
| HKHealthStore    |      | HRVStatusCard    |
| .heartRateVar-   |      |  (3 detail levels|
|  iabilitySDNN    |      |   suggestion only|
+------------------+      |   data+suggestion|
                          |   chart+data)    |
                          +------------------+
                                   ^
                                   |  first-run
                          +------------------+
                          | HRVOnboardingView|
                          |  3 pages: what  |
                          |  is HRV / privacy|
                          |  / consent       |
                          +------------------+
```

- Window: 14 days of `HKQuantitySample` for `HRVSDNN`.
- Daily aggregation: first sample per calendar day, sorted desc.
- Baseline: mean of days **after today** (requires ≥ 7 distinct days).
- Z-score: `(today - mean) / stdDev` over the past.
- Categories: `excellent` (z > 1), `normal` (-1 ≤ z ≤ 1), `low` (z < -1),
  `insufficient` (< 7 days), `noAuthorization`, `queryFailed`.
- `enable()` requests `requestAuthorization(toShare: [], read: [hrvType])`.
- `StudyPulse.entitlements` enables `com.apple.developer.healthkit`.
- Detail-level toggle in Settings: `suggestionOnly` / `dataAndSuggestion` /
  `chartAndData` (drives `HRVStatusCard` rendering).

---

## 9. Customizable Home Layout

`HomeLayoutPreference` (Codable) is persisted in `UserDefaults`
(key: `homeLayoutPreference`). `HomeView` reads it on every body evaluation
and renders enabled cards in the user-defined order, with iPad using a
two-column `LazyVGrid` and iPhone a single `VStack`.

Card types (`HomeCardType`):
- `hrvStatus`             — HRVStatusCard
- `unregisteredExamsReminder` — UnregisteredExamsReminderCard (hides if empty)
- `quickActions`          — QuickActionsCard
- `studySuggestions`      — StudySuggestionsCard
- `trendChart`            — ChartSectionView (hides if no recent grades)
- `upcomingExams`         — UpcomingExamsSection (hides if empty)
- `dailyQuote`            — DailyQuoteCard
- `recentGrades`          — RecentGradesSection (hides if no recent grades)

`HomeLayoutSettingsView` provides drag-to-reorder and on/off toggles, then
calls `preference.save()`.

`mergeWithDefault` keeps the user's choices when new card types are added
in future versions.

---

## 10. Image, OCR, and CSV Pipelines

### 10.1 Image Pipeline
- Capture: `PhotoCaptureView` (camera) / `ImagePicker` (photo library).
- Process: compress → JPEG `Data` → `DataManager.saveGradeImage(_:gradeId:)`
  or `saveAvatar(_:)` → file in `~/Documents/images/`.
- Display: cached via `ImageCache` (NSCache, max 50, 300px max dimension,
  `nonisolated` so safe from any thread).
- Full-screen: `ZoomableImageView` (pinch + double-tap).

### 10.2 OCR Pipeline
- `OCRManager.shared.recognizeText(in:completion:)` builds a
  `VNRecognizeTextRequest` with `recognitionLevel = .accurate` and
  `recognitionLanguages = ["zh-Hans", "en"]`.
- Returns top candidate string per text observation, joined by newlines.

### 10.3 CSV Export
- `DataExportManager` (MainActor enum) builds CSV strings for
  grades, mistakes, exams, comprehensive exams with proper escaping.
- `UIActivityViewController` shares the CSV via `CSVDocument` (`FileDocument`).

---

## 11. iPad Adaptation

`ContentView` switches on `horizontalSizeClass`:
- iPhone: classic `TabView` (5 tabs).
- iPad:   `NavigationSplitView` with a `List(selection:)` sidebar
  (`AppTab` enum) and a `detail` view that renders the current tab.
  `navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)`.

`Views/Helpers/iPadLayout.swift` provides:
- `adaptiveMaxWidth(_:)` — `ViewModifier` (default 720), centers content
  on iPad and leaves iPhone full-width.
- `AdaptiveHStack` — HStack on iPad, VStack on iPhone.
- `AdaptiveGridColumns(compact:regular:spacing:)` — multi-column grids.
- `adaptiveCardPadding()` — 20pt outer padding on iPhone, 0 on iPad.

| View              | Max Width (iPad) |
|-------------------|------------------|
| PreferencesView   | 640              |
| SettingsView      | 720              |
| ExamView          | 800              |
| TrendsView        | 900              |
| MistakeView       | 900              |
| HomeView          | 1100 (two-column grid for dynamic cards) |

Principles:
1. iPhone layout is unchanged; all iPad behavior is gated on
   `horizontalSizeClass == .regular` or `UIDevice.current.userInterfaceIdiom`.
2. Content is centered, not stretched.
3. All adaptive logic lives in `iPadLayout.swift`; feature views just call
   the helpers.
4. Sidebar uses `.listStyle(.sidebar)` with a `NavigationLink(value: tab)`.

---

## 12. Localisation

- `Localizable.strings` lives in each `*.lproj/`.
- All user-facing strings go through `"…".localized()`
  (`StringsLocalized.swift` extension).
- App switches language via `AppEnvironmentManager.setLanguage(_:)` which
  mutates `UserDefaults` key `AppleLanguages`; `applyLanguageOnLaunch()` is
  called in `StudyPulseApp.init`.

---

## 13. Privacy Permissions

| Key                              | Value                            |
|----------------------------------|----------------------------------|
| `NSCameraUsageDescription`       | Take photos of mistakes          |
| `NSPhotoLibraryUsageDescription` | Select photos from photo library |
| `NSCalendarsUsageDescription`    | Add exams to calendar            |
| `NSHealthShareUsageDescription`  | Read HRV data from Health        |
| `NSHealthUpdateUsageDescription` | (not used; app does not write)   |
| `com.apple.developer.healthkit`  | true (entitlement)               |

---

## 14. WidgetKit

The `StudyPulseWidget/` folder contains complete sources (Bundle, Provider,
Entry, three size Views) and an `Info.plist`. **The widget target is not yet
added to `StudyPulse.xcodeproj`.**

To enable:
1. Add a Widget Extension target in Xcode with bundle id
   `Gao.Chenkai.StudyPulse.Widget`, deployment target iOS 18.6.
2. Enable App Group `group.com.chenkai.gao.studypulse` on **both** targets.
3. Replace `AppGroupConfig.identifier` defaults if you change the group.
4. Trigger `WidgetDataSyncManager.syncExamsToWidget()` from the app on
   exam add/edit and from `applicationDidBecomeActive` (or `.task`).
5. Use `WidgetCenter.shared.reloadAllTimelines()` after writes.

`ExamWidgetData` is a small Codable struct (`name`, `subject`, `examDate`,
`daysRemaining`) shared with the app via `WidgetDataStore` in
`ExamWidgetData.swift`.

---

## 15. Dependencies (SPM)

| Package            | Source                          | Purpose                          |
|--------------------|---------------------------------|----------------------------------|
| WSOnBoarding       | local (`Swift/Packages/...`)    | First-launch welcome flow        |
| swift-markdown-ui  | local (`Swift/Packages/...`)    | Markdown preview in mistake view |
| NetworkImage       | https://github.com/gonzalezreal/NetworkImage @ 6.0.1 | Async image loading |
| cmark-gfm          | https://github.com/swiftlang/swift-cmark @ 0.8.0 | Markdown core |

Apple frameworks: `SwiftUI`, `Charts`, `Vision`, `EventKit`,
`UserNotifications`, `HealthKit`, `WidgetKit`, `UniformTypeIdentifiers`.

Resolve packages: **File → Packages → Resolve Package Versions** in Xcode.
CLI: `xcodebuild -resolvePackageDependencies -project StudyPulse.xcodeproj`.

---

## 16. Build & Run

Use the helper script:
```bash
./scripts/build.sh                # Debug, iPhone 17 simulator
./scripts/build.sh release        # Release configuration
./scripts/build.sh clean          # Clean build folder
./scripts/build.sh list           # List available simulators
./scripts/build.sh help           # Show all options
```

Direct `xcodebuild`:
```bash
xcodebuild \
  -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Schemes available: `StudyPulse`, `MarkdownUI`, `WSOnBoarding`.
Configurations: `Debug`, `Release`.

---

## 17. Code Conventions

- `@EnvironmentObject` for cross-view state (`DataManager`,
  `AppEnvironmentManager`, `HealthKitManager`).
- Models are `Codable` and `nonisolated` value types — safe to pass across
  actors.
- Managers that own `@Published` UI state are `@MainActor`; pure helpers
  (`DataFileIO`, `WidgetDataStore`, `EducationConfig`, `ImageCache`,
  `SubjectConfig`, `EducationRegion`) are `nonisolated`.
- SwiftUI views live under `Views/`, with `Components/`, `Helpers/`, `Admin/`,
  `OnBoarding/` as sub-folders for organisation.
- Strings: always use `"…".localized()` (never inline).
- Hex/asset colors via `ColorExtensions`; `Date` formatting via
  `DateExtensions`.
- Image bytes are persisted as files in `images/`, never inline in JSON
  (legacy migration is handled in `DataManager.asyncInit`).
- `EditSection` enum drives the 4-section mistake editor
  (Question/Reason/Wrong/Correct).
- `EducationConfig` is a `nonisolated enum` providing global config data.
- `SubjectConfig` uses factory methods `.required(...)` / `.elective(...)`.

---

## 18. Performance Notes

- App launch uses `asyncInit()` in `.task` to load JSON off the main thread;
  legacy sync `load*()` methods are kept for back-compat.
- `ImageCache` provides NSCache-backed thumbnails (max 50 entries,
  300px max dim) — fully thread-safe (`nonisolated`).
- `ExamRowView` / `ComprehensiveExamRowView` / `UpcomingExamCard` use
  computed properties for `daysRemaining` instead of `@State` + `onAppear`
  to avoid spurious re-renders.
- iPad `HomeView` renders the dashboard in a `LazyVGrid` to keep memory low
  even when many cards are enabled.

---

## 19. Known Issues / TODOs

1. Widget target is not wired into `StudyPulse.xcodeproj` — sources are
   committed but unused at build time.
2. App Group identifier must be created in the Apple Developer portal and
   enabled on **both** the main app and (future) widget target.
3. No iCloud sync — all data is local to the device sandbox.
4. `NewMistakeSheet.swift` / `Views/Sheets/` directory was removed; the
   active flow is `NewMistakeSetView`.

---

## 20. Changelog (Agent-Facing)

### v2026.06.20 — Home layout + HRV subsystem
- Added `HealthKitManager.swift`, `HRVOnboardingView.swift`,
  `HRVStatusCard.swift` for HRV (SDNN) readiness using a 14-day baseline
  and a Z-score category.
- Added `HomeLayoutPreference.swift` and `HomeLayoutSettingsView.swift`
  for per-card on/off + drag-to-reorder, persisted in `UserDefaults`.
- Added `Views/Admin/DataAdminView.swift` for power-user bulk data ops.
- `ContentView` rewritten with a custom `NavigationSplitView` sidebar for
  iPad (replaces `.sidebarAdaptable`); iPhone keeps the classic `TabView`.
- `HomeView` now composes its dashboard from
  `HomeLayoutPreference.load().enabledTypes` using
  `HomeCardType` cases (`hrvStatus`, `unregisteredExamsReminder`,
  `quickActions`, `studySuggestions`, `trendChart`, `upcomingExams`,
  `dailyQuote`, `recentGrades`).
- Added "Unregistered Exams Reminder" card (3–7 day window after an exam
  with no matching grade).
- `StudyPulse.entitlements` now includes `com.apple.developer.healthkit`.
- Rewrote `AGENTS.md` to match the new structure.

### v2026.06.13 — iPad adaptation
- iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) via `iPadLayout.swift` helpers
  (`adaptiveMaxWidth`, `AdaptiveHStack`, `AdaptiveGridColumns`,
  `adaptiveCardPadding`).

### v2026.06.07 — Full view-layer refactor + design system
- `HomeView` split into 9 components; gradient / animation polish.
- `MistakeView`: suggested review + card gradient.
- `TrendsView`: "Subjects Needing Attention" smart alerts.
- `ExamDetailView`: related mistakes section.
- `SubjectScoreCard`: gradient border + entrance animation.
- `AppStyle` design-system skeleton.
- First `StudyPulseWidget` skeleton (Bundle / Provider / Entry / S·M·L).

### v2026.06.06 — Multi-language
- `zh-Hant`, `ja`, `ko` localizations.

### v2026.06.05 — Mistake module launch
- 4-section mistake editor (Question / Reason / Wrong / Correct).
- Per-section photo + OCR.
- Markdown preview.
- Calendar / notification auto-scheduling.
- Zoomable image viewer.

### v2026.06 — Global education systems
- `EducationConfig` for 15+ systems.
- `SubjectConfig` factories.
- Avatar system, proportional score colour, expanded profile.

---

## 21. Agent Working Rules

- **Always try to build after writing code.** After every non-trivial code
  change, run the build (Xcode Cmd+B or `./scripts/build.sh`) to make sure
  the change compiles cleanly. Do not leave syntax / type errors behind.
- **Respect the file layout.** Put new screens in `Views/`, reusable
  building blocks in `Views/Components/`, view helpers in
  `Views/Helpers/`, dev-only screens in `Views/Admin/`, data structs in
  `Models/`, services in `Managers/`.
- **Use `nonisolated` value-type models.** New Codable models must be
  `nonisolated` and `Sendable` so they pass across actors without ceremony.
- **Localize every user-facing string.** Never ship inline English text.
  Add the key to **all five** `Localizable.strings` files.
- **Persist image bytes as files**, not in JSON. Use
  `DataManager.saveGradeImage` / `saveAvatar`.
- **Prefer `iPadLayout` helpers** over ad-hoc `if sizeClass == .regular`
  branches in feature views.
- **Do not modify `StudyPulse.xcodeproj/project.pbxproj` by hand** unless
  absolutely required — let Xcode manage it.
