# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI 构建。
> 通过 HealthKit 多维身体信号（HRV / 心率 / 呼吸率 / 深睡+REM / 锻炼）
> 与 Apple 学习场景（学习计时器 / 连续打卡 / 闪卡 SRS）给出个性化学习建议与趋势分析。

---

## 功能概览

StudyPulse 帮助学生管理学习过程中的核心数据：

- 成绩追踪：多科目成绩录入，支持自定义满分、原始分、排名、重要程度，以及成绩附件图片。
- 成绩可视化：交互式图表查看每门科目的趋势、平均分、最高/最低分；"需要关注的科目"智能提醒；图表类型可在 `Settings → Chart Type` 中切换。
- 错题本：分 4 个区块（题目 / 错误原因 / 错误解法 / 正确解法），每区块可独立添加照片，并内置 OCR 文字识别与 Markdown 预览。
  - **闪卡复习（SRS / SM-2）**：错题可入队复习队列，使用 SM-2 算法计算下次复习日期；提供 `FlashcardStudyView` / `FlashcardCardView` / `FlashcardSessionSummaryView` / `FlashcardCalculatorView` 与 `SRSReviewNotifications` 本地通知。
  - **一键导出 PDF 错题集**：按科目 / 时间范围 / 具体错题三种方式筛选，默认包含图片；用 Core Text + NSAttributedString 渲染多页 A4 PDF，文字以矢量字体嵌入（可选 / 复制 / 搜索），含封面 + 目录 + 每题独立页。
- 考试管理：单科考试与综合考试的日程表，支持多日考试（examEndDate）与具体时间段（ExamTimeSlot），关联系统日历、添加本地提醒、关联错题。
- 待办（Todo）：统一呈现日常作业 / 阅读材料 / 考试日程，含类型筛选（All / Exams / Homework / Reading）、时间分组（Within 1 Week / Within 1 Month / Later）、列表 / 日历切换、过期任务 sheet；可绑定系统 Reminders。
- HRV 健康准备度：基于 Apple Watch 的 HRV（SDNN）数据，使用 14 天基线与 Z-score 评估当日学习状态，提供简洁 / 数据 / 图表三级展示。
- 多维身体信号：基于 HealthKit 的心率 / 呼吸率 / 深睡+REM / Apple 锻炼时长，结合 30 天个人基线合成 5 档学习强度 × 5 类学习重点的个性化建议；详见 `docs/AlgorithmIntroduction.md`。
- 学习计时器（Study Timer / Pomodoro）：5 档强度（Peak / Deep Focus / Steady / Light / Recovery）匹配 StudyReadinessAlgorithm 的建议强度，配套 Lock Screen + Dynamic Island Live Activity（`StudyTimerLiveActivity`）；完成的会话持久化为 `StudySession` 写入 `~/Documents/study_sessions.json`。
- 连续打卡 & 成就系统：每日的「错题复习 / 成绩录入 / 专注分钟」三目标驱动连续天数与里程碑徽章；主页新增 `StreakHomeCard`，设置里新增 `AchievementsView` / `DailyGoalsConfigView`；支持每日 20:00 晚间提醒（可在设置中关闭）。详见 `docs/STREAK_ACHIEVEMENT_PLAN.md`。
- 学习报告（Study Report）：把成绩 / 错题 / 考试 / HRV 等数据合成为一张可分享的图像（`ReportRenderer` + `ReportContentView` + `ReportShareSheet`）；GitHub 风格的活动贡献图（`ContributionSettingsView`）。
- 可定制主页：卡片可启用 / 禁用、拖动重新排序，iPad 使用两栏网格，iPhone 使用单列。
- 全球教育系统：预置中国大陆、浙江、上海、台湾、香港、新加坡、UK (IGCSE / A-Level)、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等 15+ 种体系的科目与满分定义，并提供"智能推荐"一键套用。
- 多语言：英语、简体中文、繁體中文、日本語、한국（5 套完整本地化，主应用与小组件各 5 份 Localizable.strings）。
- 多主题：系统 / 浅色 / 深色三档。
- iPad 适配：侧栏 + 居中内容，使用 `iPadLayout` 下的 `AdaptiveHStack` / `AdaptiveGridColumns` / `adaptiveMaxWidth` / `adaptiveCardPadding` 等辅助组件，在大屏上充分利用空间。
- 小组件（WidgetKit）：四个小组件 —— ExamWidget（即将到来的考试）、TrendWidget（科目成绩趋势折线图）、HRVWidget（HRV 准备度）、StudyTimerLiveActivity（学习计时器 Lock Screen + Dynamic Island）；数据通过 App Group 容器与主应用同步。
- 数据管理：CSV 导入 / 导出，开发者工具页提供批量删除与数据统计；运行期日志可通过"Export Log"按钮导出，便于复现问题；底层使用 SwiftData 作为新的实体层（`Models/SwiftData/StudyPulseModels.swift` + `Managers/Core/ModelContainerFactory.swift`），首次启动时自动从旧 JSON 迁移。
- 启动引导：版本感知的欢迎页（首次启动 → 欢迎页；版本号变化 → 新功能介绍页；同版本不显示），原生 iOS 26 风格（TabView 分页 + 渐变背景 + 玻璃质感卡片），可附加 6 页「基础信息填写」步骤。
- 用户协议：内置 `docs/USER_AGREEMENT.md` v1.0，设置页 → `UserAgreementView` 全文可读。

---

## 技术栈

- 平台：iOS 18.6+（iPhone 与 iPad）
- 语言：Swift 6.0
- 框架：SwiftUI、Swift Charts、Vision（OCR）、EventKit（日历 / 提醒事项）、HealthKit（HRV + 多维身体信号）、UserNotifications、ActivityKit（Live Activity）、SwiftData（实体层）、UniformTypeIdentifiers、PhotosUI、WidgetKit
- 包管理器：Swift Package Manager
  - 本地包：`SwiftStreamingMarkdown`（位于 `Packages/SwiftStreamingMarkdown-0.2.0/`，含 LaTeX 公式与流式 Markdown 渲染）
  - Vendored 包（位于 `Packages/Vendored/`）：`swift-cmark`（cmark-gfm Markdown 核心）、`swift-markdown`、`highlightswift`（代码高亮）、`iosMath`（LaTeX 数学）
- 架构模式：MVVM，使用 `@EnvironmentObject` 暴露 DataManager / AppEnvironmentManager / HealthKitManager / AchievementManager
- 数据持久化：
  - 业务模型以 JSON 存储在 `~/Documents/` 下，图片以独立文件保存在 `~/Documents/images/` 下，健康历史保存在 `~/Documents/health_history.json`，学习会话保存在 `~/Documents/study_sessions.json`；
  - 偏好设置与主页顺序保存在 UserDefaults；
  - 小组件数据保存在 App Group 容器；
  - SwiftData 实体层（`SubjectRecord` / `GradeRecord` / `MistakeNoteRecord` / `ExamRecord` / `ComprehensiveExamRecord` / `UserProfileRecord` / `TaskItemRecord` / `ReviewStateRecord`）作为新的可选持久化后端，由 `ModelContainerFactory` 启动时自动从旧 JSON 迁移。
- 并发模型：Swift 6 Strict Concurrency，`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`；状态管理器使用 `@MainActor`，纯 I/O 枚举与 `ImageCache` 为 `nonisolated`
- 工程文件：`StudyPulse.xcodeproj`，含 StudyPulse 主应用 + StudyPulseWidgetExtension 小组件两个目标

---

## 目录结构

项目根目录下的主要文件和目录：

- `StudyPulse.xcodeproj`：Xcode 工程，含主应用 + 小组件两个目标。
- `StudyPulse/`：主应用源代码。
  - `StudyPulseApp.swift`：`@main` 入口，注册通知代理、启动 LagMonitor，以 `.task` 启动 `DataManager.asyncInit()` / `HealthKitManager.bootstrap()` / `AchievementManager.bootstrap()`，在 `scenePhase == .active` 时同步所有 widget。
  - `StudyPulse.entitlements` / `StudyPulseWidgetExtension.entitlements`：开启 HealthKit、App Group、NSSupportsLiveActivities 权限。
  - `Models/`：数据模型。
    - `DataModels.swift`（Subject / Grade / MistakeNote / Exam / comprehensiveExam / UserProfile / ExamTimeSlot / TaskItem / TaskType / TodoEntry / TodoEntryKind）。
    - `AppPreferences.swift`（语言 + 主题）。
    - `HomeLayoutPreference.swift`（主页卡片顺序与开关，含 `streakProgress`）。
    - `HealthHistory.swift`（DailyHealthSnapshot）。
    - `StudySession.swift`（已完成学习会话记录；字段：id / startDate / durationSeconds / intensity / completed）。
    - `SpacedRepetition.swift`（ReviewState，SM-2 算法核心字段）。
    - `Achievements.swift`（DailyGoalConfig / DailyActivityLog / StreakState / AchievementDefinition / AchievementProgress / AchievementsSnapshot）。
    - `AchievementCatalog.swift`（编译期成就目录常量）。
    - `StudyReport.swift`（学习报告不可变 value type）。
    - `MistakePDFSnapshot.swift`（错题 PDF 导出快照）。
    - `SwiftData/StudyPulseModels.swift`（@Model 实体层 + toSnapshot() / init(from:)，由 `ModelContainerFactory` 迁移工具统一管理）。
  - `Managers/`：业务逻辑层。
    - `Core/`：DataManager（@MainActor ObservableObject，对外暴露 `isReady`）、AppEnvironmentManager（语言 / 主题）、AppStyle（设计系统骨架）、DataExportManager（CSV 导出）、CSVDocument、ModelContainerFactory（SwiftData 容器 + 自动迁移）。
    - `Health/`：HealthKitManager（HRV 准备度 + BodyStatus + PersonalBaselines）、HealthHistoryStore、StudyReadinessAlgorithm（5 强度 × 5 重点）。
    - `Logging/`：Log（os.Logger + LogStore 5000 条）、LogDocument、.fileExporter 导出）、LagMonitor（CADisplayLink 卡顿检测）。
    - `PDF/`：MistakePDFRenderer（Core Text + NSAttributedString 多页 A4）、MistakePDFDocument。
    - `Report/`：ReportRenderer（ImageRenderer + Core Graphics 输出 PNG / JPEG）、ReportImageDocument。
    - `Study/`：StudyTimerManager（@MainActor ObservableObject，5 档强度 + Live Activity 协调）、DailyGoalReminder（晚间提醒）、SRSReviewNotifications（错题 SRS 通知）。
    - `Utility/`：CalendarManager（EventKit，支持具体时间段或全天）、EducationConfig、ImageCache（NSCache 缩略图，nonisolated）、OCRManager（Vision）、StringsLocalized、SubjectInfo。
    - `Widget/`：ExamWidgetData / HRVWidgetData / TrendWidgetData 与对应 SyncManager。
    - `Achievement/`：AchievementManager（@MainActor ObservableObject 单例，三个事件入口 recordGradeRecorded / recordMistakeReviewed / recordFocusMinutes）、AchievementStore（JSON 持久化 + NSLock）。
  - `Views/`：UI 层（按子领域拆分子目录）。
    - `ContentView.swift`：根视图，iPhone 使用 TabView，iPad 使用 NavigationSplitView。
    - `Home/`：HomeView（主页仪表盘，分帧渲染避免主线程长任务）、HomeLayoutSettingsView。
    - `Trends/`：TrendsView。
    - `Exam/`：ExamView / ExamCalendarView / ExamDetailView / ExamDetailEditView / NewExamSetView。
    - `Grade/`：AddGradeView、SubjectScoreCard。
    - `Mistake/`：MistakeView、MistakeDetailEditView、NewMistakeSetView、PDF（MistakePDFExportSheet、MistakePDFGenerationView）。
    - `Flashcard/`：FlashcardStudyView、FlashcardCardView、FlashcardSessionSummaryView、FlashcardCalculatorView。
    - `Todo/`：TodoView（统一待办主页面）、TodoRowView、NewTaskView、TaskDetailView、TaskDetailEditView。
    - `Profile/`：EditSubjectsView、PreferencesView、ProfileEditView。
    - `StudyTimer/`：StudyTimerView。
    - `Report/`：ReportContentView、ReportOptionsSheet、ReportShareSheet。
    - `Settings/`：SettingsView + 6 段式导航子页 —— ProfileSettingsView / AppearanceSettingsView / HealthSettingsView / DataManagementSettingsView（含 Export Log）/ AboutSettingsView / QASettingsView + AchievementsView、DailyGoalsConfigView、ChartTypeSettingsView、ContributionSettingsView、UserAgreementView。`SettingsCategory` 枚举驱动 5 段式导航。
    - `About/`：AboutView、CopyrightView、HRVOnboardingView。
    - `Admin/`：DataAdminView（开发者工具页）。
    - `OnBoarding/`：OnboardingView（原生 iOS 26 风格）、OnboardingConfig、OnboardingFlowState、OnboardingProfileFormConfig、OnboardingProfileFormView（基础信息填写步骤）、VersionedWelcomeModifier（版本感知欢迎页）。
    - `Components/`：GradeChartView、HRVStatusCard、SectionHeader、SubjectPickerView、TrendChartView、StudyTimerCard、StreakHomeCard、AchievementUnlockToast、Markdown（MarkdownEditorView、MarkdownPreviewView、MarkdownTextEditor）。
    - `Helpers/`：AvatarView（异步加载）、ImagePicker、PhotoCaptureView、ScoreColor、ZoomableImageView、iPadLayout。
  - `Extensions/`：`ColorExtensions.swift`、`DateExtensions.swift`。
  - `NotificationsControl/`：`ExamPrepareNotifications.swift`（本地通知调度）。
- `StudyPulseWidget/`：WidgetKit 小组件源码（目标已接入 StudyPulse.xcodeproj，scheme：StudyPulseWidgetExtension）。
  - `ExamWidget.swift` / `ExamWidgetEntry.swift` / `ExamWidgetProvider.swift` / `ExamWidgetViews.swift`：考试小组件 S / M / L 三种尺寸。
  - `HRVWidget.swift`：HRV 准备度小组件。
  - `TrendWidget.swift`：科目成绩趋势折线图小组件。
  - `StudyTimerActivityAttributes.swift` + `StudyTimerLiveActivity.swift`：学习计时器 Live Activity（Lock Screen + Dynamic Island compact / minimal / expanded）。
  - `StudyPulseWidgetBundle.swift`：`@main` bundle，组合三个静态小组件 + Live Activity。
  - `en.lproj` / `zh-Hans.lproj` / `zh-Hant.lproj` / `ja.lproj` / `ko.lproj`：小组件各语言 Localizable.strings。
- `Packages/`：本地 / Vendored 包（`SwiftStreamingMarkdown-0.2.0/` 与 `Vendored/` 下的 `swift-cmark` / `swift-markdown` / `highlightswift` / `iosMath`）。
- `en.lproj/`、`zh-Hans.lproj/`、`zh-Hant.lproj/`、`ja.lproj/`、`ko.lproj/`：主应用各语言 Localizable.strings。
- `TestData/`：示例 CSV、`restore_sample_data.py` 还原脚本与生成数据。
- `scripts/build.sh`：构建辅助脚本。
- `README.md`、`AGENTS.md`、`docs/CODE_WIKI.md`、`docs/CODE_WIKI_CN.md`、`docs/AlgorithmIntroduction.md`、`docs/STREAK_ACHIEVEMENT_PLAN.md`、`docs/SPEC.md`、`docs/DESIGN.md`、`docs/USER_AGREEMENT.md`、`docs/FAQ.json`、`docs/CONTRIBUTING.json`：文档、协议与许可。
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

- `DataManager.asyncInit()` 在 `.task` 后台加载 JSON（含 `health_history.json`），主数据就绪前不写入 widget；`isReady == true` 后才执行 `HealthKitManager.bootstrap()` 与 `AchievementManager.bootstrap()`。
- `ImageCache` 使用 NSCache（最多 50 项、最大 300px），完全线程安全（nonisolated）。
- `AvatarView` / `WelcomeHeaderView` / `SettingsView` 的头像加载改为异步 Task，不再阻塞主线程。
- `HomeView` 采用分帧渲染（phased rendering），把首帧 long task 拆到多个 RunLoop 帧中绘制。
- `LagMonitor.shared` 持续监测主线程帧间隔，连续丢帧时把详细堆栈 / 时间戳写入 LogStore，便于事后通过 Export Log 复盘。
- iPad `HomeView` 使用 `LazyVGrid` 呈现仪表盘，保持内存占用低。
- `ModelContainerFactory` 仅在首次启动时执行一次 SwiftData 迁移（UserDefaults flag 记录），避免重复迁移 I/O。
- `StudyTimerLiveActivity` 通过 `ActivityKit` 在 Lock Screen / Dynamic Island 上呈现，所有像素由小组件扩展渲染，不增加主应用内存占用。

---

## 开发与贡献

- 代码编辑：Xcode（推荐）或任意支持 Swift / SwiftUI 的 IDE。
- 代码规范：
  - 模型为 `nonisolated value type`（Codable + Sendable），可安全跨 actor 传递；SwiftData 实体使用 `@Model final class`，由 toSnapshot() / init(from:) 双向映射。
  - 所有用户可见字符串使用 `StringsLocalized.swift` 中的 `.localized()` 扩展（小组件扩展内复制了一份同名扩展）。
  - 图片文件写入 `~/Documents/images/`，不要内联进 JSON（旧的 `Grade.image` 字段已在 `DataManager.asyncInit` 中迁移为文件）。
  - 视图层使用 `iPadLayout` 下的辅助组件实现 iPad 适配。
  - 状态管理器使用 `@MainActor`；纯 I/O 枚举（`DataFileIO` / `WidgetDataStore` / `EducationConfig` / `ImageCache` 等）为 `nonisolated`。
- 新增功能：按照 MVVM 模式组织，视图状态由 DataManager 驱动；涉及系统 API 的跨层调用，封装在 `Managers/` 下的单独文件中。
- 本地化：新增文案时，必须同步添加 en、zh-Hans、zh-Hant、ja、ko 五份 Localizable.strings 条目（主应用与小组件各 1 份，共 10 份）。
- 小组件：写入 widget 前确认 `dataManager.isReady == true`，避免在主数据加载完成前写入空数据。修改 `App Group` 名称后记得更新 `AppGroupConfig.identifier`。
- Live Activity：`StudyTimerLiveActivity` 依赖 `StudyTimerActivityAttributes`（`ActivityAttributes`），主应用通过 `ActivityKit` 启动 / 更新 / 结束；新增静态 / 动态字段时同步更新主应用与小组件两侧的 `ContentState`。
- SwiftData 迁移：新增 / 修改 `@Model` 实体字段时，必须同步更新 `ModelContainerFactory` 的迁移工具 + `toSnapshot()` / `init(from:)`，否则旧数据迁移后会丢字段。
- 文档：修改 `StudyReadinessAlgorithm` 评分规则必须同步更新 `docs/AlgorithmIntroduction.md`；修改「每日目标 / 连续天数 / 成就」规则必须同步更新 `docs/STREAK_ACHIEVEMENT_PLAN.md`。
- 切勿手工修改 `StudyPulse.xcodeproj/project.pbxproj` —— 让 Xcode 管理；新增 Swift 文件后在 Xcode 中 Add Files to StudyPulse... / 拖入项目即可。

---

## 开发者

- Gao-Chenkai
- Ken8891837

（两个账号均为 Gao Chenkai 本人使用）

---

## 许可

CC BY-NC-SA 4.0
