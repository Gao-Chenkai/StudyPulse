# StudyPulse

> 一个支持全球教育体系的 iOS 学业管理应用，使用 SwiftUI 构建。

---

## 功能概览

StudyPulse 帮助学生管理学习过程中的核心数据：

- 成绩追踪：多科目成绩录入，支持自定义满分、原始分、排名、重要程度，以及成绩附件图片。
- 成绩可视化：交互式图表查看每门科目的趋势、平均分、最高/最低分；"需要关注的科目"智能提醒。
- 错题本：分 4 个区块（题目 / 错误原因 / 错误解法 / 正确解法），每区块可独立添加照片，并内置 OCR 文字识别与 Markdown 预览。
- 考试管理：单科考试与综合考试的日程表，关联系统日历，添加本地提醒，关联错题。
- HRV 健康准备度：基于 Apple Watch 的 HRV（SDNN）数据，使用 14 天基线与 Z-score 评估当日学习状态，提供简洁 / 数据 / 图表三级展示。
- 可定制主页：卡片可启用 / 禁用、拖动重新排序，iPad 使用两栏网格，iPhone 使用单列。
- 全球教育系统：预置中国大陆、浙江、上海、台湾、香港、新加坡、UK (IGCSE / A-Level)、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等 15+ 种体系的科目与满分定义，并提供"智能推荐"一键套用。
- 多语言：英语、简体中文、繁體中文、日本語、한국，跟随系统或手动切换。
- 多主题：系统 / 浅色 / 深色三档。
- iPad 适配：侧栏 + 居中内容，使用 AdaptiveHStack / AdaptiveGridColumns / adaptiveMaxWidth / adaptiveCardPadding 等辅助组件，在大屏上充分利用空间。
- 小组件（WidgetKit）：主屏展示即将到来的考试，数据通过 App Group 容器与主应用同步。
- 数据管理：CSV 导入 / 导出，开发者工具页提供批量删除与数据统计。

---

## 技术栈

- 平台：iOS 18.6+（iPhone 与 iPad）
- 语言：Swift 6.0
- 框架：SwiftUI、Swift Charts、Vision（OCR）、EventKit（日历）、HealthKit（HRV）、UserNotifications、UniformTypeIdentifiers、PhotosUI、WidgetKit
- 包管理器：Swift Package Manager，本地导入 WSOnBoarding / swift-markdown-ui，依赖 NetworkImage
- 架构模式：MVVM，使用 @EnvironmentObject 暴露 DataManager / AppEnvironmentManager / HealthKitManager
- 数据持久化：所有业务模型以 JSON 存储在 ~/Documents/ 下，图片以独立文件保存在 ~/Documents/images/ 下
- 并发模型：Swift 6 Strict Concurrency，SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor；状态管理器使用 @MainActor，纯 I/O 枚举为 nonisolated
- 工程文件：StudyPulse.xcodeproj，单目标主应用，另附 WidgetKit 源（待接入 Xcode 目标）

---

## 目录结构

项目根目录下的主要文件和目录：

- StudyPulse.xcodeproj：Xcode 工程。
- StudyPulse/：主应用源代码。
  - StudyPulseApp.swift：@main 入口，通知授权与任务启动。
  - Models/：数据模型，包括 DataModels.swift（Subject / Grade / MistakeNote / Exam / comprehensiveExam / UserProfile）、AppPreferences.swift（语言 + 主题）、HomeLayoutPreference.swift（主页卡片顺序与开关）。
  - Managers/：业务逻辑层，包括 DataManager（中央状态与持久化）、AppEnvironmentManager（语言 / 主题）、HealthKitManager（HRV 准备度）、EducationConfig（全球教育体系配置）、CalendarManager（日历）、OCRManager（Vision OCR）、ImageCache（NSCache 缩略图）、WidgetDataSyncManager（App Group 同步）、SubjectInfo（科目展示辅助）、AppStyle（设计系统骨架）、DataExportManager（CSV）、ExamWidgetData（小组件数据模型）。
  - Views/：UI 层，包括 ContentView（TabView + iPad 侧栏）、HomeView、TrendsView、MistakeView、ExamView、SettingsView、PreferencesView、HomeLayoutSettingsView、HRVOnboardingView、AddGradeView、NewExamSetView、NewMistakeSetView、ExamDetailView、ExamDetailEditView、MistakeDetailEditView、SubjectScoreCard；以及子目录 Components/、Helpers/（AvatarView、ImagePicker、PhotoCaptureView、ScoreColor、ZoomableImageView、iPadLayout）、Admin/、OnBoarding/。
  - Extensions/：ColorExtensions.swift、DateExtensions.swift。
  - NotificationsControl/：ExamPrepareNotifications.swift（本地通知调度）。
- StudyPulseWidget/：WidgetKit 小组件源（ExamWidget、ExamWidgetData、ExamWidgetEntry、ExamWidgetProvider、ExamWidgetViews、StudyPulseWidgetBundle）。
- en.lproj/、zh-Hans.lproj/、zh-Hant.lproj/、ja.lproj/、ko.lproj/：各语言 Localizable.strings。
- scripts/build.sh：构建辅助脚本。
- README.md、AGENTS.md、CODE_WIKI.md、CODE_WIKI_CN.md：文档。
- LICENSE：CC BY-NC-SA 4.0。

---

## 构建与运行

前置条件：

- macOS 15.0+
- Xcode 26.x（推荐 26.3 或更高）
- iOS 部署目标 18.6+
- Swift 6.0

推荐方式：在 Xcode 中打开 StudyPulse.xcodeproj，解析 SPM 包（File → Packages → Resolve Package Versions），选择模拟器或真机后按 Cmd+R 运行。

命令行方式（使用 scripts/build.sh）：

- 调试构建：./scripts/build.sh
- 发布构建：./scripts/build.sh release
- 清理：./scripts/build.sh clean
- 列出可用模拟器：./scripts/build.sh list

直接使用 xcodebuild：

```bash
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

---

## 开发与贡献

- 代码编辑：Xcode（推荐）或任意支持 Swift / SwiftUI 的 IDE。
- 代码规范：模型为 nonisolated value type（Codable + Sendable）；所有用户可见字符串使用 StringsLocalized.swift 中的 .localized() 扩展；图片文件写入 ~/Documents/images/，不要内联进 JSON；视图层使用 iPadLayout 下的辅助组件实现 iPad 适配。
- 新增功能：按照 MVVM 模式组织，视图状态由 DataManager 驱动；涉及系统 API 的跨层调用，封装在 Managers/ 下的单独文件中。
- 本地化：新增文案时，必须同步添加 en、zh-Hans、zh-Hant、ja、ko 五份 Localizable.strings 条目。

---

## 开发者

- Gao-Chenkai
- Ken8891837

（两个账号均为 Gao Chenkai 本人使用）

---

## 许可

CC BY-NC-SA 4.0
