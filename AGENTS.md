# StudyPulse - AI Agent Guide

## Project Overview

**StudyPulse** is an iOS study management app built with SwiftUI, helping students track grades, manage mistakes, schedule exams, and analyze learning trends.

- **Language**: Swift 6.0
- **Platform**: iOS 18.6+
- **Architecture**: MVVM with `@EnvironmentObject` for shared state
- **IDE**: Xcode 26.3

## Project Structure

```
StudyPulse/
├── Models/
│   └── DataModels.swift          # Grade, MistakeNote, Exam, Subject, UserProfile
├── Managers/
│   ├── DataManager.swift         # Central data layer + JSON persistence
│   ├── CalendarManager.swift     # EventKit calendar integration
│   ├── OCRManager.swift          # Vision framework text recognition
│   ├── SubjectInfo.swift         # Subject display names & colors
│   └── StringsLocalized.swift    # String localization extension
├── Views/
│   ├── ContentView.swift         # Main TabView (4 tabs)
│   ├── HomeView.swift            # Dashboard with charts & quick stats
│   ├── TrendsView.swift          # Subject score trend analysis
│   ├── ExamView.swift            # Exam list & management
│   ├── ExamDetailView.swift      # Single exam detail + calendar button
│   ├── ExamDetailEditView.swift  # Exam editing
│   ├── NewExamSetView.swift      # New exam form (single/comprehensive)
│   ├── MistakeView.swift         # Mistake notebook list + search
│   ├── MistakeDetailEditView.swift # Mistake editing with OCR
│   ├── NewMistakeSetView.swift   # New mistake form with photo + OCR
│   ├── AddGradeView.swift        # Grade entry form
│   ├── SettingsView.swift        # App settings
│   ├── Components/
│   │   ├── GradeChartView.swift  # Charts for grades
│   │   └── SubjectPickerView.swift
│   ├── Helpers/
│   │   ├── ZoomableImageView.swift # Pinch-to-zoom image viewer
│   │   ├── ImagePicker.swift       # Photo library picker
│   │   └── PhotoCaptureView.swift  # Camera capture
│   ├── OnBoarding/
│   │   └── WelcomeConfig.swift   # First-launch onboarding (WSOnBoarding)
│   └── Sheets/
│       └── NewMistakeSheet.swift # Legacy mistake sheet (unused)
├── Extensions/
│   ├── ColorExtensions.swift
│   └── DateExtensions.swift
├── NotificationsControl/
│   └── ExamPrepareNotifications.swift # Local notification scheduling
└── StudyPulseApp.swift           # App entry point
```

## Data Layer

### DataManager (ObservableObject)

Central shared state manager. All views access it via `@EnvironmentObject`.

**Published properties:**
- `grades: [Grade]` — Score records
- `subjects: [Subject]` — Subject catalog (16 default subjects)
- `mistakeSets: [MistakeNote]` — Mistake notes
- `examSets: [Exam]` — Single-subject exams
- `comprehensiveExamSets: [comprehensiveExam]` — Multi-subject exams
- `profile: UserProfile` — User settings

**Persistence:** All data saved as JSON files in `~/Documents/`:
- `profile.json`, `grades.json`, `mistakes.json`, `exams.json`, `comprehensiveExams.json`, `subjects.json`

## Key Models

### Grade
- `subject`, `score`, `rawScore` (卷面分), `ranking`, `importance` (1-5), `image`, `date`, `examName`
- `scoreRate` computed property: assumes 150 full score (hardcoded, known issue)

### MistakeNote
- `title`, `subject`, `originalQuestion`, `source`, `date`
- `errorReason`, `wrongSolution`, `correctSolution`
- Per-section image arrays: `questionImages`, `reasonImages`, `wrongSolutionImages`, `correctSolutionImages`

### Exam / comprehensiveExam
- `name`, `examDate`, `importance` (1-5), `masteryDegree` (0-100)
- `Exam.subject: String` vs `comprehensiveExam.subject: [String]`

## Dependencies

### SPM (Local Packages in ../Packages/)
| Package | Purpose |
|---------|---------|
| `WSOnBoarding` | First-launch onboarding UI |
| `swift-markdown-ui` | Markdown rendering (`Markdown()` view) |

### Apple Frameworks
| Framework | Purpose |
|-----------|---------|
| EventKit | Calendar integration |
| Vision | OCR text recognition |
| Charts | Grade/trend visualization |
| UserNotifications | Exam reminders |

## Privacy Permissions

| Key | Value |
|-----|-------|
| `NSCameraUsageDescription` | 拍照拍摄错题照片 |
| `NSPhotoLibraryUsageDescription` | 访问相册选择错题照片 |
| `NSCalendarsUsageDescription` | 将考试添加到日历 |

## Feature Notes

### Mistake Module
- Supports **photo capture** and **photo library** selection per section
- **OCR** button reads text from the last uploaded image using Vision framework
- Editor has split layout: TextEditor on top, `Markdown()` preview toggles below
- Searchable by title, question, source, subject
- Tap any image thumbnail to open `ZoomableImageView` (pinch-to-zoom, double-tap)

### Exam Module
- Supports single-subject and comprehensive (multi-subject) exams
- **Calendar integration**: New exam form has a toggle (default ON) to add to system calendar
- Exam detail view has "Add to Calendar" button
- Calendar events are all-day with 1-day advance reminder
- Local notifications scheduled via `ExamPrepareNotifications`

### Charts
- Uses SwiftUI `Charts` framework
- HomeView: bar chart for subject averages, line marks for trends
- TrendsView: multi-subject trend comparison
- GradeChartView: reusable chart component

## Known Issues / TODOs

1. `Grade.scoreRate` hardcodes 150 full score — should be dynamic per subject
2. `DataManager.deleteMistake(_:)` uses `title+date` for lookup (unreliable, should use `id`)
3. `DataManager.addGrade()` method doesn't exist — add directly to `grades` array
4. `NewMistakeSheet.swift` and `Sheets/` directory are legacy/unused code
5. No iCloud sync — data is local-only
6. No data export/import (CSV, Excel)
7. No grade deletion confirmation dialog

## Build Commands

- Open `StudyPulse.xcodeproj` in Xcode
- Resolve SPM packages: **File → Packages → Resolve Package Versions**
- Build: `Cmd+B`
- Run on simulator/device: `Cmd+R`
- No CLI test/lint commands — use Xcode's built-in tools

## Code Conventions

- Use `@EnvironmentObject var dataManager: DataManager` for shared state
- All models are `Codable` for JSON persistence
- Views follow `NavigationView` + `Form`/`List` pattern
- Chinese localization via `String.localized()` extension (reads from `Localizable.strings`)
- `EditSection` enum drives the 4-section mistake editor (Question/Reason/Wrong/Correct)
- Manager classes use `static let shared` singleton pattern
