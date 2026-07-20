# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI + MVVM 构建。
> 通过 HealthKit 多维身体信号（HRV / 心率 / 呼吸率 / 深睡+REM / 锻炼）
> 与 Apple 学习场景（学习计时器 / 连续打卡 / 闪卡 SRS）给出个性化学习建议与趋势分析。

---

## [功能概览](https://gao-chenkai.github.io/StudyPulse/)

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
- 学习日记 + 心情记录（Diary）：每日 Markdown 日记 + 5 档心情 emoji + 7 种精力标签（专注 / 平静 / 兴奋 / 疲惫 / 焦虑 / 烦躁 / 迷茫）；日历视图按日显示心情色块，30 天心情趋势折线图；首页快速入口卡片 + 可配置时间的晚间提醒通知。
- 周计划例程（Routines）：用户可创建"每日错题复习 21:00-22:00"等模板（mistakeReview / flashcard / general 三类，按 weekdays 重复）；`RoutineSpawner` 单例幂等物化当日 `RoutineInstance`（按 `routineId|yyyyMMdd` 去重）并自动清理 30 天前的 stale 实例；mistakeReview 类型 spawn 后启动 `RoutineActivityAttributes` Live Activity。
- 虚拟植物养成（Plant）：8 阶段状态机（seed → sprout → seedling → young → mature → flowering → flourishing → withered）；`PlantManager` 订阅 `AchievementManager.snapshot` 变化触发 `PlantStage.derive(...)` 纯函数重算；主页 Canvas 渲染当前阶段 + Spring 阶段切换动画；Debug 面板可强制覆盖 / 模拟 streak / 模拟断签天数。
- 主题商店（ThemeShop）：三类皮肤（`AccentPalette` 主色调色板 / `CardSkin` 卡片皮肤 / `TimerAnimation` 计时器动画），按 `AchievementDefinition.id` 解锁；商店内 `CardSkinRenderer` 预览皮肤效果；用户选中后写入 `AppPreferences`。
- 习惯洞察（HabitInsight）：基于 90 天 `StudySession` 由 `HabitInsightEngine.computeInsights(...)` 纯函数派生 4 类 PatternKind（peakEfficiency / procrastination / streakDay / weakDay）+ HourSlot 时段分布；定时通知在用户历史峰值时段前提示"今日最佳学习窗口"。
- AI 自测题（AIQuiz）：基于错题或科目由 `AIQuizLLM` 生成选择题 / 填空题（`QuizQuestion`，含 Markdown + LaTeX），用户作答后批改并解释错因；可一键把错题加入错题本。
- AI 相似题（AISimilarQuestion）：基于一道错题由 `AISimilarQuestionLLM` 生成 3~5 道相似题，用户作答后批改。
- AI 思维导图（AutoMindMap）：基于错题四块内容由 `AutoMindMapLLM` 输出节点 JSON，渲染为可折叠树。
- 错题辩论（MistakeDebate）：多轮对话引导学生反思错解，由 `AIDiscussionLLM` 驱动；首条 AI 输出用 `isInitialContext` 标记 + 视觉弱化，仅作为 system prompt 引用。
- 自定义主色：11 档预设调色板（system / blue / cyan / teal / green / mint / orange / red / pink / purple / indigo），在 `AppearanceSettingsView` 切换；通过 `effectiveAccentColor` 驱动 AccentColor、趋势图线/柱、闪卡进度条等。
- iOS 26 Liquid Glass 效果：设置中可全局开启（`glassEffectEnabled`），启用后若干卡片会改用 `Color.clear` + `glassEffect(in: Capsule())` 获得真实透明质感（老版本系统回退 `.regularMaterial`）。
- 自定义背景图：从相册选图后裁剪为 9:19.5 iPhone 屏幕比，写入 `Application Support/Backgrounds/bg_<uuid>.jpg`；`BackgroundImageView` 全屏 + 模糊 + 暗化遮罩铺在 `ContentView` 底部；为让图真正穿透，5 个主页面根使用 `Color(.systemGroupedBackground).opacity(0.4)`，`List` / `Form` 加 `.scrollContentBackground(.hidden)`。
- 错题语音备忘录（Audio）：编辑错题时录制 `.m4a` 语音备忘录（`AVAudioRecorder`），详情页内嵌 `AudioPlaybackView` 播放 / 删除；文件写入 `~/Documents/audio/<uuid>.m4a`。
- 全球教育系统：预置中国大陆、浙江、上海、台湾、香港、新加坡、UK (IGCSE / A-Level)、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等 15+ 种体系的科目与满分定义，并提供"智能推荐"一键套用。
- 多语言：英语、简体中文、繁體中文、日本語、한국（5 套完整本地化，主应用与小组件各 5 份 Localizable.strings）。
- 多主题：系统 / 浅色 / 深色三档。
- iPad 适配：侧栏 + 居中内容，使用 `iPadLayout` 下的 `AdaptiveHStack` / `AdaptiveGridColumns` / `adaptiveMaxWidth` / `adaptiveCardPadding` 等辅助组件，在大屏上充分利用空间。
- 小组件（WidgetKit）：四个小组件 —— ExamWidget（即将到来的考试）、TrendWidget（科目成绩趋势折线图）、HRVWidget（HRV 准备度）、StudyTimerLiveActivity（学习计时器 Lock Screen + Dynamic Island）；数据通过 App Group 容器与主应用同步。
- 数据管理：CSV 导入 / 导出，开发者工具页提供批量删除与数据统计；运行期日志可通过"Export Log"按钮导出，便于复现问题；底层使用 SwiftData 作为实体层（`Models/SwiftData/StudyPulseModels.swift` + `Managers/Core/ModelContainerFactory.swift`，12 个 `@Model` 实体），首次启动时自动从旧 JSON 迁移。
- 启动引导：版本感知的欢迎页（首次启动 → 欢迎页；版本号变化 → 新功能介绍页；同版本不显示），原生 iOS 26 风格（TabView 分页 + 渐变背景 + 玻璃质感卡片），可附加 6 页「基础信息填写」步骤。
- 用户协议：内置 `docs/USER_AGREEMENT.md` v1.0，设置页 → `UserAgreementView` 全文可读。
- 快捷指令（Siri Shortcuts）：`StudyPulseShortcuts` 提供 AddGrade / RecordMistake / CheckUpcomingExams / CheckBodyStatus / CheckReadiness / CheckSubjectAverage 六个 AppIntent，跨进程通过 `IntentActionStore` 把 action 桥接到 `ContentView`。
- 单元测试（StudyPulseTests）：`Infrastructure/` 共享 fixture + TestModelContainer / TestRepositoryContainer 工厂 + `TestDoubles/` 10 个 Mock Repository + Services / Algorithm 单元测试（DailyPlanEngine / DateFormatters / DifficultyTag / ExamFilter / MistakeFilter / PlantStageTransitions / QuoteProvider / RecoveryLevel / RepositoryContainer / SubjectAggregator / SuggestionEngine）。

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
  - 数据访问通过 10 个 Repository（`Repositories/Protocols/*Repository.swift` + `Default*Repository` 实现），由 `RepositoryContainer` 聚合（`@Observable @MainActor`）+ 3 个跨域编排子模块（`BulkOperationOrchestrator` / `TodoAggregator` / `PhaseFilterRefresher`）。ViewModel / View 通过 `@Environment(RepositoryContainer.self) var container` 注入。
  - 纯函数业务逻辑抽到 `Services/`（DateFormatters / SubjectAggregator / SuggestionEngine / ExamFilter / MistakeFilter / DailyPlanEngine / QuoteProvider），**不依赖 SwiftUI**，便于复用与测试。
- 数据持久化：
  - SwiftData 实体层（12 个 `@Model` 实体：`SubjectRecord` / `GradeRecord` / `MistakeNoteRecord` / `ExamRecord` / `ComprehensiveExamRecord` / `UserProfileRecord` / `TaskItemRecord` / `ReviewStateRecord` / `StudyPhaseRecord` / `PlantStateRecord` / `RoutineRecord` / `RoutineInstanceRecord` / `DiaryEntryRecord`）作为持久化后端，由 `ModelContainerFactory.makeContainer()` 启动时创建，`ModelContainerFactory.migrateFromJSONIfNeeded(context:)` 一次性从老 JSON 迁移。
  - 视图层使用 `nonisolated value type` 的 struct（`Subject` / `Grade` / `MistakeNote` / `Exam` / `comprehensiveExam` / `UserProfile` / `TaskItem` / `StudyPhase` / `PhaseGoal` / `ReviewState` / `Routine` / `RoutineInstance` / `DiaryEntry` / `QuizQuestion` / `HabitInsight` / `PlantStage` 等），由 `Repository.toSnapshot()` / `init(from:)` 与 SwiftData 实体互转。
  - 偏好设置、主页顺序、phase 激活、每日目标等保存在 UserDefaults；小组件数据保存在 App Group 容器。
- 并发模型：Swift 6 Strict Concurrency，`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`；`@Observable @MainActor` RepositoryContainer 持有 10 个 Repository；`nonisolated value-type` 模型可安全跨 actor 传递；纯 I/O 枚举与 `ImageCache` 为 `nonisolated`。
- 工程文件：`StudyPulse.xcodeproj`，含 StudyPulse 主应用 + StudyPulseWidgetExtension 小组件两个目标。

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

- `RepositoryContainer.asyncInit()` 在 `.task` 后台执行（JSON 迁移 + 10 repo 串行 `loadAll` + 内嵌图片迁移 + 通知 widget 调度 + `RoutineSpawner.runOnce()`），主数据就绪前不写入 widget；`isReady == true` 后才执行 `HealthKitManager.bootstrap()` / `AchievementManager.bootstrap()` / `PlantManager.bootstrap()`。
- `ImageCache` 使用 NSCache（最多 50 项、最大 300px），完全线程安全（nonisolated）。
- `AvatarView` / `WelcomeHeaderView` / `SettingsView` 的头像加载改为异步 Task，不再阻塞主线程。
- `HomeView` 采用分帧渲染（phased rendering），把首帧 long task 拆到多个 RunLoop 帧中绘制。
- `LagMonitor.shared` 持续监测主线程帧间隔，连续丢帧时把详细堆栈 / 时间戳写入 LogStore，便于事后通过 Export Log 复盘。
- iPad `HomeView` 使用 `LazyVGrid` 呈现仪表盘，保持内存占用低。
- `ModelContainerFactory` 仅在首次启动时执行一次 SwiftData 迁移（UserDefaults flag 记录），避免重复迁移 I/O。
- `StudyTimerLiveActivity` 通过 `ActivityKit` 在 Lock Screen / Dynamic Island 上呈现，所有像素由小组件扩展渲染，不增加主应用内存占用。
- `RepositoryContainer.observeActivePhaseChanges()` 用 0.5s polling 监测 `activePhaseId` 变化，避免引入 Combine 依赖；切换 phase 触发 6 个 `filtered*` 缓存重算（grade / mistake / exam / task / routine / diary）。
- `Services/` 是纯函数 enum，5 个 ViewModel 内部对 grade / mistake / exam 的过滤聚合全部走 `SubjectAggregator.aggregate` / `ExamFilter.examsWithinDays` 等共享服务，无重复实现。
- `PlantManager` 通过 `NotificationCenter` 监听 `achievementsSnapshotDidChange` 替代原 1.5s polling（每分钟 40 次 MainActor 唤醒），事件驱动完全足够。

---

## 开发者

- Gao-Chenkai
- Ken8891837

（两个账号均为 Gao Chenkai 本人使用）

---

## 许可

CC BY-NC-SA 4.0
