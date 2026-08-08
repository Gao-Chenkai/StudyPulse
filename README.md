<img width="1920" height="1080" alt="StudyPulse-7ad0187版本海报 001" src="https://github.com/user-attachments/assets/55f089f6-9801-48bc-90b7-f0d8716ab14e" />

# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI + MVVM 构建。
> 通过 HealthKit 多维身体信号（HRV / 心率 / 呼吸率 / 深睡+REM / 锻炼）
> 与 Apple 学习场景（学习计时器 / 连续打卡 / 闪卡 SRS）给出个性化学习建议与趋势分析。
> 本项目也接受经过人工审核的 Codex 协作。

---

## [功能概览](https://gao-chenkai.github.io/StudyPulse/)

StudyPulse 帮助学生管理学习过程中的核心数据：

- AI Coach: AI Coach 是 StudyPulse 里的“长期学习教练”，核心不是简单聊天，而是围绕学习目标持续分析、规划和跟进。
它主要有四层能力：
1. 目标管理
   你可以设定目标、目标日期、涉及科目、当前分数、目标分数、每日可用学习时间、考试关联、个人目的和限制条件。目标修改后会保留版本历史。
2. 本地学习分析
   Coach 会综合分析：
   - 历史成绩与趋势
   - 错题数量、掌握度和复习记录
   - 学习任务与考试
   - 专注学习时长
   - HealthKit 的睡眠、HRV、心率、呼吸率、运动和准备度
   - 日记中的心情、精力，以及学习反思
   然后给出各科预测分数、置信区间、目标差距、成功概率、风险和支持证据，并判断应该继续当前目标、调整策略、目标不可行，还是数据不足。
3. AI 计划建议
   在本地分析完成后，BYOK 大模型会生成一份可审核的学习计划，包括：
   - 具体学习任务
   - 科目与开始时间
   - 学习目的
   - 重要程度
   - 完成条件
   - 不可行时的替代方案
   你可以逐项修改、选择、拒绝或确认。只有确认后，计划才会加入 Todo，不会自动改动现有任务。
4. 持续对话与执行追踪
   你可以进行目标关联对话，也可以创建独立聊天。Coach 不只回答问题，还能建议 Todo。任务完成情况会根据错题复习次数、掌握度、练习数量、知识点掌握或学习反思自动评估。
此外，它还支持：
   - 每日 Coach 通知
   - 后台刷新和任务重新评估
   - 目标历史与提案记录
   - 提案过期、目标版本校验，避免旧计划误用
   - 中英文、简体中文、繁体中文、日文和韩文输出
   - Siri / App Intent 直接打开指定目标
简单说，AI Coach 的工作流程是：
目标 → 本地数据分析 → AI 解释与规划 → 你审核 → Todo 执行 → 自动评估 → 下一轮调整
它需要在设置中单独开启 AI Coach，并配置有效的 BYOK 大模型；本地分析与 Todo 管理由应用自身控制，大模型主要负责解释、对话和生成建议。
<img width="201" height="437" alt="截屏 2026-07-22 00 16 13" src="https://github.com/user-attachments/assets/6656186f-c15b-4ff9-aceb-32c2ebbde765" />
<img width="201" height="437" alt="IMG_6107" src="https://github.com/user-attachments/assets/0ee34b97-feb6-49e8-a125-06be27ede284" />
<img width="201" height="437" alt="截屏 2026-07-22 00 25 27" src="https://github.com/user-attachments/assets/69ba3c04-cd48-4a29-8f67-0d46af1c0b3f" />
<img width="201" height="437" alt="截屏 2026-07-22 00 29 50" src="https://github.com/user-attachments/assets/b94ae1c9-9460-42dd-bd87-f692c2a29878" />


---


- 成绩追踪：多科目成绩录入，支持自定义满分、原始分、排名、重要程度，以及成绩附件图片。
- 成绩可视化：交互式图表查看每门科目的趋势、平均分、最高/最低分；"需要关注的科目"智能提醒；图表类型可在 `Settings → Chart Type` 中切换（折线 / 柱状 / 饼图 / 散点 / 热力 / 频数直方图）。
<img width="201" height="437" alt="截屏 2026-07-20 21 34 12" src="https://github.com/user-attachments/assets/72df2a52-cec8-496a-bafb-0dc2a40ce718" />
<img width="201" height="437" alt="截屏 2026-07-20 21 36 14" src="https://github.com/user-attachments/assets/311cd60e-b54b-4427-aeae-21a75bc01b04" />
<img width="201" height="437" alt="截屏 2026-07-20 21 37 15" src="https://github.com/user-attachments/assets/800fe466-f19c-462b-baea-0a218f4a791a" />
<img width="201" height="437" alt="截屏 2026-07-20 21 38 22" src="https://github.com/user-attachments/assets/54314134-f574-4200-a4de-b4509efedb35" />

- 错题本：分 4 个区块（题目 / 错误原因 / 错误解法 / 正确解法），每区块可独立添加照片，并内置 OCR 文字识别与 Markdown 预览。
  - **闪卡复习（SRS / SM-2）**：错题可入队复习队列，使用 SM-2 算法计算下次复习日期；提供 `FlashcardStudyView` / `FlashcardCardView` / `FlashcardSessionSummaryView` / `FlashcardCalculatorView` 与 `SRSReviewNotifications` 本地通知。
  - **一键导出 PDF 错题集**：按科目 / 时间范围 / 具体错题三种方式筛选，默认包含图片；用 Core Text + NSAttributedString 渲染多页 A4 PDF，文字以矢量字体嵌入（可选 / 复制 / 搜索），含封面 + 目录 + 每题独立页。
- 考试管理：单科考试与综合考试的日程表，支持多日考试（examEndDate）与具体时间段（ExamTimeSlot），关联系统日历、添加本地提醒、关联错题；`ExamDetailView` 包含考场信息（学校 / 教室 / 座位）、考前待办清单（`ExamChecklistItem`）、可定制的倒计时通知天数（默认 [1, 3, 5, 10, 30]）、复盘（ExamReview）与分享给家人按钮。
- 待办（Todo）：统一呈现日常作业 / 阅读材料 / 考试日程，含类型筛选（All / Exams / Homework / Reading）、时间分组（Within 1 Week / Within 1 Month / Later）、列表 / 日历切换、过期任务 sheet；可绑定系统 Reminders。
<img width="201" height="437" alt="截屏 2026-07-20 21 39 34" src="https://github.com/user-attachments/assets/7c4a54ee-74fe-4f3f-ba0c-2029c19f6e44" />

- HRV 健康准备度：基于 Apple Watch 的 HRV（SDNN）数据，使用 14 天基线与 Z-score 评估当日学习状态，提供简洁 / 数据 / 图表三级展示。
- 多维身体信号：基于 HealthKit 的心率 / 呼吸率 / 深睡+REM / Apple 锻炼时长，结合 30 天个人基线合成 5 档学习强度 × 5 类学习重点的个性化建议；详见 `docs/AlgorithmIntroduction.md`。
<img width="201" height="437" alt="截屏 2026-07-20 21 40 26" src="https://github.com/user-attachments/assets/bcd0b9d7-c48f-453c-8df2-9af0dffa1ae1" />
<img width="201" height="437" alt="截屏 2026-07-20 21 41 19" src="https://github.com/user-attachments/assets/37cf99e0-b91f-46e9-8368-12f5f03c7aae" />

- 学习计时器（Study Timer / Pomodoro）：5 档强度（Peak / Deep Focus / Steady / Light / Recovery）匹配 StudyReadinessAlgorithm 的建议强度，配套 Lock Screen + Dynamic Island Live Activity（`StudyTimerLiveActivity`）；完成的会话持久化为 `StudySession` 写入 `~/Documents/study_sessions.json`。
- 连续打卡 & 成就系统：每日的「错题复习 / 成绩录入 / 专注分钟」三目标驱动连续天数与里程碑徽章；主页新增 `StreakHomeCard`，设置里新增 `AchievementsView` / `DailyGoalsConfigView`；支持每日 20:00 晚间提醒（可在设置中关闭）。详见 `docs/STREAK_ACHIEVEMENT_PLAN.md`。
<img width="201" height="437" alt="截屏 2026-07-20 21 42 42" src="https://github.com/user-attachments/assets/9c10ac2c-588f-4264-99c3-5ce07be4ba67" />
<img width="201" height="437" alt="截屏 2026-07-20 21 43 20" src="https://github.com/user-attachments/assets/68cd8c85-9aed-48ee-bdfa-9f5492022a43" />

- 习惯洞察（HabitInsight）：基于 90 天 `StudySession` 由 `HabitInsightEngine.computeInsights(...)` 纯函数派生 4 类 PatternKind（peakEfficiency / procrastination / streakDay / weakDay）+ HourSlot 时段分布；定时通知在用户历史峰值时段前提示"今日最佳学习窗口"。
- AI 自测题（AIQuiz）：基于错题或科目由 `AIQuizLLM` 生成选择题 / 填空题（`QuizQuestion`，含 Markdown + LaTeX），用户作答后批改并解释错因；可一键把错题加入错题本。
- AI 相似题（AISimilarQuestion）：基于一道错题由 `AISimilarQuestionLLM` 生成 3~5 道相似题，用户作答后批改。
- AI 思维导图（AutoMindMap）：基于错题四块内容由 `AutoMindMapLLM` 输出节点 JSON，渲染为可折叠树。
- 错题辩论（MistakeDebate）：多轮对话引导学生反思错解，由 `AIDiscussionLLM` 驱动；首条 AI 输出用 `isInitialContext` 标记 + 视觉弱化，仅作为 system prompt 引用。


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
