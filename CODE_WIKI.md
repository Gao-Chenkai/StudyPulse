# StudyPulse - Code Wiki

> A comprehensive code reference for the StudyPulse iOS app, an international study management application built with SwiftUI.

=====================================================================

## Table of Contents

1. [Getting Started](#getting-started)
2. [Architecture Overview](#architecture-overview)
3. [Directory Structure](#directory-structure)
4. [Data Models Reference](#data-models-reference)
5. [Managers Reference](#managers-reference)
6. [Views Reference](#views-reference)
7. [Education Systems](#education-systems)
8. [Widget Extension](#widget-extension)
9. [Notification System](#notification-system)
10. [OCR System](#ocr-system)
11. [Image Cache System](#image-cache-system)
12. [CSV Export](#csv-export)
13. [iPad Adaptation](#ipad-adaptation)
14. [Performance Patterns](#performance-patterns)
15. [Privacy](#privacy)
16. [Build Commands](#build-commands)
17. [Coding Standards and Conventions](#coding-standards-and-conventions)

=====================================================================

## Getting Started

### Prerequisites

| Requirement | Version |
|-------------|---------|
| macOS | 15.0+ |
| Xcode | 26.3 |
| iOS Deployment Target | 18.6+ |
| Swift | 6.0 |
| Supported Devices | iPhone & iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |

### Quick Start

```bash
# 1. Clone the repository
cd StudyPulse/

# 2. Open in Xcode
open StudyPulse.xcodeproj

# 3. Resolve SPM packages
#    Xcode -> File -> Packages -> Resolve Package Versions

# 4. Build and Run
#    Cmd + R
```

### Key Concepts

- **MVVM Architecture**: Views are driven by @EnvironmentObject DataManager
- **JSON Persistence**: All data stored as JSON files in ~/Documents/
- **Async Loading**: App uses asyncInit() for non-blocking startup
- **Global Education**: Supports 15+ education systems (CN, UK, IB, AP, SAT, etc.)
- **Universal Device Support**: iPhone + iPad with size-class adaptive layouts
  (see [iPad Adaptation](#ipad-adaptation) below)

=====================================================================

## Architecture Overview

StudyPulse follows the **MVVM (Model-View-ViewModel)** pattern using SwiftUI's @EnvironmentObject for dependency injection.

### High-Level Architecture Diagram

```
+---------------------------------------------------------------------------+
|                        StudyPulse iOS App                                  |
+===========================================================================+
|                                                                           |
|  +--------------------------------------------------------------------+   |
|  |                        Presentation Layer                          |   |
|  +--------------------------------------------------------------------+   |
|  |                                                                    |   |
|  |  +----------------------------------------------------------------+|   |
|  |  |                         StudyPulseApp                          ||   |
|  |  |  +----------------------------------------------------------+  ||   |
|  |  |  |                 AppEnvironmentManager                    |  ||   |
|  |  |  |  (Theme + Language Preferences + ColorScheme)            |  ||   |
|  |  |  +----------------------------------------------------------+  ||   |
|  |  +----------------------------------------------------------------+|   |
|  +--------------------------------------------------------------------+   |
|                              |                                            |
|                              v                                            |
|  +--------------------------------------------------------------------+   |
|  |                             View Layer                              |   |
|  +--------------------------------------------------------------------+   |
|  |                                                                    |   |
|  |  ContentView (TabView)                                            |   |
|  |  +----------+ +----------+ +----------+ +----------+ +----------+|   |
|  |  |   Home   | |  Trends  | | Mistakes | |  Exams   | | Settings ||   |
|  |  +----------+ +----------+ +----------+ +----------+ +----------+|   |
|  |                                                                    |   |
|  |  +----------+ +----------+ +----------+ +----------+ +----------+|   |
|  |  | HomeView | |TrendsView| |MistakeVw| | ExamView | |Settings  ||   |
|  |  +----------+ +----------+ +----------+ +----------+ +----------+|   |
|  +--------------------------------------------------------------------+   |
|                              |                                            |
|                              v                                            |
|  +--------------------------------------------------------------------+   |
|  |                      Business Logic Layer                           |   |
|  +--------------------------------------------------------------------+   |
|  |                                                                    |   |
|  |  +------------------- DataManager -----------------------------+  |   |
|  |  |  grades   |  subjects   |  mistakeSets   |  examSets       |  |   |
|  |  |  comprehensiveExamSets         |        profile            |  |   |
|  |  +------------------------------------------------------------+  |   |
|  |  |  asyncInit()        |  load*Async()    |  save*()         |  |   |
|  |  |  fullScore()        |  displayName()   |  applySmartRec() |  |   |
|  |  +------------------------------------------------------------+  |   |
|  |                                                                    |   |
|  |  +--------+ +--------+ +----------+ +------------+                |   |
|  |  |Calendar| |  OCR   | |ImageCache| |WidgetData  |                |   |
|  |  | Manager| |Manager | |          | | SyncMgr    |                |   |
|  |  +--------+ +--------+ +----------+ +------------+                |   |
|  +--------------------------------------------------------------------+   |
|                              |                                            |
|                              v                                            |
|  +--------------------------------------------------------------------+   |
|  |                             Data Layer                              |   |
|  +--------------------------------------------------------------------+   |
|  |                                                                    |   |
|  |  Models:                                                          |   |
|  |  +----------+ +---------+ +---------+ +----------+ +----------+   |   |
|  |  | Education| | Subject | | Subject | |  Grade   | |UserProfle|   |   |
|  |  |  Stage   | |  Config | |  Region | |          | |          |   |   |
|  |  +----------+ +---------+ +---------+ +----------+ +----------+   |   |
|  |  +----------+ +---------+ +----------+ +------------------+       |   |
|  |  | Mistake  | |  Exam   | |  Subject | | AppPreferences   |       |   |
|  |  |   Note   | |         | |          | |                  |       |   |
|  |  +----------+ +---------+ +----------+ +------------------+       |   |
|  |                                                                    |   |
|  |  Persistence Layer:                                                |   |
|  |  ~/Documents/                                                       |   |
|  |    profile.json    grades.json    mistakes.json                    |   |
|  |    exams.json    comprehensiveExams.json  subjects.json            |   |
|  |    images/        (avatar_*.jpg, grade_*.jpg)                      |   |
|  +--------------------------------------------------------------------+   |
|                              |                                            |
|                              v                                            |
|  +--------------------------------------------------------------------+   |
|  |                        Widget Extension                             |   |
|  |                                                                    |   |
|  |  StudyPulseWidget/                                                 |   |
|  |    ExamWidget.swift          (Widget Definition)                   |   |
|  |    ExamWidgetData.swift      (Shared Data Model)                   |   |
|  |    ExamWidgetEntry.swift     (Timeline Entry)                      |   |
|  |    ExamWidgetProvider.swift  (Timeline Provider)                   |   |
|  |    ExamWidgetViews.swift     (Widget UI)                           |   |
|  +--------------------------------------------------------------------+   |
+---------------------------------------------------------------------------+
```

### Component Interaction Flow

```
+------------------+
|    User Input    |
+--------+---------+
         |
         v
+----------------------------------------------+
|              SwiftUI Views                   |
|  +----------+  +----------+  +----------+   |
|  | HomeView |  | AddGrade |  | Settings |   |
|  +----+-----+  +----+-----+  +----+-----+   |
+-------+-------------+-------------+---------+
        |             |             |
        +-------------+-------------+
                      |
                      v
         +---------------------------+
         |      DataManager          |
         |    (@EnvironmentObject)   |
         +------------+--------------+
                      |
         +------------+------------+
         |                         |
         v                         v
+------------------+  +------------------+
|  Update Models   |  |  Save to Disk    |
|  (State Change)  |  |  (JSON + Images) |
+------------------+  +--------+---------+
                               |
                               v
                 +---------------------------+
                 | WidgetDataSyncManager     |
                 |  (App Group Sync)         |
                 +------------+--------------+
                               |
                               v
                 +---------------------------+
                 | StudyPulseWidget          |
                 |  (Timeline Refresh)       |
                 +---------------------------+
```

### Module Dependency Graph

```
+---------------------------------------------------------------------------+
|                      Module Dependency Graph                               |
+===========================================================================+
|                                                                           |
|  +-----------------+     +-----------------+     +-----------------+      |
|  | Views           |---->| DataManager     |---->| Models          |      |
|  |  - HomeView     |     |                 |     |  - Grade        |      |
|  |  - TrendsView   |     | Published:      |     |  - MistakeNote  |      |
|  |  - MistakeView  |     |  - grades       |     |  - Exam         |      |
|  |  - ExamView     |     |  - subjects     |     |  - Subject      |      |
|  |  - SettingsView |     |  - mistakeSets  |     |  - UserProfile  |      |
|  |  - AddGradeView |     |  - examSets     |     |  - SubjectConfig|      |
|  |  - NewExamSet   |     |  - profile      |     |  - EducationRgn |      |
|  +-----------------+     +--------+--------+     +-----------------+      |
|                                    |                                       |
|                                    v                                       |
|  +------------------ Helper Managers -------------------------------+     |
|  |                                                                  |     |
|  |  +--------+ +---------+ +----------+ +------------------+         |     |
|  |  |Calendar| |  OCR    | | ImageCache| | Education Config |         |     |
|  |  |Manager | | Manager | |           | | (Static)         |         |     |
|  |  |(EventKt)| | (Vision)| | (NSCache) | |                  |         |     |
|  |  +--------+ +---------+ +----------+ +------------------+         |     |
|  +-------------------------------------------------------------------+     |
|                                    |                                       |
|                                    v                                       |
|  +------------------ Extensions & Utilities -------------------------+    |
|  |                                                                  |     |
|  |  +--------+ +--------+ +-----------+ +------------------+         |     |
|  |  | Color  | |  Date  | |  Score    | | Strings Localized|         |     |
|  |  | Extensn| | Extensn| |  Color    | |                  |         |     |
|  |  +--------+ +--------+ +-----------+ +------------------+         |     |
|  +-------------------------------------------------------------------+     |
|                                                                           |
|  Dependency Direction: Views -> DataManager -> Helpers -> Extensions      |
|  (Views never directly access Helpers; DataManager mediates)              |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Data Persistence Flow

```
+---------------------------------------------------------------------------+
|                       Data Persistence Flow                                |
+===========================================================================+
|                                                                           |
|  App Launch (.task -> asyncInit())                                        |
|  +-----------------------------------------------------------------+      |
|  |                                                                 |      |
|  |  Main Thread                      Background Thread             |      |
|  |  +----------------------+         +----------------------+      |      |
|  |  | StudyPulseApp        |         | DataManager          |      |      |
|  |  |  .onAppear {         |   async |  loadProfileAsync()  |      |      |
|  |  |    dataManager.      |-------->|  loadGradesAsync()   |      |      |
|  |  |    asyncInit()       |         |  loadExamsAsync()    |      |      |
|  |  |  }                   |         |  loadMistakesAsync() |      |      |
|  |  +----------------------+         |  loadSubjectsAsync() |      |      |
|  |                                   +----------+-----------+      |      |
|  |                                              |                  |      |
|  |                                              v                  |      |
|  |                                   +----------------------+      |      |
|  |                                   | ~/Documents/         |      |      |
|  |                                   |  - profile.json      |      |      |
|  |                                   |  - grades.json       |      |      |
|  |                                   |  - exams.json        |      |      |
|  |                                   |  - mistakes.json     |      |      |
|  |                                   |  - subjects.json     |      |      |
|  |                                   +----------------------+      |      |
|  +-----------------------------------------------------------------+      |
|                                                                           |
|  Save Operation (User Action -> save)                                     |
|  +-----------------------------------------------------------------+      |
|  |                                                                 |      |
|  |  User taps "Save"                                                |      |
|  |     |                                                           |      |
|  |     v                                                           |      |
|  |  DataManager.save*() (@MainActor)                                |      |
|  |   - Update @Published property -> triggers SwiftUI re-render     |      |
|  |   - Encode model -> JSON Data (JSONEncoder)                      |      |
|  |   - Write to ~/Documents/{file}.json (atomic write)              |      |
|  |   - WidgetDataSyncManager.syncExamsToWidget()                    |      |
|  |                                                                 |      |
|  +-----------------------------------------------------------------+      |
|                                                                           |
|  File I/O Pattern (DataFileIO - nonisolated enum)                         |
|  +-----------------------------------------------------------------+      |
|  |  - read(from:)    -> Data? (throws on error)                    |      |
|  |  - write(data:to:) -> Bool (atomic via temp file + rename)      |      |
|  |  - directoryExists / createDirectory()                          |      |
|  |  - Safe for background thread execution                         |      |
|  +-----------------------------------------------------------------+      |
|                                                                           |
+---------------------------------------------------------------------------+
```

=====================================================================

## Directory Structure

```
StudyPulse/
+-- Models/                  # Data model definitions
|   +-- DataModels.swift     # Core domain models (Grade, MistakeNote, etc.)
|   +-- AppPreferences.swift # App-wide preferences (language + theme)
|   +-- ExamWidgetData.swift # Shared widget data model
+-- Managers/                # Business logic managers
|   +-- DataManager.swift    # Central state manager (@MainActor)
|   +-- EducationConfig.swift# Static education system config
|   +-- AppEnvironmentManager.swift  # Language + theme manager
|   +-- CalendarManager.swift        # EventKit integration
|   +-- OCRManager.swift             # Vision framework OCR
|   +-- ImageCache.swift             # NSCache-backed image cache
|   +-- SubjectInfo.swift            # Subject display helpers
|   +-- WidgetDataSyncManager.swift  # App Group sync
+-- Views/                   # SwiftUI views and components
|   +-- ContentView.swift    # Main TabView container (sidebar-adaptable on iPad)
|   +-- HomeView.swift       # Dashboard (4-col stats + 2-col sections on iPad)
|   +-- TrendsView.swift     # Trend analysis
|   +-- ExamView.swift       # Exam list + detail
|   +-- MistakeView.swift    # Mistake notebook
|   +-- AddGradeView.swift   # Grade entry form
|   +-- SettingsView.swift   # Settings
|   +-- ProfileEditView.swift
|   +-- EditSubjectsView.swift
|   +-- PreferencesView.swift
|   +-- Helpers/             # Reusable components
|       +-- AvatarView.swift
|       +-- ScoreColor.swift
|       +-- SubjectScoreCard.swift
|       +-- iPadLayout.swift     # iPad adaptive helpers (adaptiveMaxWidth, AdaptiveHStack, AdaptiveGridColumns)
+-- Extensions/              # Color, Date, and utility extensions
+-- Notifications/           # Local notification scheduling
+-- StudyPulseWidget/        # Widget extension (separate target)
|   +-- ExamWidget.swift     # Widget definition
|   +-- ExamWidgetEntry.swift
|   +-- ExamWidgetProvider.swift
|   +-- ExamWidgetViews.swift
|   +-- StudyPulseWidgetBundle.swift
+-- StudyPulseApp.swift      # App entry point
```

=====================================================================

## Data Models Reference

### Models Summary Table

| Model | File | Type | ID Source | Codable | Sendable | Purpose |
|-------|------|------|-----------|---------|----------|---------|
| EducationStage | DataModels.swift | enum | rawValue | Yes | Yes | User's educational stage |
| EducationCategory | DataModels.swift | enum | rawValue | Yes | Yes | Domestic / International |
| SubjectConfig | DataModels.swift | struct | name | Yes | Yes | Subject definition in region |
| EducationRegion | DataModels.swift | struct | name | Yes | Yes | Regional education system |
| Subject | DataModels.swift | struct | UUID | Yes | No | User's subject list |
| Grade | DataModels.swift | struct | UUID | Yes | No | Single grade record |
| UserProfile | DataModels.swift | struct | n/a | Yes | No | User profile + academic info |
| MistakeNote | DataModels.swift | struct | UUID | Yes | No | Mistake note entry |
| Exam | DataModels.swift | struct | UUID | Yes | No | Single-subject exam |
| comprehensiveExam | DataModels.swift | struct | UUID | Yes | No | Multi-subject exam |
| AppPreferences | AppPreferences.swift | struct | n/a | Yes | No | Language + color scheme |
| ColorSchemeOption | AppPreferences.swift | enum | rawValue | Yes | No | system/light/dark |

### EducationStage (enum)

Defines the user's current educational stage.

```swift
nonisolated enum EducationStage: String, CaseIterable, Identifiable, Codable, Sendable {
    case primarySchool = "Primary School"
    case middleSchool = "Middle School"
    case highSchool = "High School"
    case internationalHighSchool = "International High School"
    case university = "University"
    case graduate = "Graduate"
}
```

### EducationCategory (enum)

Categorizes education systems as domestic or international.

```swift
nonisolated enum EducationCategory: String, CaseIterable, Codable, Sendable {
    case domestic = "Domestic"
    case international = "International"
}
```

### SubjectConfig

Configuration for a single subject within a region.

```swift
nonisolated struct SubjectConfig: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let fullScore: Double
    let isRequired: Bool
    let isElective: Bool
    let category: String?

    // Factory methods
    static func required(_ name: String, displayName: String, fullScore: Double, category: String? = nil)
    static func elective(_ name: String, displayName: String, fullScore: Double, category: String? = nil)
}
```

### EducationRegion

Represents a regional education system (e.g., zhejiang high school).

```swift
nonisolated struct EducationRegion: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String              // e.g., "zhejiang"
    let displayName: String       // e.g., "浙江 (3+3)"
    let category: EducationCategory
    let stage: EducationStage
    let systemCode: String        // e.g., "CN-ZJ-3+3"
    let subjects: [SubjectConfig]
    let notes: String
}
```

### Subject

User's subject list with customizable full score.

```swift
nonisolated struct Subject: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String              // e.g., "Mathematics"
    var displayName: String       // e.g., "数学"
    var enabled: Bool
    var fullScore: Double         // customizable per subject
}
```

### Grade

A single grade record.

```swift
nonisolated struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var score: Double
    var rawScore: Double?         // original score before ranking
    var ranking: Int?
    var importance: Int           // 1-5
    var image: Data?              // legacy inline image
    var imageFileName: String?    // new file-based image
    var date: Date
    var examName: String
    var fullScore: Double?        // full score at the time of recording

    // Dynamic score rate calculation
    func scoreRate(subjectFullScore: Double = 100) -> Double
}
```

### UserProfile (expanded)

User's profile with detailed academic info.

```swift
nonisolated struct UserProfile: Codable {
    var username: String = "Student"
    var realName: String = ""
    var age: Int = 16
    var gender: String = "Not Specified"
    var educationLevel: String       // legacy
    var educationSystem: String      // legacy
    var region: String               // legacy
    var educationStage: String       // EducationStage rawValue
    var regionCode: String           // EducationRegion.name
    var selectedSubjects: [Subject] = []
    var theme: String = "Auto"
    var avatarFileName: String?

    // New detailed fields
    var grade: String = ""           // e.g., "高一"
    var className: String = ""
    var schoolName: String = ""
    var studentId: String = ""
    var enrollmentYear: Int
    var examYear: Int
    var targetSchool: String = ""
    var targetScore: Double = 0
}
```

### MistakeNote

A single mistake note with images.

```swift
nonisolated struct MistakeNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String
    var questionImages: [String]           // filenames
    var reasonImages: [String]
    var wrongSolutionImages: [String]
    var correctSolutionImages: [String]
}
```

### Exam / comprehensiveExam

```swift
nonisolated struct Exam: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subject: String          // single subject
    var examDate: Date
    var importance: Int          // 1-5
    var masteryDegree: Int       // 0-100
    var notes: String
}

nonisolated struct comprehensiveExam: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subject: [String]        // multiple subjects
    var examDate: Date
    var importance: Int
    var masteryDegree: Int
    var notes: String
}
```

### AppPreferences

```swift
struct AppPreferences: Codable {
    var appLanguage: String?     // "en", "zh-Hans", nil = system
    var colorScheme: ColorSchemeOption
}

enum ColorSchemeOption: String, CaseIterable, Codable {
    case system, light, dark
}
```

=====================================================================

## Managers Reference

### Managers Summary Table

| Manager | File | Actor/Type | Key Collaborators | Purpose |
|---------|------|------------|-------------------|---------|
| DataManager | DataManager.swift | @MainActor (ObservableObject) | All models, ImageCache, WidgetDataSyncManager | Central state and persistence |
| EducationConfig | EducationConfig.swift | nonisolated enum | EducationRegion, SubjectConfig | Static education system registry |
| AppEnvironmentManager | AppEnvironmentManager.swift | ObservableObject | AppPreferences | Language + theme management |
| CalendarManager | CalendarManager.swift | class (singleton) | EventKit | Add exams to system calendar |
| OCRManager | OCRManager.swift | class | Vision framework | Text recognition from images |
| ImageCache | ImageCache.swift | nonisolated class (singleton) | NSCache | Thumbnail caching |
| SubjectInfo | SubjectInfo.swift | ObservableObject | SubjectDisplay | Subject display helpers and max-score lookups |
| WidgetDataSyncManager | WidgetDataSyncManager.swift | class (singleton) | App Group container | Data sync with widget |

### DataManager Data Flow

```
+---------------------------------------------------------------------------+
|                        DataManager Data Flow                               |
+===========================================================================+
|                                                                           |
|  +-------------------------- Initialization ---------------------------+   |
|  |                                                                    |   |
|  |  asyncInit()                                                       |   |
|  |   |                                                                 |   |
|  |   +---> loadProfileAsync()  ->  UserProfile from profile.json       |   |
|  |   +---> loadGradesAsync()   ->  [Grade] from grades.json            |   |
|  |   +---> loadSubjectsAsync() ->  [Subject] from subjects.json        |   |
|  |   +---> loadExamsAsync()    ->  [Exam] from exams.json              |   |
|  |   +---> loadComprehensiveExamsAsync()                               |   |
|  |   |            -> [comprehensiveExam] from comprehensiveExams.json  |   |
|  |   +---> loadMistakeSetsAsync() -> [MistakeNote] from mistakes.json  |   |
|  |   |                                                                 |   |
|  |   +---> initializeDefaultSubjects()  (if no subjects exist)         |   |
|  |                                                                    |   |
|  +--------------------------------------------------------------------+   |
|                                                                           |
|  +--------------------------- Write Path --------------------------------+   |
|  |                                                                    |   |
|  |  SwiftUI View (user action)                                          |   |
|  |       |                                                              |   |
|  |       v                                                              |   |
|  |  DataManager.save{Entity}()                                          |   |
|  |   |                                                                  |   |
|  |   +---> @Published property updated  ->  SwiftUI refresh             |   |
|  |   +---> JSONEncoder.encode(entity)     ->  JSON Data                 |   |
|  |   +---> DataFileIO.write(data, to: file) ->  Atomic write           |   |
|  |   |                                                                  |   |
|  |   +---> WidgetDataSyncManager.syncExamsToWidget()  (if exams)        |   |
|  |                                                                    |   |
|  +--------------------------------------------------------------------+   |
|                                                                           |
|  +--------------------------- Image Path -------------------------------+   |
|  |                                                                    |   |
|  |  saveGradeImage(Data)                                                |   |
|  |   |                                                                  |   |
|  |   +---> Generate UUID filename ("grade_UUID.jpg")                    |   |
|  |   +---> Write JPEG to ~/Documents/images/{filename}                  |   |
|  |   +---> Return filename (stored on Grade.imageFileName)              |   |
|  |                                                                    |   |
|  |  getImage(filename)                                                  |   |
|  |   |                                                                  |   |
|  |   +---> First check ImageCache                                       |   |
|  |   +---> If miss, load from disk -> UIImage -> Cache                  |   |
|  |                                                                    |   |
|  +--------------------------------------------------------------------+   |
|                                                                           |
+---------------------------------------------------------------------------+
```

### EducationConfig System Resolution Flow

```
+---------------------------------------------------------------------------+
|                  EducationConfig System Resolution Flow                   |
+===========================================================================+
|                                                                           |
|  User selects EducationStage in ProfileEditView                           |
|        |                                                                  |
|        v                                                                  |
|  EducationConfig.availableRegions(for: stage)                             |
|        |                                                                  |
|        v                                                                  |
|  Returns [EducationRegion] filtered by stage                              |
|        |                                                                  |
|        +---> .domestic regions (e.g., 浙江 高中 3+3)                      |
|        +---> .international regions (e.g., UK A-Level, IB DP, US AP)     |
|        |                                                                  |
|        v                                                                  |
|  User picks region -> region.code stored in UserProfile.regionCode        |
|        |                                                                  |
|        v                                                                  |
|  "Apply Smart Recommendation" button                                      |
|        |                                                                  |
|        v                                                                  |
|  DataManager.applySmartSubjectRecommendation(stage, regionCode)           |
|   |                                                                       |
|   +---> Lookup EducationRegion via EducationConfig.region(...)            |
|   +---> Iterate region.subjects (SubjectConfig[])                        |
|   +---> Map each SubjectConfig -> Subject (with fullScore)                |
|   +---> Replace UserProfile.selectedSubjects                              |
|   |                                                                       |
|   +---> saveProfile() / saveSubjects()                                    |
|        |                                                                  |
|        v                                                                  |
|  SwiftUI refreshes to show new subjects                                   |
|                                                                           |
+---------------------------------------------------------------------------+
```

### AppEnvironmentManager Theme / Language Flow

```
+---------------------------------------------------------------------------+
|            AppEnvironmentManager (Theme + Language) Flow                   |
+===========================================================================+
|                                                                           |
|  PreferencesView                                                           |
|    +---> Language selector:  English / 简体中文 / 繁體中文 / 日本語       |
|    |                         / 한국어 / Follow System                     |
|    |                                                                      |
|    +---> Theme selector: Light / Dark / Follow System                     |
|        |                                                                  |
|        v                                                                  |
|  AppEnvironmentManager.setLanguage("zh-Hans")                             |
|    +---> updates preferences.appLanguage                                  |
|    +---> writes preferences to disk                                       |
|    +---> triggers .environment(\.locale, ...) on root view                |
|                                                                           |
|  AppEnvironmentManager.setColorScheme(.dark)                              |
|    +---> updates preferences.colorScheme                                  |
|    +---> writes preferences to disk                                       |
|    +---> computed effectiveColorScheme used by root view                  |
|                                                                           |
|  On launch:                                                               |
|    AppEnvironmentManager loads preferences file and restores state        |
|                                                                           |
+---------------------------------------------------------------------------+
```

### WidgetDataSyncManager Sync Flow

```
+---------------------------------------------------------------------------+
|                    WidgetDataSyncManager Sync Flow                         |
+===========================================================================+
|                                                                           |
|  Main App:                                                               |
|  DataManager.saveExams() / saveComprehensiveExams()                       |
|        |                                                                  |
|        v                                                                  |
|  WidgetDataSyncManager.syncExamsToWidget(exams)                           |
|   |                                                                       |
|   +---> Build ExamWidgetData struct (shared model)                        |
|   |       - upcomingExams: filtered and limited list                      |
|   |       - lastUpdated: Date                                             |
|   |                                                                       |
|   +---> Encode to JSON                                                    |
|   +---> Write to App Group container file                                 |
|   |       (group.Gao-Chenkai.StudyPulse / widgetExams.json)               |
|   |                                                                       |
|   +---> WidgetKit reloadTimelines(ofKind:...)                             |
|        |                                                                  |
|        v                                                                  |
|  Widget Extension:                                                         |
|  ExamWidgetProvider.getTimeline(in: for: after:)                          |
|   |                                                                       |
|   +---> Load ExamWidgetData from App Group file                           |
|   +---> Build TimelineEntry[] with upcoming exam info                     |
|   +---> Return -> WidgetKit renders ExamWidgetViews                       |
|                                                                           |
+---------------------------------------------------------------------------+
```

=====================================================================

## Views Reference

### Tab Structure

```
+---------------------------------------------------------------------------+
|                        ContentView (TabView)                               |
+===========================================================================+
|                                                                           |
|  Tab 1: HomeView           -> Dashboard                                   |
|  Tab 2: TrendsView         -> Trend analysis                              |
|  Tab 3: MistakeView        -> Mistake notebook                            |
|  Tab 4: ExamView           -> Exam list                                   |
|  Tab 5: SettingsView       -> Settings: profile card, edit profile/subjects, preferences, academic info, data management (CSV export/import), about |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Modal Sheet Navigation

```
+---------------------------------------------------------------------------+
|                       Modal Sheet Navigation Flow                          |
+===========================================================================+
|                                                                           |
|  HomeView                                                                 |
|   +---> (quick action) AddGradeView        (.sheet)                       |
|   +---> (quick action) NewExamSet          (.sheet)                       |
|   +---> (tap exam)    ExamDetailView       (.navigationDestination)       |
|                                                                           |
|  TrendsView                                                               |
|   +---> (tap subject) SubjectDetailView    (.navigationDestination)       |
|                                                                           |
|  ExamView                                                                 |
|   +---> (+ button)    NewExamSetView       (.sheet)                       |
|   +---> (tap exam)    ExamDetailView       (.navigationDestination)       |
|          |                                                                  |
|          +---> (edit)    NewExamSetView (edit mode)                       |
|          +---> (related) MistakeDetailEditView                            |
|                                                                           |
|  MistakeView                                                              |
|   +---> (+ button)    MistakeDetailEditView (new)   (.sheet)              |
|   +---> (tap mistake) MistakeDetailEditView (edit)  (.navigationDestination)|
|          |                                                                  |
|          +---> (OCR)     OCRManager.recognizeText()  (async)              |
|          +---> (image)   PhotosPicker / UIImagePicker  (async)            |
|                                                                           |
|  SettingsView                                                             |
|   +---> Profile Card (tap avatar -> AvatarPickerSheet)                    |
|   +---> ProfileEditView      (.sheet)                                      |
|   +---> EditSubjectsView     (.sheet)                                      |
|   +---> PreferencesView      (.sheet)                                      |
|   +---> AboutView / CopyrightView (.sheet)                                 |
|          |                                                                  |
|          +---> AvatarPickerSheet         (nested)                         |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Views Reference Table

| View | File | Role | Key Features |
|------|------|------|--------------|
| ContentView | ContentView.swift | Root container | 5-tab TabView with `.tabViewStyle(.sidebarAdaptable)` for iPad sidebar |
| HomeView | HomeView.swift | Dashboard | Welcome header, stat cards (4-col on iPad), upcoming exams, subject chart, smart tips; `AdaptiveHStack` 2-col sections on iPad |
| TrendsView | TrendsView.swift | Trend analysis | Subjects Needing Attention alerts, per-subject score cards, score/ranking toggle; `.adaptiveMaxWidth(900)` on iPad |
| ExamView | ExamView.swift | Exam list | Calendar integration, days remaining countdown; `.adaptiveMaxWidth(800)` on iPad |
| ExamDetailView | ExamDetailView.swift | Exam detail | Related Mistakes section, mastery degree, notes |
| NewExamSetView | NewExamSetView.swift | Exam editor | Create / edit exam, calendar & reminder toggles |
| MistakeView | MistakeView.swift | Mistake list | Suggested for Review section, search, card layout; `.adaptiveMaxWidth(900)` on iPad |
| MistakeDetailEditView | MistakeDetailEditView.swift | Mistake editor | 4-section editing, OCR, photo per-section, markdown preview |
| AddGradeView | AddGradeView.swift | Grade entry | Single / multi-subject input, custom full score, raw score/ranking |
| SettingsView | SettingsView.swift | Settings | Profile card (tap avatar -> picker), edit profile/subjects, app preferences (navigation link), academic info (school/grade/class/region/education system/targets), data management (CSV export / import grouped as menus), about / copyright & license / test notification; `.adaptiveMaxWidth(720)` on iPad |
| ProfileEditView | ProfileEditView.swift | Profile editor | 12+ fields (student ID, enrollment year, target school, etc.) |
| EditSubjectsView | EditSubjectsView.swift | Subject editor | Per-subject full score customization |
| PreferencesView | PreferencesView.swift | Preferences | Light/Dark/System theme; English/Chinese/Japanese/Korean/Follow-System language; `.adaptiveMaxWidth(640)` on iPad |
| AvatarView | Helpers/AvatarView.swift | Reusable | Avatar display with first-letter fallback |
| SubjectScoreCard | Helpers/SubjectScoreCard.swift | Reusable | Icon + score + mini trend chart |
| iPadLayout | Helpers/iPadLayout.swift | Reusable | `adaptiveMaxWidth()`, `AdaptiveHStack`, `AdaptiveGridColumns`, `adaptiveCardPadding()` -- iPad layout helpers |

### HomeView Chart Selection Strategies

| Strategy | Selection Criterion |
|----------|---------------------|
| Focus: Weakest | Lowest average score |
| Focus: Most Data | Most recorded grades |
| Focus: Recent | Most active in last 30 days |
| Focus: Improving | Biggest improvement |
| Random | Random subject |

### Score Color Rules

Proportional to full score (not fixed 100):

| Percent of Full Score | Color |
|----------------------|-------|
| >= 90% | Green |
| >= 75% | Blue |
| >= 60% | Orange |
| < 60%  | Red |

```swift
// Backward compatible (assumes 100 full score)
func scoreColor(_ score: Double) -> Color

// Proportional color based on full score
func scoreColor(_ score: Double, fullScore: Double) -> Color

// Format: "85.0/100 (85%)"
func scoreColorText(_ score: Double, fullScore: Double) -> String
```

=====================================================================

## Education Systems

### Education System Classification Tree

```
Education Systems (EducationConfig)
|
+-- Domestic (国内)
|   +-- China (中国)
|   |   +-- Mainland Standard (中国大陆标准版)
|   |   |   +-- Primary School (小学)
|   |   |   +-- Middle School (初中)
|   |   |   +-- High School (高中)
|   |   +-- Zhejiang (浙江)
|   |   |   +-- Middle School (初中)
|   |   |   +-- High School 3+3 (高中 3+3)
|   |   +-- Shanghai (上海)
|   |   |   +-- Middle School (初中)
|   |   |   +-- High School 3+3 (高中 3+3)
|   |   +-- Taiwan (台湾)
|   |   |   +-- Middle School (初中)
|   |   |   +-- GSAT (学测)
|   |   +-- Hong Kong (香港)
|   |       +-- DSE
|   |
|   +-- Singapore (新加坡)
|       +-- O-Level
|
+-- International (国际)
    +-- United Kingdom (英国)
    |   +-- IGCSE
    |   +-- A-Level
    |
    +-- IB
    |   +-- Diploma Programme (DP)
    |
    +-- United States (美国)
    |   +-- AP (Advanced Placement)
    |   +-- SAT (Scholastic Assessment Test)
    |   +-- ACT (American College Testing)
    |
    +-- Graduate & Language (研究生 & 语言)
        +-- GRE (Graduate Record Examination)
        +-- GMAT (Graduate Management Admission Test)
        +-- TOEFL (Test of English as a Foreign Language)
        +-- IELTS (International English Language Testing System)
```

### Coverage Matrix

| Region | Primary | Middle | High School | Intl. High School | University | Graduate |
|--------|---------|--------|-------------|-------------------|------------|----------|
| 中国大陆 | Yes | Yes | Yes | - | - | - |
| 浙江 | - | Yes | Yes (3+3) | - | - | - |
| 上海 | - | Yes | Yes (3+3) | - | - | - |
| 台湾 | - | Yes | Yes (学测) | - | - | - |
| 香港 | - | - | Yes (DSE) | - | - | - |
| 新加坡 | - | Yes (O-Level) | Yes (O-Level) | Yes | - | - |
| UK IGCSE | - | Yes | - | Yes | - | - |
| UK A-Level | - | - | Yes | Yes | - | - |
| IB Diploma | - | - | Yes | Yes | - | - |
| US AP | - | - | Yes | Yes | - | - |
| US SAT | - | - | - | - | Yes | - |
| US ACT | - | - | - | - | Yes | - |
| GRE / GMAT | - | - | - | - | - | Yes |
| TOEFL / IELTS | - | - | - | - | - | Yes |

### Score Scale Reference

| System | Scale | Example |
|--------|-------|---------|
| 中国大陆 高中 | 100 / 150 | 语文 150, 物理 100 |
| 浙江 高中 | 100 (赋分) | All subjects 100 max |
| 香港 DSE | 1-7 (5** = 7) | All subjects 7 max |
| 台湾 学测 | 100 | 数学A / 数学B 各 100 |
| UK A-Level | 100 | A* = 90+ |
| IB DP | 1-7 | 6 subjects + TOK + EE = 45 |
| US AP | 1-5 | 5 = max |
| US SAT | 200-800 | 1600 total |
| US ACT | 1-36 | 36 = max |
| GRE | 130-170 | 340 total |
| TOEFL | 0-120 | - |
| IELTS | 0-9 | - |

### Domestic vs. International Comparison

| Dimension | Domestic Systems | International Systems |
|-----------|------------------|-----------------------|
| Typical full score | 100 / 150 | Variable (1-5, 1-7, 1-36, 200-800, 0-120, 0-9) |
| Subjects fixed / flexible | Mostly fixed (regional curriculum) | Flexible (choose subjects) |
| Exam frequency | Annual / semester | Set dates (AP May, SAT monthly, etc.) |
| Ranking system | Yes (ranking on Grade) | Not applicable (percentile-based scales) |
| Supported stages | Primary / Middle / High | High / University / Graduate |

=====================================================================

## Widget Extension

### Widget Architecture Diagram

```
+---------------------------------------------------------------------------+
|                         Main App (StudyPulse)                              |
+===========================================================================+
|                                                                           |
|  +--------------------------------------------------------------------+   |
|  |  DataManager                                                         |   |
|  |  - examSets                                                          |   |
|  |  - comprehensiveExamSets                                             |   |
|  +-----------------------------+---------------------------------------+   |
|                                |                                           |
|                                v                                           |
|  +--------------------------------------------------------------------+   |
|  |  WidgetDataSyncManager                                               |   |
|  |  - syncExamsToWidget()                                               |   |
|  +-----------------------------+---------------------------------------+   |
|                                |                                           |
+--------------------------------+------------------------------------------+
                                 |
                                 |   App Group Container
                                 |   (group.Gao-Chenkai.StudyPulse)
                                 |
+--------------------------------+------------------------------------------+
|                    StudyPulseWidget Extension                             |
+===========================================================================+
|                                |                                           |
|                                v                                           |
|  +--------------------------------------------------------------------+   |
|  |  ExamWidgetData (Shared Data Model)                                 |   |
|  +-----------------------------+---------------------------------------+   |
|                                |                                           |
|                                v                                           |
|  +--------------------------------------------------------------------+   |
|  |  ExamWidgetProvider (Timeline Provider)                             |   |
|  |  - getTimeline()                                                    |   |
|  |  - placeholder()                                                    |   |
|  +-----------------------------+---------------------------------------+   |
|                                |                                           |
|                                v                                           |
|  +--------------------------------------------------------------------+   |
|  |  ExamWidgetViews                                                      |   |
|  |  - Small Widget View                                                  |   |
|  |  - Medium Widget View                                                 |   |
|  |  - Large Widget View                                                  |   |
|  +--------------------------------------------------------------------+   |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Widget Files

| File | Role |
|------|------|
| ExamWidget.swift | Widget definition |
| ExamWidgetData.swift | Shared data model (App Group) |
| ExamWidgetEntry.swift | Timeline entry |
| ExamWidgetProvider.swift | Timeline provider |
| ExamWidgetViews.swift | Widget UI views (small / medium / large) |
| StudyPulseWidgetBundle.swift | Widget bundle |

### Data Sharing Mechanism

| Component | Role |
|-----------|------|
| App Group container | `group.Gao-Chenkai.StudyPulse` |
| WidgetDataSyncManager | Syncs ExamWidgetData to shared container on every exam save |
| ExamWidgetProvider | Reads ExamWidgetData from shared container, builds timeline |
| WidgetKit | Reloads timelines when sync manager signals |

=====================================================================

## Notification System

### Notification Scheduling Flow

```
+---------------------------------------------------------------------------+
|                    Notification Scheduling Flow                           |
+===========================================================================+
|                                                                           |
|  Trigger: User creates / edits an exam with reminders enabled             |
|                                                                           |
|  +-----------------------------------------------------------------+      |
|  |                                                                 |      |
|  |  NewExamSetView / ExamDetailView                                |      |
|  |   |                                                              |      |
|  |   +---> Toggle: "Add to Calendar" (default ON)                  |      |
|  |   +---> Toggle: "Exam Reminders"  (default ON)                  |      |
|  |                                                                 |      |
|  +-----------------------------+-----------------------------------+      |
|                                |                                           |
|                                v                                           |
|  ExamPrepareNotifications.scheduleExamPrepareNotification(exam: Exam)      |
|   |                                                                       |
|   +---> Request UNAuthorization (.alert, .sound, .badge)                |
|   +---> Create UNMutableNotificationContent                              |
|   |       title: "Exam Tomorrow: {exam.name}"                            |
|   |       body:  "Do not forget to review!"                              |
|   |       sound: .default                                                |
|   |                                                                      |
|   +---> Calculate trigger date (examDate - 1 day)                        |
|   +---> Create UNCalendarNotificationTrigger                             |
|   +---> Create UNNotificationRequest (id: "exam_{exam.id}")              |
|   +---> UNUserNotificationCenter.add(request)                            |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Notification Lifecycle

```
+---------------------------------------------------------------------------+
|                          Notification Lifecycle                           |
+===========================================================================+
|                                                                           |
|  Create Exam  ------> Schedule Notification                               |
|                                                                           |
|  Edit Exam    ------> Cancel Old Notification                             |
|  (date changed)        |                                                  |
|                         +------> Create New Notification                  |
|                                                                           |
|  Delete Exam  ------> Cancel Notification (by id: "exam_{exam.id}")      |
|                                                                           |
+---------------------------------------------------------------------------+
```

=====================================================================

## OCR System

### OCR Processing Pipeline

```
+---------------------------------------------------------------------------+
|                       OCR Processing Pipeline                              |
+===========================================================================+
|                                                                           |
|  User Action: Tap "OCR" button in MistakeDetailEditView                   |
|                                                                           |
|  +-----------------------------------------------------------------+      |
|  |  Step 1: Check Image Availability                               |      |
|  |   - Current edit section has image array                        |      |
|  |   - Get last uploaded image filename                            |      |
|  |   - Load image from ~/Documents/images/{filename}               |      |
|  |   - If no image -> Show alert "No image to recognize"           |      |
|  +-----------------------------+-----------------------------------+      |
|                                |                                           |
|                                v                                           |
|  +-----------------------------------------------------------------+      |
|  |  Step 2: Vision Framework Processing                             |      |
|  |   - Create VNImageRequestHandler(cgImage, options:)              |      |
|  |   - Create VNRecognizeTextRequest                               |      |
|  |        recognitionLevel:    .accurate  (slower, better results) |      |
|  |        usesLanguageCorrection: true                               |      |
|  |        revision: VNRecognizeTextRequestRevision3                  |      |
|  |                                                                      |
|  |   - Perform request -> [VNRecognizedTextObservation]              |      |
|  |   - Extract topCandidates(1) from each observation                |      |
|  |   - Join all candidate strings with newlines                      |      |
|  +-----------------------------+-----------------------------------+      |
|                                |                                           |
|                                v                                           |
|  +-----------------------------------------------------------------+      |
|  |  Step 3: Result Display                                            |      |
|  |   - If text found -> Insert into current TextEditor section       |      |
|  |        (originalQuestion / errorReason / wrongSolution /         |      |
|  |         correctSolution)                                          |      |
|  |   - If no text -> Show alert "No text detected in image"          |      |
|  |   - Error -> Show error alert                                     |      |
|  +-----------------------------------------------------------------+      |
|                                                                           |
|  Vision Framework Details:                                                 |
|   - Supports: Chinese (Simplified / Traditional), English, mixed          |
|   - async/await pattern: await handler.perform([request])                 |
|   - Runs on background thread (non-blocking UI)                           |
|   - Accuracy: .accurate > .fast (trade-off speed vs. quality)             |
|   - Language correction: Improves results for common words                |
|                                                                           |
+---------------------------------------------------------------------------+
```

### OCRManager API

```swift
class OCRManager {
    func recognizeText(from image: UIImage) async throws -> String
}
```

### Supported Languages

| Language | Code |
|----------|------|
| Simplified Chinese | zh-Hans |
| Traditional Chinese | zh-Hant |
| English | en |
| Mixed (auto) | auto |

=====================================================================

## Image Cache System

### Image Cache Architecture

```
+---------------------------------------------------------------------------+
|                       Image Cache System                                  |
+===========================================================================+
|                                                                           |
|  SwiftUI Views (MistakeDetailEditView, Grade cards, etc.)                |
|                                |                                           |
|                                v                                           |
|  DataManager.getImage(filename)                                            |
|   |                                                                       |
|   +---> Check ImageCache.cached[filename]                                 |
|   |     +---> Hit? -> return UIImage immediately                          |
|   |     +---> Miss? -> load from disk                                     |
|   |                                                                       |
|   +---> Load from disk: ~/Documents/images/{filename}                     |
|   |     +---> Read file as Data -> UIImage(data:)                         |
|   |     +---> Downscale to max 300 px for thumbnail                       |
|   |                                                                       |
|   +---> Store in NSCache (key: filename)                                  |
|   |     +---> Max 50 entries (LRU eviction by NSCache)                    |
|   |                                                                       |
|   +---> Return UIImage                                                     |
|                                                                           |
+---------------------------------------------------------------------------+
```

### ImageCache API

```swift
nonisolated class ImageCache {
    static let shared = ImageCache()

    func image(for filename: String) -> UIImage?       // full size
    func thumbnail(for filename: String) -> UIImage?   // ~300 px thumbnail
    func clear()                                        // flush cache
}
```

### Cache Configuration

| Parameter | Value |
|-----------|-------|
| Cache backend | NSCache<NSString, UIImage> |
| Max entries | 50 |
| Max thumbnail size | 300 px |
| Thread safety | nonisolated + NSCache internal locking |
| Disk path | ~/Documents/images/ |

=====================================================================

## CSV Export

### CSV Export Flow

```
+---------------------------------------------------------------------------+
|                         CSV Export Flow                                   |
+===========================================================================+
|                                                                           |
|  User action: Tap "Export Grades" (in SettingsView or TrendsView)         |
|                                |                                           |
|                                v                                           |
|  1. Collect source data                                                     |
|     DataManager.grades            -> [Grade]                               |
|     DataManager.profile           -> UserProfile (for subject fullScores) |
|     SubjectConfig.fullScore maps -> per-subject scale                     |
|                                |                                           |
|                                v                                           |
|  2. Build header row                                                         |
|     "Subject,Score,FullScore,ScoreRate,Ranking,ExamName,Date,Importance"   |
|                                |                                           |
|                                v                                           |
|  3. Iterate grades and build data rows                                      |
|     For each Grade:                                                         |
|       - Subject display name (SubjectDisplay.displayName)                   |
|       - Score                                                               |
|       - FullScore  (resolve via Subject / SubjectConfig)                    |
|       - ScoreRate = score / fullScore                                       |
|       - Ranking                                                             |
|       - Exam name                                                           |
|       - Date (ISO 8601)                                                     |
|       - Importance (1-5)                                                    |
|                                |                                           |
|                                v                                           |
|  4. Write to CSV file                                                         |
|     Filename: "StudyPulse_Grades_{yyyyMMdd}.csv"                            |
|     Path:     ~/Documents/exports/{filename}                                |
|     Encoding: UTF-8                                                         |
|                                |                                           |
|                                v                                           |
|  5. Share via UIActivityViewController                                        |
|     Present system share sheet with .fileURL                                |
|                                |                                           |
|                                v                                           |
|  6. Optional: Mistakes / Exams CSV                                           |
|     Same pattern for MistakeNote[] and Exam[] / comprehensiveExam[]        |
|                                                                           |
+---------------------------------------------------------------------------+
```

### CSV Column Layout - Grades

| Column | Source | Notes |
|--------|--------|-------|
| Subject | Grade.subject -> displayName | Resolved via SubjectDisplay |
| Score | Grade.score | Numeric |
| FullScore | Grade.fullScore ?? Subject.fullScore | Fallback chain |
| ScoreRate | score / fullScore | Percent |
| Ranking | Grade.ranking | Optional, blank if absent |
| Exam Name | Grade.examName | |
| Date | Grade.date | ISO 8601 |
| Importance | Grade.importance | 1-5 |

### CSV Column Layout - Mistakes

| Column | Source |
|--------|--------|
| Title | MistakeNote.title |
| Subject | MistakeNote.subject |
| Source | MistakeNote.source |
| Date | MistakeNote.date |
| Original Question | MistakeNote.originalQuestion (truncated) |
| Error Reason | MistakeNote.errorReason (truncated) |
| Correct Solution | MistakeNote.correctSolution (truncated) |

=====================================================================

## iPad Adaptation

The app is a universal binary targeting both iPhone and iPad
(`TARGETED_DEVICE_FAMILY = "1,2"`). iPhone layouts are untouched; iPad gets
a native sidebar tab bar and multi-column, width-constrained layouts.

### High-Level Approach

| Concern | iPhone Behavior | iPad Behavior |
|---------|-----------------|---------------|
| Tab Bar | Bottom 5-tab (classic) | Left sidebar (`.tabViewStyle(.sidebarAdaptable)`) |
| Content width | Full screen edge-to-edge | Centered, clamped to max-width |
| Section layout | Vertical stack (VStack) | Side-by-side (HStack) via `AdaptiveHStack` |
| Stats card | 2x2 grid | 4-in-a-row |
| Form / List | Full width | Centered, narrow column |

### Adaptive Helpers (`Views/Helpers/iPadLayout.swift`)

```swift
// 1) Content max-width
struct AdaptiveContentWidth: ViewModifier {  // var maxWidth: CGFloat = 720
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)        // center
    }
}
extension View {
    func adaptiveMaxWidth(_ maxWidth: CGFloat = 720) -> some View
}

// 2) Multi-column grid items (1 col on iPhone, N col on iPad)
struct AdaptiveGridColumns {
    init(compact: Int = 1, regular: Int = 2, spacing: CGFloat = 20)
}

// 3) 2-column HStack / VStack switcher
struct AdaptiveHStack<Content: View>: View {
    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content)
    // sizeClass == .regular -> HStack
    // else                -> VStack
}

// 4) Card outer padding (20pt on iPhone, 0 on iPad)
struct AdaptiveCardPadding: ViewModifier
extension View {
    func adaptiveCardPadding() -> some View
}
```

All helpers read `horizontalSizeClass` via `@Environment` inside `body`; this
environment value cannot be accessed from a generic View extension property.

### File-by-File Changes

| File | iPad Adaptation |
|------|-----------------|
| `ContentView.swift` | `.tabViewStyle(.sidebarAdaptable)` for sidebar on iPad |
| `HomeView.swift` | `frame(maxWidth: 1100)` container + `AdaptiveHStack` 2-col sections + 4-col `MainStatsCard` |
| `SettingsView.swift` | `.adaptiveMaxWidth(720)` on the List |
| `PreferencesView.swift` | `.adaptiveMaxWidth(640)` on the Form |
| `TrendsView.swift` | `.adaptiveMaxWidth(900)` on the ScrollView |
| `MistakeView.swift` | `.adaptiveMaxWidth(900)` on `MistakeView` + `SubjectMistakesView` |
| `ExamView.swift` | `.adaptiveMaxWidth(800)` on the List |
| `Helpers/iPadLayout.swift` | **NEW** -- all adaptive helpers |

### Width Constraints Reference

| View | iPad Max Width | Reason |
|------|----------------|--------|
| `SettingsView` | 720 | Single-column forms read best near 600-720pt |
| `PreferencesView` | 640 | Compact settings panel |
| `ExamView` | 800 | Slightly wider for countdown + notes |
| `TrendsView` | 900 | Charts need more horizontal space |
| `MistakeView` | 900 | Long markdown content benefits from width |
| `HomeView` | 1100 | Dashboard / multi-column can be wider |

### HomeView Multi-Column Layout (iPad)

```
+---------------------------------------------------+
|  Welcome Header (full width within 1100 max)      |
+-----------------+---------------------------------+
|   Stat 1  Stat 2  Stat 3  Stat 4   (one row)     |
+-----------------+---------------------------------+
| Quick Actions   |  Upcoming Exams   (2-col)       |
|-----------------+---------------------------------|
| Chart / Trend   |  Suggestions       (2-col)      |
+-----------------+---------------------------------+
| Daily Quote / Recent Grades (full width)          |
+---------------------------------------------------+
```

### Design Principles

1. **No iPhone regression** -- every change gated on `horizontalSizeClass` or
   `UIDevice.current.userInterfaceIdiom`.
2. **Centered, not stretched** -- content is centered with a max-width on
   iPad, preserving readability.
3. **Native iPad feel** -- sidebar tab bar + multi-column dashboards.
4. **Single source of truth** -- all adaptive logic in `iPadLayout.swift`;
   feature views just call the helpers.

=====================================================================

## Performance Patterns

### Pattern Summary Table

| Pattern | Implementation | Benefit |
|---------|----------------|---------|
| Async startup | `asyncInit()` in `.task` modifier | No main-thread blocking on launch |
| Image caching | `ImageCache` (NSCache, max 50 entries) | Fast thumbnail reuse; avoids disk hit on repeat renders |
| File-based images | Grade/avatar images stored as separate files, not in JSON | Smaller JSON files; faster model (de)serialization |
| Computed properties | `daysRemaining` etc. computed, not `@State` + `onAppear` | Fewer invalidations, cleaner code |
| Sendable models | All models marked `nonisolated` + `Sendable` | Swift 6 concurrency safety, actor isolation checks |
| Factory construction | `SubjectConfig.required(...)` / `.elective(...)` | Clean subject configuration without ad-hoc literals |
| Atomic file writes | DataFileIO uses temp file + rename | No partial writes; crash-safe saves |

### Asynchronous Data Loading Timeline

```
           User launches app
                 |
                 v
+------------------------------+  Main Thread
|  StudyPulseApp appears       |
|  .task { ... } modifier      |
+------------+-----------------+
             |
             |   (async await)
             v
+------------------------------+  Background Thread (cooperative)
|  DataManager.asyncInit()     |
|  +---> loadProfileAsync()    |
|  +---> loadGradesAsync()     |
|  +---> loadSubjectsAsync()   |
|  +---> loadExamsAsync()      |
|  +---> loadComprehensiveExamsAsync() |
|  +---> loadMistakeSetsAsync()|
|  +---> (optional) default subjects |
+------------+-----------------+
             |
             |   @MainActor: state commit
             v
+------------------------------+  Main Thread
|  @Published properties set   |
|  SwiftUI re-renders views    |
|  (HomeView, TrendsView, ...) |
+------------------------------+
```

### View Optimization Techniques

| Technique | Where |
|-----------|-------|
| Computed properties instead of @State + onAppear | Days remaining, score rate, derived stats |
| Reusable components (SubjectScoreCard, AvatarView) | HomeView, TrendsView, MistakeView, ExamView |
| Lazy stacks for long lists | MistakeView card grid, ExamView list |
| ImageCache for thumbnail reuse | Every view that renders grade/mistake images |
| Small / medium / large Widget variants | ExamWidgetViews (different layouts per size class) |

=====================================================================

## Privacy

### Permissions Table

| Permission | Purpose |
|------------|---------|
| Camera | Photo capture for mistake notes and avatar |
| Photo Library | Photo selection for mistake notes and avatar |
| Calendars | Add exams to the system calendar (EventKit) |
| Notifications | Schedule exam reminder notifications |

### Data Storage Locations

| Data | Location | Encryption |
|------|----------|------------|
| User profile, grades, subjects, exams, mistakes | ~/Documents/*.json | iOS default at-rest encryption |
| Grade images, avatars | ~/Documents/images/*.jpg | iOS default at-rest encryption |
| Widget data | App Group container (shared with widget) | iOS default at-rest encryption |
| App preferences (language + theme) | preferences file in sandbox | iOS default at-rest encryption |

Note: All data is stored locally on the device. No data is uploaded to remote servers.

=====================================================================

## Build Commands

```bash
# Open project in Xcode
open StudyPulse.xcodeproj

# Resolve Swift Package Manager dependencies
# Xcode -> File -> Packages -> Resolve Package Versions

# Build (from Xcode)
# Cmd + B

# Run on simulator or device (from Xcode)
# Cmd + R

# Clean build folder
# Cmd + Shift + K

# Product -> Archive to distribute
# (ad-hoc, App Store, or TestFlight)
```

### Targets

| Target | Role | Notes |
|--------|------|-------|
| StudyPulse (iOS) | Main app | SwiftUI, iOS 18.6+ |
| StudyPulseWidget | Home screen widget | WidgetKit, shares data via App Group |

=====================================================================

## Coding Standards and Conventions

### General Style Guide

| Rule | Standard |
|------|----------|
| File organization | One file per major manager / view / model; helpers grouped in `Helpers/` |
| Naming | UpperCamelCase for types, lowerCamelCase for members; American English |
| Access control | Use `private` / `fileprivate` where possible; managers expose minimal public API |
| Singletons | Prefer `.shared` singletons for managers that are stateless caches or system clients |
| `@MainActor` | All ObservableObject view-model objects marked `@MainActor` (via class-level annotation) |
| Async / await | Prefer structured concurrency; avoid unchecked Task detaches |
| Error handling | `async throws` for recoverable failure paths; fatalError only for true programmatic bugs |
| Force unwraps | Avoid; use guard-let / if-let / default values |

### Model / Manager Conventions

| Item | Pattern |
|------|---------|
| Models | `nonisolated struct X: Identifiable, Codable, Hashable` (Sendable when fields allow) |
| ID property | `var id = UUID()` unless there is a stable business key (e.g., `name`) |
| Persistence API | `DataManager.save{Entity}()` writes to `{entity}.json` atomically |
| Published properties | One `@Published var` per entity array / object; views read via `@EnvironmentObject` |
| Manager dependencies | Views never import helpers; DataManager mediates ImageCache / OCRManager / etc. |

### View Conventions

| Item | Pattern |
|------|---------|
| Root view | `ContentView` is the top-level TabView; `StudyPulseApp` owns environment injection |
| Navigation | `.navigationDestination(...)` for drill-down; `.sheet(...)` for modal editors |
| State | Prefer `@Binding` + `@EnvironmentObject` over local `@State` for business data |
| Reusables | Stateless `struct Foo: View` with explicit `let` parameters in `Helpers/` |
| Theme | Color scheme driven by `AppEnvironmentManager.effectiveColorScheme` |
| Localization | Use `String(localized:...)` / `Text("key")`; never hard-coded user-facing strings |

### File I/O Conventions

| Item | Pattern |
|------|---------|
| Reader | `DataFileIO.read(from: .documentsDirectory.appending(...))` returns `Data?` or throws |
| Writer | `DataFileIO.write(data, to: url)` uses temp file + `rename()` for atomicity |
| Threading | `DataFileIO` is `nonisolated`; safe to call from async contexts |
| Images | Always stored as files in `~/Documents/images/` with UUID filenames; `imageFileName` on model, not inline `Data` |

### Concurrency Model

| Layer | Actor Isolation |
|-------|-----------------|
| Views | MainActor (SwiftUI default) |
| DataManager | MainActor (declared via ObservableObject on main actor) |
| Persistence helpers (DataFileIO) | nonisolated |
| ImageCache | nonisolated |
| OCRManager | nonisolated (Vision runs off main) |
| WidgetDataSyncManager | nonisolated (App Group I/O) |
| Models | nonisolated structs, Sendable where possible |

=====================================================================

## Changelog

### v2026.06.13 - iPad Adaptation

- Project now supports iPad natively (`TARGETED_DEVICE_FAMILY = "1,2"`)
- New `Views/Helpers/iPadLayout.swift` with size-class adaptive helpers:
  - `adaptiveMaxWidth(_:)` ViewModifier -- center & clamp content on iPad
  - `AdaptiveHStack` -- HStack on iPad, VStack on iPhone
  - `AdaptiveGridColumns` -- multi-column grids by device idiom
  - `adaptiveCardPadding()` -- unified outer padding across iPhone/iPad
- `ContentView` uses `.tabViewStyle(.sidebarAdaptable)` (iOS 18+) so iPad
  gets a native sidebar tab bar automatically
- `HomeView`:
  - Centered `frame(maxWidth: 1100)` container on iPad
  - `MainStatsCard` lays out 4 stats in one row on iPad (vs 2x2 on iPhone)
  - Welcome / Quick Actions / Exams / Chart sections use `AdaptiveHStack`
    for 2-column layouts on iPad
- `SettingsView` (720), `PreferencesView` (640), `TrendsView` (900),
  `MistakeView` (900), `ExamView` (800) all use `.adaptiveMaxWidth` to keep
  form/list content centered and readable on iPad
- iPhone layout is unchanged; all iPad behavior is gated on
  `horizontalSizeClass == .regular` or `UIDevice.current.userInterfaceIdiom`
- Verified on iPad Pro 11-inch (M5) simulator + iPhone simulator builds
  with no warnings

### v2026.06.07 - Full View Layer Refactor + Design System

- HomeView split into 9 independent components for modular design
- MistakeView: suggested review horizontal scroll + card gradient beautification
- TrendsView: added "Subjects Needing Attention" smart alerts
- ExamDetailView: added related mistakes section
- SubjectScoreCard: gradient border + entrance animation
- New AppStyle design system skeleton (.minimal / .literature / .tech)
- New StudyPulseWidget home screen widget complete skeleton
- WidgetBundle / Provider / Entry / three size views
- App side ExamWidgetData + WidgetDataSyncManager
- Rewrote AGENTS.md as full AI agent guide
- Added architecture diagrams and data flow diagrams to all three docs

### v2026.06.06 - Multi-Language Support

- Added Traditional Chinese (zh-Hant) localization
- Added Japanese (ja) localization
- Added Korean (ko) localization
- Updated language selector, supporting six languages
- Optimized app performance and memory management
- Improved ImageCache and DataManager

### v2026.06.05 - Mistake Module Launch

- Mistake editing in four sections: original question / error reason / wrong solution / correct solution
- Each section supports photo capture or gallery selection independently
- OCR text recognition based on Vision framework
- Markdown preview functionality
- Calendar integration, auto add exam reminders
- ZoomableImageView with pinch-to-zoom
- Complete mistake CRUD operations

### v2026.06 - Global Education System Support

- Added EducationConfig supporting 15+ education systems
- Added SubjectConfig factory methods
- New user avatar system
- Score color by proportion of full score
- Extended user profile fields
- Redesigned home page UI
- Added "Subjects Needing Attention" alerts on Trends page
- Added "Suggested for Review" section on Mistakes page
- Added "Related Mistakes" display on Exam detail page
- Added WidgetKit widget support

=====================================================================
