# StudyPulse - AI Agent Guide

## Project Overview

**StudyPulse** is an iOS study management app built with SwiftUI, helping students track grades, manage mistakes, schedule exams, and analyze learning trends. It supports multi-language (en/zh-Hans/zh-Hant/ja/ko), system-wide theming, OCR-based mistake capture, and a Home Screen widget for upcoming exams.

- **Language**: Swift 6.0
- **Platform**: iOS 18.6+
- **Architecture**: MVVM with `@EnvironmentObject` for shared state (`DataManager`, `AppEnvironmentManager`)
- **IDE**: Xcode 26.3
- **License**: CC BY-NC-SA 4.0

## Project Structure

The Xcode project (`StudyPulse.xcodeproj`) is a **File System Synchronized Group** — the `StudyPulse/` folder is mirrored automatically, so new files added there are picked up by Xcode on next build (no manual project edits required for source files).

```
StudyPulse/                                  # App target (iOS app)
├── StudyPulseApp.swift                      # @main entry; injects DataManager + AppEnvironmentManager; hosts onboarding; async data init
├── Assets.xcassets/                         # App icons + accent color
│
├── Models/
│   ├── DataModels.swift                     # Grade, MistakeNote, Exam, comprehensiveExam, Subject, UserProfile (all nonisolated)
│   └── AppPreferences.swift                 # AppPreferences + ColorSchemeOption + Language enum (en/zh-Hans/zh-Hant/ja/ko + system)
│
├── Managers/
│   ├── DataManager.swift                    # ObservableObject singleton; JSON persistence; asyncInit; async loaders
│   ├── DataFileIO.swift                     # nonisolated enum, generic Codable file loader (background-thread safe)
│   ├── AppEnvironmentManager.swift          # @MainActor ObservableObject; user prefs (language + theme); writes UserDefaults
│   ├── AppStyle.swift                       # nonisolated enums AppStyle / CardBG + style-aware Color modifiers (minimal / literature / tech)
│   ├── CalendarManager.swift                # EventKit wrapper; all-day exam events with 1-day advance alarm
│   ├── OCRManager.swift                     # Vision-based text recognition (recognizeText(in: / from:))
│   ├── ImageCache.swift                     # nonisolated NSCache wrapper; thumbnail generation
│   ├── SubjectInfo.swift                    # getMaxScore(level:subject:) — subject/score rules (hardcoded)
│   ├── StringsLocalized.swift               # String.localized() extension wrapping NSLocalizedString
│   ├── ExamWidgetData.swift                 # Widget shared model + AppGroupConfig + WidgetDataStore
│   └── WidgetDataSyncManager.swift          # @MainActor enum; copies 14-day upcoming exams to App Group & reloads widgets
│
├── Views/
│   ├── ContentView.swift                    # Root TabView (5 tabs: Home / Trends / Mistakes / Exams / Settings); haptic on tab change
│   ├── HomeView.swift                       # Dashboard: stats, quick actions, suggestions, recent grades, daily quote
│   ├── TrendsView.swift                     # Per-subject score/ranking trend cards + SubjectDetailView (time range filter)
│   ├── ExamView.swift                       # Grouped exam list (Within 1 Week / 1 Month / Later); swipe-delete
│   ├── ExamDetailView.swift                 # Exam detail; Add-to-Calendar button; related mistakes
│   ├── ExamDetailEditView.swift             # Form for editing an existing Exam
│   ├── NewExamSetView.swift                 # Form for new single-subject or comprehensive exam; calendar toggle; notifications
│   ├── MistakeView.swift                    # Mistake list; search; suggested-for-review horizontal scroll; ThumbnailImageView
│   ├── MistakeDetailEditView.swift          # Mistake editor (4 sections); OCR; markdown preview
│   ├── NewMistakeSetView.swift              # New-mistake form; defines EditSection enum (question/reason/wrong/correct)
│   ├── AddGradeView.swift                   # Single or comprehensive grade entry
│   ├── PreferencesView.swift                # Language + theme picker; restart button (exit(0))
│   ├── SettingsView.swift                   # Profile, academic info, subjects toggle, preferences link, about, copyright, test notification
│   ├── SubjectScoreCard.swift               # Reusable per-subject card (latest + mini chart) with score/ranking mode toggle
│   ├── Components/
│   │   ├── GradeChartView.swift             # Reusable line+point chart wrapper
│   │   └── SubjectPickerView.swift          # Picker bound to enabled subjects
│   ├── Helpers/
│   │   ├── ZoomableImageView.swift          # Pinch-to-zoom + fullscreen sheet
│   │   ├── ImagePicker.swift                # UIImagePickerController (photo library) wrapper
│   │   ├── PhotoCaptureView.swift           # UIImagePickerController (camera) wrapper
│   │   ├── BackgroundColors.swift           # getBackgroundColor(_:) for light/dark
│   │   └── ScoreColor.swift                 # scoreColor(_:) — green/blue/orange/red thresholds
│   ├── OnBoarding/
│   │   └── WelcomeConfig.swift              # WSWelcomeConfig.welcomeInfo (WSOnBoarding)
│   └── Sheets/
│       └── NewMistakeSheet.swift            # Legacy mistake form (unused — see Known Issues)
│
├── Extensions/
│   ├── ColorExtensions.swift                # Color.systemBackground etc. aliases
│   └── DateExtensions.swift                 # Date.formatted(date:time:) convenience
│
└── NotificationsControl/
    └── ExamPrepareNotifications.swift       # Local notifications: 1/3/5/10/30-day exam countdowns

StudyPulseWidget/                            # Widget extension target — see "Widget Extension" below
├── StudyPulseWidgetBundle.swift             # @main WidgetBundle { ExamWidget() }
├── ExamWidget.swift                         # Widget configuration + family dispatch
├── ExamWidgetEntry.swift                    # TimelineEntry(date, exams)
├── ExamWidgetProvider.swift                 # TimelineProvider; reads from WidgetDataStore; refresh at next midnight
├── ExamWidgetViews.swift                    # ExamRowView + Small/Medium/Large widget views
├── ExamWidgetData.swift                     # Mirror copy of the App-side data shape + AppGroupConfig + WidgetDataStore
├── Info.plist                               # NSExtensionPointIdentifier = com.apple.widgetkit-extension
└── Assets.xcassets/                         # AccentColor, AppIcon, WidgetBackground
```

## Data Layer

### DataManager (`ObservableObject`, `@MainActor`)

Central shared state, accessed via `@EnvironmentObject` in views. Also exposes `static let shared` for use inside `nonisolated` helpers (e.g. `Grade.getImage()`).

**Published properties:**

| Property | Type | Notes |
|---|---|---|
| `grades` | `[Grade]` | Score records (images stored as separate files, not embedded) |
| `subjects` | `[Subject]` | 16 default subjects seeded on first run |
| `mistakeSets` | `[MistakeNote]` | Mistake notes (per-section image arrays) |
| `examSets` | `[Exam]` | Single-subject exams |
| `comprehensiveExamSets` | `[comprehensiveExam]` | Multi-subject exams |
| `profile` | `UserProfile` | Username, age, education level/system/region, theme |

**Persistence** (all in `~/Documents/`):

| File | Owner |
|---|---|
| `profile.json` | `UserProfile` |
| `grades.json` | `[Grade]` (no image data — only filenames) |
| `mistakes.json` | `[MistakeNote]` (images inlined as `[Data]`) |
| `exams.json` | `[Exam]` (`iso8601` date encoding) |
| `comprehensiveExams.json` | `[comprehensiveExam]` (`iso8601` date encoding) |
| `subjects.json` | `[Subject]` |
| `images/` | Grade image files (`grade_<uuid>.jpg`) — only when an image is attached |

**Sync vs async loaders:**

- Sync `load*()` methods are kept for backward compatibility and used during `init`.
- `asyncInit()` runs on `Task.detached(priority: .userInitiated)`, performs all loads off the main thread, migrates legacy inlined `Grade.image` data to files, then hops to `MainActor` to assign `@Published` properties.
- `loadProfileAsync()` / `loadGradesAsync()` / `loadMistakeSetsAsync()` are individual async reloaders (e.g. after sheet dismissal).

**Save/load discipline:** every collection has a paired `save*()` / `load*()` (and async variant where used). `asyncInit` handles grade-image migration from inline `Data` to a filesystem file the first time it sees legacy data.

**Mistake mutation helpers:** `addMistake(_:)`, `deleteMistake(_:)` / `deleteMistake(at:in:)`, `updateMistake(_:)` — all match on `id` (not title+date) to be safe.

## Key Models

All declared `nonisolated` so they can be safely passed across actor boundaries.

### Grade
- Fields: `subject`, `score`, `rawScore?` (卷面分), `ranking?`, `importance` (1–5), `image: Data?` (legacy), `imageFileName: String?` (new), `date`, `examName`
- `scoreRate` → `score / 150.0` (**hardcoded 150 — known issue**; should be per-subject)
- `@MainActor func getImage() -> Data?` — checks `imageFileName` first, falls back to inline `image` for backward compat

### MistakeNote
- `title`, `subject`, `originalQuestion`, `source`, `date`
- `errorReason`, `wrongSolution`, `correctSolution`
- Four parallel image arrays: `questionImages`, `reasonImages`, `wrongSolutionImages`, `correctSolutionImages` (all `[Data]`)
- Editor driven by `EditSection` enum (`.question / .reason / .wrong / .correct`) defined at the top of `NewMistakeSetView.swift`

### Exam vs comprehensiveExam
- Common: `id`, `name`, `examDate`, `importance` (1–5), `examName`, `masteryDegree` (0–100)
- `Exam.subject: String` (single) vs `comprehensiveExam.subject: [String]` (multi)

### Subject / UserProfile
- `Subject`: `id`, `name`, `enabled`
- `UserProfile`: `username`, `age`, `educationLevel`, `educationSystem`, `region`, `selectedSubjects`, `theme` (note: `theme` here is legacy — the live theme is in `AppPreferences.colorScheme`)

## App Preferences

### `AppPreferences` (`nonisolated`, Codable, persisted to `UserDefaults` under `"appPreferences"`)
- `appLanguage: String?` — `nil` = follow system, else `"en" | "zh-Hans" | "zh-Hant" | "ja" | "ko"`
- `colorScheme: ColorSchemeOption` — `.system` / `.light` / `.dark`

### `AppEnvironmentManager` (`@MainActor`, `ObservableObject`)
- `static let shared` (also injected via `@EnvironmentObject`)
- `@Published var preferences` auto-saves on `didSet`
- `effectiveColorScheme: ColorScheme?` for `.preferredColorScheme()`
- `setLanguage(_:)` writes `AppleLanguages` to `UserDefaults` and `synchronize()`s
- `setColorScheme(_:)` flips the published option (UI updates automatically)
- `applyLanguageOnLaunch()` runs once at app start (no `synchronize` to avoid restart prompt)

### `PreferencesView`
- **Appearance** section: inline picker (icon + localized name) over `ColorSchemeOption.allCases`
- **Language** section: picker over `AppPreferences.Language.allLocalized` (the only section that *does* need an app restart to take full effect; a destructive "Restart Now" button calls `exit(0)`)

## Style System

`AppStyle` (`nonisolated enum`) is a **prepared but not yet wired** design system. Three variants:

| Case | Corner radius | Border | Accent | Background |
|---|---|---|---|---|
| `.minimal` | 12 | 0 | `Color.accentColor` | systemGroupedBackground |
| `.literature` | 16 | 0 | `Color.accentColor` | systemGroupedBackground |
| `.tech` | 10 | 1.5pt cyan/purple gradient | cyan→purple gradient | dark purple gradient |

Helpers provided:
- `CardBG.view(for:)` — style-specific card background
- `AppStyle.primaryTextColor()` / `secondaryTextColor()` / `tertiaryTextColor()` — adapt to dark tech mode
- `accentButtonBackground()`, `neonBorder(width:)`, `statCardBorder(...)`, `cyanBorder(...)`, `cardBorder(...)` — style-aware view modifiers

⚠️ The current views do not yet consume `AppStyle` — it's a design system waiting to be adopted. Until then, individual views use `Color(.secondarySystemGroupedBackground)`, `Color(.systemBackground)`, etc.

## Widget Extension (`StudyPulseWidget/`)

A standalone widget target rendering upcoming exams on the Home Screen.

- **Data flow:** `DataManager` (main app) → `WidgetDataSyncManager.syncUpcomingExams(...)` → `WidgetDataStore.save(...)` (App Group `UserDefaults`) → `WidgetCenter.shared.reloadAllTimelines()` → `ExamWidgetProvider` reads via `WidgetDataStore.load()`.
- **Refresh policy:** `.after(nextMidnight)` — refreshes once per day.
- **Supported families:** `.systemSmall`, `.systemMedium`, `.systemLarge`.
- **App Group identifier:** `group.com.chenkai.gao.studypulse` (defined in `AppGroupConfig`). Must be enabled in the Apple Developer portal and configured for both targets in Xcode for the widget to actually load data.
- **Models:** `ExamWidgetData`, `WidgetDataStore`, `AppGroupConfig` are duplicated in both targets (the widget cannot import the main app module) — keep them in sync if you change fields.

⚠️ `WidgetDataSyncManager.syncUpcomingExams` is defined but **not yet called from anywhere**. Wire it into `DataManager.asyncInit` (or after `saveExamSets` / `saveComprehensiveExams`) to actually push data to the widget.

⚠️ The `StudyPulseWidget/` folder exists on disk but is not yet registered as a target in `StudyPulse.xcodeproj/project.pbxproj` — adding it to the project is required before the widget can be built/run.

## Swift 6 Concurrency

- All model structs (`Grade`, `MistakeNote`, `Exam`, `comprehensiveExam`, `Subject`, `UserProfile`, `AppPreferences`, `ExamWidgetData`) are `nonisolated`.
- Enums that back persistence (`DataFileIO`, `WidgetDataStore`) are `nonisolated`.
- `ImageCache` is `nonisolated`; the singleton accessor `ImageCache.shared` is `@MainActor`.
- `AppStyle` and `CardBG` are `nonisolated` enums.
- `DataManager` is `@MainActor`-isolated through `ObservableObject` inference; `Grade.getImage()` is explicitly `@MainActor` so it can call `DataManager.shared`.
- `AppEnvironmentManager` and `WidgetDataSyncManager` are `@MainActor`.
- `ExamPrepareNotifications` uses `@preconcurrency import UserNotifications` to bridge UN APIs without strict-concurrency warnings.

## Dependencies

### SPM (local packages, referenced as `../Packages/<name>`)
| Package | Path | Purpose |
|---|---|---|
| `WSOnBoarding` | `../Packages/WSOnBoarding-main` | First-launch welcome screen (configured in `WelcomeConfig.welcomeInfo`) |
| `MarkdownUI` (swift-markdown-ui) | `../Packages/swift-markdown-ui-main` | `Markdown()` view used in mistake editor preview |

> The project also keeps a `Package.resolved` (NetworkImage, swift-cmark) — leftover from when NetworkImage was a dependency; safe to delete.

### Apple Frameworks
| Framework | Purpose |
|---|---|
| EventKit | Calendar integration (`CalendarManager`) |
| Vision | OCR text recognition (`OCRManager`) |
| Charts | Grade/trend visualisation |
| WidgetKit | Home Screen widget (`StudyPulseWidget`) |
| UserNotifications | Exam reminders + onboarding test-notification button |

## Privacy Permissions
| Key | Value |
|---|---|
| `NSCameraUsageDescription` | 拍照拍摄错题照片 |
| `NSPhotoLibraryUsageDescription` | 访问相册选择错题照片 |
| `NSCalendarsUsageDescription` | 将考试添加到日历 |

## Feature Notes

### Mistake module
- `NewMistakeSetView` / `MistakeDetailEditView` both expose four editable sections (`EditSection`: question / reason / wrong / correct) with independent image arrays
- Photo capture (`PhotoCaptureView`) and photo-library picker (`ImagePicker`) per section
- **OCR** reads the most recently added image with `OCRManager.recognizeText(from:)` (Vision, accurate level, language correction on)
- Markdown preview toggle (`MarkdownUI`); writes back via `dataManager.updateMistake(_:)`
- `MistakeView` lists `mistakeSets` sorted by date, with `.searchable` (matches title/question/source/subject)
- `SuggestedMistakeCard` priority bands: within 1 week (high), >1 month (medium), else normal
- Thumbnail rendering uses `ThumbnailImageView` → `ImageCache.shared` (NSCache, max 50) → `ImageCache.thumbnail(from:maxDimension: 300)` → `ZoomableImageView` for full-screen pinch zoom

### Exam module
- Single-subject (`Exam`) and multi-subject (`comprehensiveExam`)
- `NewExamSetView` has a default-ON "add to system calendar" toggle — schedules all-day event with 1-day alarm via `CalendarManager`
- `ExamDetailView` exposes an explicit "Add to Calendar" button (also schedules notification reminders at 1/3/5/10/30 days via `ExamPrepareNotifications`, if called)
- Grouped list in `ExamView`: Within 1 Week / Within 1 Month / Later

### Trends
- `TrendsView` shows `SubjectScoreCard` per active subject (only those with at least one grade)
- Toggling score/ranking mode (toolbar menu) flows down to `SubjectDetailView` and the mini-chart
- "Subjects Needing Attention" surfaces subjects whose recent average < 70 or whose last 3 grades trend down by > 15 points
- `SubjectDetailView` filter: All / 3 Months / 6 Months / 1 Year, with line chart + history list

### Home dashboard
- Top stats (average, total grades, upcoming-in-2-weeks, mistake count)
- Quick action buttons (Add Grade / New Exam / New Mistake) open the appropriate sheet
- `StudySuggestionsCard` generates contextual suggestions (weakest subject, mistake review, upcoming exam prep, strongest subject, "add more grades" prompt)
- `ChartSectionView` lets the user focus on a subject picked by rule: lowest score / most data / recent activity / most improved / random
- Daily motivational quote (`dailyQuote` in `HomeView.swift`) rotates by day-of-year

### Settings
- Profile (username, age, education level / system / region) and subject toggles
- "App Preferences" link → `PreferencesView` (language + theme + restart)
- About / Copyright (CC BY-NC-SA 4.0 detail sheet) / send test notification (5-second local push) — useful for verifying notification permission was granted

### Charts
- `Charts` framework everywhere
- `miniChartView` (in `SubjectScoreCard.swift`) is the reusable per-card line+point chart; switches to ranking mode by filtering `ranking > 0`
- `GradeChartView` (in `Components/`) is a thinner wrapper for plain score-over-time

## Onboarding

- Triggered by `.wsWelcomeView(config: .welcomeInfo, style: .standard)` on the root `ContentView` (in `StudyPulseApp.swift`)
- Config: `WSWelcomeConfig.welcomeInfo` (3 features: chart analysis, fast response, offline)
- Hardcoded Chinese copy — needs translation to be useful for non-zh users

## Notification lifecycle
- `StudyPulseApp.init` requests `[.alert, .sound, .badge]`, sets `setBadgeCount(0)`, and registers a `NotificationCoordinator` as `UNUserNotificationCenter.current().delegate` (so banners/sound still fire in foreground and tapping a notification clears the badge)
- The test-notification button in `SettingsView` schedules a 5-second `UNTimeIntervalNotificationTrigger` (useful debug aid)

## Known Issues / TODOs

1. **`Grade.scoreRate` hardcodes 150.** Use `SubjectInfo.getMaxScore(level:subject:)` (or store full-score per subject) instead.
2. **No `DataManager.addGrade()` / `addExam()`.** Insert directly into the array and call the matching `save*()` method.
3. **`Sheets/NewMistakeSheet.swift` is legacy/unused** — current flow goes through `NewMistakeSetView`. Safe to delete.
4. **Widget is not wired up.** `StudyPulseWidget/` exists on disk but is not yet a target in `project.pbxproj`; `WidgetDataSyncManager.syncUpcomingExams` is also never called. Add the target, enable App Group `group.com.chenkai.gao.studypulse` for both, and call the sync after exam mutations.
5. **No iCloud sync** — all data is local-only in `~/Documents/`.
6. **No data export/import** (CSV, Excel, JSON).
7. **No confirmation dialog** for deleting grades or exams (mistakes likewise).
8. **`DataManager` uses both `static let shared` and `@EnvironmentObject`** — pick one (usually `@EnvironmentObject` only; `shared` is only needed inside `nonisolated` helpers like `Grade.getImage`).
9. **Onboarding copy is Chinese-only** — should be localised via `String.localized()`.
10. **AppStyle is not adopted by views** — most views still hardcode `Color(.secondarySystemGroupedBackground)`. Migrate opportunistically when touching a view.
11. **`Subject.scoreColor` and `SubjectInfo.getMaxScore` thresholds are hardcoded for 150/120/160/100** scoring scales.
12. **Hardcoded `addToCalendarToggle` in `NewExamSetView`** and no removal flow if the user changes their mind later.
13. **`reloadAllTimelines()` is unconditional** when widget sync is wired — consider scoping to a smaller subset of `WidgetKind` if you add more widgets.

## Build & Run

- Open `StudyPulse.xcodeproj` in Xcode
- Resolve SPM packages: **File → Packages → Resolve Package Versions** (Xcode usually does this automatically; the `../Packages/` directory must exist)
- Build: **Cmd+B**
- Run on simulator/device: **Cmd+R**
- No CLI test/lint targets — use Xcode's built-in test runner
- For the widget: add the `StudyPulseWidget` target to the project, set both targets' `App Group` capability to `group.com.chenkai.gao.studypulse`, then run the widget scheme

## Code Conventions

- Shared state via `@EnvironmentObject var dataManager: DataManager` (and `@EnvironmentObject var envManager: AppEnvironmentManager` where needed)
- All models are `nonisolated struct ... Codable` for JSON persistence
- Views use the `NavigationView` / `NavigationStack` + `Form` / `List` pattern; sheets drive creation/editing
- Localisation via `String.localized()` (reads `Localizable.strings` from `en.lproj`, `zh-Hans.lproj`, `zh-Hant.lproj`, `ja.lproj`, `ko.lproj`)
- Manager classes prefer `static let shared` for non-MainActor callers
- `EditSection` enum drives the 4-section mistake editor
- Style intent: `Color(.secondarySystemGroupedBackground)` for card surfaces, `Color(.systemBackground)` for content, `Color(.systemGroupedBackground)` for list/root backgrounds

## Performance Patterns

### Data loading
- App launch uses `dataManager.asyncInit()` from the root `.task` modifier — no main-thread blocking
- Legacy sync `load*()` methods are kept for `init` and tests
- Grade images stored as separate files in `images/`, not embedded in JSON
- Old inline `Grade.image` data is migrated to a file the first time `asyncInit` or `loadGrades()` sees it

### Image handling
- `ImageCache.shared` (NSCache, max 50) keyed by `data.hashValue`
- `ThumbnailImageView` decodes asynchronously via `Task.detached` with a `ProgressView` placeholder, then stores the thumb in the cache
- `ZoomableImageView` wraps the thumb and opens a `FullscreenZoomableView` sheet on tap

### View optimisation
- `ExamRowView`, `ComprehensiveExamRowView`, `CompactExamCard`, `RelatedMistakeCard` use computed `daysRemaining` instead of `@State` + `onAppear` mutation — avoids redundant re-renders
- `ContentView` triggers a `UIImpactFeedbackGenerator` (with 50ms async-after) on tab change

## Useful Starting Points for New Work

| Task | Start here |
|---|---|
| Add a new data field | `Models/DataModels.swift` → `Managers/DataManager.swift` (sync + `asyncInit`) |
| Add a new view | `Views/<Name>.swift`; inject via `@EnvironmentObject`; update `ContentView` tabs if needed |
| Add a new chart | Reuse `miniChartView` in `SubjectScoreCard.swift` or `GradeChartView` in `Components/` |
| Add a new language | Add a new `xx.lproj/Localizable.strings`, register in `project.pbxproj` `knownRegions`, add the code in `AppPreferences.Language` |
| Add a widget kind | New `Widget` in `StudyPulseWidget/`; new model in both `StudyPulseWidget/ExamWidgetData.swift` and `StudyPulse/Managers/ExamWidgetData.swift`; call `WidgetCenter.shared.reloadTimelines(ofKind:)` from the app |
