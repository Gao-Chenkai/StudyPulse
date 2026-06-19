# StudyPulse - AI Agent Guide

> Complete developer guide for AI agents working on the StudyPulse iOS app

==============================================================================

## Quick Reference

| Item | Details |
|------|---------|
| **Platform** | iOS 18.6+ (iPhone & iPad) |
| **Language** | Swift 6.0 |
| **Architecture** | MVVM + `@EnvironmentObject` |
| **IDE** | Xcode 26.3 |
| **Device Family** | iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) |
| **Dependencies** | WSOnBoarding, swift-markdown-ui (SPM) |
| **Storage** | JSON files in `~/Documents/` |
| **App Group** | `group.Gao-Chenkai.StudyPulse` |
| **Privacy** | Camera, Photo Library, Calendar |
| **Charts** | SwiftUI Charts framework |
| **OCR** | Vision framework |
| **Calendar** | EventKit |
| **iPad Layout** | `Views/Helpers/iPadLayout.swift` (size-class adaptive) |

==============================================================================

## Project Overview

StudyPulse is an iOS study management app built with SwiftUI, helping students
track grades, manage mistakes, schedule exams, and analyze learning trends. It
supports global education systems (CN, US, UK, IB, AP, SAT, ACT, A-Level,
IGCSE, DSE, etc.).

==============================================================================

## Architecture Diagram

```
+---------------------------------------------------------------------------+
|                          StudyPulse iOS App                                |
+---------------------------------------------------------------------------+
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                         Presentation Layer                            |  |
|  +-----------------------------------------------------------------------+  |
|  |                                                                       |  |
|  |  +----------------+----------------+----------------+               |  |
|  |  |   ContentView (TabView) with 5 tabs                              |  |
|  |  |                                                                   |  |
|  |  |  +--------+  +--------+  +----------+  +----------+  +--------+  |  |
|  |  |  |  Home  |  | Trends |  | Mistakes |  |  Exams   |  |Setting |  |  |
|  |  |  +----+---+  +----+---+  +-----+----+  +-----+----+  +---+----+  |  |
|  |  |       |           |             |               |           |     |  |
|  |  +-------+-----------+-------------+---------------+-----------+-----+  |
|  |                                                                       |  |
|  +--+-----------+-----------+-----------+-----------+-----------+---------+  |
|     |           |           |           |           |           |           |
|     v           v           v           v           v           v           |
|  HomeView    TrendsView MistakeView   ExamView    MistakeDetailEditView    |
|  StatCards   Subject     Suggested     ExamList    (4 sections + OCR)      |
|  QuickActions  Cards      Review        Detail                               |
|  ExamCards    Alerts     Search        Calendar                             |
|  TrendChart   Charts     Markdown      Notifications                        |
|  RecentGrades Detail     Images        Related Mistakes                     |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                           Business Layer                              |  |
|  +-----------------------------------------------------------------------+  |
|  |                                                                       |  |
|  |  +----------------+   +----------------------+   +-----------------+  |  |
|  |  |  DataManager   |<--| AppEnvironmentManager |<--| EducationConfig |  |  |
|  |  |  (@MainActor)  |   |                      |   |                 |  |  |
|  |  +-------+--------+   +----------------------+   +-----------------+  |  |
|  |          |                                                             |  |
|  |  +-------+-----------------------------------------------------------+ |  |
|  |  |                          Managers                                | |  |
|  |  |                                                                   | |  |
|  |  |  +----------------+  +----------------+  +----------------+      | |  |
|  |  |  | Calendar       |  |   OCR          |  |  ImageCache    |      | |  |
|  |  |  | Manager        |  |   Manager      |  |                |      | |  |
|  |  |  +----------------+  +----------------+  +----------------+      | |  |
|  |  |                                                                   | |  |
|  |  |  +----------------+                                              | |  |
|  |  |  | WidgetData     |                                              | |  |
|  |  |  | SyncMgr        |                                              | |  |
|  |  |  +----------------+                                              | |  |
|  |  +-------------------------------------------------------------------+ |  |
|  +-----------------------------------------------------------------------+  |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                            Data Layer                                 |  |
|  +-----------------------------------------------------------------------+  |
|  |                                                                       |  |
|  |  +----------------+----------------+----------------+                |  |
|  |  |                        Models                                  | |  |
|  |  |  +------+  +------+  +------+  +---------+  +---------------+ | |  |
|  |  |  | Grade |  |Mistake|  | Exam |  | Subject |  |  UserProfile  | | |  |
|  |  |  +------+  +------+  +------+  +---------+  +---------------+ | |  |
|  |  |                                                                 | |  |
|  |  |  +-------------------+  +-------------------+                     |  |
|  |  |  |  SubjectConfig    |  |  EducationRegion  |                     |  |
|  |  |  +-------------------+  +-------------------+                     |  |
|  |  +-------------------------------------------------------------------+ |  |
|  |          |                                                               |  |
|  |  +-------+-----------------------------------------------------------+ |  |
|  |  |                         Persistence                               | |  |
|  |  |  ~/Documents/                                                      | |  |
|  |  |   +-- profile.json       grades.json       mistakes.json         | |  |
|  |  |   +-- exams.json         comprehensiveExams.json  subjects.json   | |  |
|  |  |   +-- images/            (avatar_*.jpg, grade_*.jpg)             | |  |
|  |  +-------------------------------------------------------------------+ |  |
|  +-----------------------------------------------------------------------+  |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                           Extensions                                  |  |
|  |  +-----------------+  +-----------------+  +------------------------+ |  |
|  |  | ColorExtensions |  | DateExtensions  |  | ExamPrepareNotificat.  | |  |
|  |  +-----------------+  +-----------------+  +------------------------+ |  |
|  +-----------------------------------------------------------------------+  |
|                                                                             |
|  +-----------------------------------------------------------------------+  |
|  |                        Widget Extension                                |  |
|  |  StudyPulseWidget/     (via App Group)                                 |  |
|  |   +-- ExamWidget.swift                                                 |  |
|  |   +-- ExamWidgetData.swift                                             |  |
|  |   +-- ExamWidgetProvider.swift                                         |  |
|  |   +-- ExamWidgetViews.swift                                            |  |
|  |   +-- StudyPulseWidgetBundle.swift                                     |  |
|  +-----------------------------------------------------------------------+  |
+---------------------------------------------------------------------------+
```

==============================================================================

## Module Dependency Graph

```
+------------------------+         +------------------------+
|        Views           |         |     Widget Extension    |
|  ContentView           |         |  ExamWidget             |
|  HomeView / TrendsView |         |  ExamWidgetViews        |
|  MistakeView / ExamView|         |  ExamWidgetProvider     |
|  + AddGradeView        |         +-----------+------------+
|  + NewExamSetView      |                     |
|  + NewMistakeSetView   |                     | (reads via App Group)
+-----------+------------+                     v
            |                       +------------------------+
            | (@EnvironmentObject)  |    App Group Container  |
            v                       |  group.Gao-Chenkai.    |
+------------------------+           |    StudyPulse           |
|      DataManager       |<----------+  (UserDefaults shared) |
|  (@MainActor,          |           +-----------+------------+
|   ObservableObject)    |                       |
|  grades / subjects     |                       v
|  mistakeSets / exams   |           +------------------------+
|  comprehensiveExams    |           |  WidgetDataSyncManager |
|  profile               |           |  ExamWidgetData        |
+-----+-----+------+-----+           +------------------------+
      |     |      |     |
      v     v      v     v
+-----+---+ +-+  +-+---+ +--------+
| Calendar| |O|  |Image| |Education|
| Manager | |C|  |Cache| | Config  |
| EventKit| |R|  |     | |Subject  |
+---------+ |M|  +-----+ |Config   |
            |g|          |Education|
            |r|          |Region   |
            | |          +--------+
            | |
            | |     +----------------+
            | +---->| OCRManager     |
            |       | (Vision)       |
            |       +----------------+
            |
            |       +---------------------+
            +------>| AppEnvironmentMgr   |
            |       |  AppPreferences      |
            |       |  Language + Theme    |
            |       +---------------------+
            |
            |       +---------------------+
            +------>| DataFileIO          |
                    |  nonisolated enum   |
                    |  background thread  |
                    +---------------------+
```

==============================================================================

## File Structure

```
StudyPulse/
|-- Models/
|   |-- DataModels.swift          Grade, MistakeNote, Exam, Subject, UserProfile
|   |-- AppPreferences.swift      Language + theme preference model
|
|-- Managers/
|   |-- DataManager.swift         Central data layer + JSON persistence + async loading
|   |-- AppEnvironmentManager.swift Global language & theme management
|   |-- AppStyle.swift            App visual style helpers
|   |-- CalendarManager.swift     EventKit calendar integration
|   |-- EducationConfig.swift     Global education systems (CN/UK/IB/AP/SAT/ACT)
|   |-- ExamWidgetData.swift      Widget-shared data (App Group)
|   |-- WidgetDataSyncManager.swift Sync data with widget extension
|   |-- OCRManager.swift          Vision framework text recognition
|   |-- ImageCache.swift          NSCache + thumbnail generation (nonisolated)
|   |-- SubjectInfo.swift         Subject display names & colors + max score fallback
|   |-- StringsLocalized.swift    String localization extension
|   |-- DataExportManager.swift   CSV export for grades / mistakes / exams
|
|-- Views/
|   |-- ContentView.swift         Main TabView (5 tabs)
|   |-- HomeView.swift            Dashboard with charts, suggestions, learning tips
|   |-- TrendsView.swift          Subject score trend analysis + attention alerts
|   |-- ExamView.swift            Exam list & management
|   |-- ExamDetailView.swift      Single exam detail + related mistakes
|   |-- ExamDetailEditView.swift  Exam editing
|   |-- NewExamSetView.swift      New exam form (single/comprehensive)
|   |-- MistakeView.swift         Mistake notebook + suggested review + search
|   |-- MistakeDetailEditView.swift Mistake editing with OCR
|   |-- NewMistakeSetView.swift   New mistake form with photo + OCR
|   |-- AddGradeView.swift        Grade entry form (supports custom full score)
|   |-- SettingsView.swift        Grouped settings: profile, edit, preferences, academic info, data management, about
|   |-- PreferencesView.swift     Language/theme preferences
|   |-- SubjectScoreCard.swift    Reusable subject score card
|   |
|   |-- Components/
|   |   |-- GradeChartView.swift  Charts for grades
|   |   |-- SubjectPickerView.swift
|   |
|   |-- Helpers/
|   |   |-- AvatarView.swift      User avatar with first-letter fallback
|   |   |-- BackgroundColors.swift
|   |   |-- ImagePicker.swift     Photo library / camera picker
|   |   |-- PhotoCaptureView.swift Camera capture
|   |   |-- ScoreColor.swift      Score-to-color mapping (proportional)
|   |   |-- ZoomableImageView.swift Pinch-to-zoom image viewer
|   |   |-- iPadLayout.swift      iPad adaptive helpers (adaptiveMaxWidth, AdaptiveHStack, AdaptiveGridColumns)
|   |
|   |-- OnBoarding/
|   |   |-- WelcomeConfig.swift   First-launch onboarding (WSOnBoarding)
|   |
|   |-- Sheets/
|       |-- NewMistakeSheet.swift Legacy mistake sheet (unused)
|
|-- Extensions/
|   |-- ColorExtensions.swift
|   |-- DateExtensions.swift
|
|-- NotificationsControl/
|   |-- ExamPrepareNotifications.swift Local notification scheduling
|
|-- StudyPulseApp.swift           App entry point

StudyPulseWidget/                 WidgetKit extension
|-- ExamWidget.swift              Widget definition
|-- ExamWidgetData.swift          Widget data model
|-- ExamWidgetEntry.swift         Timeline entry
|-- ExamWidgetProvider.swift      Timeline provider
|-- ExamWidgetViews.swift         Widget UI views
|-- StudyPulseWidgetBundle.swift  Widget bundle
|-- Info.plist
```

==============================================================================

## View Navigation Flow

```
+----------------------------+
|     StudyPulseApp          |
|  (.onAppear -> asyncInit)  |
+------------+---------------+
             |
             v
+--------------------------------------------------+
|         ContentView (TabView)                    |
|                                                  |
|  +-------+  +-------+  +--------+  +------+  +--------+
|  | Home  |  | Trends|  |Mistakes|  | Exams|  | Settings|
|  +---+---+  +---+---+  +----+---+  +--+---+  +----+---+
+------|----------|-----------|---------|-----------|------+
       |          |           |         |           |       |
       v          v           v         v           v       |
+--------------+  +---------------+  +-------------+  +-----------+
| HomeView     |  | TrendsView    |  | MistakeView |  | ExamView  |
| + Welcome    |  | + Attention   |  | + Suggested |  | + Exam    |
|   Header     |  |   Alerts      |  |   Review    |  |   List    |
| + StatCards  |  | + Subject     |  | + Searchable|  | + Compreh.|
| + Quick      |  |   Cards       |  |   List      |  |   ExamList|
|   Actions    |  | + Detail      |  | + [Add      |  | + [Add    |
| + ExamCards  |  |   View        |  |   Mistake]  |  |   Exam]   |
| + DailyQuote |  |               |  |     |       |  |    |      |
| + TrendChart |  |               |  |     v       |  |    v      |
| + Recent     |  |               |  | NewMistake  |  | NewExam   |
|   Grades     |  |               |  | SetView     |  | SetView   |
+--------------+  +---------------+  +-------------+  +-----+-----+
                                                        |
                                                        v
                                              +---------------+
                                              | ExamDetailView|
                                              | + Exam Info   |
                                              | + Add to      |
                                              |   Calendar    |
                                              | + Related     |
                                              |   Mistakes    |
                                              | + [Edit]      |
                                              |    +--> Exam  |
                                              |         Detail|
                                              |         Edit  |
                                              +---------------+

+---------------------------------------+
| SettingsView                          |
| + Profile Card (tap avatar -> picker) |
| + Edit Profile / Edit Subjects        | --> EditSubjectsView / ProfileEditView
| + App Preferences                     | --> PreferencesView
| + Academic Info (school/grade/region/ |
|   education system / targets)         |
| + Data Management (Export / Import)   | --> CSV for grades / mistakes / exams
| + About / Copyright & License /       |
|   Test Notification                   |
+---------------------------------------+

  [ Modal Sheets (presented via .sheet) ]
  +-----------------------------------------------------+
  |  AddGradeView    NewExamSetView                    |
  |  NewMistakeSetView                                |
  |  MistakeDetailEditView  (4 sections + OCR)         |
  |  ExamDetailEditView                                |
  +-----------------------------------------------------+
```

==============================================================================

## Image Handling Pipeline

```
+---------------------------------------------------------------------------+
|                       Image Handling Pipeline                              |
+---------------------------------------------------------------------------+
|                                                                             |
|  Step 1: Capture / Selection                                                 |
|  +---------------+      +---------------+      +---------------+            |
|  |  Camera       |      |  Gallery      |      |  Crop/        |            |
|  |  Capture      |      |  Selection    |      |  Edit         |            |
|  +-------+-------+      +-------+-------+      +-------+-------+            |
|          |                      |                      |                    |
|          +----------------------+----------------------+                    |
|                                 |                                             |
|                                 v                                             |
|  Step 2: Processing                                                            |
|  +-------------------------------------------------------------------+       |
|  |  ImageProcessor (in NewMistakeSetView / AvatarPickerSheet)         |       |
|  |  +-- Compress UIImage -> JPEG Data                                 |       |
|  |  +-- Generate unique filename (UUID + timestamp)                    |       |
|  |  +-- Determine storage path (images/grade_*.jpg,                    |       |
|  |      images/avatar_*.jpg)                                           |       |
|  +-------------------------------+-----------------------------------+       |
|                                  |                                           |
|                                  v                                           |
|  Step 3: Persistence                                                         |
|  +-------------------------------------------------------------------+       |
|  |  DataManager.saveGradeImage(_:) / saveAvatar(_:)                   |       |
|  |  +-- Write JPEG Data -> ~/Documents/images/{filename}              |       |
|  |  +-- Update model (Grade.imageFileName /                          |       |
|  |      UserProfile.avatarFileName)                                   |       |
|  |  +-- Save model -> JSON file                                       |       |
|  +-------------------------------+-----------------------------------+       |
|                                  |                                           |
|                                  v                                           |
|  Step 4: Display                                                              |
|  +-------------------------------------------------------------------+       |
|  |  ThumbnailImageView (Views/Helpers/)                               |       |
|  |  +-- Check ImageCache.shared.thumbnail(for:)                       |       |
|  |      +-- HIT: return cached UIImage instantly                      |       |
|  |      +-- MISS: load from disk, resize to 300px, cache, display     |       |
|  |  +-- Tap -> ZoomableImageView (pinch-to-zoom, double-tap)          |       |
|  +-------------------------------------------------------------------+       |
|                                                                             |
|  ImageCache Details:                                                         |
|  +-------------------------------------------------------------------+       |
|  |  - NSCache<NSString, UIImage>, max 50 entries                      |       |
|  |  - Max dimension: 300px (thumbnail)                                |       |
|  |  - nonisolated class for thread-safe access                        |       |
|  |  - Automatic eviction under memory pressure                        |       |
|  +-------------------------------------------------------------------+       |
|                                                                             |
|  Cleanup:                                                                     |
|  - DataManager.deleteGradeImage(filename:) - removes from disk                |
|  - deleteMistake iterates all 4 image arrays, deletes each file               |
|  - Avatar change deletes old avatar file, saves new one                       |
+---------------------------------------------------------------------------+
```

==============================================================================

## Widget Data Sync Flow

```
+---------------------------------------------------------------------------+
|                   Widget Data Sync Flow (Detailed)                         |
+---------------------------------------------------------------------------+
|                                                                             |
|   Main App (StudyPulse)                      Widget Extension               |
|                                                                             |
|  +-----------------------------+           +--------------------------+    |
|  |                             |           |                          |    |
|  |  DataManager                |           |  ExamWidget             |    |
|  |  +-----------------------+  |           |  +------------------+   |    |
|  |  |  examSets             |  |           |  |  WidgetEntry     |   |    |
|  |  |  comprehensiveExamSets|  |           |  |  Timeline        |   |    |
|  |  +-----------+-----------+  |           |  |  UI (S/M/L)      |   |    |
|  |              |              |           |  +--------+---------+   |    |
|  |              v              |           |           |             |    |
|  |  WidgetDataSyncManager      |           |           |             |    |
|  |  +-----------------------+  |           |           v             |    |
|  |  |  1. Convert Exam[]   |  |           |  ExamWidgetData         |    |
|  |  |     -> ExamWidgetData |  |           |  +------------------+   |    |
|  |  |  2. Encode to JSON   |  |           |  |  examName        |   |    |
|  |  |  3. Write to App     |  |           |  |  examDate        |   |    |
|  |  |     Group Container   |  |           |  |  daysRemaining   |   |    |
|  |  |     (UserDefaults)    |  |           |  |  importance      |   |    |
|  |  +-----------------------+  |           |  |  masteryDegree   |   |    |
|  |              |              |           |  +------------------+   |    |
|  |              v              |           |            ^             |    |
|  |  App Group Container        |           |            |             |    |
|  |  group.Gao-Chenkai.         |           |  ExamWidgetProvider      |    |
|  |  StudyPulse                 |           |  +------------------+    |    |
|  |  +-----------------------+  |           |  |  1. Read from    |    |    |
|  |  |  UserDefaults(suiteName:)| |           |  |     App Group    |    |    |
|  |  |  widgetExamData        |  |           |  |  2. Decode JSON  |    |    |
|  |  +-----------------------+  |           |  |  3. Create Timeline|   |    |
|  |                             |           |  |  4. Return Entry  |    |    |
|  +-----------------------------+           |  +------------------+    |    |
|                                            |                          |    |
|  Triggers:                                  |  Widget Refresh:         |    |
|  - addExam() -> syncExamsToWidget()         |  - Timeline expiration   |    |
|  - deleteExam() -> syncExamsToWidget()      |  - System wake            |    |
|  - appDidBecomeActive -> syncExamsToWidget()|  - Manual reload          |    |
|                                            |                          |    |
+---------------------------------------------------------------------------+
```

==============================================================================

## Subject Recommendation Flow

```
+---------------------------------------------------------------------------+
|                  Smart Subject Recommendation Flow                         |
+---------------------------------------------------------------------------+
|                                                                             |
|  User Action: Select Education Stage + Region in Settings                   |
|  +-------------------------------------------------------------------+     |
|  |                                                                   |     |
|  |  +---------------+     +---------------+                          |     |
|  |  | Education     |---->| Education     |                          |     |
|  |  | Stage Picker  |     | Region Picker |                          |     |
|  |  | (6 options)   |     | (filtered)    |                          |     |
|  |  +---------------+     +-------+-------+                          |     |
|  |                                |                                  |     |
|  +--------------------------------+----------------------------------+     |
|                                   |                                          |
|                                   v                                          |
|  +-------------------------------------------------------------------+     |
|  |  EducationConfig.region(systemCode:)                               |     |
|  |  +-- Lookup EducationRegion by systemCode                           |     |
|  |  +-- Return region with subjects: [SubjectConfig]                  |     |
|  |  +-- If not found -> fallback to                                    |     |
|  |      EducationConfig.defaultRegion(stage)                           |     |
|  +-------------------------------+-----------------------------------+     |
|                                  |                                          |
|                                  v                                          |
|  +-------------------------------------------------------------------+     |
|  |  DataManager.applySmartSubjectRecommendation(stage:, regionCode:)  |     |
|  |  +-------------------------------------------------------------+  |     |
|  |  |  1. EducationConfig.region(systemCode:) -> get Education-  |  |     |
|  |  |     Region                                                   |  |     |
|  |  |  2. Map SubjectConfig[] -> Subject[]                         |  |     |
|  |  |     (name, displayName, fullScore, enabled=true for         |  |     |
|  |  |     required, false for elective)                            |  |     |
|  |  |  3. profile.selectedSubjects = converted subjects            |  |     |
|  |  |  4. saveProfile() -> persist to profile.json                 |  |     |
|  |  +-------------------------------------------------------------+  |     |
|  +-------------------------------+-----------------------------------+     |
|                                  |                                          |
|                                  v                                          |
|  +-------------------------------------------------------------------+     |
|  |  EditSubjectsView (UI)                                           |     |
|  |  +-- Display recommended subjects with toggles                    |     |
|  |  +-- User can enable/disable elective subjects                    |     |
|  |  +-- User can customize fullScore per subject                     |     |
|  |  +-- Save -> profile.selectedSubjects updated                     |     |
|  +-------------------------------------------------------------------+     |
|                                                                             |
|  Example Flow:                                                               |
|  Zhejiang High School -> systemCode: "CN-ZJ-3+3"                             |
|  +-- Chinese   (required, 120 pts) -> enabled=true                          |
|  +-- Math      (required, 150 pts) -> enabled=true                          |
|  +-- English   (required, 150 pts) -> enabled=true                          |
|  +-- Physics   (elective, 100 pts) -> enabled=false (user toggles)          |
|  +-- Chemistry (elective, 100 pts) -> enabled=false (user toggles)          |
|  +-- Biology   (elective, 100 pts) -> enabled=false (user toggles)          |
|  +-- Politics  (elective, 100 pts) -> enabled=false (user toggles)          |
|  +-- History   (elective, 100 pts) -> enabled=false (user toggles)          |
|  +-- Geography (elective, 100 pts) -> enabled=false (user toggles)          |
+---------------------------------------------------------------------------+
```

==============================================================================

## Data Layer

### Data Flow Diagram

```
+-------------------------------------------------------------------------+
|                          User Actions                                    |
|  +---------------+  +---------------+  +---------------+  +------------+ |
|  |  Add Grade    |  |  New Exam     |  |  New Mistake  |  | Update     | |
|  |               |  |               |  |               |  |  Profile   | |
|  +-------+-------+  +-------+-------+  +-------+-------+  +------+-----+ |
+----------+----------------+----------------+----------------+-------------+
           |                |                |                |
           v                v                v                v
+-------------------------------------------------------------------------+
|                        Views (SwiftUI)                                   |
|  +---------------------+  +---------------------+  +-----------------+  |
|  |  AddGradeView       |  |  NewExamSetView      |  |  SettingsView   |  |
|  +-----------+---------+  +-----------+---------+  +---------+-------+  |
+-------------+------------------------+-----------------------+----------+
              |                        |                       |
              v                        v                       v
+-------------------------------------------------------------------------+
|                      DataManager (@MainActor)                           |
|                                                                         |
|  Published Properties:                                                  |
|  +-- grades           subjects         mistakeSets          exams        |
|  +-- comprehensiveExamSets         profile                            |
|                                                                         |
|  Persistence Methods:                                                   |
|  +-- saveGrades()     saveExams()       saveMistakeSets()              |
|  +-- saveSubjects()   saveProfile()                                    |
+-----------------------------+-------------------------------------------+
                              |
              +---------------+---------------+
              |                               |
              v                               v
+--------------------------+   +---------------------------+
|  ~/Documents/JSON        |   |  ~/Documents/images/       |
|  +-- profile.json        |   |  +-- avatar_*.jpg          |
|  +-- grades.json         |   |  +-- grade_*.jpg           |
|  +-- mistakes.json       |   |                           |
|  +-- exams.json          |   +---------------------------+
|  +-- comprehensiveExams.json
|  +-- subjects.json
+-------------+------------+
              |
              v
+-------------------------------------------+
|  WidgetDataSyncManager                     |
|  (App Group: group.Gao-Chenkai.StudyPulse)|
+-------------------+-----------------------+
                    |
                    v
+-------------------------------------------+
|      StudyPulseWidget                      |
|  (WidgetKit Timeline Provider)             |
+-------------------------------------------+
```

### DataManager (ObservableObject)

Central shared state manager. All views access it via `@EnvironmentObject`.

Published properties:
- `grades: [Grade]` -- Score records
- `subjects: [Subject]` -- Subject catalog (auto-generated from EducationConfig)
- `mistakeSets: [MistakeNote]` -- Mistake notes
- `examSets: [Exam]` -- Single-subject exams
- `comprehensiveExamSets: [comprehensiveExam]` -- Multi-subject exams
- `profile: UserProfile` -- User settings (avatar, school, grade, region, target, etc.)

Persistence: All data saved as JSON files in `~/Documents/`:
- `profile.json`, `grades.json`, `mistakes.json`, `exams.json`,
  `comprehensiveExams.json`, `subjects.json`
- `images/` directory for grade image files (migrated from inline Data)
- App Group `group.Gao-Chenkai.StudyPulse` shared with widget

Key methods:
- `asyncInit()` -- async background load
- `load*Async()` -- non-blocking loaders
- `fullScore(for:)` -- get subject full score
- `displayName(for:)` -- get subject display name
- `applySmartSubjectRecommendation(stage:regionCode:)` -- smart subject recommendation
- `saveAvatar(_:) / loadAvatar()` -- avatar file management
- `deleteMistake` uses `id` matching (not `title+date`)

==============================================================================

## Data Persistence Flow (Detailed)

```
+-------------------------------------------------------------------------+
|               Data Persistence Flow (Detailed)                          |
+-------------------------------------------------------------------------+
|                                                                         |
|  [App Launch]                                                            |
|  |                                                                       |
|  v                                                                       |
|  StudyPulseApp -> .task { await dataManager.asyncInit() }                |
|  |                                                                       |
|  +--> DataManager.asyncInit()                                            |
|  |    |                                                                  |
|  |    +-- loadProfileAsync()  -> profile.json                            |
|  |    +-- loadGradesAsync()   -> grades.json    (migrate inline images)  |
|  |    +-- loadMistakesAsync() -> mistakes.json                           |
|  |    +-- loadExamsAsync()    -> exams.json                              |
|  |    +-- loadComprehensiveExamsAsync() -> comprehensiveExams.json       |
|  |    +-- loadSubjectsAsync() -> subjects.json                           |
|  |    +-- (if missing) EducationConfig -> default subjects               |
|  |                                                                       |
|  v                                                                       |
|  All @Published properties are populated on main thread                  |
|                                                                         |
|                                                                         |
|  [User Action: Edit Data]                                                |
|  |                                                                       |
|  v                                                                       |
|  View mutates model via DataManager method                               |
|  +-- e.g. dataManager.grades.append(newGrade)                            |
|  |                                                                       |
|  v                                                                       |
|  dataManager.save*(...) called                                           |
|  +-- saveProfile()  -> encode(UserProfile) -> profile.json               |
|  +-- saveGrades()   -> encode([Grade])     -> grades.json                |
|  +-- saveSubjects() -> encode([Subject])   -> subjects.json              |
|  |                                                                       |
|  v                                                                       |
|  DataFileIO (nonisolated) writes data on background thread               |
|  +-- static func save<T: Encodable>(_ object: T, to filename: String)    |
|  +-- FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
|  |                                                                       |
|  v                                                                       |
|  ~/Documents/{filename}.json                                             |
|  ~/Documents/images/{avatar_*, grade_*}.jpg                              |
|                                                                         |
|                                                                         |
|  [Image Migration (Legacy)]                                              |
|  +-------------------------------------------------------------------+   |
|  |  Old Grade.image (Data, inline in JSON)                           |   |
|  |  -> Detected on load -> write to images/grade_{UUID}.jpg          |   |
|  |  -> Set Grade.imageFileName to new filename                       |   |
|  |  -> Clear Grade.image (Data) field                                |   |
|  |  -> Save updated Grade[] to grades.json                            |   |
|  +-------------------------------------------------------------------+   |
|                                                                         |
|                                                                         |
|  [Widget Sync Trigger]                                                   |
|  |                                                                       |
|  v                                                                       |
|  WidgetDataSyncManager.syncExamsToWidget()                               |
|  +-- Collect examSets + comprehensiveExamSets                            |
|  +-- Convert to compact ExamWidgetData struct                            |
|  +-- Encode to JSON                                                      |
|  +-- Write to UserDefaults(suiteName: "group.Gao-Chenkai.StudyPulse")    |
|  +-- Key: "widgetExamData"                                                |
|                                                                         |
+-------------------------------------------------------------------------+
```

==============================================================================

## Key Models

### EducationStage (enum)
- `primarySchool`, `middleSchool`, `highSchool`, `internationalHighSchool`,
  `university`, `graduate`

### EducationCategory (enum)
- `domestic` (CN, TW, HK, SG, etc.)
- `international` (UK A-Level, IB, AP, SAT, ACT, etc.)

### SubjectConfig
- `name`, `displayName`, `fullScore`, `isRequired`, `isElective`, `category`
- Factory methods: `.required(...)` / `.elective(...)`

### EducationRegion
- `name`, `displayName`, `category`, `stage`, `systemCode`, `subjects`, `notes`

### Grade
- `subject`, `score`, `rawScore`, `ranking`, `importance` (1-5)
- `image` (legacy), `imageFileName` (new)
- `date`, `examName`, `fullScore` (records the full score at the time of recording)
- `scoreRate(subjectFullScore:)` -- now uses dynamic full score

### Subject
- `name`, `displayName`, `enabled`, `fullScore` (customizable per subject)

### UserProfile (expanded)
- `username`, `realName`, `age`, `gender`
- `educationStage` / `regionCode` / `educationLevel` (legacy) /
  `educationSystem` (legacy) / `region` (legacy)
- `schoolName`, `grade`, `className`, `studentId`
- `enrollmentYear`, `examYear`
- `targetSchool`, `targetScore`
- `selectedSubjects: [Subject]`, `theme`, `avatarFileName`

### MistakeNote
- `title`, `subject`, `originalQuestion`, `source`, `date`
- `errorReason`, `wrongSolution`, `correctSolution`
- Per-section image arrays: `questionImages`, `reasonImages`,
  `wrongSolutionImages`, `correctSolutionImages`

### Exam / comprehensiveExam
- `name`, `examDate`, `importance` (1-5), `masteryDegree` (0-100)
- `Exam.subject: String` vs `comprehensiveExam.subject: [String]`

==============================================================================

## Education Systems (EducationConfig)

### Education System Tree Structure

```
Education Systems
+-- Domestic
|   +-- China Mainland
|   |   +-- Primary School
|   |   +-- Middle School
|   |   |   +-- Standard
|   |   +-- High School
|   |       +-- Standard
|   |       +-- Zhejiang (3+3)
|   |       +-- Shanghai (3+3)
|   +-- Taiwan
|   |   +-- GSAT
|   +-- Hong Kong
|   |   +-- DSE
|   +-- Singapore
|       +-- O-Level
|
+-- International
    +-- UK
    |   +-- IGCSE
    |   +-- A-Level
    +-- IB
    |   +-- Diploma Programme
    +-- US
    |   +-- AP
    |   +-- SAT
    |   +-- ACT
    +-- Graduate
        +-- GRE
        +-- GMAT
        +-- TOEFL
        +-- IELTS
```

Supports global education systems organized by stage and region.

### Domestic Systems

| Region | Stage | Code | Notes |
|--------|-------|------|-------|
| China Mainland | Middle / High | CN-MID / CN-HS | Standard |
| Zhejiang | Middle / High | CN-ZJ-MID / CN-ZJ-3+3 | Combined: Science + Social Studies |
| Shanghai | Middle / High | CN-SH-MID / CN-SH-3+3 | Physics & Chemistry scored separately |
| Taiwan | Middle / High | TW-MID / TW-GSAT | Math A / Math B separate papers |
| Hong Kong | High | HK-DSE | 4 core + 2-3 electives (5** = 7 pts) |
| Singapore | O-Level | SG-OLEVEL | Mother Tongue + Social Studies |

### International Systems

| System | Code | Full Score | Notes |
|--------|------|------------|-------|
| UK IGCSE | UK-IGCSE | 100 (200 for Combined Science) | Cambridge / Edexcel |
| UK A-Level | UK-ALEVEL | 100 | CIE / Edexcel / AQA / OCR |
| IB Diploma | IB-DP | 7 | 6 Groups + TOK + EE = 45 |
| US AP | US-AP | 5 | 35+ courses |
| US SAT | US-SAT | 800 (per section) | EBRW + Math = 1600 |
| US ACT | US-ACT | 36 | 4 sections |
| GRE / GMAT | GRAD | 170 / 800 | Graduate tests |
| TOEFL / IELTS | GRAD | 120 / 9 | Language proficiency |

==============================================================================

## App Preferences

### AppPreferences (Codable, persisted in UserDefaults)
- `appLanguage: String?` -- Language code (`"en"`, `"zh-Hans"`, or `nil` for system)
- `colorScheme: ColorSchemeOption` -- `.system`, `.light`, `.dark`

### AppEnvironmentManager (ObservableObject)
- `@Published var preferences: AppPreferences` -- auto-saves to UserDefaults
- `effectiveColorScheme: ColorScheme?` -- computed for `.preferredColorScheme()`
- `setLanguage(_:)` -- switches via `UserDefaults AppleLanguages` key
- `setColorScheme(_:)` -- updates published property, triggers UI update

### PreferencesView
- Appearance section: inline picker with Light / Dark / Follow System options
- Language section: picker with English / Simplified Chinese / Follow System

==============================================================================

## Notification Scheduling Flow

```
+-------------------------------------------------------------------------+
|              Notification Scheduling Flow                               |
+-------------------------------------------------------------------------+
|                                                                         |
|  [App Launch]                                                            |
|  |                                                                       |
|  v                                                                       |
|  ExamPrepareNotifications.shared.requestAuthorization()                  |
|  +-- UNUserNotificationCenter.current().requestAuthorization             |
|  |   (options: [.alert, .sound, .badge])                                 |
|  |                                                                         |
|  v                                                                         |
|  Permission granted or denied (stored in system)                          |
|                                                                         |
|                                                                         |
|  [Exam Created / Edited]                                                 |
|  |                                                                         |
|  v                                                                       |
|  NewExamSetView / ExamDetailEditView                                     |
|  +-- "Add to Calendar" toggle (default ON)                               |
|  |                                                                         |
|  +-- Save exam -> Exam added to exams / comprehensiveExams arrays        |
|  +-- If toggle ON:                                                        |
|      |                                                                    |
|      +--> CalendarManager.addExamToCalendar(exam)                         |
|      |    +-- EventKit: EKEvent with all-day event                        |
|      |    +-- 1-day advance alarm                                         |
|      |                                                                    |
|      +--> ExamPrepareNotifications.shared.scheduleNotifications(          |
|              for: examName, date: examDate)                               |
|           |                                                                 |
|           v                                                                 |
|           daysToNotify = [1, 3, 5, 10, 30]                                 |
|           For each day:                                                    |
|           +-- triggerDate = examDate - N days                              |
|           +-- If triggerDate < Date(), skip (in the past)                 |
|           +-- Create UNMutableNotificationContent                          |
|           |   +-- title: "Exam countdown"                                 |
|           |   +-- body:  "X days until examName"                          |
|           |   +-- sound: .default                                          |
|           +-- Create UNCalendarNotificationTrigger                         |
|           +-- Create UNNotificationRequest with unique ID                  |
|           +-- Add to UNUserNotificationCenter                              |
|                                                                         |
|                                                                         |
|  [Calendar Integration]                                                   |
|  +-------------------------------------------------------------------+   |
|  |  CalendarManager (EventKit)                                        |   |
|  |  +-- requestAccessIfNeeded() to EKEventStore                       |   |
|  |  +-- addExamToCalendar(exam) creates all-day EKEvent               |   |
|  |  +-- removeExamFromCalendar(exam) deletes by matching event       |   |
|  |  +-- Exam calendar events have 1-day advance reminder              |   |
|  +-------------------------------------------------------------------+   |
|                                                                         |
|  [Info.plist Requirements]                                                |
|  +-- NSCalendarsUsageDescription: "Add exams to calendar"                |
|  +-- NSCameraUsageDescription: "Take photos of mistakes"                 |
|  +-- NSPhotoLibraryUsageDescription: "Select photos from library"        |
|                                                                         |
+-------------------------------------------------------------------------+
```

==============================================================================

## OCR Processing Pipeline

```
+-------------------------------------------------------------------------+
|                   OCR Processing Pipeline                                |
+-------------------------------------------------------------------------+
|                                                                         |
|  [User Action: Tap OCR button in Mistake editor]                         |
|  |                                                                       |
|  v                                                                       |
|  MistakeDetailEditView or NewMistakeSetView                              |
|  +-- OCR button in each of the 4 sections (Question, Reason,             |
|  |   Wrong Solution, Correct Solution)                                   |
|  +-- Button identifies which section/image to process                    |
|  |                                                                         |
|  v                                                                         |
|  OCRManager.recognizeText(in image: UIImage,                            |
|                           completion: @escaping (String?) -> Void)        |
|  |                                                                         |
|  +-- Create VNImageRequestHandler with CIImage from UIImage             |
|  |                                                                         |
|  +-- VNRecognizeTextRequest                                              |
|  |   +-- recognitionLevel: .accurate (or .fast)                          |
|  |   +-- recognitionLanguages: ["zh-Hans", "en"]                         |
|  |       (priority: Chinese then English)                                 |
|  |   +-- automaticallyDetectsLanguage: true                               |
|  |                                                                         |
|  v                                                                         |
|  Vision framework processes image on background queue                     |
|  +-- Detects text regions (VNTextObservation)                             |
|  +-- Extracts text candidates with confidence scores                      |
|  |                                                                         |
|  v                                                                         |
|  Completion handler returns concatenated string                            |
|  +-- Each VNTextObservation.topCandidates(1).first?.string                |
|  +-- Joined with newlines for multi-line layout                          |
|  |                                                                         |
|  v                                                                         |
|  View receives result on main thread                                      |
|  +-- Append text to the active TextEditor section                         |
|  +-- User can edit and review the OCR result                              |
|  +-- Markdown preview updates automatically                                |
|                                                                         |
|  OCRManager Details:                                                     |
|  +-- Singleton: OCRManager.shared                                         |
|  +-- Uses Apple Vision framework (VNRecognizeTextRequest)                 |
|  +-- Supports Chinese (zh-Hans) and English (en)                         |
|  +-- Accurate mode for better quality, slightly slower                    |
|  +-- Async processing via completion handler on main thread              |
|                                                                         |
+-------------------------------------------------------------------------+
```

==============================================================================

## CSV Export Flow

```
+-------------------------------------------------------------------------+
|                    CSV Export Flow                                       |
+-------------------------------------------------------------------------+
|                                                                         |
|  [User Action: Tap Export button in relevant view]                      |
|  |                                                                         |
|  v                                                                       |
|  DataExportManager (MainActor enum)                                      |
|  |                                                                         |
|  +-- exportGradesToCSV(grades: [Grade], subjects: [Subject])             |
|  |   +-- Header: "ID, Subject, Score, Full Score, Rate, Raw, Rank,       |
|  |   |           Importance, Exam Name, Date"                            |
|  |   +-- For each grade:                                                 |
|  |   |   +-- look up subject fullScore from subjects array               |
|  |   |   +-- compute scoreRate = score / subjectFullScore                |
|  |   |   +-- escapeCSV() handles commas and quotes                       |
|  |   |   +-- formatDate(grade.date) -> YYYY-MM-DD                       |
|  |   +-- Return multiline CSV string                                     |
|  |                                                                         |
|  +-- exportMistakesToCSV(mistakes: [MistakeNote])                        |
|  |   +-- Header: "ID, Title, Subject, Question, Source, Date,            |
|  |   |           Reason, WrongSolution, CorrectSolution"                 |
|  |   +-- escapeCSV() applied to each text field                          |
|  |   +-- Text fields may contain newlines; CSV escaping handles this     |
|  |                                                                         |
|  +-- exportExamsToCSV(exams: [Exam], comprehensiveExams: [...])           |
|  |   +-- Single exams and comprehensive exams are exported               |
|  |   |   with appropriate type indicator                                 |
|  |   +-- Fields: ID, Name, Date, Subject(s), Importance, Mastery         |
|  |                                                                         |
|  v                                                                         |
|  CSV string handed off to UIActivityViewController                       |
|  +-- UIActivityViewController(activityItems: [csvText, tempFileURL])     |
|  +-- User can share to Files, Mail, Notes, AirDrop, etc.                |
|  +-- Or write to temporary .csv file in ~/Documents/                     |
|                                                                         |
|  DataExportManager Details:                                              |
|  +-- @MainActor enum with static methods                                 |
|  +-- escapeCSV(_ string: String) -> String                               |
|  |   +-- If string contains comma, newline, or quote                    |
|  |   |   wrap in double quotes, escape inner quotes with ""             |
|  |   +-- Else return as-is                                               |
|  +-- formatDate(_ date: Date) -> "YYYY-MM-DD"                           |
|  +-- format numbers with String(format:)                                 |
|                                                                         |
+-------------------------------------------------------------------------+
```

==============================================================================

## Swift 6 Concurrency Model

```
+-------------------------------------------------------------------------+
|                 Swift 6 Concurrency Model                                |
+-------------------------------------------------------------------------+
|                                                                         |
|  @MainActor Isolated (UI + Primary State)                                |
|  +-------------------------------------------------------------------+   |
|  |  DataManager (ObservableObject, inferred @MainActor)              |   |
|  |   +-- All @Published properties accessed on main thread            |   |
|  |   +-- asyncInit() / save*() / load*Async() methods                |   |
|  |   +-- Views interact with DataManager via @EnvironmentObject       |   |
|  |                                                                     |   |
|  |  Views (SwiftUI body runs on main actor)                           |   |
|  |  AppEnvironmentManager (ObservableObject)                          |   |
|  |  DataExportManager (@MainActor enum)                               |   |
|  +-------------------------------------------------------------------+   |
|          ^                                                                 |
|          | (cross-actor calls to DataFileIO)                               |
|          v                                                                 |
|  Nonisolated (Background-Safe)                                             |
|  +-------------------------------------------------------------------+   |
|  |  DataFileIO enum                                                   |   |
|  |   +-- static func save<T: Encodable>(...)                          |   |
|  |   +-- static func load<T: Decodable>(...)                          |   |
|  |   +-- FileManager calls on background thread                      |   |
|  |                                                                     |   |
|  |  ImageCache (nonisolated class)                                    |   |
|  |   +-- NSCache access from any thread                                |   |
|  |   +-- thumbnail(for:) returns UIImage?                             |   |
|  |                                                                     |   |
|  |  EducationConfig (nonisolated enum)                                |   |
|  |   +-- Static data, no mutable state                                |   |
|  |                                                                     |   |
|  |  SubjectConfig / EducationRegion (nonisolated, Sendable)            |   |
|  |   +-- Structs conforming to Codable & Sendable                     |   |
|  |                                                                     |   |
|  |  Model structs (Grade, MistakeNote, Exam, Subject, UserProfile)    |   |
|  |   +-- All are Codable, value types, thread-safe to pass across     |   |
|  |       actors                                                        |   |
|  +-------------------------------------------------------------------+   |
|                                                                         |
|  Typical Async Flow:                                                    |
|  1. View calls await dataManager.someAsyncMethod()                     |
|  2. dataManager (on MainActor) calls DataFileIO.load(...)              |
|  3. DataFileIO runs FileManager access on generic executor              |
|  4. Result returns to dataManager, updates @Published on main actor    |
|  5. Views react via SwiftUI diffing                                     |
|                                                                         |
|  @preconcurrency imports:                                                |
|  - UserNotifications (UNUserNotificationCenter completion handler)      |
|  - EventKit (calendar event store access)                               |
|                                                                         |
+-------------------------------------------------------------------------+
```

==============================================================================

## Dependencies

### SPM (Local Packages)
| Package | Purpose |
|---------|---------|
| `WSOnBoarding` | First-launch onboarding UI |
| `swift-markdown-ui` | Markdown rendering in Mistake editor |

### Apple Frameworks
| Framework | Purpose |
|-----------|---------|
| EventKit | Calendar integration |
| Vision | OCR text recognition |
| Charts | Grade/trend visualization |
| UserNotifications | Exam reminders |
| WidgetKit | Home screen exam widget |

==============================================================================

## Privacy Permissions

| Key | Value |
|-----|-------|
| `NSCameraUsageDescription` | Take photos of mistakes |
| `NSPhotoLibraryUsageDescription` | Select photos from photo library |
| `NSCalendarsUsageDescription` | Add exams to calendar |

==============================================================================

## Feature Notes

### User Profile
- Avatar upload (photo library / camera) with first-letter fallback
- Detailed profile: real name, school, grade, class, student ID
- Smart subject recommendation based on region and stage
- Customizable full score per subject
- Target school + target score for motivation

### Home Page
- Top welcome area with avatar (tap -> Settings)
- Time-of-day greeting + date display
- 2x2 stat cards (exams, avg score, latest grade) on iPhone
- **iPad**: 4 stats in a single horizontal row + 2-column section layout
- Quick action buttons (add grade, exam, mistake)
- Upcoming exam cards with countdown
- Daily motivational quote (rotates daily)
- Subject trend chart (with 5 selection strategies)
- Recent grades display
- Learning tips based on user state

### Trend Page
- Subjects Needing Attention alerts (avg < 70% or declining > 15 pts)
- Per-subject detail with chart + history
- Score / ranking mode toggle

### Mistake Module
- Supports photo capture and photo library selection per section
- OCR button reads text from the last uploaded image using Vision framework
- Editor has split layout: TextEditor on top, Markdown preview toggles below
- Searchable by title, question, source, subject
- Tap any image thumbnail to open ZoomableImageView (pinch-to-zoom, double-tap)
- Thumbnails cached via ImageCache (NSCache, max 50, 300px max dimension)
- Suggested for Review section based on priority

### Exam Module
- Supports single-subject and comprehensive (multi-subject) exams
- Calendar integration: New exam form has a toggle (default ON) to add to system calendar
- Exam detail view has Add to Calendar button
- Calendar events are all-day with 1-day advance reminder
- Local notifications scheduled via ExamPrepareNotifications
- Related Mistakes section in exam detail (mistakes for that subject)

### Charts
- Uses SwiftUI Charts framework
- Score color uses proportional mapping (>=90% green, >=75% blue, >=60% orange, <60% red)
- HomeView: subject trend chart with selection strategies
- TrendsView: multi-subject trend comparison
- GradeChartView: reusable chart component

### WidgetKit
- Home screen widget showing upcoming exam countdown
- Shares data via App Group with main app
- Multiple widget sizes (small, medium, large)

==============================================================================

## iPad Adaptation (iOS 18+)

The app supports both iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) using
a non-invasive, size-class-based approach. iPhone layouts are unchanged; on
iPad, the app presents a native sidebar tab bar and uses multi-column layouts
with width constraints for readability.

### Key Files & Modifications

| File | Change |
|------|--------|
| `Views/Helpers/iPadLayout.swift` | **NEW** -- adaptive helpers (see below) |
| `Views/ContentView.swift` | Added `.tabViewStyle(.sidebarAdaptable)` for iPad sidebar |
| `Views/HomeView.swift` | Max-width 1100 container, `AdaptiveHStack` 2-column sections, 4-column stat row on iPad |
| `Views/SettingsView.swift` | `.adaptiveMaxWidth(720)` on List |
| `Views/PreferencesView.swift` | `.adaptiveMaxWidth(640)` on Form |
| `Views/TrendsView.swift` | `.adaptiveMaxWidth(900)` on ScrollView |
| `Views/MistakeView.swift` | `.adaptiveMaxWidth(900)` on MistakeView + SubjectMistakesView |
| `Views/ExamView.swift` | `.adaptiveMaxWidth(800)` on List |

### Adaptive Helpers (`iPadLayout.swift`)

```swift
// 1) Content max-width -- centers & clamps content on iPad, full-width on iPhone
struct AdaptiveContentWidth: ViewModifier
extension View {
    func adaptiveMaxWidth(_ maxWidth: CGFloat = 720) -> some View
}

// 2) Multi-column grid items
struct AdaptiveGridColumns {
    init(compact: Int = 1, regular: Int = 2, spacing: CGFloat = 20)
}

// 3) 2-column layout: HStack on iPad, VStack on iPhone
struct AdaptiveHStack<Content: View>: View {
    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content)
}

// 4) Card outer padding: 20pt on iPhone, 0 on iPad (max-width container owns margin)
struct AdaptiveCardPadding: ViewModifier
extension View {
    func adaptiveCardPadding() -> some View
}
```

All helpers read `horizontalSizeClass` via `@Environment` inside `body` (this
environment value is **not** accessible from a generic View extension property).

### ContentView Sidebar

`TabView` uses `.tabViewStyle(.sidebarAdaptable)` (iOS 18+). iPhone keeps the
classic bottom tab bar; iPad and Mac Catalyst get a sidebar automatically
selected by the system based on size class.

### HomeView Multi-Column Layout

The Home page is constrained to `frame(maxWidth: 1100)` and centered on iPad.
Specific sections use `AdaptiveHStack` for side-by-side content on iPad:

- `MainStatsCard` shows 4 stats in a single horizontal row on iPad (vs 2x2
  grid on iPhone) for a more dashboard-like feel.
- Quick actions, upcoming exams, and chart/suggestion pairs are laid out in
  two columns on iPad.

### Width Constraints Reference

| View | Max Width (iPad) | Reason |
|------|------------------|--------|
| `SettingsView` List | 720 | Single-column forms read best near 600-720pt |
| `PreferencesView` Form | 640 | Compact settings panel |
| `ExamView` List | 800 | Slightly wider to fit countdown + notes |
| `TrendsView` ScrollView | 900 | Charts need more horizontal space |
| `MistakeView` | 900 | Long markdown content benefits from width |
| `HomeView` container | 1100 | Dashboard / multi-column can be wider |

### Design Principles Applied

1. **No iPhone regression** -- every change is gated on `horizontalSizeClass`
   or device idiom; iPhone layout is identical to before.
2. **Centered, not stretched** -- content is centered with a max-width on iPad
   rather than expanding to the full screen, preserving readability.
3. **Native iPad feel** -- sidebar tab bar, multi-column dashboards, no
   stretched-out iPhone-style single-column layouts.
4. **Single source of truth** -- all adaptive logic lives in `iPadLayout.swift`;
   feature views just call the helpers.

==============================================================================

## Known Issues / TODOs

1. Grade.scoreRate hardcodes 150 full score -- FIXED, now uses dynamic full score
2. DataManager.addGrade() method did not exist -- FIXED, added method
3. NewMistakeSheet.swift and Sheets/ directory were legacy/unused -- CLEANED UP
4. No iCloud sync -- data is local-only
5. No data export/import (CSV, Excel) -- FIXED, CSV export via DataExportManager
6. Widget extension needs to be configured in Xcode project file
7. App Group needs to be configured in Xcode for widget data sync

==============================================================================

## Build Commands

- Open `StudyPulse.xcodeproj` in Xcode
- Resolve SPM packages: File -> Packages -> Resolve Package Versions
- Build: Cmd+B
- Run on simulator/device: Cmd+R
- No CLI test/lint commands -- use Xcode built-in tools

==============================================================================

## Code Conventions

- Use `@EnvironmentObject var dataManager: DataManager` for shared state
- All models are `Codable` for JSON persistence
- Views follow `NavigationView` + `Form`/`List` pattern
- Chinese localization via `String.localized()` extension (reads from `Localizable.strings`)
- `EditSection` enum drives the 4-section mistake editor (Question/Reason/Wrong/Correct)
- Manager classes use `static let shared` singleton pattern (where applicable)
- `EducationConfig` is a `nonisolated enum` providing global config data
- `SubjectConfig` uses factory methods `.required(...)` / `.elective(...)` for clarity

==============================================================================

## Performance Patterns (Post-Optimization)

### Data Loading
- App launch uses `asyncInit()` in `.task` modifier -- no main-thread blocking
- Legacy sync `load*()` methods kept for backward compatibility

### Image Handling
- ImageCache provides NSCache-backed thumbnail cache (max 50 entries)
- ThumbnailImageView loads images asynchronously with ProgressView placeholder
- Grade images stored as separate files in `images/` directory, not in JSON
- Old inline `image` Data automatically migrated to files on save/load
- Avatar images stored separately in `images/avatar_*.jpg`

### View Optimization
- ExamRowView and ComprehensiveExamRowView use computed properties instead of
  `@State` + `onAppear` for `daysRemaining`
- UpcomingExamCard uses computed properties -- no side-effect mutations
- Eliminated unnecessary view re-renders from state mutation in `onAppear`

==============================================================================

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
  - Welcome / Quick Actions / Exams / Chart sections use `AdaptiveHStack` for
    2-column layouts on iPad
- `SettingsView` (720), `PreferencesView` (640), `TrendsView` (900),
  `MistakeView` (900), `ExamView` (800) all use `.adaptiveMaxWidth` to keep
  form/list content centered and readable on iPad
- iPhone layout is unchanged; all iPad behavior is gated on
  `horizontalSizeClass == .regular` or `UIDevice.current.userInterfaceIdiom`
- Verified on iPad Pro 11-inch (M5) simulator + iPhone simulator builds with
  no warnings

### v2026.06.07 - Full View Layer Refactor + Design System
- HomeView split into 9 independent components for modular design
- MistakeView: suggested review horizontal scroll + card gradient beautification
- TrendsView: added Subjects Needing Attention smart alerts
- ExamDetailView: added related mistakes section
- SubjectScoreCard: gradient border + entrance animation
- New AppStyle design system skeleton (minimal / literature / tech)
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
- Mistake editing in four sections: original question, error reason, wrong solution, correct solution
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
- Added Subjects Needing Attention alerts on Trends page
- Added Suggested for Review section on Mistakes page
- Added Related Mistakes display on Exam detail page
- Added WidgetKit widget support
