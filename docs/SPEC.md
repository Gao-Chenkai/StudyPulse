# StudyPulse — Product Specification

> Functional and non-functional specification for the **StudyPulse** iOS app.
> Authoritative source for product scope, features, requirements, and
> release planning. For architecture and code structure, see
> [AGENTS.md](AGENTS.md). For design language, see [DESIGN.md](DESIGN.md).

---

## 1. Product Summary

**StudyPulse** is a personal study-management app for iPhone and iPad that
helps students track academic grades, manage a mistake notebook, schedule
exams, sync with HealthKit for HRV-based study-readiness, and visualise
learning trends across many global education systems.

- **Bundle ID:** `Gao.Chenkai.StudyPulse`
- **Platforms:** iOS 18.6+, iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`)
- **Languages:** English, Simplified Chinese, Traditional Chinese, Japanese, Korean
- **License:** CC BY-NC-SA 4.0
- **Distribution:** App Store (developer `Gao-Chenkai` / `Ken8891837`)

---

## 2. Target Users

| Persona          | Age  | Profile                                  | Primary need                          |
|------------------|------|------------------------------------------|---------------------------------------|
| High-schooler    | 15–18| Daily multi-subject study load           | Track grades, see weak subjects       |
| Gaokao / DSE / AP student | 16–19 | High-stakes exam prep, fixed score scales | Subject-level trends, exam countdowns |
| IGCSE / A-Level student | 14–18 | UK / international curriculum           | Match subject names to local system   |
| IB / AP student  | 16–19| Crossover (CN + international subjects)  | Custom full scores per subject        |
| Health-aware student | 16–22 | Wears Apple Watch overnight         | HRV-based "should I push today?" cue  |

The product is **not** aimed at primary-schoolers, university research
students, or non-students. Tone is calm, technical, neutral.

---

## 3. In-Scope Features (v1)

### 3.1 Grade tracking
- Add a single grade with subject, score, raw score, ranking, importance
  (1–5), date, exam name, and a full-score override.
- Optional photo of the original paper (saved as `images/grade_{uuid}.jpg`).
- Subject list is **derived from the user's education system** (see §3.6);
  full score per subject is customisable.
- List / edit / delete.
- See Trends (§3.4) for visualisation.

### 3.2 Mistake notebook
- Four-section entry: **Question / Reason / Wrong / Correct**.
- Per-section photos (camera or library).
- OCR (Vision, `zh-Hans` + `en`, `.accurate`) one-tap into the active
  text field.
- Markdown preview per text field.
- Searchable by title, question, source, subject.
- "Suggested for Review" surfaced on the Mistakes tab based on age +
  subject priority.
- Pinch-to-zoom image viewer.
- **PDF export** (v1.x): a `square.and.arrow.up` button on the
  Mistakes toolbar opens an export sheet with three selection modes
  (subjects / date range / individual mistakes), an "Include Images"
  toggle (on by default), and a live preview of the mistake count.
  Generation runs on `MainActor` via **Core Text + NSAttributedString**
  drawn into a `UIGraphicsPDFRenderer` context, producing an A4
  (595×842 pt) PDF with a cover page, a table of contents, and one or
  more pages per mistake (`CTFramesetter` auto-paginates text;
  overflow is rendered on the next page; long sections span
  multiple pages automatically). Text is embedded as **vector PDF
  fonts** so it remains selectable / copyable / searchable in any
  PDF reader. The output is exposed via `FileDocument` and the
  standard share sheet (`.fileExporter`).

### 3.3 Exam scheduling
- Single-subject exam (`Exam`) and multi-subject comprehensive exam
  (`comprehensiveExam`).
- "Add to Calendar" toggle (EventKit, all-day event, 1-day reminder).
- Local notifications at −30 / −10 / −5 / −3 / −1 days.
- "Related Mistakes" section on `ExamDetailView` for the same subject.
- "Unregistered-exam reminder" card on Home for exams from 3–7 days
  ago with no matching grade.

### 3.3a Todo / Task tracker (v1.x)
- Two new task types in addition to exams: **Homework** (日常作业)
  and **Reading Material** (阅读材料), each with:
  - Title, type, related subject, importance (1–5), notes.
  - **Due date** (截止日期) and **reminder time** (提醒时间), set
    independently by the user.
  - Completion toggle (`isCompleted`), surfaced via strikethrough and
    a half-opacity card.
- Unified **Todo** page (replaces the former "Exams" tab) with:
  - All three types rendered as `TodoEntry` rows with a coloured type
    tag (Exam / Compre. / Homework / Reading).
  - Filter chips (All / Exams / Homework / Reading) and a "Show
    Completed" toggle.
  - Time-based grouping (Within 1 Week / Within 1 Month / Later) and a
    "Past Items" sheet.
  - List mode and Calendar mode (calendar mode is exam-only).
- Reminders / Calendar split:
  - **Exams** continue to sync to the system Calendar via
    `EKEventStore` (existing `CalendarManager.addExamToCalendar`).
  - **Homework / Reading** sync to the system Reminders app via
    `EKReminder`, with `dueDateComponents` driven by the task's due
    date and an `EKAlarm(absoluteDate:)` driven by the reminder time.
- Reminder edit behaviour:
  - Toggling the completion flag mirrors to the linked Reminder.
  - Editing a synced task calls `updateTaskInReminders`; if the
    Reminder has been deleted externally, a new one is created.
  - Deleting a task removes its linked Reminder.
  - The user may opt out of Reminders sync per task; opt-out deletes
    any existing linked Reminder.

### 3.4 Trends
- Per-subject line chart of score rate over time.
- "Subjects Needing Attention" alerts:
  - Average rate < 70 %, **or**
  - Recent decline > 15 points.
- Score / ranking mode toggle.

### 3.5 HRV-based study readiness
- Reads `HKQuantityTypeIdentifier.heartRateVariabilitySDNN` from
  HealthKit, last 14 days.
- Baseline: mean + std-dev of days **after today**, requires ≥ 7 distinct
  days.
- Z-score → category:
  - `excellent` (z > 1.0)
  - `normal`   (-1.0 ≤ z ≤ 1.0)
  - `low`      (z < -1.0)
  - `insufficient` (< 7 days)
  - `noAuthorization` / `queryFailed` for non-data states
- Three detail levels: suggestion only / data + suggestion / chart + data.
- Onboarding flow explains HRV, privacy, and requests consent before
  the first `requestAuthorization` call.

### 3.6 Global education systems
15+ systems supported, configured in `EducationConfig`:

| Family   | Codes                                                              |
|----------|--------------------------------------------------------------------|
| CN       | CN-MID, CN-HS, CN-ZJ-MID, CN-ZJ-3+3, CN-SH-MID, CN-SH-3+3         |
| TW       | TW-MID, TW-GSAT                                                    |
| HK       | HK-DSE                                                             |
| SG       | SG-OLEVEL                                                          |
| UK       | UK-IGCSE, UK-ALEVEL                                               |
| IB       | IB-DP                                                              |
| US       | US-AP, US-SAT, US-ACT                                             |
| GRAD     | GRE, GMAT, TOEFL, IELTS                                            |

The system list is the source of truth for default subject names and
default full scores per subject.

### 3.7 Home dashboard
- Customisable card order (drag to reorder) and visibility (on / off).
- Default cards: HRV, Unregistered-exam reminder, Quick Actions, Study
  Suggestions, Trend Chart, Upcoming Exams, Daily Quote, Recent Grades.
- Daily motivational quote rotated by day-of-year.

### 3.8 Data admin
- `Views/Admin/DataAdminView.swift` lists every grade, exam, and mistake
  with bulk actions for power users.
- CSV export for grades / mistakes / exams
  (`DataExportManager`, share sheet via `UIActivityViewController`).
- CSV import path covered in the data layer (TBD via UI).

### 3.9 Customisable Home layout
- `HomeLayoutPreference` is persisted in `UserDefaults` and read by
  `HomeView` on every render. Future card types merge into the existing
  user choices via `mergeWithDefault`.

### 3.10 Settings
- Profile (name, school, grade, class, student ID, enrollment year,
  exam year, target school, target score, avatar).
- Subject selection + full score override.
- App preferences (language, appearance: Light / Dark / Follow System).
- HRV toggle, HRV detail level.
- Academic info (education stage, region, education system).
- Data export / import.
- About / copyright / test notification.

### 3.11 Onboarding
- WSOnBoarding welcome flow driven by `WelcomeConfig.swift`.
- HRV consent flow (`HRVOnboardingView`) before the first HealthKit
  authorization request.

### 3.12 iPad adaptation
- `NavigationSplitView` sidebar with 5 destinations, column width
  220–280 pt.
- `iPadLayout.swift` provides `adaptiveMaxWidth`,
  `AdaptiveHStack`, `AdaptiveGridColumns`, `adaptiveCardPadding`.
- Max content widths per view (640 / 720 / 800 / 900 / 1100 pt).
- Home dashboard on iPad is a 2-column `LazyVGrid`.
- Keyboard navigation: `Tab` cycles, `1`–`5` jumps to a tab.
- Medium haptic on tab change.

### 3.13 Localisation
- Five locales (en, zh-Hans, zh-Hant, ja, ko) — all keys covered in
  every `Localizable.strings`.
- Language switcher in Preferences mutates the `AppleLanguages` key in
  `UserDefaults` and is applied at next launch.

### 3.14 Widget (sources committed, target not yet wired)
- Small / medium / large sizes.
- Shows the next upcoming exam (name, subject, days remaining).
- Reads from App Group `group.com.chenkai.gao.studypulse`.

---

## 4. Out-of-Scope (v1)

- iCloud sync (data is local to the device sandbox only).
- Real-time shared study sessions / social features.
- Cloud backup of images.
- Web companion.
- Apple Pencil-first mistake editing.
- macOS / Mac Catalyst first-class experience (iPad layout is
  Catalyst-friendly but not optimised for menu bar / multi-window).
- Custom subject colours per user — colours come from the education
  config; this is a future enhancement.
- iPad Stage Manager multi-window behaviour.

---

## 5. Functional Requirements

| ID    | Requirement                                                                                       |
|-------|---------------------------------------------------------------------------------------------------|
| F-01  | All persistent state must survive app relaunch and device reboot.                                 |
| F-02  | JSON files in `~/Documents/` are the source of truth. UserDefaults holds small prefs only.         |
| F-03  | Image bytes are written to `~/Documents/images/`, never inlined in JSON.                          |
| F-04  | Inline `Grade.image` data from old installs is migrated on first launch to file-based storage.    |
| F-05  | All views read shared state via `@EnvironmentObject` for `DataManager`, `AppEnvironmentManager`, `HealthKitManager`. |
| F-06  | Adding / editing an exam with the calendar toggle on must create an EventKit event + 1-day reminder. |
| F-07  | Adding / editing an exam must schedule local notifications at −30 / −10 / −5 / −3 / −1 days.     |
| F-08  | HRV data must be refreshed on app launch, on `hrvEnabled` toggle on, and on manual pull-to-refresh. |
| F-09  | HRV data must NOT be requested until the user has finished `HRVOnboardingView` and granted consent. |
| F-10  | The Home dashboard must reflect `HomeLayoutPreference` exactly: ordered, filtered by `enabled`.  |
| F-11  | Home cards with no data (recent grades, upcoming exams, unregistered exams) must hide themselves. |
| F-12  | Score-rate colour thresholds (90 / 75 / 60 %) must apply to every education system, including IB (7 pts) and SAT (800 pts). |
| F-13  | iPad must use `NavigationSplitView` for top-level navigation. iPhone must use `TabView`.         |
| F-14  | iPad content must be centered with the per-view max-width; iPhone must remain full-bleed.        |
| F-15  | Every user-facing string must come from `Localizable.strings` via `"…".localized()`.              |
| F-16  | CSV export must escape commas, quotes, and newlines correctly.                                   |
| F-17  | All app-internal model types must be `nonisolated`, `Codable`, and value types.                   |
| F-18  | `DataManager.asyncInit` must finish before the first render of the Home view.                      |
| F-19  | iPhone hardware keyboard `Tab` cycles tabs; `1`–`5` jumps to a tab.                              |
| F-20  | Tab change must trigger a single medium haptic.                                                  |

---

## 6. Non-Functional Requirements

| ID    | Requirement                                                                              |
|-------|------------------------------------------------------------------------------------------|
| N-01  | Cold launch → first Home render ≤ 1.5 s on iPhone 15 simulator with seeded data.         |
| N-02  | No main-thread JSON decoding. All `~/Documents` reads use `DataFileIO` (nonisolated).   |
| N-03  | Thumbnail cache must cap at 50 entries / 300 px max dimension, evict under pressure.   |
| N-04  | All async work uses `Task.detached` or `withCheckedContinuation`; no `DispatchQueue.global().async` for app data. |
| N-05  | Minimum iOS 18.6, deployment target reflects Xcode 26 toolchain.                        |
| N-06  | Swift 6 strict concurrency; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.                 |
| N-07  | No third-party analytics, no crash reporting, no remote configuration.                  |
| N-08  | App size on disk ≤ 50 MB (excluding user data and images).                              |
| N-09  | Battery: HRV refresh ≤ 1x per app foreground. No background HealthKit queries in v1.    |
| N-10  | Localisation coverage: 100 % of keys present in every `Localizable.strings`.            |

---

## 7. Data Model

```
Subject { id, name, displayName, enabled, fullScore }
Grade   { id, subject, score, rawScore?, ranking?, importance (1..5),
          image? (legacy), imageFileName?, date, examName, fullScore? }
MistakeNote { id, title, subject, originalQuestion, source, date,
              errorReason, wrongSolution, correctSolution,
              questionImages, reasonImages, wrongSolutionImages, correctSolutionImages }
Exam   { id, name, examDate, importance (1..5), subject, examName, masteryDegree (0..100) }
comprehensiveExam { id, name, examDate, importance (1..5), subject: [String],
                    examName, masteryDegree (0..100) }
TaskItem { id, title, type: TaskType, dueDate, reminderDate, subject,
           importance (1..5), notes, isCompleted,
           reminderEventId?, reminderCalendarId?, createdAt }
TaskType { homework | reading }
TodoEntry { id, kind: TodoEntryKind, title, subject, date, endDate?,
            importance, isCompleted, exam?, comprehensiveExam?, taskItem? }
TodoEntryKind { exam | comprehensiveExam | homework | reading }
UserProfile { username, realName, age, gender, schoolName, grade, className,
              studentId, enrollmentYear, examYear,
              educationStage, regionCode, theme, avatarFileName,
              targetSchool, targetScore, selectedSubjects,
              // legacy: educationLevel, educationSystem, region }
AppPreferences { appLanguage?, colorScheme (system | light | dark) }
HomeLayoutPreference { items: [HomeCardItem] }
HomeCardItem { type: HomeCardType, enabled: Bool }
HomeCardType { hrvStatus | unregisteredExamsReminder | quickActions
             | studySuggestions | trendChart | upcomingExams
             | dailyQuote | recentGrades }
```

Persistence:

| What                      | Where                                           |
|---------------------------|-------------------------------------------------|
| Grade / exam / mistake / profile / subjects | `~/Documents/*.json`           |
| Grade images              | `~/Documents/images/grade_{uuid}.jpg`           |
| Avatar                    | `~/Documents/images/avatar_{uuid}.jpg`          |
| App preferences           | `UserDefaults` key `appPreferences`             |
| Home layout               | `UserDefaults` key `homeLayoutPreference`       |
| HRV feature flags         | `UserDefaults` keys `hrv_enabled`, `hrv_onboarding_completed`, `hrv_detail_level` |
| Widget exam snapshot      | App Group `group.com.chenkai.gao.studypulse` → `widgetUpcomingExams` |

---

## 8. Permissions

| Key                              | Value                              |
|----------------------------------|------------------------------------|
| `NSCameraUsageDescription`       | "Take photos of mistakes"          |
| `NSPhotoLibraryUsageDescription` | "Select photos from photo library" |
| `NSCalendarsUsageDescription`    | "Add exams to calendar"            |
| `NSRemindersFullAccessUsageDescription` (iOS 17+) / `NSRemindersUsageDescription` (legacy) | "Add homework / reading tasks to the system Reminders app" |
| `NSHealthShareUsageDescription`  | "Read HRV data from Health"        |
| `com.apple.developer.healthkit`  | true (entitlement)                 |

The app never writes to Health; it only reads. The app never writes to
the calendar's *other* calendars, only the one chosen by the user via
the EventKit picker. Homework and reading tasks write only to the
Reminders list chosen by EventKit (`defaultCalendarForNewReminders()`)
and never to other lists.

---

## 9. Architecture Snapshot

```
+-------------------------------+
|  StudyPulseApp  (@main)       |
|  - NotificationCoordinator    |
|  - applyLanguageOnLaunch      |
|  - .task { asyncInit }         |
+-------------------------------+
                |
                v
+-------------------------------+
|  ContentView                  |
|  iPhone: TabView               |
|  iPad: NavigationSplitView     |
+-------------------------------+
                |
                v
+-------------------------------+
|  HomeView / TrendsView / ...   |
|  HRVStatusCard, ChartSection,  |
|  UpcomingExams, ...            |
+-------------------------------+
       |              |
       v              v
+-------------+  +----------------------+
| DataManager |  | HealthKitManager     |
| (MainActor) |  | (MainActor singleton)|
+-------------+  +----------------------+
       |              |
       v              v
+-------------------------------+
|  DataFileIO  (nonisolated enum)|
|  ImageCache  (nonisolated)     |
|  ExamWidgetData                |
|  EducationConfig               |
+-------------------------------+
       |
       v
+-------------------------------+
|  ~/Documents/*.json           |
|  ~/Documents/images/*.jpg     |
|  UserDefaults                 |
|  App Group UserDefaults       |
+-------------------------------+
```

See [AGENTS.md §4–6](AGENTS.md) for full ASCII diagrams.

---

## 10. Roadmap

### v1.0 (current)
- Grade, mistake, exam, trend, settings, multi-language, iPad layout,
  customisable Home, HRV readiness, CSV export, widget sources staged
  (target not yet wired).

### v1.1 (next)
- Wire up the `StudyPulseWidget` target in `StudyPulse.xcodeproj` and
  ship to the App Store.
- CSV import via UI.
- Subject colours per user override.

### v1.2
- `tech` style promoted to a user-selectable variant in Preferences.
- Charts colour-blind mode.

### v2.0 (longer term)
- Optional iCloud sync (CloudKit private database) for grades, mistakes,
  exams, profile.
- Family Sharing (different students on the same device).
- macOS / Mac Catalyst first-class app (multi-window, menu bar).

---

## 11. Acceptance Criteria (v1.0 release gate)

A build is shippable when all of the following hold:

- [ ] `./scripts/build.sh release` produces a clean release archive.
- [ ] The app launches on iPhone 17 simulator and reaches Home within 1.5 s.
- [ ] The app launches on iPad Pro 11-inch simulator and shows a sidebar.
- [ ] Adding a grade, mistake, and exam each persist across a relaunch.
- [ ] HRV card stays hidden until the user finishes `HRVOnboardingView`.
- [ ] Home layout changes in `HomeLayoutSettingsView` persist across a relaunch.
- [ ] Switching language in Preferences to any of the five locales updates
      the UI on next launch.
- [ ] Score rate colours match §3.12 of [DESIGN.md](DESIGN.md) at 90 / 75 / 60 %.
- [ ] CSV export of grades / mistakes / exams opens cleanly in Numbers
      and Excel without quoting errors.
- [ ] No new `// TODO` or `print` left in `Managers/` or `Models/`.
- [ ] No `swiftc` / `xcodebuild` warnings in `release` build.
- [ ] All 100 % of `Localizable.strings` keys present in every locale.

---

## 12. Open Questions

1. **Widget target wiring.** Who owns the Xcode project change to add
   the widget target — see [AGENTS.md §14](AGENTS.md)?
2. **Cloud sync.** CloudKit private database vs iCloud Drive JSON
   round-trip — needs product decision before v2.0.
3. **Subject colour override.** UX question: per-subject colour or per-
   subject palette? (Affects `SubjectInfo` model.)
4. **HRV detail level default.** Is `dataAndSuggestion` the right v1
   default, or should it be `suggestionOnly` to be less overwhelming?
5. **Daily quote copy.** Do we ship a built-in list (current behaviour)
   or pull from a remote source?

---

## 13. Glossary

- **HRV** — Heart Rate Variability. Here, specifically the SDNN
  (standard deviation of NN intervals) recorded by Apple Watch overnight.
- **Z-score** — `(today − mean) / stdDev`, where mean and stdDev are
  computed over the user's own recent days. Personalized, not a
  population reference.
- **Rate** — `score / fullScore` for the relevant subject. Score colours
  and chart Y-axes are rate-based, not absolute.
- **Comprehensive exam** — A single dated event covering several
  subjects (e.g. a mock Gaokao). Distinct from `Exam` which is single-
  subject.
- **Raw score** — Optional, used in scored-ranking systems (e.g. Zhejiang
  3+3) where the displayed score is a converted value.
- **Education stage** — `primarySchool` / `middleSchool` / `highSchool` /
  `internationalHighSchool` / `university` / `graduate`.
- **Region** — A specific education-system code within a stage (e.g.
  `CN-ZJ-3+3`, `IB-DP`, `US-SAT`).
