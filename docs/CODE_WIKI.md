# StudyPulse — Code Wiki

> A comprehensive code reference for the StudyPulse iOS app. This file provides the full picture with tables, ASCII flowcharts and diagrams.

---

## Table of Contents

1. Getting Started
2. Architecture Overview
3. Repository Layout
4. Data Models Reference
5. Managers Reference
6. Views Reference
7. Home Card System
8. Education Systems
9. HRV / HealthKit Subsystem
10. Image, OCR and CSV Pipelines
11. iPad Adaptation
12. Localization
13. Privacy Permissions
14. Widget Extension
15. Dependencies (SPM)
16. Build & Run
17. Coding Standards
18. Performance Notes
19. Known Issues / TODO

---

## 1. Getting Started

### 1.1 Prerequisites

| Item | Requirement |
|---|---|
| macOS | 15.0 or higher |
| Xcode | 26.x (26.3 recommended) |
| iOS Deployment Target | 18.6+ |
| Swift | 6.0 |
| Supported Devices | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |

### 1.2 Quick Start

```bash
# Clone the repository and open in Xcode
open StudyPulse.xcodeproj

# Resolve Swift packages
# Xcode → File → Packages → Resolve Package Versions
# Then Cmd+R to run
```

CLI build:

```bash
./scripts/build.sh              # Debug, iPhone 17 simulator
./scripts/build.sh release      # Release
./scripts/build.sh clean        # Clean build folder
./scripts/build.sh list         # List available simulators
```

### 1.3 Key Concepts

| Concept | Description |
|---|---|
| Architecture | MVVM with `@EnvironmentObject` injection |
| Persistence | JSON files in `~/Documents/`; images in `~/Documents/images/`; preferences in `UserDefaults` |
| Startup | `StudyPulseApp` calls `dataManager.asyncInit()` inside `.task` |
| Global Education | 15+ education systems (CN, UK, IB, AP, SAT, ACT, GRE, GMAT, TOEFL, IELTS, etc.) |
| Universal Layout | iPhone TabView + iPad NavigationSplitView with adaptive helpers |
| HRV Readiness | Apple Watch SDNN, 14-day baseline, Z-score classification |
| Customizable Home | 8 card types, drag-to-reorder + per-card on/off |

---

## 2. Architecture Overview

StudyPulse follows an **MVVM** pattern. Views read state from `@EnvironmentObject` singletons; managers encapsulate business logic and access models; models are plain `Codable` value types.

### 2.1 Layer Diagram

```
+-------------------------------------------------------------------------+
|                          StudyPulse iOS App                              |
+-------------------------------------------------------------------------+
|                                                                         |
|  +---------------- Presentation (SwiftUI, @MainActor) ----------------+ |
|  |  ContentView                                                       | |
|  |   |- iPhone TabView (5 tabs)                                       | |
|  |   '- iPad NavigationSplitView (sidebar + detail)                   | |
|  |                                                                    | |
|  |  HomeView | TrendsView | MistakeView | ExamView | SettingsView     | |
|  |   + dynamic cards driven by HomeLayoutPreference                   | |
|  |   + HRVStatusCard, UnregisteredExamsReminderCard,                  | |
|  |     QuickActionsCard, StudySuggestionsCard, ChartSectionView,      | |
|  |     UpcomingExamsSection, DailyQuoteCard, RecentGradesSection      | |
|  |                                                                    | |
|  |  Modal sheets: AddGradeView, NewExamSetView, NewMistakeSetView,    | |
|  |                MistakeDetailEditView, ExamDetailEditView,          | |
|  |                HRVOnboardingView, HomeLayoutSettingsView,          | |
|  |                DataAdminView                                       | |
|  +--------------------------------------------------------------------+ |
|                              |                                          |
|                              v  (@EnvironmentObject)                    |
|  +---------------- Business / Service Layer -------------------------+ |
|  |                                                                    | |
|  |  DataManager  (@MainActor ObservableObject)                        | |
|  |   - published: grades, subjects, mistakeSets, examSets,            | |
|  |                comprehensiveExamSets, profile                      | |
|  |   - methods: asyncInit(), save*(), load*Async(),                   | |
|  |            saveGradeImage() / loadGradeImage() / deleteGradeImage()| |
|  |            saveAvatar() / loadAvatar() / deleteAvatar()            | |
|  |            fullScore(for:), displayName(for:),                     | |
|  |            applySmartSubjectRecommendation(stage:regionCode:)      | |
|  |                                                                    | |
|  |  AppEnvironmentManager (@MainActor ObservableObject, singleton)    | |
|  |   - preferences: AppPreferences                                    | |
|  |   - effectiveColorScheme, setLanguage(), setColorScheme()          | |
|  |                                                                    | |
|  |  HealthKitManager (@MainActor ObservableObject, singleton)         | |
|  |   - hrvEnabled, hrvOnboardingCompleted, isAuthorized               | |
|  |   - readiness: HRVReadiness (z-score + category + suggestion)      | |
|  |   - dailyHRVHistory, lastSampleCount, hrvDetailLevel               | |
|  |   - enable(), disable(), refreshReadiness()                        | |
|  |                                                                    | |
|  |  CalendarManager (EventKit)                                        | |
|  |  DataExportManager (CSV; @MainActor enum)                          | |
|  |  OCRManager (Vision)                                               | |
|  |  ImageCache (nonisolated class, NSCache, 50 entries, 300px thumb)  | |
|  |  EducationConfig (nonisolated enum)                                | |
|  |  SubjectInfo (display names + color + max-score fallback)          | |
|  |  WidgetDataSyncManager (encode exams → App Group)                  | |
|  +--------------------------------------------------------------------+ |
|                              |                                          |
|                              v                                          |
|  +---------------------- Data Layer ----------------------------------+ |
|  |                                                                    | |
|  |  Models (Codable, nonisolated value types)                         | |
|  |   Subject, Grade, MistakeNote, Exam, comprehensiveExam,            | |
|  |   UserProfile, AppPreferences, HomeLayoutPreference                | |
|  |                                                                    | |
|  |  Persistence                                                       | |
|  |   ~/Documents/                                                     | |
|  |     profile.json, grades.json, mistakes.json, exams.json,          | |
|  |     comprehensiveExams.json, subjects.json                         | |
|  |     images/  (grade_UUID.jpg, avatar_UUID.jpg)                     | |
|  |   UserDefaults (AppPreferences, HomeLayoutPreference, hrv prefs)   | |
|  |   App Group (widgetUpcomingExams)                                  | |
|  +--------------------------------------------------------------------+ |
|                              |                                          |
|                              v                                          |
|  +---------------- Extensions / Notifications ------------------------+ |
|  |                                                                    | |
|  |  ColorExtensions, DateExtensions, StringsLocalized                 | |
|  |  ExamPrepareNotifications (UNUserNotificationCenter, [1,3,5,10,30])| |
|  +--------------------------------------------------------------------+ |
|                                                                         |
+-------------------------------------------------------------------------+
```

### 2.2 Module Dependency Graph

```
+-------------------------+      +------------------------+      +------------------------+
| Views (SwiftUI)         | ---> | DataManager            | ---> | Models (Codable)        |
|  HomeView, TrendsView,   |      | AppEnvironmentManager  |      |  Subject, Grade,         |
|  MistakeView, ExamView,  |      | HealthKitManager       |      |  MistakeNote, Exam,      |
|  SettingsView, +sheets   |      |                        |      |  comprehensiveExam,      |
+------------+------------+      +------------+-----------+      |  UserProfile, etc.       |
             |                                  |                  +------------------------+
             |                                  |
             |                                  v
             |                      +------------------------+
             |                      | Helper Managers         |
             |                      |  CalendarManager         |
             |                      |  OCRManager              |
             |                      |  ImageCache              |
             |                      |  EducationConfig         |
             |                      |  SubjectInfo             |
             |                      |  DataExportManager       |
             |                      |  WidgetDataSyncManager   |
             |                      +------------+-------------+
             |                                   |
             +-----------------------------------+
             (Views never call helpers directly; always via DataManager)

+-------------------------+      +------------------------+
| StudyPulseWidget        | ---> | WidgetDataStore        |
|  ExamWidget, Entry,     |      | (App Group container)  |
|  Views, Provider        |      |                        |
+-------------------------+      +------------------------+
```

### 2.3 Data Persistence Flow

```
[App Launch]
StudyPulseApp
  └─ .task { dataManager.asyncInit() }
       └─ Task.detached(priority: .userInitiated)
            ├─ load profile.json
            ├─ load grades.json   (migrate inline image data → files)
            ├─ load mistakes.json
            ├─ load exams.json    (ISO8601 dates)
            ├─ load comprehensiveExams.json
            └─ load subjects.json
       └─ MainActor.run { assign @Published; initializeDefaultSubjects() }

[User Edit]
View → DataManager.save*()  → JSONEncoder → ~/Documents/{file}.json
                                   ↓
                       WidgetDataSyncManager.syncExamsToWidget()
                                   ↓
                       App Group UserDefaults
                       └─ WidgetCenter.reloadTimelines()
```

---

## 3. Repository Layout

```
StudyPulse/
├── StudyPulse.xcodeproj/              # Xcode project (single target: StudyPulse)
│
├── StudyPulse/                        # Main target sources
│   ├── StudyPulseApp.swift            # @main entry, NotificationCoordinator, scene setup
│   ├── StudyPulse.entitlements        # HealthKit entitlement
│   ├── Assets.xcassets/               # AccentColor, AppIcon
│   │
│   ├── Models/                        # Data model definitions
│   │   ├── DataModels.swift           # Subject, Grade, MistakeNote, Exam,
│   │   │                              # comprehensiveExam, UserProfile, plus
│   │   │                              # EducationStage, EducationCategory,
│   │   │                              # SubjectConfig, EducationRegion
│   │   ├── AppPreferences.swift       # Persisted prefs (language + color scheme)
│   │   └── HomeLayoutPreference.swift # Home card order + enabled flags (UserDefaults)
│   │
│   ├── Managers/                      # Business-logic layer
│   │   ├── DataManager.swift          # @MainActor ObservableObject + DataFileIO
│   │   ├── AppEnvironmentManager.swift# Global language + theme management
│   │   ├── AppStyle.swift             # Design-system helpers
│   │   ├── CalendarManager.swift      # EventKit integration
│   │   ├── DataExportManager.swift    # CSV export (MainActor enum)
│   │   ├── EducationConfig.swift      # Global education systems (nonisolated enum)
│   │   ├── ExamWidgetData.swift       # Widget data model + AppGroupConfig + WidgetDataStore
│   │   ├── HealthKitManager.swift     # HRV (SDNN) readiness, baseline, daily history
│   │   ├── ImageCache.swift           # NSCache-backed thumbnail cache (nonisolated)
│   │   ├── OCRManager.swift           # Vision text recognition
│   │   ├── StringsLocalized.swift     # String.localized() helper
│   │   ├── SubjectInfo.swift          # Display names + color + max-score fallback
│   │   └── WidgetDataSyncManager.swift# App Group sync (encode + write)
│   │
│   ├── Views/                         # SwiftUI screens
│   │   ├── ContentView.swift          # Root view: iPhone TabView / iPad NavigationSplitView
│   │   ├── HomeView.swift             # Dashboard
│   │   ├── TrendsView.swift           # Per-subject trend analysis
│   │   ├── MistakeView.swift          # Mistake list + suggested review
│   │   ├── ExamView.swift             # Single + comprehensive exam lists
│   │   ├── SettingsView.swift         # Profile, prefs, academic info, data, about
│   │   ├── PreferencesView.swift      # Language + appearance
│   │   ├── HomeLayoutSettingsView.swift# Reorder + toggle home cards
│   │   ├── HRVOnboardingView.swift    # 3-page HRV explainer + consent
│   │   ├── AddGradeView.swift         # Modal: add a grade
│   │   ├── NewExamSetView.swift       # Modal: add / edit an exam
│   │   ├── NewMistakeSetView.swift    # Modal: new mistake with photo + OCR
│   │   ├── ExamDetailView.swift       # Exam detail + related mistakes
│   │   ├── ExamDetailEditView.swift   # Edit exam
│   │   ├── MistakeDetailEditView.swift# 4-section mistake editor
│   │   ├── SubjectScoreCard.swift     # Reusable subject score card
│   │   │
│   │   ├── Components/                # Reusable building blocks
│   │   │   ├── GradeChartView.swift
│   │   │   ├── HRVStatusCard.swift    # Home HRV card (3 detail levels)
│   │   │   ├── SectionHeader.swift
│   │   │   └── SubjectPickerView.swift
│   │   │
│   │   ├── Helpers/                   # View-level helpers
│   │   │   ├── AvatarView.swift
│   │   │   ├── ImagePicker.swift
│   │   │   ├── PhotoCaptureView.swift
│   │   │   ├── ScoreColor.swift
│   │   │   ├── ZoomableImageView.swift
│   │   │   └── iPadLayout.swift       # adaptiveMaxWidth / AdaptiveHStack /
│   │   │                              # AdaptiveGridColumns / adaptiveCardPadding
│   │   │
│   │   ├── Admin/                     # Developer-only pages
│   │   │   └── DataAdminView.swift
│   │   │
│   │   └── OnBoarding/
│   │       └── WelcomeConfig.swift    # WSOnBoarding welcome
│   │
│   ├── Extensions/
│   │   ├── ColorExtensions.swift
│   │   └── DateExtensions.swift
│   │
│   └── NotificationsControl/
│       └── ExamPrepareNotifications.swift # Local notification scheduling
│
├── StudyPulseWidget/                  # WidgetKit sources (NOT wired into pbxproj yet)
│   ├── ExamWidget.swift               # Widget definition
│   ├── ExamWidgetData.swift           # Shared data model
│   ├── ExamWidgetEntry.swift          # Timeline entry
│   ├── ExamWidgetProvider.swift       # Timeline provider
│   ├── ExamWidgetViews.swift          # S / M / L widget UI
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
├── en.lproj/, zh-Hans.lproj/, zh-Hant.lproj/, ja.lproj/, ko.lproj/
│       └── Localizable.strings
│
├── AGENTS.md, CODE_WIKI.md, CODE_WIKI_CN.md, README.md, LICENSE
│
└── scripts/
    └── build.sh                       # Bash build helper (xcodebuild wrapper)
```

---

## 4. Data Models Reference

### 4.1 Model Summary Table

| Model | File | Type | ID Source | Codable | Sendable | Purpose |
|---|---|---|---|---|---|---|
| Subject | DataModels.swift | struct | UUID | Yes | Yes | User subject list, with customizable fullScore |
| Grade | DataModels.swift | struct | UUID | Yes | Yes | Single grade record (with imageFileName for persisted image) |
| MistakeNote | DataModels.swift | struct | UUID | Yes | Yes | Mistake note (4 sections, each with image file names) |
| Exam | DataModels.swift | struct | UUID | Yes | Yes | Single-subject exam |
| comprehensiveExam | DataModels.swift | struct | UUID | Yes | Yes | Multi-subject exam |
| UserProfile | DataModels.swift | struct | n/a | Yes | Yes | User profile (username, school, target school/score, avatarFileName, selectedSubjects, enrollment/exam years, regionCode, educationStage) |
| AppPreferences | AppPreferences.swift | struct | n/a | Yes | Yes | appLanguage, colorScheme (stored in UserDefaults) |
| HomeLayoutPreference | HomeLayoutPreference.swift | struct | n/a | Yes | Yes | ordered items (HomeCardItem array, with enabled flag) |
| EducationStage | DataModels.swift | enum | rawValue | Yes | Yes | primary / middle / high / internationalHigh / university / graduate |
| EducationCategory | DataModels.swift | enum | rawValue | Yes | Yes | domestic / international |
| SubjectConfig | DataModels.swift | struct | name | Yes | Yes | Subject definition in an EducationRegion (required / elective) |
| EducationRegion | DataModels.swift | struct | name | Yes | Yes | Regional education system (subjects, notes, systemCode) |

### 4.2 Subject Model

```swift
nonisolated struct Subject: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var displayName: String
    var enabled: Bool
    var fullScore: Double
}
```

### 4.3 Grade Model

```swift
nonisolated struct Grade: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var subject: String
    var score: Double
    var rawScore: Double?
    var ranking: Int?
    var importance: Int             // 1 ... 5
    var image: Data?                // legacy inline data; migrated to files
    var imageFileName: String?      // new file-based image (in images/)
    var date: Date
    var examName: String
    var fullScore: Double?          // per-record custom full-score

    func scoreRate(subjectFullScore: Double = 100) -> Double
}
```

### 4.4 MistakeNote Model

```swift
nonisolated struct MistakeNote: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var subject: String
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String

    // Per-section image files (in images/)
    var questionImages: [String]
    var reasonImages: [String]
    var wrongSolutionImages: [String]
    var correctSolutionImages: [String]
}
```

### 4.5 Exam / comprehensiveExam

```swift
nonisolated struct Exam: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var subject: String              // single subject
    var examDate: Date
    var importance: Int
    var masteryDegree: Int           // 0 ... 100
    var notes: String
}

nonisolated struct comprehensiveExam: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var subject: [String]            // multiple subjects
    var examDate: Date
    var importance: Int
    var masteryDegree: Int
    var notes: String
}
```

### 4.6 UserProfile

```swift
nonisolated struct UserProfile: Codable, Sendable {
    var username: String = "Student"
    var realName: String = ""
    var age: Int = 16
    var gender: String = "Not Specified"
    var grade: String = ""
    var className: String = ""
    var schoolName: String = ""
    var studentId: String = ""
    var enrollmentYear: Int
    var examYear: Int
    var targetSchool: String = ""
    var targetScore: Double = 0
    var educationStage: String        // EducationStage rawValue
    var regionCode: String             // EducationRegion name
    var selectedSubjects: [Subject] = []
    var theme: String = "Auto"
    var avatarFileName: String?
}
```

### 4.7 AppPreferences & HomeLayoutPreference

```swift
struct AppPreferences: Codable {
    var appLanguage: String?           // "en", "zh-Hans", ... nil = follow system
    var colorScheme: ColorSchemeOption
}

enum ColorSchemeOption: String, CaseIterable, Codable {
    case system, light, dark
}

struct HomeLayoutPreference: Codable {
    var items: [HomeCardItem]          // ordered; each has enabled flag
}

struct HomeCardItem: Codable, Identifiable, Hashable {
    var id: String { type.rawValue }
    var type: HomeCardType
    var enabled: Bool
}

enum HomeCardType: String, CaseIterable, Codable {
    case hrvStatus
    case unregisteredExamsReminder
    case quickActions
    case studySuggestions
    case trendChart
    case upcomingExams
    case dailyQuote
    case recentGrades
}
```

---

## 5. Managers Reference

### 5.1 Manager Summary Table

| Manager | File | Actor / Scope | Key Collaborators | Purpose |
|---|---|---|---|---|
| DataManager | DataManager.swift | @MainActor ObservableObject | All models, ImageCache, WidgetDataSyncManager | Central state & persistence |
| AppEnvironmentManager | AppEnvironmentManager.swift | @MainActor ObservableObject | AppPreferences, UserDefaults | Language + theme management |
| HealthKitManager | HealthKitManager.swift | @MainActor ObservableObject | HKHealthStore, HRVReadiness, HRVStatusCard | HRV (SDNN) readiness |
| CalendarManager | CalendarManager.swift | class singleton | EventKit | Add exams to system calendar |
| OCRManager | OCRManager.swift | class | Vision framework | Text recognition from images |
| ImageCache | ImageCache.swift | nonisolated class singleton | NSCache | Thumbnail caching (50 items, 300px) |
| EducationConfig | EducationConfig.swift | nonisolated enum | EducationRegion, SubjectConfig | Static education system registry |
| SubjectInfo | SubjectInfo.swift | class | SubjectConfig / Subject | Display names + color + max-score fallback |
| WidgetDataSyncManager | WidgetDataSyncManager.swift | class singleton | App Group container, WidgetCenter | Sync exam data to widget |
| DataExportManager | DataExportManager.swift | @MainActor enum | CSVDocument, FileDocument | CSV export for grades / mistakes / exams |

### 5.2 DataManager Flow

```
[View] taps Save
   |
   v
DataManager.save{Entity}() (@MainActor)
   |
   +---> update @Published property  →  SwiftUI refresh
   +---> JSONEncoder.encode(entity)  →  JSON Data
   +---> DataFileIO.write(data, to: ~/Documents/{file}.json)   (atomic)
   |
   +---> if exams changed → WidgetDataSyncManager.syncExamsToWidget()
                                                    |
                                                    v
                                          App Group container
                                          (group.com.chenkai.gao.studypulse)
                                                    |
                                                    v
                                          WidgetCenter.reloadTimelines()

[View] requests image
   |
   +---> ImageCache.thumbnail(for: filename)
   |        +---> cache hit → return UIImage
   |        +---> cache miss → load from disk → cache → return UIImage
   |
   +---> ZoomableImageView for full-screen pinch-zoom
```

### 5.3 EducationConfig → DataManager Smart Subject Recommendation

```
User selects EducationStage + EducationRegion on ProfileEditView
       |
       v
EducationConfig.availableRegions(for: stage)
       |
       v
[EducationRegion] list returned
       |
       v
User picks region → region.name stored in UserProfile.regionCode
       |
       v
"Apply Smart Recommendation" button → DataManager.applySmartSubjectRecommendation(stage, regionCode)
       |
       +---> look up EducationRegion via EducationConfig.region(name)
       +---> iterate region.subjects (SubjectConfig[])
       +---> map each SubjectConfig → Subject (fullScore, displayName, enabled)
       +---> replace UserProfile.selectedSubjects
       +---> saveProfile() / saveSubjects()
       |
       v
SwiftUI refreshes → new subjects visible in TrendsView / AddGradeView
```

---

## 6. Views Reference

### 6.1 Tab & Navigation Flow

```
ContentView
  |
  +-- iPhone  → TabView (5 tabs)
  |
  +-- iPad    → NavigationSplitView  (sidebar + detail)
                   |
                   v
             [Home] [Trends] [Mistakes] [Exams] [Settings]   --- navigation items
                     |
                     v
                    HomeView ────────┬──→ AddGradeView (sheet)
                      |               ├──→ NewExamSetView (sheet)
                      |               ├──→ NewMistakeSetView (sheet)
                      |               ├──→ HomeLayoutSettingsView (sheet)
                      |               ├──→ HRVOnboardingView (first-run sheet)
                      |               └──→ ExamDetailView (navigationDestination)
                      |
                    TrendsView ──────→ per-subject detail
                      |
                    MistakeView ─────→ MistakeDetailEditView (sheet or nav destination)
                      |                       |
                      |                       +-- OCRManager.recognizeText(in:)
                      |                       +-- PhotosPicker / ImagePicker
                      |                       +-- Markdown preview
                      |
                    ExamView ───────┬──→ NewExamSetView (+ button)
                      |              └──→ ExamDetailView (tap exam)
                      |                       |
                      |                       +--→ ExamDetailEditView (edit)
                      |                       +--→ MistakeDetailEditView (related mistake)
                      |
                    SettingsView ───┬──→ PreferencesView
                                     ├──→ ProfileEditView
                                     ├──→ EditSubjectsView
                                     ├──→ DataAdminView
                                     ├──→ AboutView
                                     └──→ CopyrightView
```

### 6.2 Views Summary Table

| View | File | Role | Key Features |
|---|---|---|---|
| ContentView | ContentView.swift | Root container | iPhone TabView (5 tabs) / iPad NavigationSplitView (sidebar list) |
| HomeView | HomeView.swift | Dashboard | Welcome header, stat cards, dynamic cards from HomeLayoutPreference, two-column LazyVGrid on iPad |
| TrendsView | TrendsView.swift | Trend analysis | Per-subject score cards, needs-attention alerts, `.adaptiveMaxWidth(900)` on iPad |
| MistakeView | MistakeView.swift | Mistake list | Suggested review section, search, card layout, `.adaptiveMaxWidth(900)` |
| ExamView | ExamView.swift | Exam list | Calendar integration, days-remaining countdown, `.adaptiveMaxWidth(800)` |
| ExamDetailView | ExamDetailView.swift | Exam detail | Related mistakes, mastery degree, notes |
| NewExamSetView | NewExamSetView.swift | Exam editor | Create / edit exam, calendar & reminder toggles |
| NewMistakeSetView | NewMistakeSetView.swift | New mistake | 4-section editing, photo + OCR per section, Markdown preview |
| MistakeDetailEditView | MistakeDetailEditView.swift | Mistake editor | Same editing features as NewMistakeSetView, EditSection enum |
| AddGradeView | AddGradeView.swift | Grade entry | Single / multi-subject input, custom full-score, raw score + ranking |
| SettingsView | SettingsView.swift | Settings | Profile card, edit profile/subjects, preferences, academic info, CSV export/import, about, `.adaptiveMaxWidth(720)` |
| ProfileEditView | ProfileEditView.swift | Profile editor | 12+ fields (school, grade, class, student ID, enrollment/exam years, target school/score) |
| EditSubjectsView | EditSubjectsView.swift | Subject editor | Per-subject full-score customization |
| PreferencesView | PreferencesView.swift | Preferences | Theme (system/light/dark); language (en/zh-Hans/zh-Hant/ja/ko/follow-system); `.adaptiveMaxWidth(640)` |
| HomeLayoutSettingsView | HomeLayoutSettingsView.swift | Home layout | Drag-to-reorder + per-card on/off toggle, persisted to UserDefaults |
| HRVOnboardingView | HRVOnboardingView.swift | HRV onboarding | 3-page explainer (what is HRV / privacy / consent) |
| DataAdminView | Views/Admin/DataAdminView.swift | Developer tool | Bulk data operations |
| AvatarView | Views/Helpers/AvatarView.swift | Reusable | Avatar display with first-letter fallback |
| SubjectScoreCard | Views/Helpers/SubjectScoreCard.swift | Reusable | Gradient border + entrance animation, mini chart |
| HRVStatusCard | Views/Components/HRVStatusCard.swift | Reusable | Three detail levels (suggestion only / data+suggestion / chart+data) |
| iPadLayout | Views/Helpers/iPadLayout.swift | Reusable | `adaptiveMaxWidth()`, `AdaptiveHStack`, `AdaptiveGridColumns`, `adaptiveCardPadding()` |

### 6.3 HomeView Card Slots

| Card Type | File | Default Enabled | Empty Hides | Purpose |
|---|---|---|---|---|
| hrvStatus | HRVStatusCard.swift | Yes, but hides when HRV is not enabled | No | Show HRV readiness indicator |
| unregisteredExamsReminder | HomeView.swift (inlined) | Yes | Yes | Warns about exams in the past 3–7 days without matching grade |
| quickActions | HomeView.swift (inlined) | Yes | No | Quick shortcuts to AddGradeView, NewExamSetView, NewMistakeSetView |
| studySuggestions | HomeView.swift (inlined) | Yes | No | Daily AI-style tips |
| trendChart | GradeChartView.swift | Yes | Yes | Chart of subject trends; hides when no recent grades |
| upcomingExams | HomeView.swift (inlined) | Yes | Yes | List of upcoming exams, tap → ExamDetailView |
| dailyQuote | HomeView.swift (inlined) | Yes | No | Daily inspirational quote |
| recentGrades | HomeView.swift (inlined) | Yes | Yes | Last 5 grades |

HomeView rendering order comes from `HomeLayoutPreference.load().enabledTypes`.

---

## 7. Home Card System

### 7.1 Card Type Listing

| HomeCardType | UI Component | Controlled By | Persistence |
|---|---|---|---|
| hrvStatus | HRVStatusCard | HealthKitManager.hrvEnabled + HomeLayoutPreference | UserDefaults (HomeLayoutPreference) |
| unregisteredExamsReminder | Inline in HomeView | DataManager grades vs exams (3–7 day window) | UserDefaults (HomeLayoutPreference) |
| quickActions | Inline in HomeView | Static | UserDefaults (HomeLayoutPreference) |
| studySuggestions | Inline in HomeView | Static / computed from data | UserDefaults (HomeLayoutPreference) |
| trendChart | GradeChartView | DataManager.grades (only visible when recent grades exist) | UserDefaults (HomeLayoutPreference) |
| upcomingExams | Inline in HomeView | DataManager.examSets + comprehensiveExamSets | UserDefaults (HomeLayoutPreference) |
| dailyQuote | Inline in HomeView | Static | UserDefaults (HomeLayoutPreference) |
| recentGrades | Inline in HomeView | DataManager.grades | UserDefaults (HomeLayoutPreference) |

### 7.2 Persistence Flow

```
User opens HomeLayoutSettingsView
       |
       v
HomeLayoutPreference.load() ← reads from UserDefaults
       |
       v
User drags to reorder, toggles on/off
       |
       v
HomeLayoutPreference.save() → writes to UserDefaults
       |
       v
HomeView.body reads enabledTypes → renders cards in user-defined order
       (iPad: two-column LazyVGrid; iPhone: single VStack)
```

### 7.3 mergeWithDefault When New Cards Are Added

```
App update ships with a new HomeCardType
       |
       v
HomeLayoutPreference.load()
       |
       +---> existing items (from UserDefaults) are kept in order
       +---> new card types, not yet present, are appended with enabled = true
       +---> any old unknown card types are removed
       |
       v
User sees old ordering preserved + new cards enabled at the end
```

---

## 8. Education Systems

### 8.1 System Tree

```
Education Systems (EducationConfig)
|
+-- Domestic
|   +-- China (Mainland Standard)
|   |   +-- Primary School
|   |   +-- Middle School
|   |   +-- High School
|   |
|   +-- Zhejiang
|   |   +-- Middle School
|   |   +-- High School (3+3)
|   |
|   +-- Shanghai
|   |   +-- Middle School
|   |   +-- High School (3+3)
|   |
|   +-- Taiwan
|   |   +-- Middle School
|   |   +-- GSAT (学测)
|   |
|   +-- Hong Kong
|       +-- DSE
|
|   +-- Singapore
|       +-- O-Level
|
+-- International
    +-- United Kingdom
    |   +-- IGCSE
    |   +-- A-Level
    |
    +-- IB
    |   +-- Diploma Programme (DP)
    |
    +-- United States
    |   +-- AP (Advanced Placement)
    |   +-- SAT (Scholastic Assessment Test)
    |   +-- ACT (American College Testing)
    |
    +-- Graduate & Language
        +-- GRE
        +-- GMAT
        +-- TOEFL
        +-- IELTS
```

### 8.2 Coverage Matrix

| Region | Primary | Middle | High School | Intl High School | University | Graduate |
|---|---|---|---|---|---|---|
| China Mainland | Yes | Yes | Yes | - | - | - |
| Zhejiang | - | Yes | Yes (3+3) | - | - | - |
| Shanghai | - | Yes | Yes (3+3) | - | - | - |
| Taiwan | - | Yes | Yes (学测) | - | - | - |
| Hong Kong | - | - | Yes (DSE) | - | - | - |
| Singapore | - | Yes (O-Level) | Yes (O-Level) | Yes | - | - |
| UK IGCSE | - | Yes | - | Yes | - | - |
| UK A-Level | - | - | Yes | Yes | - | - |
| IB Diploma | - | - | Yes | Yes | - | - |
| US AP | - | - | Yes | Yes | - | - |
| US SAT | - | - | - | - | Yes | - |
| US ACT | - | - | - | - | Yes | - |
| GRE / GMAT | - | - | - | - | - | Yes |
| TOEFL / IELTS | - | - | - | - | - | Yes |

### 8.3 Score Scale Reference

| System | Typical Scale | Example Subject Scores |
|---|---|---|
| China Mainland High | 100 / 150 | Chinese 150, Physics 100 |
| Zhejiang High (赋分) | 100 | All subjects 100 max |
| Hong Kong DSE | 1-7 (5** = 7) | All subjects 7 max |
| Taiwan 学测 | 100 | Math A / Math B each 100 |
| UK A-Level | 100 | A* = 90+ |
| IB DP | 1-7 | 6 subjects + TOK + EE = 45 max |
| US AP | 1-5 | 5 = max |
| US SAT | 200-800 | 1600 total |
| US ACT | 1-36 | 36 = max |
| GRE | 130-170 | 340 total |
| TOEFL | 0-120 | - |
| IELTS | 0-9 | - |

### 8.4 SubjectConfig Factories

```swift
// Required subject
SubjectConfig.required(name, displayName, fullScore, category)
// Elective subject
SubjectConfig.elective(name, displayName, fullScore, category)
```

Each EducationRegion.subjects is an array of SubjectConfig, which maps to Subject with the same name + displayName + fullScore.

---

## 9. HRV / HealthKit Subsystem

### 9.1 Architecture

```
+-----------------------------+
|  HealthKitManager            |
|  (@MainActor ObservableObject)|
|   - hrvEnabled: Bool          |
|   - hrvOnboardingCompleted    |
|   - isAuthorized: Bool        |
|   - readiness: HRVReadiness   |
|     (z-score, category, suggestion)
|   - dailyHRVHistory: [HRVSample]
|   - lastSampleCount: Int      |
|   - hrvDetailLevel: HRVDetailLevel (suggestionOnly/data/chart)
+--------------+---------------+
               | read HRV samples
               v
+-----------------------------+
|   HKHealthStore              |
|   heartRateVariabilitySDNN   |
|   (14-day window of samples) |
+--------------+---------------+
               |
               v
+-----------------------------+        +-----------------------------+
|  HRVStatusCard (HomeView)    |        |  HRVOnboardingView          |
|  (renders 1 of 3 detail      |        |  (3-page explainer +        |
|   levels based on hrvDetailLevel)    |   HealthKit authorization)  |
+-----------------------------+        +-----------------------------+
```

### 9.2 Readiness Calculation Flow

```
User opens HomeView (or taps "Refresh")
       |
       v
HealthKitManager.refreshReadiness()
       |
       +---> HKHealthStore.requestAuthorization (if needed)
       +---> HKSampleQuery for heartRateVariabilitySDNN, last 14 days
       |
       +---> Aggregate per calendar day (first sample per day, sorted desc)
       |
       +---> Baseline: mean + std of days AFTER today (requires ≥ 7 distinct days)
       |
       +---> z-score = (today_SDNN − mean) / stdDev
       |
       +---> Category:
       |       excellent (z > 1)
       |       normal    (-1 ≤ z ≤ 1)
       |       low       (z < -1)
       |       insufficient (< 7 days)
       |       noAuthorization
       |       queryFailed
       |
       +---> Suggestion string (localized)
       |
       v
@Published readiness updated → SwiftUI re-render HRVStatusCard
```

### 9.3 Category Table

| Category | Z-score Range | Suggestion Direction |
|---|---|---|
| excellent | z > 1 | "High recovery today — tackle challenging study." |
| normal | -1 ≤ z ≤ 1 | "Steady as usual — follow your plan." |
| low | z < -1 | "Low recovery — consider lighter tasks today." |
| insufficient | < 7 distinct days | "Wear your Apple Watch more often to establish a baseline." |
| noAuthorization | HealthKit denied | "Grant HealthKit access to see your HRV readiness." |
| queryFailed | Query error | "Something went wrong — try again later." |

---

## 10. Image, OCR and CSV Pipelines

### 10.1 Image Pipeline

```
Capture Flow:
  PhotoCaptureView (camera) / ImagePicker (photo library)
          |
          v
     original image
          |
          v
     JPEG compression (Data)
          |
          v
     DataManager.saveGradeImage(data) or saveAvatar(data)
          |
          v
     generate filename (grade_UUID.jpg / avatar_UUID.jpg)
          |
          v
     DataFileIO.write to ~/Documents/images/
          |
          v
     filename stored back in Grade.imageFileName or UserProfile.avatarFileName

Display Flow:
  SwiftUI view (HomeView, ExamDetailView, ProfileEditView, ...)
          |
          v
     ImageCache.thumbnail(for: filename) — nonisolated, thread-safe
          |
          +-- cache hit → return UIImage
          +-- cache miss → load from disk → cache → return UIImage
          |
          v
     Full-screen → ZoomableImageView (pinch + double-tap zoom)
```

### 10.2 OCR Pipeline

```
User selects image in MistakeDetailEditView (Question/Reason/Wrong/Correct)
          |
          v
     OCRManager.shared.recognizeText(in: imageData)
          |
          +---> VNRecognizeTextRequest
          |       recognitionLevel = .accurate
          |       recognitionLanguages = ["zh-Hans", "en"]
          |
          +---> completion handler returns top-candidate string per observation
          |
          v
     Recognized text populated into the section text field
```

### 10.3 CSV Pipeline

```
User taps "Export" in SettingsView
          |
          v
     DataExportManager.build{Kind}CSV()  (@MainActor enum)
          |
          +-- headers
          +-- rows (properly escaped: commas, quotes, newlines)
          |
          v
     CSV String → CSVDocument (FileDocument) → UIActivityViewController → share / save
```

### 10.4 ImageCache Spec

| Property | Value |
|---|---|
| Scope | nonisolated class (Sendable-safe) |
| Singleton | `ImageCache.shared` |
| Max items | 50 |
| Max dimension | 300 px |
| Key source | filename (in `~/Documents/images/`) |
| Backing store | NSCache with cost-based eviction |

---

## 11. iPad Adaptation

### 11.1 iPad Layout Helpers

| Helper | File | Purpose |
|---|---|---|
| adaptiveMaxWidth(_:) | iPadLayout.swift | Center content on iPad; default 720 |
| AdaptiveHStack | iPadLayout.swift | HStack on iPad, VStack on iPhone |
| AdaptiveGridColumns(compact:regular:spacing:) | iPadLayout.swift | Grid columns — compact value for iPhone, regular value for iPad |
| adaptiveCardPadding() | iPadLayout.swift | 20pt outer padding on iPhone, 0 on iPad |

### 11.2 Per-view Maximum Widths

| View | Max Width (iPad) | Notes |
|---|---|---|
| PreferencesView | 640 | Language + theme pickers |
| SettingsView | 720 | Settings hub |
| ExamView | 800 | Exam list + upcoming |
| TrendsView | 900 | Per-subject charts |
| MistakeView | 900 | Mistake cards |
| HomeView | 1100 | Two-column LazyVGrid for dynamic cards; single-column stat header |

### 11.3 Root Layout Switch

```
ContentView
  ┌─ horizontalSizeClass
  │
  ├─ .compact → TabView { HomeView / TrendsView / MistakeView / ExamView / SettingsView }
  │
  └─ .regular → NavigationSplitView
                  ├ sidebar: List with NavigationLink(value: tab)
                  │         [Home] [Trends] [Mistakes] [Exams] [Settings]
                  │
                  └ detail: current tab view, wrapped in adaptiveMaxWidth()
```

### 11.4 Adaptation Principles

1. iPhone layouts are unchanged — all iPad-specific branches depend on `horizontalSizeClass == .regular` or `UIDevice.current.userInterfaceIdiom == .pad`.
2. Content is centered, not stretched to the edges.
3. Use the helpers in iPadLayout.swift instead of inline size-class branches in feature views.
4. The sidebar uses `.listStyle(.sidebar)` with `NavigationLink(value: tab)`.

---

## 12. Localization

### 12.1 Supported Languages

| Language | Key | Folder |
|---|---|---|
| English | en | en.lproj/Localizable.strings |
| Simplified Chinese | zh-Hans | zh-Hans.lproj/Localizable.strings |
| Traditional Chinese | zh-Hant | zh-Hant.lproj/Localizable.strings |
| Japanese | ja | ja.lproj/Localizable.strings |
| Korean | ko | ko.lproj/Localizable.strings |

### 12.2 String.localized() Extension

```swift
// StringsLocalized.swift
extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}
```

Usage in views:

```swift
Text("home.welcome.title".localized)
```

### 12.3 Language Switching Flow

```
User opens PreferencesView → taps Language
         |
         v
AppEnvironmentManager.shared.setLanguage("zh-Hans")
         |
         +---> update preferences.appLanguage
         +---> write preferences to UserDefaults
         +---> set AppleLanguages in UserDefaults
         |
         v
Root view re-renders with new locale
```

On launch: `AppEnvironmentManager.shared.applyLanguageOnLaunch()` is called from `StudyPulseApp.init`, which applies the persisted language (if any).

---

## 13. Privacy Permissions

| Info.plist Key | Usage | Reason |
|---|---|---|
| NSCameraUsageDescription | Camera access | Take photos of mistakes to attach to MistakeNote |
| NSPhotoLibraryUsageDescription | Photo library | Select photos from photo library to attach |
| NSCalendarsUsageDescription | Calendar access | Add exams to system calendar |
| NSHealthShareUsageDescription | HealthKit | Read HRV (SDNN) samples to compute readiness; app does NOT write |

Entitlements:

| Entitlement | Value | Purpose |
|---|---|---|
| com.apple.developer.healthkit | true | Enable HealthKit APIs |

Note: NSHealthUpdateUsageDescription is NOT declared because the app never writes to HealthKit.

---

## 14. Widget Extension

### 14.1 Architecture

```
+-----------------------------------+
|     Main App (StudyPulse)         |
|                                   |
|  DataManager.saveExams() /        |
|    saveComprehensiveExams()       |
|           |                       |
|           v                       |
|  WidgetDataSyncManager            |
|   .syncExamsToWidget(exams)       |
|           |                       |
|           v                       |
|  App Group Container              |
|  (group.com.chenkai.gao.studypulse)|
|                                   |
+-----------+-----------------------+
            |
            v
+-----------+-----------------------+
|  StudyPulseWidget Extension        |
|                                    |
|  ExamWidgetProvider.getTimeline()  |
|           |                        |
|           +-- load ExamWidgetData  |
|               from App Group       |
|           +-- build TimelineEntry  |
|           +-- return to System     |
|                                    |
|  ExamWidgetViews (S / M / L)       |
|  rendered by WidgetKit             |
+------------------------------------+
```

### 14.2 Components

| Component | File | Purpose |
|---|---|---|
| ExamWidget | StudyPulseWidget/ExamWidget.swift | Widget definition |
| ExamWidgetData | StudyPulseWidget/ExamWidgetData.swift | Shared data model (name, subject, examDate, daysRemaining) |
| ExamWidgetEntry | StudyPulseWidget/ExamWidgetEntry.swift | Timeline entry |
| ExamWidgetProvider | StudyPulseWidget/ExamWidgetProvider.swift | Timeline provider |
| ExamWidgetViews | StudyPulseWidget/ExamWidgetViews.swift | Small / Medium / Large widget UI |
| StudyPulseWidgetBundle | StudyPulseWidget/StudyPulseWidgetBundle.swift | @main bundle |

### 14.3 How to Enable

1. Add a Widget Extension target in Xcode with bundle ID `Gao.Chenkai.StudyPulse.Widget` and deployment target iOS 18.6.
2. Enable App Group `group.com.chenkai.gao.studypulse` on BOTH the main app target AND the widget target.
3. If you change the App Group identifier, update `AppGroupConfig.identifier`.
4. Call `WidgetDataSyncManager.syncExamsToWidget()` after any exam add/edit in the main app, and also when the app becomes active.
5. Call `WidgetCenter.shared.reloadAllTimelines()` after writes.

---

## 15. Dependencies (SPM)

| Package | Source | Purpose |
|---|---|---|
| WSOnBoarding | Local package (Swift/Packages/WSOnBoarding) | First-launch welcome flow |
| swift-markdown-ui | Local package (Swift/Packages/swift-markdown-ui) | Markdown preview in MistakeView |
| NetworkImage | https://github.com/gonzalezreal/NetworkImage @ 6.0.1 | Async image loading |
| cmark-gfm | (internal) | Markdown parser core |

Apple frameworks used:

- SwiftUI
- Charts
- Vision
- EventKit
- UserNotifications
- HealthKit
- WidgetKit
- UniformTypeIdentifiers
- PhotosUI

---

## 16. Build & Run

### 16.1 Build Helper (scripts/build.sh)

| Command | Effect |
|---|---|
| `./scripts/build.sh` | Debug build, iPhone 17 simulator |
| `./scripts/build.sh release` | Release build |
| `./scripts/build.sh clean` | Clean build folder |
| `./scripts/build.sh list` | List available simulators |
| `./scripts/build.sh help` | Show all options |

### 16.2 Direct xcodebuild

```bash
xcodebuild \
  -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

### 16.3 Available Schemes & Configurations

| Kind | Values |
|---|---|
| Schemes | StudyPulse, MarkdownUI, WSOnBoarding |
| Configurations | Debug, Release |

### 16.4 Resolving Packages

In Xcode: File → Packages → Resolve Package Versions

On the command line:

```bash
xcodebuild -resolvePackageDependencies -project StudyPulse.xcodeproj
```

---

## 17. Coding Standards

| Area | Rule |
|---|---|
| Concurrency | Swift 6 Strict Concurrency; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; `@MainActor` for state-holding managers; `nonisolated` for pure helpers and I/O |
| Models | Codable, nonisolated, Sendable value types; no class-based models |
| Views | Place under `Views/` with subdirectories `Components/`, `Helpers/`, `Admin/`, `OnBoarding/` |
| Managers | Place under `Managers/`; own `@Published` state → mark `@MainActor` |
| Strings | Always use `"key".localized` — **never** write inline English |
| Colors / Dates | Use `ColorExtensions` / `DateExtensions` wrappers |
| Images | Persist as files in `~/Documents/images/` via `DataManager.saveGradeImage()` / `saveAvatar()` — never inline JSON (`Grade.image` legacy) |
| Mistake editing | Driven by `EditSection` enum (Question / Reason / Wrong / Correct) |
| Education systems | Always use `EducationConfig` (nonisolated enum) with `SubjectConfig` factories (`required(...)` / `elective(...)`) |
| iPad adaptation | Prefer helpers in `iPadLayout.swift` instead of inline size-class branches |
| Project file | Do not edit `StudyPulse.xcodeproj/project.pbxproj` by hand — let Xcode manage it |
| After every non-trivial code change | Run build (Xcode Cmd+B or `./scripts/build.sh`) and ensure no syntax / type errors |

---

## 18. Performance Notes

| Optimization | Details |
|---|---|
| Async startup | `StudyPulseApp` calls `dataManager.asyncInit()` in `.task` — JSON is loaded off the main thread; legacy sync `load*()` methods kept for backward compat |
| Image caching | `ImageCache.shared` — NSCache with 50 entries, 300 px max; fully thread-safe (nonisolated) |
| Days-remaining | `ExamRowView`, `ComprehensiveExamRowView`, `UpcomingExamCard` use computed `daysRemaining` rather than `@State + onAppear` to avoid spurious re-renders |
| iPad HomeView | Renders dashboard in a two-column `LazyVGrid` to keep memory low even when many cards are enabled |

---

## 19. Known Issues / TODO

| Issue | Status | Impact |
|---|---|---|
| Widget Extension target not wired into `StudyPulse.xcodeproj` | Open | WidgetKit sources exist but are not built; requires manual Xcode target creation |
| App Group identifier not enabled on main app target | Open | App Group must be created in Apple Developer portal and enabled on both main app target and widget target |
| No iCloud sync | Open | All data is local to the device sandbox |
| `NewMistakeSheet.swift` / `Views/Sheets/` removed | Closed (historical) | Active flow is `NewMistakeSetView`; do not re-create the old paths |

---

## 20. Changelog (Agent-Facing)

### v2026.06.20 — Home layout + HRV subsystem

- Added HealthKitManager.swift, HRVOnboardingView.swift, HRVStatusCard.swift for HRV (SDNN) readiness (14-day baseline + Z-score category).
- Added HomeLayoutPreference.swift and HomeLayoutSettingsView.swift for per-card on/off + drag-to-reorder (persisted to UserDefaults).
- Added Views/Admin/DataAdminView.swift for power-user bulk data ops.
- Rewrote ContentView with custom NavigationSplitView sidebar for iPad (replaces `.sidebarAdaptable`); iPhone keeps classic TabView.
- HomeView composes its dashboard from `HomeLayoutPreference.load().enabledTypes` using HomeCardType cases.
- Added "Unregistered Exams Reminder" card (3–7 day window after an exam with no matching grade).
- StudyPulse.entitlements now includes `com.apple.developer.healthkit`.
- Rewrote AGENTS.md / CODE_WIKI.md / CODE_WIKI_CN.md / README.md.

### v2026.06.13 — iPad adaptation

- iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) via iPadLayout.swift helpers (`adaptiveMaxWidth`, `AdaptiveHStack`, `AdaptiveGridColumns`, `adaptiveCardPadding`).

### v2026.06.07 — Full view-layer refactor + design system

- HomeView split into components; gradient + animation polish.
- MistakeView suggested review + card gradient.
- TrendsView "Subjects Needing Attention" smart alerts.
- ExamDetailView related mistakes section.
- SubjectScoreCard gradient border + entrance animation.
- AppStyle design-system skeleton.
- First StudyPulseWidget skeleton.

### v2026.06.06 — Multi-language

- zh-Hant, ja, ko localizations added.

### v2026.06.05 — Mistake module launch

- 4-section mistake editor (Question / Reason / Wrong / Correct).
- Per-section photo + OCR (Vision).
- Markdown preview (swift-markdown-ui).
- Calendar / notification auto-scheduling.
- Zoomable image viewer.

### v2026.06 — Global education systems

- EducationConfig for 15+ systems (CN, UK, IB, AP, SAT, ACT, GRE, GMAT, TOEFL, IELTS, DSE, etc.).
- SubjectConfig factories (`required(...)`, `elective(...)`).
- Avatar system, proportional score-color mapping, expanded profile.
