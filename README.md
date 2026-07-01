# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI 构建。
> 通过 HealthKit 多维身体信号（HRV / 心率 / 呼吸率 / 深睡+REM / 锻炼）给出个性化学习建议与趋势分析。

---

## 功能概览

StudyPulse 帮助学生管理学习过程中的核心数据：

- 成绩追踪：多科目成绩录入，支持自定义满分、原始分、排名、重要程度，以及成绩附件图片。
- 成绩可视化：交互式图表查看每门科目的趋势、平均分、最高/最低分；"需要关注的科目"智能提醒。
- 错题本：分 4 个区块（题目 / 错误原因 / 错误解法 / 正确解法），每区块可独立添加照片，并内置 OCR 文字识别与 Markdown 预览。支持**一键导出 PDF 错题集**：按科目 / 时间范围 / 具体错题三种方式筛选，默认包含图片；用 Core Text + NSAttributedString 渲染多页 A4 PDF，文字以矢量字体嵌入（可选 / 复制 / 搜索），含封面 + 目录 + 每题独立页。
- 考试管理：单科考试与综合考试的日程表，支持多日考试（examEndDate）与具体时间段（ExamTimeSlot），关联系统日历、添加本地提醒、关联错题。
- HRV 健康准备度：基于 Apple Watch 的 HRV（SDNN）数据，使用 14 天基线与 Z-score 评估当日学习状态，提供简洁 / 数据 / 图表三级展示。
- 多维身体信号：基于 HealthKit 的心率 / 呼吸率 / 深睡+REM / Apple 锻炼时长，结合 30 天个人基线合成 5 档学习强度 × 5 类学习重点的个性化建议；详见 `docs/AlgorithmIntroduction.md`。
- 可定制主页：卡片可启用 / 禁用、拖动重新排序，iPad 使用两栏网格，iPhone 使用单列。
- 全球教育系统：预置中国大陆、浙江、上海、台湾、香港、新加坡、UK (IGCSE / A-Level)、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等 15+ 种体系的科目与满分定义，并提供"智能推荐"一键套用。
- 多语言：英语、简体中文、繁體中文、日本語、한국（5 套完整本地化，主应用与小组件各 5 份 Localizable.strings）。
- 多主题：系统 / 浅色 / 深色三档。
- iPad 适配：侧栏 + 居中内容，使用 `iPadLayout` 下的 `AdaptiveHStack` / `AdaptiveGridColumns` / `adaptiveMaxWidth` / `adaptiveCardPadding` 等辅助组件，在大屏上充分利用空间。
- 小组件（WidgetKit）：三个小组件 —— ExamWidget（即将到来的考试）、TrendWidget（科目成绩趋势折线图）、HRVWidget（HRV 准备度），数据通过 App Group 容器与主应用同步。
- 数据管理：CSV 导入 / 导出，开发者工具页提供批量删除与数据统计；运行期日志可通过"Export Log"按钮导出，便于复现问题。
- 启动引导：版本感知的欢迎页（首次启动 → 欢迎页；版本号变化 → 新功能介绍页），原生 iOS 26 风格（TabView 分页 + 渐变背景 + 玻璃质感卡片）。

---

## 技术栈

- 平台：iOS 18.6+（iPhone 与 iPad）
- 语言：Swift 6.0
- 框架：SwiftUI、Swift Charts、Vision（OCR）、EventKit（日历）、HealthKit（HRV + 多维身体信号）、UserNotifications、UniformTypeIdentifiers、PhotosUI、WidgetKit
- 包管理器：Swift Package Manager
  - 本地包：swift-markdown-ui
  - 远程包：NetworkImage（gonzalezreal/NetworkImage @ 6.0.1）
  - 内建：cmark-gfm（Markdown 解析核心）
- 架构模式：MVVM，使用 `@EnvironmentObject` 暴露 DataManager / AppEnvironmentManager / HealthKitManager
- 数据持久化：所有业务模型以 JSON 存储在 `~/Documents/` 下，图片以独立文件保存在 `~/Documents/images/` 下，健康历史保存在 `~/Documents/health_history.json`；偏好设置与主页顺序保存在 UserDefaults；小组件数据保存在 App Group 容器
- 并发模型：Swift 6 Strict Concurrency，`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`；状态管理器使用 `@MainActor`，纯 I/O 枚举与 `ImageCache` 为 `nonisolated`
- 工程文件：`StudyPulse.xcodeproj`，含 StudyPulse 主应用 + StudyPulseWidgetExtension 小组件两个目标

---

## 目录结构

项目根目录下的主要文件和目录：

- `StudyPulse.xcodeproj`：Xcode 工程，含主应用 + 小组件两个目标。
- `StudyPulse/`：主应用源代码。
  - `StudyPulseApp.swift`：`@main` 入口，注册通知代理、启动 LagMonitor，以 `.task` 启动 `DataManager.asyncInit()` 与 `HealthKitManager.bootstrap()`，在 `scenePhase == .active` 时同步所有 widget。
  - `StudyPulse.entitlements` / `StudyPulseWidgetExtension.entitlements`：开启 HealthKit 与 App Group 权限。
  - `Models/`：数据模型，包括 `DataModels.swift`（Subject / Grade / MistakeNote / Exam / comprehensiveExam / UserProfile / ExamTimeSlot）、`AppPreferences.swift`（语言 + 主题）、`HomeLayoutPreference.swift`（主页卡片顺序与开关）、`HealthHistory.swift`（DailyHealthSnapshot，HRV / 心率 / 呼吸 / 深睡+REM / 锻炼的 30 天滚动窗口）。
  - `Managers/`：业务逻辑层。
    - `DataManager.swift`：中央状态管理器（@MainActor ObservableObject），管理 grades / subjects / mistakeSets / examSets / comprehensiveExamSets / profile，对外暴露 `isReady`。
    - `AppEnvironmentManager.swift`：全局语言与主题管理。
    - `AppStyle.swift`：设计系统骨架。
    - `CalendarManager.swift`：EventKit 集成，支持 startTime/endTime（nil 时回退为全天事件）。
    - `CSVDocument.swift` / `DataExportManager.swift`：CSV 导出。
    - `EducationConfig.swift`：全球教育体系静态配置。
    - `OCRManager.swift`：Vision 文本识别。
    - `ImageCache.swift`：NSCache 缩略图缓存（50 项 / 300px，nonisolated）。
    - `LagMonitor.swift`：主线程卡顿检测器（CADisplayLink 监测帧间隔）。
    - `Log.swift` / `LogDocument.swift`：统一日志层（os.Logger + LogStore 内存缓冲 5000 条 + .fileExporter 导出）。
    - `HealthHistoryStore.swift`：DailyHealthSnapshot 30 天滚动持久化（NSLock 线程安全）。
    - `HealthKitManager.swift`：HRV 准备度（14 天基线 + Z-score）+ BodyStatus（多维身体信号）+ PersonalBaselines（30 天个人基线）。
    - `StudyReadinessAlgorithm.swift`：多维学习准备度算法，5 强度 × 5 重点。
    - `WidgetDataSyncManager` / `HRVWidgetSyncManager` / `TrendWidgetSyncManager`：三个小组件的 App Group 同步。
    - `SubjectInfo.swift`：科目展示辅助。
  - `Views/`：UI 层。
    - `ContentView.swift`：根视图，iPhone 使用 TabView，iPad 使用 NavigationSplitView。
    - `HomeView.swift`：主页仪表盘，采用分帧渲染避免主线程长任务。
    - `TrendsView.swift` / `MistakeView.swift` / `ExamView.swift` / `SettingsView.swift`。
    - `PreferencesView.swift` / `HomeLayoutSettingsView.swift` / `HRVOnboardingView.swift`。
    - `AddGradeView.swift` / `NewExamSetView.swift` / `NewMistakeSetView.swift` / `ExamDetailView.swift` / `ExamDetailEditView.swift` / `MistakeDetailEditView.swift` / `SubjectScoreCard.swift`。
    - `AboutView.swift` / `CopyrightView.swift` / `EditSubjectsView.swift` / `ProfileEditView.swift`。
    - `Components/`：GradeChartView、HRVStatusCard、SectionHeader、SubjectPickerView。
    - `Helpers/`：AvatarView（异步加载）、ImagePicker、PhotoCaptureView、ScoreColor、ZoomableImageView、iPadLayout。
    - `Admin/`：DataAdminView（开发者工具页）。
    - `OnBoarding/`：OnboardingConfig、OnboardingView（原生气质卡片）、VersionedWelcomeModifier（版本感知欢迎页）。
    - `Settings/`：6 个聚焦子页 —— ProfileSettingsView / AppearanceSettingsView / HealthSettingsView / DataManagementSettingsView（含 Export Log 按钮）/ AboutSettingsView / QASettingsView，由 `SettingsCategory` 枚举驱动 5 段式导航。
  - `Extensions/`：`ColorExtensions.swift`、`DateExtensions.swift`。
  - `NotificationsControl/`：`ExamPrepareNotifications.swift`（本地通知调度）。
- `StudyPulseWidget/`：WidgetKit 小组件源码（目标已接入 StudyPulse.xcodeproj，scheme：StudyPulseWidgetExtension）。
  - `ExamWidget.swift` / `ExamWidgetEntry.swift` / `ExamWidgetProvider.swift` / `ExamWidgetViews.swift`：考试小组件 S / M / L 三种尺寸。
  - `HRVWidget.swift`：HRV 准备度小组件。
  - `TrendWidget.swift`：科目成绩趋势折线图小组件。
  - `StudyPulseWidgetBundle.swift`：`@main` bundle，组合三个小组件。
  - `en.lproj` / `zh-Hans.lproj` / `zh-Hant.lproj` / `ja.lproj` / `ko.lproj`：小组件各语言 Localizable.strings。
- `en.lproj/`、`zh-Hans.lproj/`、`zh-Hant.lproj/`、`ja.lproj/`、`ko.lproj/`：主应用各语言 Localizable.strings。
- `TestData/`：示例 CSV、`restore_sample_data.py` 还原脚本与生成数据。
- `scripts/build.sh`：构建辅助脚本。
- `README.md`、`AGENTS.md`、`docs/CODE_WIKI.md`、`docs/CODE_WIKI_CN.md`、`docs/AlgorithmIntroduction.md`、`docs/SPEC.md`、`docs/DESIGN.md`：文档与许可。
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
- `NSHealthShareUsageDescription`：读取 HRV / 心率 / 呼吸率 / 睡眠 / Apple 锻炼时间。
- `com.apple.developer.healthkit`：entitlements 开启 HealthKit 能力。
- `com.apple.security.application-groups`：App Group `group.com.chenkai.gao.studypulse`，主应用与小组件共享数据。

应用不向 HealthKit 写入数据（无 `NSHealthUpdateUsageDescription`）。

---

## 性能要点

- `DataManager.asyncInit()` 在 `.task` 后台加载 JSON（含 `health_history.json`），主数据就绪前不写入 widget；`isReady == true` 后才执行 `HealthKitManager.bootstrap()`。
- `ImageCache` 使用 NSCache（最多 50 项、最大 300px），完全线程安全（nonisolated）。
- `AvatarView` / `WelcomeHeaderView` / `SettingsView` 的头像加载改为异步 Task，不再阻塞主线程。
- `HomeView` 采用分帧渲染（phased rendering），把首帧 long task 拆到多个 RunLoop 帧中绘制。
- `LagMonitor.shared` 持续监测主线程帧间隔，连续丢帧时把详细堆栈 / 时间戳写入 LogStore，便于事后通过 Export Log 复盘。
- iPad `HomeView` 使用 `LazyVGrid` 呈现仪表盘，保持内存占用低。

---

## 开发与贡献

- 代码编辑：Xcode（推荐）或任意支持 Swift / SwiftUI 的 IDE。
- 代码规范：
  - 模型为 `nonisolated value type`（Codable + Sendable），可安全跨 actor 传递。
  - 所有用户可见字符串使用 `StringsLocalized.swift` 中的 `.localized()` 扩展。
  - 图片文件写入 `~/Documents/images/`，不要内联进 JSON（旧的 `Grade.image` 字段已在 `DataManager.asyncInit` 中迁移为文件）。
  - 视图层使用 `iPadLayout` 下的辅助组件实现 iPad 适配。
  - 状态管理器使用 `@MainActor`；纯 I/O 枚举（`DataFileIO` / `WidgetDataStore` / `EducationConfig` / `ImageCache` 等）为 `nonisolated`。
- 新增功能：按照 MVVM 模式组织，视图状态由 DataManager 驱动；涉及系统 API 的跨层调用，封装在 `Managers/` 下的单独文件中。
- 本地化：新增文案时，必须同步添加 en、zh-Hans、zh-Hant、ja、ko 五份 Localizable.strings 条目（主应用与小组件各 1 份，共 10 份）。
- 小组件：写入 widget 前确认 `dataManager.isReady == true`，避免在主数据加载完成前写入空数据。修改 `App Group` 名称后记得更新 `AppGroupConfig.identifier`。
- 文档：修改 `StudyReadinessAlgorithm` 评分规则必须同步更新 `docs/AlgorithmIntroduction.md`。
- 切勿手工修改 `StudyPulse.xcodeproj/project.pbxproj` —— 让 Xcode 管理；新增 Swift 文件后在 Xcode 中 Add Files to StudyPulse... / 拖入项目即可。

---

## 开发者

- Gao-Chenkai
- Ken8891837

（两个账号均为 Gao Chenkai 本人使用）

---

## 许可

CC BY-NC-SA 4.0
