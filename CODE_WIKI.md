# StudyPulse Code Wiki

> 一款综合性学习管理应用，帮助学生追踪学业表现、分析学习趋势，并高效管理学习资料。

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Tech Stack & Requirements](#2-tech-stack--requirements)
- [3. Project Structure](#3-project-structure)
- [4. Architecture Design](#4-architecture-design)
- [5. Data Models](#5-data-models)
- [6. Core Managers](#6-core-managers)
- [7. View Layer](#7-view-layer)
- [8. Components & Helpers](#8-components--helpers)
- [9. Extensions](#9-extensions)
- [10. Notification System](#10-notification-system)
- [11. Internationalization](#11-internationalization)
- [12. Dependencies](#12-dependencies)
- [13. Data Flow](#13-data-flow)
- [14. How to Run](#14-how-to-run)
- [15. Build Configuration](#15-build-configuration)

---

## 1. Project Overview

| Item | Description |
|------|-------------|
| **App Name** | StudyPulse |
| **Bundle Identifier** | `Gao.Chenkai.StudyPulse` |
| **Version** | 1.0 (Marketing Version) |
| **Developer** | Gao-Chenkai |
| **License** | CC BY-NC-SA 4.0 |

### Core Features

| Feature | Description |
|---------|-------------|
| **Multi-subject Grade Tracking** | Record scores across multiple subjects with raw score and ranking support |
| **Interactive Chart Visualization** | Use Apple's Charts framework to visualize score trends and rankings |
| **Exam Management** | Create, view, and manage single-subject and comprehensive exams with countdown |
| **Mistake Collection** | Organize wrong questions with detailed analysis (title, error reason, wrong solution, correct solution) |
| **Photo Upload** | Capture or select photos for exam papers and mistake notes |
| **Exam Notifications** | Local notifications with 30/10/5/3/1 day countdown reminders |
| **User Profile** | Store education level, system, region, and selected subjects |
| **Daily Motivational Quotes** | 14 rotating inspirational quotes displayed on the home page |

---

## 2. Tech Stack & Requirements

| Layer | Technology |
|-------|------------|
| **UI Framework** | SwiftUI |
| **Language** | Swift 6.0 |
| **Minimum OS** | iOS 18.6 |
| **Xcode Version** | Xcode 26.x |
| **Charts** | Apple Charts framework (native) |
| **Data Persistence** | JSON file serialization in Documents directory |
| **Onboarding** | WSOnBoarding (third-party package) |
| **Notifications** | UserNotifications framework |
| **Camera/Gallery** | UIKit UIImagePickerController (via UIViewControllerRepresentable) |

### Supported Platforms

- iPhone (`iphoneos`)
- iPad Simulator (`iphonesimulator`)
- Mac Catalyst: **Not supported**

---

## 3. Project Structure

```
StudyPulse/
├── StudyPulse.xcodeproj/          # Xcode project configuration
│   └── project.pbxproj
│
├── StudyPulse/                    # Main app source
│   ├── StudyPulseApp.swift        # App entry point
│   │
│   ├── Models/
│   │   └── DataModels.swift       # Core data models (Subject, Grade, Exam, etc.)
│   │
│   ├── Managers/
│   │   ├── DataManager.swift      # Central data management & persistence
│   │   ├── StringsLocalized.swift # String localization extension
│   │   └── SubjectInfo.swift      # Max score calculation by education level
│   │
│   ├── Extensions/
│   │   ├── ColorExtensions.swift  # UIColor → Color bridge
│   │   └── DateExtensions.swift   # Date formatting helper
│   │
│   ├── NotificationsControl/
│   │   └── ExamPrepareNotifications.swift  # Local notification scheduling
│   │
│   ├── Views/
│   │   ├── ContentView.swift      # Main TabView navigation
│   │   ├── HomeView.swift         # Dashboard with stats & trends
│   │   ├── TrendsView.swift       # Score trend charts
│   │   ├── ExamView.swift         # Exam list with grouping
│   │   ├── ExamDetailView.swift   # Single exam detail display
│   │   ├── ExamDetailEditView.swift # Edit exam detail form
│   │   ├── NewExamSetView.swift   # Create new exam form
│   │   ├── AddGradeView.swift     # Add grade entry form
│   │   ├── MistakeView.swift      # Mistake collection list
│   │   ├── MistakeDetailEditView.swift # Edit mistake detail
│   │   ├── NewMistakeSetView.swift # Create new mistake entry
│   │   ├── SettingsView.swift     # User profile & settings
│   │   ├── SubjectScoreCard.swift # Subject score card with mini chart
│   │   │
│   │   ├── Components/
│   │   │   ├── GradeChartView.swift    # Line chart for grades
│   │   │   └── SubjectPickerView.swift # Subject selection picker
│   │   │
│   │   ├── Helpers/
│   │   │   ├── BackgroundColors.swift  # Adaptive background color
│   │   │   ├── ImagePicker.swift       # Photo library picker
│   │   │   ├── PhotoCaptureView.swift  # Camera capture
│   │   │   └── ScoreColor.swift        # Score-to-color mapping
│   │   │
│   │   ├── OnBoarding/
│   │   │   └── WelcomeConfig.swift     # Onboarding screen config
│   │   │
│   │   └── Sheets/
│   │       └── NewMistakeSheet.swift   # New mistake sheet view
│   │
│   ├── StudyPulseIcon.icon/      # App icon configuration
│   └── Assets.xcassets/          # Image & color assets
│
├── zh-Hans.lproj/
│   └── Localizable.strings       # Chinese (Simplified) translations
├── en.lproj/
│   └── Localizable.strings       # English strings
│
├── README.md                     # Project readme
├── LICENSE                       # CC BY-NC-SA 4.0 license
└── .gitignore
```

---

## 4. Architecture Design

StudyPulse follows a **MVVM-inspired architecture** with SwiftUI's declarative paradigm:

```
┌─────────────────────────────────────────────────────────┐
│                     View Layer (SwiftUI)                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ HomeView │ │TrendsView│ │ ExamView │ │SettingsView│  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       └─────────────┴────────────┴────────────┘         │
│                         │                               │
│              @EnvironmentObject<DataManager>             │
└─────────────────────────┼───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                  Manager Layer                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│  │ DataManager  │ │ SubjectInfo  │ │ExamPrepareNotif. │ │
│  │ (Observable) │ │ (Helper)     │ │ (Scheduler)      │ │
│  └──────┬───────┘ └──────────────┘ └──────────────────┘ │
│         │                                                │
│   JSON Persistence (Documents/)                         │
└─────────┼───────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────┐
│                   Model Layer                            │
│  ┌────────┐ ┌───────┐ ┌──────────┐ ┌──────────┐        │
│  │ Subject│ │ Grade │ │  Exam    │ │MistakeNote│       │
│  └────────┘ └───────┘ └──────────┘ └──────────┘        │
│  ┌──────────────────┐ ┌──────────┐                      │
│  │comprehensiveExam │ │UserProfile│                     │
│  └──────────────────┘ └──────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Patterns

| Pattern | Implementation |
|---------|---------------|
| **Centralized State** | `DataManager` as `@StateObject` at app root, passed via `@EnvironmentObject` |
| **Observable Data** | `DataManager` conforms to `ObservableObject` with `@Published` properties |
| **Navigation** | `TabView` with 4 tabs (Home, Trends, Exams, Settings); `NavigationStack` within each tab |
| **Sheet Presentation** | `.sheet` modifier for forms (AddGradeView, NewExamSetView, etc.) |
| **Data Persistence** | JSON encoding/decoding to files in `FileManager.default.urls(for: .documentDirectory)` |
| **Reactive Updates** | `@Published` triggers automatic UI refresh on data changes |

---

## 5. Data Models

All data models are defined in [DataModels.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Models/DataModels.swift) and conform to `Identifiable`, `Codable`, and `Equatable`.

### 5.1 Subject

```swift
class Subject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String      // e.g., "Chinese", "Mathematics"
    var enabled: Bool     // Whether the subject is active
}
```

Represents a single academic subject. Used for filtering grades, selecting subjects in exams, and configuring user profiles.

### 5.2 Grade

```swift
struct Grade: Identifiable, Codable, Equatable {
    let id: UUID
    var subject: String        // Subject name
    var score: Double?         // Normalized score (0-100 scale)
    var rawScore: Double?      // Original exam score
    var ranking: Int?          // Class/school ranking
    var importance: Int        // 1-5 stars importance
    var image: String?         // Photo filename
    var date: Date             // Exam date
    var examName: String       // Associated exam name
}
```

Records a single grade entry for a subject. Supports both normalized scores and raw scores.

### 5.3 MistakeNote

```swift
struct MistakeNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String                  // Title of the mistake note
    var originalQuestion: String       // The original question text
    var source: String                 // Source (which exam)
    var date: Date                     // Date recorded
    var errorReason: String            // Why the mistake was made
    var wrongSolution: String          // The incorrect solution attempted
    var correctSolution: String        // The correct solution
    var images: [String]               // Associated photo filenames
}
```

A detailed mistake/错题 record with four-section analysis structure.

### 5.4 UserProfile

```swift
struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var username: String
    var age: Int
    var educationLevel: String      // "Primary School", "Middle School", "High School"
    var educationSystem: String     // e.g., "Chinese", "IB", etc.
    var region: String              // Geographic region
    var selectedSubjects: [String]  // Active subject names
    var theme: String               // UI theme preference
}
```

Stores user's personal and academic information. Used for score normalization and personalized display.

### 5.5 Exam

```swift
struct Exam: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var examDate: Date
    var importance: Int             // 1-5 stars
    var subject: String             // Single subject
    var examName: String            // Parent exam name
    var masteryDegree: Double       // 0.0 - 1.0 mastery percentage
}
```

Single-subject exam entry with countdown and mastery tracking.

### 5.6 ComprehensiveExam

```swift
struct ComprehensiveExam: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var examDate: Date
    var importance: Int
    var subject: [String]           // Multiple subjects
    var examName: String
    var masteryDegree: Double
}
```

Multi-subject exam that bundles several subjects under one exam event.

---

## 6. Core Managers

### 6.1 DataManager

**File:** [DataManager.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/DataManager.swift)

The central data management hub. Conforms to `ObservableObject` and manages all app data with JSON persistence.

#### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `grades` | `[Grade]` | All recorded grades |
| `subjects` | `[Subject]` | Available academic subjects |
| `mistakeSets` | `[MistakeNote]` | All mistake notes |
| `examSets` | `[Exam]` | All single-subject exams |
| `comprehensiveExamSets` | `[ComprehensiveExam]` | All comprehensive exams |
| `profile` | `UserProfile` | Current user profile |

#### Key Methods

| Method | Description |
|--------|-------------|
| `init()` | Initializes default subjects and loads all data from JSON files |
| `loadData()` | Reads all JSON files from Documents directory and decodes into arrays |
| `saveData()` | Encodes all data arrays to JSON files in Documents directory |
| `getDocumentsDirectory()` | Returns the URL for the app's Documents directory |
| `addGrade(_:)` | Appends a grade and saves |
| `removeGrade(_:)` | Deletes a grade and saves |
| `addSubject(_:)` | Appends a subject and saves |
| `removeSubject(_:)` | Deletes a subject and saves |
| `toggleSubject(_:)` | Toggles a subject's enabled state |
| `addMistakeSet(_:)` | Appends a mistake note and saves |
| `removeMistakeSet(_:)` | Deletes a mistake note and saves |
| `addExamSet(_:)` | Appends an exam and saves |
| `removeExamSet(_:)` | Deletes an exam and saves |
| `addComprehensiveExam(_:)` | Appends a comprehensive exam and saves |
| `removeComprehensiveExam(_:)` | Deletes a comprehensive exam and saves |
| `updateExam(_:)` | Updates an existing exam and saves |
| `updateComprehensiveExam(_:)` | Updates an existing comprehensive exam and saves |
| `updateProfile(_:)` | Updates user profile and saves |

#### Data Persistence Format

Each data type is stored as a separate JSON file:

| File | Content |
|------|---------|
| `grades.json` | Array of Grade objects |
| `subjects.json` | Array of Subject objects |
| `mistakeSets.json` | Array of MistakeNote objects |
| `examSets.json` | Array of Exam objects |
| `comprehensiveExamSets.json` | Array of ComprehensiveExam objects |
| `profile.json` | Single UserProfile object |

#### Default Subjects

Initialized on first launch:

| Subject | Enabled |
|---------|---------|
| Chinese | Yes |
| Mathematics | Yes |
| English | Yes |
| Science | Yes |
| History & Society | Yes |
| Physics | Yes |
| Chemistry | Yes |
| Biology | Yes |
| History | Yes |
| Geography | Yes |
| Politics | Yes |
| Information Technology | Yes |
| General Technology | Yes |
| Art | Yes |
| Music | Yes |
| PE & Health | Yes |

### 6.2 SubjectInfo

**File:** [SubjectInfo.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/SubjectInfo.swift)

Helper class that calculates maximum possible scores based on education level and subject.

```swift
func getMaxScore(level: String, subject: String) -> Double
```

| Education Level | Subject | Max Score |
|-----------------|---------|-----------|
| Primary School | All | 100 |
| Middle School | Chinese, Mathematics, English | 120 |
| Middle School | Science | 160 |
| Middle School | Others | 100 |
| High School | Chinese, Mathematics, English | 150 |
| High School | Others | 100 |

Used for score normalization (converting raw scores to percentage-based scores).

### 6.3 StringsLocalized

**File:** [StringsLocalized.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/StringsLocalized.swift)

Simple extension on `String` that provides a shorthand for `NSLocalizedString`:

```swift
extension String {
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}
```

---

## 7. View Layer

### 7.1 App Entry Point

**File:** [StudyPulseApp.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/StudyPulseApp.swift)

```swift
@main
struct StudyPulseApp: App
```

#### Responsibilities

1. Creates and holds `DataManager` as `@StateObject`
2. Configures `UNUserNotificationCenter` delegate via `NotificationCoordinator`
3. Requests notification permissions on launch
4. Wraps `ContentView` with `WSOnBoarding` welcome screen
5. Injects `DataManager` into the environment

#### NotificationCoordinator

Implements `UNUserNotificationCenterDelegate`:
- `willPresent`: Presents notifications as banner with sound and badge
- `didReceive`: Clears badge count when user taps notification

### 7.2 ContentView

**File:** [ContentView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ContentView.swift)

The main tab-based navigation container.

| Tab | Icon | View | Tag |
|-----|------|------|-----|
| Home | `house.fill` | HomeView | 0 |
| Trends | `chart.bar.fill` | TrendsView | 1 |
| Exams | `list.bullet.clipboard` | ExamView | 3 |
| Settings | `gearshape.fill` | SettingsView | 4 |

> Note: The Mistakes tab (tag 2) is currently commented out/disabled.

Features `UIImpactFeedbackGenerator` for haptic feedback on tab switching.

### 7.3 HomeView

**File:** [HomeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/HomeView.swift)

The main dashboard page. Largest view in the app (~783 lines).

#### Key Components

| Component | Description |
|-----------|-------------|
| `WelcomeCardView` | Top card with greeting, daily quote, and quick stats |
| `StatCardView` | Reusable stat display card (icon, label, value) |
| `GradeDetailView` | Scrollable list of recent grades with score details |
| `UpcomingExamCard` | Displays upcoming exams within 2 weeks |
| `HomeMainInfoView` | Container for all home page sections |
| `DailyQuoteCard` | Displays a daily motivational quote |

#### Daily Quotes System

- `dailyQuotes`: Array of 14 motivational quotes
- `dailyQuote`: Computed property that selects a quote based on the current day of year (cycles through the array)

#### Displayed Statistics

| Stat Card | Data Source |
|-----------|-------------|
| Total Exams | `dataManager.examSets.count + dataManager.comprehensiveExamSets.count` |
| Upcoming Exams | Exams within 2 weeks |
| Overall Average | Average of all grades' scores |
| Latest Grade | Most recent grade entry |

### 7.4 TrendsView

**File:** [TrendsView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/TrendsView.swift)

Score trend analysis and visualization page.

#### Features

| Feature | Description |
|---------|-------------|
| Score/Ranking Toggle | Switch between score and ranking display modes |
| Time Range Filter | All / 3 Months / 6 Months / 1 Year |
| Subject Detail View | Expandable detail for each subject |
| Charts Integration | Uses Apple's Charts framework for line/point marks |

#### SubjectDetailView

Inner view that shows a chart and grade list for a specific subject:
- Line chart with date on X-axis and score/ranking on Y-axis
- Scrollable list of individual grade entries with color-coded scores
- Delete support via swipe gesture

### 7.5 ExamView

**File:** [ExamView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamView.swift)

Exam management list view.

#### Features

| Feature | Description |
|---------|-------------|
| Combined Display | Merges `examSets` and `comprehensiveExamSets` into `allExams` |
| Time Grouping | Groups exams into: Within 1 Week, Within 1 Month, Later |
| Swipe to Delete | Supports left-swipe deletion with confirmation |
| Countdown Display | Shows days remaining until each exam |

#### ExamRowView

Displays a single exam row with:
- Exam name and date
- Subject tags (multiple for comprehensive exams)
- Importance stars (1-5)
- Mastery degree progress bar
- Days remaining countdown

### 7.6 ExamDetailView

**File:** [ExamDetailView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamDetailView.swift)

Read-only exam detail display.

#### Layout Sections

| Section | Content |
|---------|---------|
| Overview | Exam name, date, subject tags |
| Metrics | Importance (star icons), Mastery degree (progress bar) |
| Countdown | Large remaining days display |

### 7.7 ExamDetailEditView

**File:** [ExamDetailEditView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamDetailEditView.swift)

Form for editing existing exam details. Fields:
- Exam name (TextField)
- Subject (disabled, shows current)
- Date (DatePicker)
- Importance (1-5 star picker)
- Mastery degree (slider)
- Notes (TextEditor)

### 7.8 NewExamSetView

**File:** [NewExamSetView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/NewExamSetView.swift)

Form for creating new exams.

#### Features

| Feature | Description |
|---------|-------------|
| Exam Type Toggle | Single Subject vs Comprehensive Exam |
| Subject Multi-Select | Select multiple subjects for comprehensive exams |
| Date Picker | Select exam date |
| Importance Picker | 1-5 star rating |
| Mastery Degree Slider | 0-100% slider |

### 7.9 AddGradeView

**File:** [AddGradeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/AddGradeView.swift)

Form for recording new grades.

#### Features

| Feature | Description |
|---------|-------------|
| Exam Type | Single Subject or Comprehensive Exam |
| Exam Selection | Pick from existing exams |
| Subject Picker | Select subject (or multiple for comprehensive) |
| Score Input | Normalized score input |
| Raw Score Toggle | Optional raw/original score entry |
| Ranking Toggle | Optional ranking entry |
| Importance Picker | 1-5 star rating |
| Image Upload | Attach exam photo |

#### ScoreControlView / RankingControlView

Helper sub-views within AddGradeView for score and ranking input with +/- increment buttons.

### 7.10 MistakeView

**File:** [MistakeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/MistakeView.swift)

Mistake collection list and detail view.

#### Features

| Feature | Description |
|---------|-------------|
| List View | Shows all mistake notes with title, source, and date |
| Detail View | Full mistake analysis with four sections |
| Navigation | NavigationStack with detail push |

### 7.11 MistakeDetailEditView

**File:** [MistakeDetailEditView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/MistakeDetailEditView.swift)

Detailed mistake editing form with four collapsible sections:

| Section | Purpose |
|---------|---------|
| 题目 (Question) | The original exam question |
| 错因 (Error Reason) | Why the mistake was made |
| 错解 (Wrong Solution) | The incorrect answer attempted |
| 正解 (Correct Solution) | The correct answer |

Each section is independently expandable/collapsible via toggle.

### 7.12 NewMistakeSetView

**File:** [NewMistakeSetView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/NewMistakeSetView.swift)

Form for creating new mistake entries.

#### Fields

| Field | Type |
|-------|------|
| Title | TextField |
| Subject | Picker (from enabled subjects) |
| Date | DatePicker |
| Importance | Star picker (1-5) |
| Source | TextField (which exam) |
| 题目 | Collapsible TextEditor |
| 错因 | Collapsible TextEditor |
| 错解 | Collapsible TextEditor |
| 正解 | Collapsible TextEditor |
| Images | Photo capture/gallery support |

### 7.13 NewMistakeSheet

**File:** [NewMistakeSheet.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Sheets/NewMistakeSheet.swift)

Sheet-based version of the new mistake form. Wraps `NewMistakeSetView`-like content in a `.sheet` presentation with navigation bar.

### 7.14 SettingsView

**File:** [SettingsView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/SettingsView.swift)

App settings and configuration page. Largest settings-related file (~576 lines).

#### Sections

| Section | Content |
|---------|---------|
| **User Information** | Username, age, education level, system, region |
| **Academic Info** | Edit subjects (enable/disable), selected subjects |
| **About** | App description, features list, GitHub link |
| **Copyright** | CC BY-NC-SA 4.0 license details |
| **Test** | Send test notification in 5 seconds (for debugging) |

#### Sub-views

| View | Description |
|------|-------------|
| `EditSubjectsView` | Toggle individual subjects on/off |
| `ProfileEditView` | Edit user profile fields |
| `AboutView` | App info, features, and GitHub link |
| `CopyrightView` | License information |
| `LicenseDetailView` | Full CC BY-NC-SA 4.0 license text |
| `SectionHeader` | Reusable section header with optional action button |

### 7.15 SubjectScoreCard

**File:** [SubjectScoreCard.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/SubjectScoreCard.swift)

Reusable card component for displaying a subject's score information.

#### Features

| Feature | Description |
|---------|-------------|
| Score/Ranking Toggle | Switch display mode |
| Score History | List of past grades for the subject |
| Mini Chart | Small line chart showing trend (miniChartView) |
| Delete Support | Swipe to delete individual grades |

#### ChartDataPoint

Internal struct for chart rendering:
```swift
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
```

---

## 8. Components & Helpers

### 8.1 GradeChartView

**File:** [GradeChartView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Components/GradeChartView.swift)

Simple line chart for a specific subject's grades using Apple Charts framework.

```swift
struct GradeChartView: View {
    let grades: [Grade]
    let subject: String
    // Filters grades by subject, sorts by date, renders line + point marks
}
```

### 8.2 SubjectPickerView

**File:** [SubjectPickerView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Components/SubjectPickerView.swift)

Reusable picker that shows only enabled subjects:

```swift
struct SubjectPickerView: View {
    @Binding var selectedSubject: String
    let subjects: [Subject]
    // Filters subjects by .enabled property
}
```

### 8.3 BackgroundColors

**File:** [BackgroundColors.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/BackgroundColors.swift)

Adaptive background color function based on color scheme:

```swift
func getBackgroundColor(_ colorScheme: ColorScheme) -> Color
// Light mode: systemGray6
// Dark mode: systemBackground
```

### 8.4 ImagePicker

**File:** [ImagePicker.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/ImagePicker.swift)

`UIViewControllerRepresentable` wrapper for `UIImagePickerController` to select images from the photo library.

### 8.5 PhotoCaptureView

**File:** [PhotoCaptureView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/PhotoCaptureView.swift)

`UIViewControllerRepresentable` wrapper for `UIImagePickerController` with `sourceType = .camera` for direct camera capture.

### 8.6 ScoreColor

**File:** [ScoreColor.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/ScoreColor.swift)

Maps numeric scores to semantic colors:

| Score Range | Color |
|-------------|-------|
| >= 120 | systemGreen |
| >= 90 | systemBlue |
| >= 60 | systemOrange |
| < 60 | systemRed |

---

## 9. Extensions

### 9.1 ColorExtensions

**File:** [ColorExtensions.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Extensions/ColorExtensions.swift)

Bridges UIKit UIColor constants to SwiftUI Color:

| Extension | Maps To |
|-----------|---------|
| `Color.systemBackground` | `UIColor.systemBackground` |
| `Color.secondarySystemBackground` | `UIColor.secondarySystemBackground` |
| `Color.systemGray6` | `UIColor.systemGray6` |

### 9.2 DateExtensions

**File:** [DateExtensions.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Extensions/DateExtensions.swift)

Convenience method for date formatting:

```swift
extension Date {
    func formatted(date style: DateFormatter.Style, time style2: DateFormatter.Style) -> String
}
```

---

## 10. Notification System

**File:** [ExamPrepareNotifications.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/NotificationsControl/ExamPrepareNotifications.swift)

Manages local notifications for exam countdown reminders.

### Key Methods

| Method | Description |
|--------|-------------|
| `requestAuthorization()` | Requests user permission for local notifications |
| `scheduleNotifications(for: examName, date: examDate)` | Schedules a series of countdown notifications |
| `cancelNotifications(for: examName)` | Cancels all notifications for a specific exam |

### Notification Schedule

| Days Before Exam | Notification Content |
|------------------|---------------------|
| 30 days | "30 days until [examName]" |
| 10 days | "10 days until [examName]" |
| 5 days | "5 days until [examName]" |
| 3 days | "3 days until [examName]" |
| 1 day | "1 day until [examName]" |

Each notification is scheduled at 8:00 AM on the respective countdown day, using calendar components for recurring delivery.

### Usage Flow

1. When a new exam is created in `NewExamSetView`, `ExamPrepareNotifications.scheduleNotifications(for: date:)` is called
2. When an exam is deleted, `ExamPrepareNotifications.cancelNotifications(for:)` is called
3. `SettingsView` includes a debug option to send a test notification in 5 seconds

---

## 11. Internationalization

StudyPulse supports two locales:

| Locale | File | Status |
|--------|------|--------|
| English (en) | [en.lproj/Localizable.strings](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/en.lproj/Localizable.strings) | Minimal (fallback) |
| Chinese Simplified (zh-Hans) | [zh-Hans.lproj/Localizable.strings](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/zh-Hans.lproj/Localizable.strings) | Complete translations |

### Localized Categories

| Category | Keys |
|----------|------|
| AddGradeView | GROUP, Exam Details, Exam Name, Score, Ranking, etc. |
| ContentView | Home, Trends, Mistakes, Exams, Settings |
| ExamView | Within 1 Week, Within 1 Month, Later, Delete, etc. |
| HomeView | Welcome back, Total Exams, Dashboard, etc. |
| SettingsView | User Information, Edit Profile, About, Copyright, etc. |
| Subjects | All 16 subject names (Chinese, Mathematics, English, etc.) |

Usage pattern:
```swift
"Total Exams".localized()  // Returns "考试总次数" in zh-Hans
```

---

## 12. Dependencies

### Third-Party Packages

| Package | Repository | Purpose |
|---------|------------|---------|
| **WSOnBoarding** | [github.com/Jewel591/WSOnBoarding](https://github.com/Jewel591/WSOnBoarding) | Onboarding/welcome screen with feature highlights |

### WSOnBoarding Configuration

**File:** [WelcomeConfig.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/OnBoarding/WelcomeConfig.swift)

| Feature Item | Icon | Color |
|--------------|------|-------|
| 图表分析 | `list.clipboard` | Blue |
| 毫秒级响应 | `bolt.fill` | Orange |
| 离线支持 | `wifi.slash` | Green |

App icon: `graduationcap.fill`, Primary color: Blue

### Native Frameworks Used

| Framework | Purpose |
|-----------|---------|
| `SwiftUI` | UI framework |
| `Charts` | Data visualization |
| `UserNotifications` | Local notifications |
| `UIKit` | Image picker, view controllers |
| `AVFoundation` | Camera support |
| `Combine` | Reactive programming (SubjectInfo) |
| `Foundation` | Data types, JSON encoding, date handling |

---

## 13. Data Flow

### 13.1 Adding a Grade

```
User taps + on HomeView/TrendsView
       │
       ▼
AddGradeView presented as .sheet
       │
       ▼
User fills form (exam, subject, score, ranking, importance)
       │
       ▼
User taps "Save"
       │
       ▼
dataManager.addGrade(newGrade)
       │
       ├──► grades.append(newGrade)
       ├──► saveData() → grades.json
       │
       ▼
@Published triggers automatic UI update
       │
       ▼
Sheet dismisses, views refresh with new data
```

### 13.2 Creating an Exam

```
User taps + on ExamView
       │
       ▼
NewExamSetView presented as .sheet
       │
       ▼
User selects exam type (single/comprehensive), subjects, date, etc.
       │
       ▼
User taps "Save"
       │
       ├──► dataManager.addExamSet() or .addComprehensiveExam()
       ├──► ExamPrepareNotifications.scheduleNotifications(for: date)
       │
       ▼
Views refresh, notifications scheduled
```

### 13.3 Data Persistence Cycle

```
App Launch
    │
    ▼
DataManager.init()
    │
    ├──► Initialize default subjects (16 subjects)
    ├──► loadData()
    │       │
    │       ├──► Read grades.json → decode → grades[]
    │       ├──► Read subjects.json → decode → subjects[]
    │       ├──► Read mistakeSets.json → decode → mistakeSets[]
    │       ├──► Read examSets.json → decode → examSets[]
    │       ├──► Read comprehensiveExamSets.json → decode → comprehensiveExamSets[]
    │       └──► Read profile.json → decode → profile
    │
    ▼
App is ready

Any data modification
    │
    ▼
saveData()
    │
    ├──► Encode grades[] → grades.json
    ├──► Encode subjects[] → subjects.json
    ├──► Encode mistakeSets[] → mistakeSets.json
    ├──► Encode examSets[] → examSets.json
    ├──► Encode comprehensiveExamSets[] → comprehensiveExamSets.json
    └──► Encode profile → profile.json
```

---

## 14. How to Run

### Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | Latest (compatible with Xcode 26) |
| Xcode | 26.x |
| iOS Deployment Target | 18.6+ |
| Swift | 6.0 |

### Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd StudyPulse
   ```

2. **Open in Xcode**
   ```bash
   open StudyPulse.xcodeproj
   ```

3. **Resolve Swift Package Dependencies**
   - Xcode should automatically resolve WSOnBoarding from `https://github.com/Jewel591/WSOnBoarding`
   - If not: `File` → `Packages` → `Resolve Package Versions`

4. **Select Target Device**
   - Choose an iPhone simulator (iOS 18.6+) or a physical device

5. **Build and Run**
   - Press `Cmd + R` or click the Run button
   - The app will launch with the WSOnBoarding welcome screen on first run

### Building from Command Line

```bash
# Build for simulator
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# Build for device (requires signing)
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -sdk iphoneos \
  -configuration Release \
  build
```

### Debugging Tips

- **Test Notifications**: Go to Settings → "在 5 秒后进行本地通知接收测试"
- **Data Location**: JSON files are stored in the app's Documents directory. Use Xcode's Devices & Simulators window to download the container.
- **Reset Data**: Delete the app and reinstall to start fresh (all JSON files are removed)

---

## 15. Build Configuration

### Project Settings

| Setting | Value |
|---------|-------|
| **Bundle Identifier** | `Gao.Chenkai.StudyPulse` |
| **Swift Version** | 6.0 |
| **C++ Standard** | gnu++20 |
| **C Standard** | gnu17 |
| **Development Team** | D2G8858WRZ |
| **Code Sign Style** | Automatic |

### Deployment Targets

| Platform | Version |
|----------|---------|
| iOS | 18.6 |
| Xcode Build Target | 26.0 |

### Build Configurations

| Setting | Debug | Release |
|---------|-------|---------|
| Optimization | `-Onone` | `wholemodule` |
| Debug Info | `dwarf` | `dwarf-with-dsym` |
| Assertions | Enabled | Disabled |
| Testability | Enabled | Disabled |
| Validation | No | `VALIDATE_PRODUCT = YES` |

### Compiler Flags

| Flag | Value |
|------|-------|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | YES |
| `SWIFT_EMIT_LOC_STRINGS` | YES |
| `CLANG_ENABLE_MODULES` | YES |
| `CLANG_ENABLE_OBJC_ARC` | YES |
| `ENABLE_STRICT_OBJC_MSGSEND` | YES |

### Info.plist Keys (Generated)

| Key | Value |
|-----|-------|
| `UIApplicationSceneManifest_Generation` | YES |
| `UIApplicationSupportsIndirectInputEvents` | YES |
| `UILaunchScreen_Generation` | YES |
| Supported Orientations (iPhone) | Portrait, Landscape Left, Landscape Right |
| Supported Orientations (iPad) | Portrait, Portrait Upside Down, Landscape Left, Landscape Right |

### Supported Device Families

- iPhone (`1`)
- iPad (`2`)
- Mac Catalyst: **Disabled** (`SUPPORTS_MACCATALYST = NO`)
