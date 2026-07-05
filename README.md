# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI + MVVM 构建。
> 通过 HealthKit 多维身体信号（HRV / 心率 / 呼吸率 / 深睡+REM / 锻炼）
> 与 Apple 学习场景（学习计时器 / 连续打卡 / 闪卡 SRS）给出个性化学习建议与趋势分析。

---

## 功能概览

StudyPulse 帮助学生管理学习过程中的核心数据：

- 成绩追踪：多科目成绩录入，支持自定义满分、原始分、排名、重要程度，以及成绩附件图片。
- 成绩可视化：交互式图表查看每门科目的趋势、平均分、最高/最低分；"需要关注的科目"智能提醒；图表类型可在 `Settings → Chart Type` 中切换（折线 / 柱状 / 饼图 / 散点 / 热力 / 频数直方图）。
- 错题本：分 4 个区块（题目 / 错误原因 / 错误解法 / 正确解法），每区块可独立添加照片，并内置 OCR 文字识别与 Markdown 预览。
  - **闪卡复习（SRS / SM-2）**：错题可入队复习队列，使用 SM-2 算法计算下次复习日期；提供 `FlashcardStudyView` / `FlashcardCardView` / `FlashcardSessionSummaryView` / `FlashcardCalculatorView` 与 `SRSReviewNotifications` 本地通知。
  - **一键导出 PDF 错题集**：按科目 / 时间范围 / 具体错题三种方式筛选，默认包含图片；用 Core Text + NSAttributedString 渲染多页 A4 PDF，文字以矢量字体嵌入（可选 / 复制 / 搜索），含封面 + 目录 + 每题独立页。
- 考试管理：单科考试与综合考试的日程表，支持多日考试（examEndDate）与具体时间段（ExamTimeSlot），关联系统日历、添加本地提醒、关联错题；`ExamDetailView` 包含考场信息（学校 / 教室 / 座位）、考前待办清单（`ExamChecklistItem`）、可定制的倒计时通知天数（默认 [1, 3, 5, 10, 30]）、复盘（ExamReview）与分享给家人按钮。
- 待办（Todo）：统一呈现日常作业 / 阅读材料 / 考试日程，含类型筛选（All / Exams / Homework / Reading）、时间分组（Within 1 Week / Within 1 Month / Later）、列表 / 日历切换、过期任务 sheet；可绑定系统 Reminders。
- HRV 健康准备度：基于 Apple Watch 的 HRV（SDNN）数据，使用 14 天基线与 Z-score 评估当日学习状态，提供简洁 / 数据 / 图表三级展示。
- 多维身体信号：基于 HealthKit 的心率 / 呼吸率 / 深睡+REM / Apple 锻炼时长，结合 30 天个人基线合成 5 档学习强度 × 5 类学习重点的个性化建议；详见 `docs/AlgorithmIntroduction.md`。
- 学习计时器（Study Timer / Pomodoro）：5 档强度（Peak / Deep Focus / Steady / Light / Recovery）匹配 StudyReadinessAlgorithm 的建议强度，配套 Lock Screen + Dynamic Island Live Activity（`StudyTimerLiveActivity`）；完成的会话持久化为 `StudySession` 写入 `~/Documents/study_sessions.json`。
- 连续打卡 & 成就系统：每日的「错题复习 / 成绩录入 / 专注分钟」三目标驱动连续天数与里程碑徽章；主页新增 `StreakHomeCard`，设置里新增 `AchievementsView` / `DailyGoalsConfigView`；支持每日 20:00 晚间提醒（可在设置中关闭）。详见 `docs/STREAK_ACHIEVEMENT_PLAN.md`。
- 90 天学习热力图：GitHub 风格的 7×13 格子图（`LearningHeatmapView`），数据源为 `AchievementManager.snapshot.logs`，5 档颜色（基于 `effectiveAccentColor` 不同 opacity）；点击格子弹当日详情 sheet；可选择在 Trends 顶部显示。
- 学习报告（Study Report）：把成绩 / 错题 / 考试 / HRV 等数据合成为一张可分享的图像（`ReportRenderer` + `ReportContentView` + `ReportShareSheet`）；GitHub 风格的活动贡献图（`ContributionSettingsView`）。
- 可定制主页：卡片可启用 / 禁用、拖动重新排序，iPad 使用两栏网格，iPhone 使用单列。
- 学期/假期阶段（Study Phase）：用户可创建"2026 春季学期" / "2026 暑假" / "高考冲刺"等自定义时间段，给历史数据划定边界；激活某个 phase 后主页 Trends / Mistakes / Exams / Todo 全部按 phase 过滤；Settings → Data Management 顶部 Phase Management 提供 active list + archived disclosure + overview 视图。`PhaseSelectorView` 胶囊 pill 放在 5 个主页面的 toolbar `.principal` 位置。
- 阶段目标（Phase Goal）：每个 phase 可绑定一组 `PhaseGoal`（科目 + 目标分 + 自由文字备注，例如"期末数学 ≥ 120"），帮助用户在长周期内盯住目标。
- 自定义主色：11 档预设调色板（system / blue / cyan / teal / green / mint / orange / red / pink / purple / indigo），在 `AppearanceSettingsView` 切换；通过 `effectiveAccentColor` 驱动 AccentColor、趋势图线/柱、闪卡进度条等。
- iOS 26 Liquid Glass 效果：设置中可全局开启（`glassEffectEnabled`），启用后若干卡片会改用 `Color.clear` + `glassEffect(in: Capsule())` 获得真实透明质感（老版本系统回退 `.regularMaterial`）。
- 自定义背景图：从相册选图后裁剪为 9:19.5 iPhone 屏幕比，写入 `Application Support/Backgrounds/bg_<uuid>.jpg`；`BackgroundImageView` 全屏 + 模糊 + 暗化遮罩铺在 `ContentView` 底部；为让图真正穿透，5 个主页面根使用 `Color(.systemGroupedBackground).opacity(0.4)`，`List` / `Form` 加 `.scrollContentBackground(.hidden)`。
- 全球教育系统：预置中国大陆、浙江、上海、台湾、香港、新加坡、UK (IGCSE / A-Level)、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等 15+ 种体系的科目与满分定义，并提供"智能推荐"一键套用。
- 多语言：英语、简体中文、繁體中文、日本語、한국（5 套完整本地化，主应用与小组件各 5 份 Localizable.strings）。
- 多主题：系统 / 浅色 / 深色三档。
- iPad 适配：侧栏 + 居中内容，使用 `iPadLayout` 下的 `AdaptiveHStack` / `AdaptiveGridColumns` / `adaptiveMaxWidth` / `adaptiveCardPadding` 等辅助组件，在大屏上充分利用空间。
- 小组件（WidgetKit）：四个小组件 —— ExamWidget（即将到来的考试）、TrendWidget（科目成绩趋势折线图）、HRVWidget（HRV 准备度）、StudyTimerLiveActivity（学习计时器 Lock Screen + Dynamic Island）；数据通过 App Group 容器与主应用同步。
- 数据管理：CSV 导入 / 导出，开发者工具页提供批量删除与数据统计；运行期日志可通过"Export Log"按钮导出，便于复现问题；底层使用 SwiftData 作为新的实体层（`Models/SwiftData/StudyPulseModels.swift` + `Managers/Core/ModelContainerFactory.swift`），首次启动时自动从旧 JSON 迁移。
- 启动引导：版本感知的欢迎页（首次启动 → 欢迎页；版本号变化 → 新功能介绍页；同版本不显示），原生 iOS 26 风格（TabView 分页 + 渐变背景 + 玻璃质感卡片），可附加 6 页「基础信息填写」步骤。
- 用户协议：内置 `docs/USER_AGREEMENT.md` v1.0，设置页 → `UserAgreementView` 全文可读。
- 快捷指令（Siri Shortcuts）：`StudyPulseShortcuts` 提供 AddGrade / RecordMistake / CheckUpcomingExams / CheckBodyStatus / CheckReadiness / CheckSubjectAverage 六个 AppIntent，跨进程通过 `IntentActionStore` 把 action 桥接到 `ContentView`。

---

## 技术栈

- 平台：iOS 18.6+（iPhone 与 iPad）
- 语言：Swift 6.0
- 框架：SwiftUI、Swift Charts、Vision（OCR）、EventKit（日历 / 提醒事项）、HealthKit（HRV + 多维身体信号）、UserNotifications、ActivityKit（Live Activity）、SwiftData（实体层）、AppIntents（快捷指令）、UniformTypeIdentifiers、PhotosUI、WidgetKit
- 包管理器：Swift Package Manager
  - 本地包：`SwiftStreamingMarkdown`（位于 `Packages/SwiftStreamingMarkdown-0.2.0/`，含 LaTeX 公式与流式 Markdown 渲染）
  - Vendored 包（位于 `Packages/Vendored/`）：`swift-cmark`（cmark-gfm Markdown 核心）、`swift-markdown`、`highlightswift`（代码高亮）、`iosMath`（LaTeX 数学）
- 架构模式：MVVM + Repository
  - 视图层（`Views/`）只负责 SwiftUI 渲染与用户交互，**不**直接管理数据状态。
  - 5 个主页面（Home / Trends / Mistake / Exam / Todo）各持一个 `@MainActor final class XxxViewModel: ObservableObject`，状态为 `@Published private(set)`，由父 View 通过 `static func makeDefault(container:)` 工厂创建。
  - 数据访问通过 7 个 Repository（`Repositories/Protocols/*Repository.swift` + `Default*Repository` 实现），由 `RepositoryContainer` 聚合（`@Observable @MainActor`）。ViewModel / View 通过 `@Environment(RepositoryContainer.self) var container` 注入。
  - 纯函数业务逻辑抽到 `Services/`（DateFormatters / SubjectAggregator / SuggestionEngine / ExamFilter / MistakeFilter / QuoteProvider），**不依赖 SwiftUI**，便于复用与测试。
- 数据持久化：
  - SwiftData 实体层（`SubjectRecord` / `GradeRecord` / `MistakeNoteRecord` / `ExamRecord` / `ComprehensiveExamRecord` / `TaskItemRecord` / `ReviewStateRecord` / `StudyPhaseRecord` 等）作为新的持久化后端，由 `ModelContainerFactory.makeContainer()` 启动时创建，`ModelContainerFactory.migrateFromJSONIfNeeded(context:)` 一次性从老 JSON 迁移。
  - 视图层使用 `nonisolated value type` 的 struct（`Subject` / `Grade` / `MistakeNote` / `Exam` / `comprehensiveExam` / `UserProfile` / `TaskItem` / `StudyPhase` / `PhaseGoal` / `ReviewState` 等），由 `Repository.toSnapshot()` / `init(from:)` 与 SwiftData 实体互转。
  - 偏好设置、主页顺序、phase 激活、每日目标等保存在 UserDefaults；小组件数据保存在 App Group 容器。
- 并发模型：Swift 6 Strict Concurrency，`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`；`@Observable @MainActor` RepositoryContainer 持有 7 个 Repository；`nonisolated value-type` 模型可安全跨 actor 传递；纯 I/O 枚举与 `ImageCache` 为 `nonisolated`。
- 工程文件：`StudyPulse.xcodeproj`，含 StudyPulse 主应用 + StudyPulseWidgetExtension 小组件两个目标。

---

## 目录结构

项目根目录下的主要文件和目录：

- `StudyPulse.xcodeproj`：Xcode 工程，含主应用 + 小组件两个目标。
- `StudyPulse/`：主应用源代码。
  - `StudyPulseApp.swift`：`@main` 入口，持有 `RepositoryContainer`（7 个 Repository 聚合）+ 三个 `@StateObject` 单例（`AppEnvironmentManager` / `HealthKitManager` / `StudyTimerManager`），注册通知代理、启动 LagMonitor。`.task` 中 `await container.asyncInit()`（JSON 迁移 + 7 repo 串行 loadAll + 内嵌图片迁移），完成后 `isReady == true` 才 `await hrvManager.bootstrap()` 与 `AchievementManager.shared.bootstrap(container:)`；`scenePhase == .active` 时统一 sync widget + SRS / Exam Review 通知。
  - `StudyPulse.entitlements` / `StudyPulseWidgetExtension.entitlements`：开启 HealthKit、App Group、NSSupportsLiveActivities 权限。
  - `Models/`：数据模型。
    - `DataModels.swift`（`StudyPhase` / `PhaseGoal` / `Subject` / `Grade` / `MistakeNote` / `Exam` / `comprehensiveExam` / `UserProfile` / `ExamTimeSlot` / `TaskItem` / `TaskType` / `TodoEntry` / `TodoEntryKind` / `ExamChecklistItem` / `ExamReview`）。
    - `AppPreferences.swift`（语言 + 主题 + 图表类型 + 主色预设 + glassEffect 开关 + Trends 热力图开关 + 激活 phaseId，附带向后兼容的 `init(from:)`）。
    - `HomeLayoutPreference.swift`（主页卡片顺序与开关）。
    - `HealthHistory.swift`（`DailyHealthSnapshot`）。
    - `StudySession.swift`（已完成学习会话记录）。
    - `SpacedRepetition.swift`（`ReviewState`，SM-2 算法核心字段）。
    - `Achievements.swift` + `AchievementCatalog.swift`（连续打卡 / 成就目录）。
    - `StudyReport.swift`（学习报告不可变 value type）。
    - `MistakePDFSnapshot.swift`（错题 PDF 导出快照）。
    - `SwiftData/StudyPulseModels.swift`（`@Model` 实体层 + `toSnapshot()` / `init(from:)`，由 `ModelContainerFactory` 迁移工具统一管理；新增 `StudyPhaseRecord` 与 `phaseId` 字段索引）。
  - `Managers/`：业务逻辑层。
    - `Core/`：`RepositoryContainer`（`@Observable @MainActor`，7 个 Repository 聚合 + ModelContainer 持有 + 跨域编排 + active phase 监听）；`AppEnvironmentManager`（语言 / 主题 / 主色 / glassEffect 开关 / activePhaseId + `effectiveAccentColor`）；`AppStyle`（设计系统骨架）；`DataExportManager`（CSV 导出）；`CSVDocument`；`ModelContainerFactory`（SwiftData 容器 + 自动迁移）。
    - `Health/`：`HealthKitManager`（HRV 准备度 + BodyStatus + PersonalBaselines）、`HealthHistoryStore`、`StudyReadinessAlgorithm`（5 强度 × 5 重点）。
    - `Logging/`：`Log`（`os.Logger` + `LogStore` 5000 条）、`LogDocument`（`.fileExporter` 导出）、`LagMonitor`（`CADisplayLink` 卡顿检测）。
    - `PDF/`：`MistakePDFRenderer`（Core Text + `NSAttributedString` 多页 A4）、`MistakePDFDocument`。
    - `Report/`：`ReportRenderer`（`ImageRenderer` + Core Graphics 输出 PNG / JPEG）、`ReportImageDocument`。
    - `Study/`：`StudyTimerManager`（`@MainActor` ObservableObject，5 档强度 + Live Activity 协调）、`DailyGoalReminder`（晚间提醒）、`SRSReviewNotifications`（错题 SRS 通知）、`ExamReviewNotifications`（考试复盘提醒）。
    - `Utility/`：`CalendarManager`（EventKit，支持具体时间段或全天）、`EducationConfig`、`ImageCache`（NSCache 缩略图，nonisolated）、`OCRManager`（Vision）、`StringsLocalized`、`SubjectInfo`。
    - `Widget/`：`ExamWidgetData` / `HRVWidgetData` / `TrendWidgetData` 与对应 `SyncManager`、`WidgetDataSyncManager`。
    - `Achievement/`：`AchievementManager`（`@MainActor` ObservableObject 单例，三个事件入口 `recordGradeRecorded` / `recordMistakeReviewed` / `recordFocusMinutes`）、`AchievementStore`（JSON 持久化 + NSLock）。
  - `Repositories/`：7 域 Repository（`Repositories/Protocols/` 协议 + `Default*Repository` 实现），由 `RepositoryContainer` 聚合：
    - `GradeRepository`（含 `filteredGrades`）
    - `MistakeRepository`（含 `filteredMistakeSets`）
    - `ExamRepository`（单科 Exam + 综合 comprehensiveExam + `filtered*`）
    - `TaskRepository`（作业 / 阅读 + Reminders 同步 + `filteredTaskItems`）
    - `PhaseRepository`（StudyPhase CRUD + activate / archive + 跨域清理 phaseId 引用）
    - `ProfileRepository`（UserProfile + 头像）
    - `SubjectRepository`（科目 + 满分 + 智能推荐）
  - `Services/`：纯函数服务，不依赖 SwiftUI（`QuoteProvider` 例外）：
    - `DateFormatters`（统一日期格式 + locale 切换）。
    - `SubjectAggregator`（按科目分组聚合 avg / count / recentCount / sortedAsc）。
    - `SuggestionEngine`（学习建议生成，输入 `StudySuggestionsContext`）。
    - `ExamFilter`（`examsWithinDays` / `unregisteredExams`）。
    - `MistakeFilter`（错题筛选与排序）。
    - `QuoteProvider`（每日金句；持有 `Color`，是唯一依赖 SwiftUI 的服务）。
  - `ViewModels/`：5 主页面 + 1 子页面 ViewModel：
    - `HomeViewModel`（SRS 概览 / 近期成绩 / 即将到来考试 / 未登记考试 / 图表选科）。
    - `TrendsViewModel`（趋势图数据 + 关注科目聚合）。
    - `MistakeViewModel`（错题列表 + 分组 + 搜索）。
    - `SubjectMistakesViewModel`（按科目的错题子页）。
    - `ExamViewModel`（考试列表 + 倒计时 + 复盘）。
    - `TodoViewModel`（统一待办聚合 `container.todoEntries(...)`）。
    - `ViewModelError`（错误类型）。
  - `Views/`：UI 层（按子领域拆分子目录）。
    - `ContentView.swift`：根视图，iPhone 使用 `TabView`，iPad 使用 `NavigationSplitView`，并观察 `IntentActionStore` 处理 Siri Shortcuts 跨进程跳转。
    - `Home/`：`HomeView`（主页仪表盘，分帧渲染 + 接收 `HomeViewModel`）、`HomeLayoutSettingsView`。
    - `Trends/`：`TrendsView`。
    - `Exam/`：`ExamView` / `ExamCalendarView` / `ExamDetailView` / `ExamDetailEditView` / `NewExamSetView` / `ExamReviewView` / `ScorePredictionEngine` / `ScorePredictionSheet`。
    - `Grade/`：`AddGradeView`、`SubjectScoreCard`。
    - `Mistake/`：`MistakeView`、`MistakeDetailEditView`、`NewMistakeSetView`、`PDF/`（`MistakePDFExportSheet`、`MistakePDFGenerationView`）。
    - `Flashcard/`：`FlashcardStudyView`、`FlashcardCardView`、`FlashcardSessionSummaryView`、`FlashcardCalculatorView`。
    - `Todo/`：`TodoView`、`TodoRowView`、`NewTaskView`、`TaskDetailView`、`TaskDetailEditView`。
    - `Profile/`：`EditSubjectsView`、`PreferencesView`、`ProfileEditView`。
    - `StudyTimer/`：`StudyTimerView`。
    - `Report/`：`ReportContentView`、`ReportOptionsSheet`、`ReportShareSheet`。
    - `Settings/`：`SettingsView` + 6 段式导航子页（`ProfileSettingsView` / `AppearanceSettingsView` / `HealthSettingsView` / `DataManagementSettingsView` / `AboutSettingsView` / `QASettingsView`）+ `AchievementsView` / `DailyGoalsConfigView` / `ChartTypeSettingsView` / `ContributionSettingsView` / `UserAgreementView` / `PhaseManagementView` / `PhaseEditView`。`SettingsCategory` 枚举驱动 6 段式导航。
    - `About/`：`AboutView`、`CopyrightView`、`HRVOnboardingView`。
    - `Admin/`：`DataAdminView`（开发者工具页）。
    - `OnBoarding/`：`OnboardingView`（原生 iOS 26 风格）、`OnboardingConfig`、`OnboardingFlowState`、`OnboardingProfileFormView`（6 页基础信息表单）、`VersionedWelcomeModifier`。
    - `Components/`：`GradeChartView`、`HRVStatusCard`、`LearningHeatmapView`（90 天热力图）、`MasteryCurveView`、`PhaseSelectorView`（全局 phase 切换器 pill）、`SectionHeader`、`StreakHomeCard`、`StudyTimerCard`、`SubjectPickerView`、`TrendChartView`。
    - `Helpers/`：`AvatarView`（异步加载）、`ImagePicker`、`PhotoCaptureView`、`ScoreColor`、`ZoomableImageView`、`iPadLayout`。
  - `Extensions/`：`AppleIntelligenceGradient`、`ColorExtensions`、`DateExtensions`、`GlassCardModifier`。
  - `Intents/`：`StudyPulseShortcuts`（6 个 AppIntent）、`SubjectEntity`（AppEntity）、`IntentAction` / `IntentDataLoader` / `IntentActionStore`（跨进程桥接）。
  - `NotificationsControl/`：`ExamPrepareNotifications`（考试倒计时通知，按 `countdownNotifyDays` 调度）。
- `StudyPulseWidget/`：WidgetKit 小组件源码。
  - `ExamWidget` / `TrendWidget` / `HRVWidget` 三个静态小组件 + `StudyTimerLiveActivity`。
  - 每个 widget 完整本地化 en / zh-Hans / zh-Hant / ja / ko 五种语言。
- `Packages/`：本地 / Vendored 包（`SwiftStreamingMarkdown-0.2.0/` 与 `Vendored/` 下的 `swift-cmark` / `swift-markdown` / `highlightswift` / `iosMath`）。
- `en.lproj/`、`zh-Hans.lproj/`、`zh-Hant.lproj/`、`ja.lproj/`、`ko.lproj/`：主应用各语言 Localizable.strings。
- `TestData/`：示例 CSV、`restore_sample_data.py` 还原脚本与生成数据。
- `scripts/build.sh`：构建辅助脚本。
- `README.md`、`AGENTS.md`、`docs/CODE_WIKI.md`、`docs/CODE_WIKI_CN.md`、`docs/AlgorithmIntroduction.md`、`docs/ScorePredictionAlgorithm.md`、`docs/STREAK_ACHIEVEMENT_PLAN.md`、`docs/SPEC.md`、`docs/DESIGN.md`、`docs/USER_AGREEMENT.md`、`docs/FAQ.json`、`docs/CONTRIBUTING.json`：文档、协议与许可。
- `LICENSE`：CC BY-NC-SA 4.0。

---

## 构建与运行

前置条件：

- macOS 15.0+
- Xcode 26.x（推荐 26.3 或更高）
- iOS 部署目标 18.6+
- Swift 6.0

推荐方式：在 Xcode 中打开 `StudyPulse.xcodeproj`，解析 SPM 包（File → Packages → Resolve Package Versions），选择模拟器或真机后按 Cmd+R 运行。

命令行方式（使用 `scripts/build.sh`）：

- 调试构建（默认 iPhone 17 模拟器）：`./scripts/build.sh`
- 发布构建：`./scripts/build.sh release`
- 清理构建目录：`./scripts/build.sh clean`
- 列出可用模拟器：`./scripts/build.sh list`
- 查看所有选项：`./scripts/build.sh help`

直接使用 xcodebuild：

```bash
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

可用 scheme：`StudyPulse`、`MarkdownUI`、StudyPulseWidgetExtension。
可用配置：`Debug`、`Release`。

> **注意**：Xcode IDE 和 xcodebuild CLI 不要在同一 DerivedData 目录上并发运行（会引起 `build.db` 锁）。`scripts/build.sh` 默认使用 `DerivedDataBuild/` 子目录以隔离。

---

## 隐私权限

应用需要以下权限键（已在 Info.plist 与 entitlements 中声明）：

- `NSCameraUsageDescription`：拍摄错题照片。
- `NSPhotoLibraryUsageDescription`：从照片库选择照片。
- `NSCalendarsUsageDescription`：添加考试到系统日历。
- `NSRemindersUsageDescription`：同步作业 / 阅读到系统提醒事项（Todo 模块需要）。
- `NSHealthShareUsageDescription`：读取 HRV / 心率 / 呼吸率 / 睡眠 / Apple 锻炼时间。
- `NSSupportsLiveActivities`：启用学习计时器 Live Activity。
- `com.apple.developer.healthkit`：entitlements 开启 HealthKit 能力。
- `com.apple.security.application-groups`：App Group `group.com.chenkai.gao.studypulse`，主应用与小组件共享数据。

应用不向 HealthKit 写入数据（无 `NSHealthUpdateUsageDescription`）。

---

## 性能要点

- `RepositoryContainer.asyncInit()` 在 `.task` 后台执行（JSON 迁移 + 7 repo 串行 `loadAll` + 内嵌图片迁移），主数据就绪前不写入 widget；`isReady == true` 后才执行 `HealthKitManager.bootstrap()` 与 `AchievementManager.bootstrap()`。
- `ImageCache` 使用 NSCache（最多 50 项、最大 300px），完全线程安全（nonisolated）。
- `AvatarView` / `WelcomeHeaderView` / `SettingsView` 的头像加载改为异步 Task，不再阻塞主线程。
- `HomeView` 采用分帧渲染（phased rendering），把首帧 long task 拆到多个 RunLoop 帧中绘制。
- `LagMonitor.shared` 持续监测主线程帧间隔，连续丢帧时把详细堆栈 / 时间戳写入 LogStore，便于事后通过 Export Log 复盘。
- iPad `HomeView` 使用 `LazyVGrid` 呈现仪表盘，保持内存占用低。
- `ModelContainerFactory` 仅在首次启动时执行一次 SwiftData 迁移（UserDefaults flag 记录），避免重复迁移 I/O。
- `StudyTimerLiveActivity` 通过 `ActivityKit` 在 Lock Screen / Dynamic Island 上呈现，所有像素由小组件扩展渲染，不增加主应用内存占用。
- `RepositoryContainer.observeActivePhaseChanges()` 用 0.5s polling 监测 `activePhaseId` 变化，避免引入 Combine 依赖；切换 phase 触发 5 个 `filtered*` 缓存重算。
- `Services/` 是纯函数 enum，5 个 ViewModel 内部对 grade / mistake / exam 的过滤聚合全部走 `SubjectAggregator.aggregate` / `ExamFilter.examsWithinDays` 等共享服务，无重复实现。

---

## 开发与贡献

- 代码编辑：Xcode（推荐）或任意支持 Swift / SwiftUI 的 IDE。
- 代码规范：
  - 模型为 `nonisolated value type`（Codable + Sendable + Hashable），可安全跨 actor 传递；SwiftData 实体使用 `@Model final class`，由 `toSnapshot()` / `init(from:)` 双向映射。
  - 所有用户可见字符串使用 `StringsLocalized.swift` 中的 `.localized()` 扩展（**注意：必须 `Text("foo".localized())` 带括号**，`"foo".localized` 会被推断为闭包）。小组件扩展内复制了一份同名扩展。
  - 图片文件写入 `~/Documents/images/`，不要内联进 JSON（旧的 `Grade.image` 字段已在 `RepositoryContainer.asyncInit` 中迁移为文件）。
  - 视图层使用 `iPadLayout` 下的辅助组件实现 iPad 适配。
  - 状态管理器使用 `@MainActor`；纯 I/O 枚举（`DataFileIO` / `WidgetDataStore` / `EducationConfig` / `ImageCache` 等）为 `nonisolated`。
- MVVM + Repository 约定：
  - **新建 ViewModel 必须**：`@MainActor final class XxxViewModel: ObservableObject` + `@Published private(set)` 状态 + `static func makeDefault(container:)` 工厂 + `import Combine`（`@Published` 需要）。
  - **子 View 接收 ViewModel 用 `let viewModel: XxxViewModel` 参数 + `@ObservedObject`**（不是 `@StateObject`，因为 VM 由父 View 创建并拥有）。
  - **Services 是纯函数 `enum` / `struct`**，**不 import SwiftUI**（`QuoteProvider` 是唯一例外，因为 `StudySuggestion.color: Color`）。
  - **Repository 实现必须是 `@MainActor` class**（由 `RepositoryContainer` 持有），跨域操作由 `RepositoryContainer` 编排，不要在 Repository 之间互相调用。
  - **DataManager 双实例陷阱**：`StudyPulseApp` 写 `@State private var container = RepositoryContainer()`，**不要写** `DataManager.shared` 之类的双实例。
- 新增功能：按照 MVVM + Repository 模式组织，视图层只持 ViewModel；ViewModel 通过 `RepositoryContainer` 读 7 域 Repository；跨域操作（widget sync、Achievement 事件、SRS 通知）封装在 `RepositoryContainer` 的 facade 方法（`addGrade` / `addMistake` / `addExams` / `addTask` / `deleteXxx` / `activatePhase`）。
- 新增 phase 字段：在 `StudyPhaseRecord` 上添加 `@Attribute` 字段后，**必须**同步在 `StudyPhase` struct（`init(from:)` 用 `decodeIfPresent` 给默认值）、`StudyPhaseRecord.toSnapshot()` / `init(from:)` 与 `PhaseRepository` 双向映射中补齐；否则老用户迁移会丢字段。
- 本地化：新增文案时，必须同步添加 en、zh-Hans、zh-Hant、ja、ko 五份 Localizable.strings 条目（主应用与小组件各 1 份，共 10 份）。
- 小组件：写入 widget 前确认 `container.isReady == true`，避免在主数据加载完成前写入空数据。修改 `App Group` 名称后记得更新 `AppGroupConfig.identifier`。
- Live Activity：`StudyTimerLiveActivity` 依赖 `StudyTimerActivityAttributes`（`ActivityAttributes`），主应用通过 `ActivityKit` 启动 / 更新 / 结束；新增静态 / 动态字段时同步更新主应用与小组件两侧的 `ContentState`。
- SwiftData 迁移：新增 / 修改 `@Model` 实体字段时，必须同步更新 `ModelContainerFactory` 的迁移工具 + `toSnapshot()` / `init(from:)`，否则旧数据迁移后会丢字段。新增 `@Model` 实体（如 `StudyPhaseRecord`）必须显式列入 `ModelContainerFactory.modelTypes` 数组，schema 才会包含它。
- 文档：修改 `StudyReadinessAlgorithm` 评分规则必须同步更新 `docs/AlgorithmIntroduction.md`；修改「每日目标 / 连续天数 / 成就」规则必须同步更新 `docs/STREAK_ACHIEVEMENT_PLAN.md`；修改 phase / 主色 / glass / 背景图 / 热力图 / 错题 SRS / 考试清单等架构性规则时同步更新 `AGENTS.md` / `SPEC.md` / `README.md`。
- 切勿手工修改 `StudyPulse.xcodeproj/project.pbxproj` —— 让 Xcode 管理；新增 Swift 文件后在 Xcode 中 Add Files to StudyPulse... / 拖入项目即可（Xcode 16+ 使用 `PBXFileSystemSynchronizedRootGroup` 自动收录 `StudyPulse/` 下的新 `.swift` 文件）。
- 用到 `Log.xxx.info(...)` 的任何文件必须 `import os`，否则编译报 "instance method 'appendInterpolation...' is not available due to missing import of defining module 'os'"。

---

## 开发者

- Gao-Chenkai
- Ken8891837

（两个账号均为 Gao Chenkai 本人使用）

---

## 许可

CC BY-NC-SA 4.0
