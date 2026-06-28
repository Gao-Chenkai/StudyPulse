# StudyPulse — AI Agent Guide

> 一份面向 AI 代理的完整开发指南。
> 本文件仅使用纯文本和代码块描述架构，不使用任何表格或 ASCII 流程图。

---

## 1. 项目速览

StudyPulse 是一个使用 SwiftUI 构建的 iOS 学业管理应用，帮助学生
追踪成绩、管理错题、规划考试、与 HealthKit 同步 HRV / 多维身体信号
（心率 / 呼吸率 / 深睡+REM / 锻炼）并给出个性化学习建议与趋势分析。
支持多种全球教育体系（中国大陆、浙江、上海、台湾、香港、新加坡、UK IGCSE 与 A-Level、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等）。

平台：iOS 18.6+，同时支持 iPhone 与 iPad。
语言：Swift 6.0。
架构：MVVM 与 @EnvironmentObject，通过 ObservableObject 向视图层注入 DataManager。
并发：Swift 6 Strict Concurrency，默认 Actor 隔离为 MainActor。
构建：Xcode 26.x。
依赖：本地包 WSOnBoarding、swift-markdown-ui；远程包 NetworkImage（GitHub）；内建 cmark-gfm。
存储：业务模型序列化为 JSON 文件保存在 ~/Documents/；图片以独立文件保存在 ~/Documents/images/；偏好设置与主页顺序保存在 UserDefaults；健康历史保存在 ~/Documents/health_history.json。
应用组：group.com.chenkai.gao.studypulse，用于小组件数据同步。
本地化：English、简体中文、繁體中文、日本語、한국（主应用与小组件各自维护五份 Localizable.strings）。
图表：SwiftUI Charts。
OCR：Vision 框架 VNRecognizeTextRequest。
日历：EventKit（支持具体时间段或全天事件）。
健康：HealthKit HRV（SDNN）+ BodyStatus（心率 / 呼吸率 / 睡眠 / 锻炼）。
小组件：WidgetKit 三个小组件（ExamWidget / TrendWidget / HRVWidget），已接入 StudyPulse.xcodeproj。
工程文件：StudyPulse.xcodeproj（含 StudyPulse + StudyPulseWidgetExtension 两个目标）。
基础设施：统一日志层（os.Logger + LogStore 内存缓冲 + LogDocument 导出）；主线程卡顿监测（LagMonitor）。

---

## 2. 仓库布局

仓库根目录包含以下核心内容：

- StudyPulse.xcodeproj：Xcode 工程，含 StudyPulse 主应用 + StudyPulseWidgetExtension 小组件两个目标。
- StudyPulse/：主应用源代码目录。
  - StudyPulseApp.swift：@main 入口，注册通知代理、启动 LagMonitor、以 .task 启动 DataManager.asyncInit() 与 HealthKitManager.bootstrap()，在 scenePhase == .active 时同步所有 widget。
  - StudyPulse.entitlements：开启 com.apple.developer.healthkit 与 App Groups 权限。
  - StudyPulseWidgetExtension.entitlements：小组件目标 entitlements（App Groups + WidgetKit）。
  - Assets.xcassets：AccentColor、AppIcon、StudyPulseIcon（含 SVG 源图）。
  - Models/：数据模型定义。
    - DataModels.swift：Subject、Grade、MistakeNote、Exam、comprehensiveExam、UserProfile、ExamTimeSlot（考试时间段），以及教育系统相关枚举与结构（EducationStage、EducationCategory、SubjectConfig、EducationRegion）。
    - AppPreferences.swift：应用偏好（语言与色彩方案）。
    - HomeLayoutPreference.swift：主页卡片顺序与启用标记（按名称顺序存储，持久化到 UserDefaults）。
    - HealthHistory.swift：DailyHealthSnapshot 单日身体信号聚合（HRV、静息心率、呼吸频率、总睡眠 / 深睡 / REM、Apple 锻炼时长），由 HealthHistoryStore 持久化为个人 30 天基线。
  - Managers/：业务逻辑层。
    - DataManager.swift：@MainActor ObservableObject，中央状态管理器。管理 grades、subjects、mistakeSets、examSets、comprehensiveExamSets、profile、isReady 等 @Published 属性，提供 asyncInit() 与各 save/loadAsync/load 方法。
    - AppEnvironmentManager.swift：全局语言与主题管理。
    - AppStyle.swift：应用设计系统骨架。
    - CalendarManager.swift：EventKit 集成，支持 startTime/endTime（nil 时回退为全天事件）。
    - CSVDocument.swift：FileDocument 包装 CSV 导出文件。
    - DataExportManager.swift：CSV 导出（@MainActor enum）。
    - EducationConfig.swift：全球教育体系静态配置（nonisolated enum）。
    - ExamWidgetData.swift：考试小组件数据模型、AppGroupConfig、WidgetDataStore（App Group 读写）。
    - HRVWidgetData.swift / HRVWidgetSyncManager.swift：HRV 小组件数据与同步。
    - TrendWidgetData.swift / TrendWidgetSyncManager.swift：科目成绩趋势小组件数据与同步。
    - WidgetDataSyncManager.swift：考试小组件 App Group 同步。
    - HealthHistoryStore.swift：DailyHealthSnapshot 的 30 天滚动持久化（~/Documents/health_history.json），NSLock 线程安全。
    - HealthKitManager.swift：HRV（SDNN）准备度、14 天基线、日级历史、BodyStatus（心率 / 呼吸率 / 睡眠 / 锻炼）、PersonalBaselines 30 天个人基线。
    - ImageCache.swift：nonisolated class，NSCache + 缩略图，单例 50 条缓存。
    - LagMonitor.swift：主线程卡顿检测器，CADisplayLink 监测帧间隔（连续丢帧超阈值写入 LogStore）。
    - Log.swift：LogLevel、LogEntry、LogStore（线程安全 NSLock，5000 条上限，超出丢最早条目）；提供 Log.app / Log.widget / Log.notification / Log.ui 等 subsystem category，以及 Log.record(_:category:message:) 同时写 os.Logger 与 LogStore。
    - LogDocument.swift：FileDocument 包装内存日志，供 .fileExporter 导出。
    - OCRManager.swift：Vision 文本识别。
    - StudyReadinessAlgorithm.swift：多维学习准备度算法，HRV + 睡眠 + 心率 + 呼吸 + 锻炼打分合成 5 档强度 × 5 类重点建议；详细说明见 docs/AlgorithmIntroduction.md。
    - StringsLocalized.swift：字符串本地化扩展 .localized()。
    - SubjectInfo.swift：展示名称与颜色、满分回退。
  - Views/：SwiftUI 视图。
    - ContentView.swift：根视图，iPhone 使用 TabView（5 个标签），iPad 使用自定义 NavigationSplitView 侧栏。
    - HomeView.swift：主页仪表盘（欢迎头、统计卡、动态卡片、每日金句、图表、即将到来的考试、近期成绩）。主页加载采用分帧渲染，将卡片拆分到多个 RunLoop 帧中绘制，避免主线程长任务卡顿。
    - TrendsView.swift：趋势分析（每科目趋势与需要关注的科目）。
    - MistakeView.swift：错题列表（建议复习、搜索、卡片布局）。
    - ExamView.swift：考试列表（单科与综合考试）。
    - SettingsView.swift：设置根视图，按 SettingsCategory 拆为 5 段式导航（Profile / Appearance / Health / Data / About / FAQ，详见 §5）。
    - PreferencesView.swift：语言与外观。
    - HomeLayoutSettingsView.swift：主页卡片重新排序与开关。
    - HRVOnboardingView.swift：HRV 介绍、隐私与授权三页。
    - AddGradeView.swift：添加成绩模态。
    - NewExamSetView.swift：新增 / 编辑考试（单科或综合），支持多日考试（examEndDate）与具体时间段（ExamTimeSlot）。
    - NewMistakeSetView.swift：新增错题（带照片与 OCR）。
    - ExamDetailView.swift：单科考试详情（关联错题）。
    - ExamDetailEditView.swift：编辑考试。
    - MistakeDetailEditView.swift：四块错题编辑（每块独立照片 + OCR + Markdown 预览）。
    - SubjectScoreCard.swift：可复用的科目成绩卡。
    - AboutView.swift：应用信息页。
    - CopyrightView.swift：版权许可页。
    - EditSubjectsView.swift：每科目满分自定义（NavigationLink push，由 ProfileSettingsView 进入）。
    - ProfileEditView.swift：编辑用户资料（学校、年级、班级、学号、入学年、考试年、目标学校、目标分数）。
    - Components/：组件目录（GradeChartView、HRVStatusCard、SectionHeader、SubjectPickerView）。
    - Helpers/：视图辅助（AvatarView、ImagePicker、PhotoCaptureView、ScoreColor、ZoomableImageView、iPadLayout）。AvatarView 与头像相关加载已切换为异步，避免阻塞主线程。
    - Admin/：开发者页面（DataAdminView）。
    - OnBoarding/：启动引导（WelcomeConfig、VersionedWelcomeModifier —— 版本感知欢迎页 / 新功能介绍页）。
    - Settings/：将原 SettingsView 拆分为 6 个聚焦子页：ProfileSettingsView、AppearanceSettingsView、HealthSettingsView、DataManagementSettingsView（含 Export Log 按钮）、AboutSettingsView、QASettingsView，SettingsCategory 枚举提供 5 段式导航标识。
  - Extensions/：ColorExtensions.swift、DateExtensions.swift。
  - NotificationsControl/：ExamPrepareNotifications.swift（本地通知）。
- StudyPulseWidget/：WidgetKit 小组件源码（目标已接入 StudyPulse.xcodeproj，scheme：StudyPulseWidgetExtension）。
  - ExamWidget.swift：即将到来的考试小组件。
  - ExamWidgetData.swift：ExamWidget 共享数据模型。
  - ExamWidgetEntry.swift / ExamWidgetProvider.swift / ExamWidgetViews.swift：时间轴条目、提供者、S / M / L 三种尺寸视图。
  - HRVWidget.swift / HRVWidgetData.swift：HRV 准备度小组件，样式与 HomeView HRVStatusCard 一致。
  - TrendWidget.swift / TrendWidgetData.swift：科目成绩趋势折线图小组件，样式与 HomeView GradeChartView 一致。
  - StudyPulseWidgetBundle.swift：@main bundle，组合 ExamWidget + TrendWidget + HRVWidget。
  - Info.plist：小组件 Info.plist。
  - Assets.xcassets：AccentColor、AppIcon、WidgetBackground。
  - en.lproj / zh-Hans.lproj / zh-Hant.lproj / ja.lproj / ko.lproj：小组件本地化字符串。
- TestData/：示例 CSV、restore_sample_data.py 还原脚本与生成数据。
- en.lproj、zh-Hans.lproj、zh-Hant.lproj、ja.lproj、ko.lproj：主应用各语言本地化字符串。
- AGENTS.md / docs/CODE_WIKI.md / docs/CODE_WIKI_CN.md / README.md / docs/AlgorithmIntroduction.md / docs/SPEC.md / docs/DESIGN.md / LICENSE：文档与许可（docs/AlgorithmIntroduction.md 专门解释 StudyReadinessAlgorithm 的输入 / 评分 / 决策）。
- scripts/build.sh：构建辅助脚本。

---

## 3. 架构说明

应用遵循 MVVM 模式，通过 @EnvironmentObject 在视图层注入 DataManager、AppEnvironmentManager 与 HealthKitManager。视图层负责展示与用户交互，业务逻辑层集中在 Managers/下的管理器，数据层为 Codable 的 value type。数据流从视图触发 DataManager.save*()，DataManager 将变更发布到 @Published 属性，触发 SwiftUI 重渲染；同时写入 ~/Documents/{file}.json。涉及考试的写入还会通过 WidgetDataSyncManager 同步到 App Group；涉及成绩趋势通过 TrendWidgetSyncManager 同步；涉及 HRV / 准备度通过 HRVWidgetSyncManager 同步。

辅助基础设施：
- 日志：Log.swift 提供 Log.app / Log.widget / Log.notification / Log.ui 等 os.Logger subsystem 与全局 LogStore 内存缓冲（5000 条上限，NSLock 线程安全）。所有 Manager / View 生命周期事件调用 Log.record(_:category:message:) 写入 os.Logger 与 LogStore。LogDocument 把 LogStore 序列化为文本供 .fileExporter 导出。
- 卡顿监控：LagMonitor.shared 通过 CADisplayLink 监测主线程帧间隔，连续丢帧超过阈值时记录到 LogStore，便于事后导出诊断。
- 启动顺序：StudyPulseApp.init() 注册通知代理、启动 LagMonitor；.task 中先 await dataManager.asyncInit()，主数据就绪后再 await hrvManager.bootstrap() 避免启动期 I/O 竞争；scenePhase == .active 且 dataManager.isReady 时同步所有 widget 并刷新 BodyStatus。

视图层目录：
- 根视图使用 ContentView。iPhone 以 TabView 五标签呈现 HomeView、TrendsView、MistakeView、ExamView、SettingsView；iPad 以自定义 NavigationSplitView 呈现侧栏 + 详情，保持 iPhone 布局不变而内容居中。HomeView 动态卡片由 HomeLayoutPreference 的启用顺序渲染，iPad 使用两栏 LazyVGrid，iPhone 使用单列 VStack。模态面板为 AddGradeView、NewExamSetView、NewMistakeSetView、MistakeDetailEditView、ExamDetailEditView、HRVOnboardingView、HomeLayoutSettingsView、DataAdminView，通过 .sheet 或 .navigationDestination 展示。

业务 / 服务层目录：
- DataManager（@MainActor ObservableObject）集中保存并对外暴露 grades / subjects / mistakeSets / examSets / comprehensiveExamSets / profile；提供 asyncInit()、save*()、load*Async() 与 saveGradeImage() / loadGradeImage() / deleteGradeImage()、saveAvatar() / loadAvatar() / deleteAvatar()，以及 fullScore(for:)、displayName(for:)、applySmartSubjectRecommendation(stage:regionCode:)。
- AppEnvironmentManager（@MainActor ObservableObject 单例）持有 AppPreferences，并提供 effectiveColorScheme、setLanguage、setColorScheme 等计算属性与方法。
- HealthKitManager（@MainActor ObservableObject 单例）持有 HRVReadiness（Z-score、分类、建议）、dailyHRVHistory、lastSampleCount、hrvDetailLevel、BodyStatus（心率 / 呼吸率 / 睡眠 / 锻炼）、PersonalBaselines 30 天个人基线、bodyStatusAuthorized、isReady；负责 enable() / disable() / refreshReadiness() / refreshBodyStatus() / bootstrap()。StudyReadinessAlgorithm 在 HRV 之外把多维身体信号（深睡 + REM、锻炼、心率、呼吸）归一化打分，合成 5 档强度 × 5 类重点建议，详见 docs/AlgorithmIntroduction.md。
- CalendarManager：EventKit 单例，负责添加考试到系统日历；addExamToCalendar 接受可选 startTime/endTime（nil 时回退为全天事件）。
- OCRManager：Vision 文本识别（recognitionLanguages = ["zh-Hans", "en"]）。
- ImageCache：nonisolated class，单例 NSCache 50 项、300px 缩略图。
- EducationConfig：nonisolated enum，提供全球教育系统配置。
- SubjectInfo：科目显示辅助。
- WidgetDataSyncManager / HRVWidgetSyncManager / TrendWidgetSyncManager：App Group 同步，分别对应考试、HRV、成绩趋势三个小组件。
- Log / LogStore / LogDocument：统一日志层（见上文「辅助基础设施」）。
- LagMonitor：主线程卡顿检测器（见上文「辅助基础设施」）。
- HealthHistoryStore：DailyHealthSnapshot 的 30 天滚动持久化（~/Documents/health_history.json），NSLock 线程安全。

数据层目录：
- 模型为 nonisolated value type，Codable 与 Sendable，可无 ceremony 跨 actor 传递。Subject、Grade、MistakeNote、Exam、comprehensiveExam、ExamTimeSlot、UserProfile、AppPreferences、HomeLayoutPreference、HealthHistory（DailyHealthSnapshot）。
- 持久化层写入 ~/Documents/ 下的对应 JSON；图片以 grade_UUID.jpg 写入 ~/Documents/images/；头像写入 avatar_UUID.jpg；健康历史以 health_history.json 保存。UserDefaults 保存 AppPreferences、HomeLayoutPreference、hrv 相关偏好、lastSeenAppVersion（版本感知欢迎页使用）；App Group 容器保存 widgetUpcomingExams、HRVWidgetData、TrendWidgetData。

扩展与通知目录：
- ColorExtensions、DateExtensions、StringsLocalized 提供跨层使用的辅助；ExamPrepareNotifications 使用 UNUserNotificationCenter 调度本地通知，默认提醒天数 [1, 3, 5, 10, 30]。

---

## 4. 模块依赖关系

模块依赖顺序为：视图层依赖 DataManager（通过 @EnvironmentObject 注入），DataManager 再依赖辅助管理器与模型；模型本身不依赖其它层。

视图层到 DataManager 的调用示例：
- HomeView、TrendsView、MistakeView、ExamView、SettingsView 通过 @EnvironmentObject 读写 DataManager。
- DataManager 通过 CalendarManager / OCRManager / ImageCache / EducationConfig / SubjectInfo / WidgetDataSyncManager / HealthHistoryStore / HealthKitManager / Log 等辅助组件。
- HealthKitManager 通过 HealthHistoryStore 维护 30 天个人基线，并通过 StudyReadinessAlgorithm 把多维身体信号合成为学习建议。
- StudyPulseApp 在合适时机调用 WidgetDataSyncManager / HRVWidgetSyncManager / TrendWidgetSyncManager 把数据写入 App Group；Log.record() / LagMonitor 共享 LogStore。
- 辅助组件不反向调用视图层。
- 所有辅助组件与视图层解耦，便于单独测试。

小组件（StudyPulseWidgetExtension）通过 App Group 容器读取主应用写入的 ExamWidgetData / HRVWidgetData / TrendWidgetData 数据，自身不依赖 DataManager，依赖链不跨越进程边界。

---

## 5. 导航流程

应用入口在 StudyPulseApp：
- 设置 NotificationCoordinator 作为 UNUserNotificationCenter delegate，点击通知时清除角标。
- 请求通知授权。
- 启动 LagMonitor.shared 监测主线程帧间隔。
- 调用 AppEnvironmentManager.shared.applyLanguageOnLaunch() 恢复语言设置。
- 使用 .task 先 await dataManager.asyncInit()，主数据就绪后（isReady = true）再 await hrvManager.bootstrap()，避免启动期 I/O 竞争。
- 监听 scenePhase == .active：当 dataManager.isReady == true 时同步 ExamWidget / TrendWidget / HRVWidget 并调用 hrvManager.refreshBodyStatus()。

ContentView 根据水平 size class 判定设备：
- iPhone：TabView 五个标签（Home / Trends / Mistakes / Exams / Settings）。
- iPad：NavigationSplitView，列表项目与 iPhone 五标签一致。

HomeView：
- 快速动作按钮打开 AddGradeView、NewExamSetView、NewMistakeSetView。
- HRV 状态卡首次出现时会启动 HRVOnboardingView。
- 未注册考试提醒卡引导到 AddGradeView。
- 即将到来的考试引导到 ExamDetailView。

TrendsView：
- 点击科目进入 per-subject 详情。

MistakeView：
- 新建错题进入 MistakeDetailEditView。
- 已有错题进入 MistakeDetailEditView（编辑模式）。

ExamView：
- 点击 + 按钮进入 NewExamSetView。
- 点击考试进入 ExamDetailView。
- ExamDetailView 中编辑按钮进入 ExamDetailEditView。
- ExamDetailView 可跳转关联的 MistakeDetailEditView。

SettingsView：
新版采用 5 段式 NavigationLink 导航 + 6 个聚焦子页，SettingsCategory 枚举标识每一段（appearance / health / data / about / faq）：
1. Profile：ProfileSettingsView（头像卡片 + Edit Subjects + 跳转 ProfileEditView）。
2. Appearance & Layout：AppearanceSettingsView（语言 / 主题）+ HomeLayoutSettingsView（主页卡片顺序与开关）。
3. Health & Readiness：HealthSettingsView（HRV 开关与详细介绍链接，弱化引导）。
4. Data Management：DataManagementSettingsView（CSV 导出 / 还原示例数据 / Developer Admin / 导出日志 Export Log）。
5. About：AboutSettingsView（关于 + 版权 + Test Notifications）。
6. FAQ：QASettingsView（高频问题）。

---

## 6. 数据层说明

DataManager 为 @MainActor ObservableObject，作为视图层的 @EnvironmentObject 被注入。
@Published 属性包括 grades、subjects、mistakeSets、examSets、comprehensiveExamSets，外加 profile、isReady（主数据加载完成时为 true）与辅助属性。
生命周期方法包括 init()（同步加载，为向后兼容保留）、asyncInit()（Task.detached 在后台线程加载，通过 MainActor.run 回主线程，同时迁移 Grade.image 内联数据为独立文件）。asyncInit 完成后 isReady 置 true，scenePhase 监听者据此避免写入空 widget 数据。
持久化时，各模型写入 ~/Documents/ 下单独文件，各模型对应 JSON；图片（成绩与头像）写入 ~/Documents/images/ 目录；健康历史写入 ~/Documents/health_history.json；Widget 数据通过 WidgetDataSyncManager / HRVWidgetSyncManager / TrendWidgetSyncManager 写入 App Group。

DataFileIO 为 nonisolated enum，负责 getDocsDir()、getImagesDir()、load<T: Codable>(url:) 等纯 I/O 方法。imagesDir 路径用 NSLock 缓存以避免重复 stat。

图像文件命名：
- 成绩快照：images/grade_UUID.jpg。
- 头像：images/avatar_UUID.jpg。

持久化数据流：
- 应用启动：StudyPulseApp 在 .task 中调用 dataManager.asyncInit()。asyncInit 内部在后台 Task.detached（优先级 .userInitiated）并行加载 profile.json、grades.json、mistakes.json、exams.json、comprehensiveExams.json、subjects.json、health_history.json。回到主 Actor 后把结果分配给 @Published 并初始化默认科目。完成后 isReady = true，触发 HealthKitManager.bootstrap()。
- 用户编辑：视图调用 DataManager.save()，序列化写入文件并同步更新 @Published 变更触发 SwiftUI 重渲染。如果 save 涉及考试，还会调用 WidgetDataSyncManager.syncExamsToWidget() 触发 WidgetKit reloadTimelines。成绩变更通过 TrendWidgetSyncManager.syncTrend(...) 同步；HRV 状态由 HRVWidgetSyncManager.syncHRV(from:) 在 scenePhase == .active 时拉取。

核心模型说明：
- Subject：name、displayName、enabled、fullScore。
- Grade：subject、score、rawScore?、ranking?、importance（1..5）、image?（legacy 字段）、imageFileName?、date、examName、fullScore?。
- MistakeNote：title、subject、originalQuestion、source、date、errorReason、wrongSolution、correctSolution，以及每区块的文件名数组。
- Exam：name、examDate、examEndDate?（多日考试，nil 表示单日）、importance、subject、examName、masteryDegree、timeSlot（ExamTimeSlot?，nil 时回退为全天事件）。
- comprehensiveExam：name、examDate、examEndDate?、importance、subject（[String]）、examName、masteryDegree、timeSlot?。
- ExamTimeSlot：startTime、endTime（考试具体时间段，用于 CalendarManager 同步系统日历）。
- UserProfile：username、realName、age、gender、school / grade / class / studentId、enrollmentYear / examYear、educationStage、regionCode、theme、avatarFileName、selectedSubjects、targetSchool、targetScore。
- AppPreferences：appLanguage（可选）、colorScheme（ColorSchemeOption）。
- HomeLayoutPreference：有序 items（HomeCardItem 数组，每块带 enabled flag），持久化到 UserDefaults。
- HealthHistory（DailyHealthSnapshot）：date、hrv、restingHeartRate、respiratoryRate、sleepHours、deepSleepHours、remSleepHours、exerciseMinutes；由 HealthHistoryStore 维护 30 天滚动窗口。

---

## 7. HRV / HealthKit 子系统

HealthKitManager 为 @MainActor ObservableObject 单例，统一管理两类 HealthKit 数据：HRV（SDNN）准备度（与个人 14 天基线的 Z-score 对比）和 BodyStatus（多维身体信号快照）。

授权与生命周期：
- readTypes 一次请求授权：heartRateVariabilitySDNN、heartRate、restingHeartRate、respiratoryRate、sleepAnalysis、appleExerciseTime。
- bootstrap() 由 StudyPulseApp 在 dataManager.asyncInit() 完成、isReady = true 之后调用，避免启动期 I/O 竞争。
- enable() / disable() 切换 HRV 参与度；refreshReadiness() 重算 HRV 准备度；refreshBodyStatus() 重算 BodyStatus。

HRV 准备度：
- 采样窗口：14 天 HKQuantitySample（heartRateVariabilitySDNN）。
- 按日历日聚合：取每个日历日的第一个样本，按日期降序。
- 基线计算：仅统计 ≥ 7 个不同天数的样本，计算过去 14 天均值与标准差。
- Z-score：（当日 SDNN − 均值） / 标准差。
- 分类：excellent（z > 1）、normal（-1 ≤ z ≤ 1）、low（z < -1）、insufficient（少于 7 天）、noAuthorization（无授权）、queryFailed（查询失败）。

BodyStatus 多维身体信号：
- 字段：restingHeartRate、latestHeartRate、respiratoryRate、lastNightSleepHours、deepSleepHours、remSleepHours、exerciseMinutesToday、isUsable。
- 派生量：restorativeSleepHours = deepSleepHours + remSleepHours（这是「恢复性睡眠」雷达轴使用的值，反映深睡 + REM，不只是总睡眠时长）。
- SleepQuality 分类：unknown / poor (< 6h) / short (6-7h) / good (7-9h) / excellent (≥ 9h)。

PersonalBaselines 30 天个人基线：
- 由 HealthHistoryStore 维护，过去 30 天 DailyHealthSnapshot 滚动窗口，存于 ~/Documents/health_history.json（NSLock 线程安全）。
- StudyReadinessAlgorithm 优先用个人 30 天均值 / 标准差对每个信号打分，至少 7 天样本时启用；样本不足时回退到 AgeReference 年龄段参考范围。
- 每个信号最终归一化到 0~1，HRV 作为硬覆盖，其余信号合成 5 档学习强度 × 5 类学习重点（最多 25 种组合），未覆盖的组合回退到「steady / balanced」。
- 完整输入 / 评分 / 决策细节见 docs/AlgorithmIntroduction.md。

对外状态：hrvEnabled、hrvOnboardingCompleted、isAuthorized、isReady、readiness、dailyHRVHistory、lastSampleCount、hrvDetailLevel、bodyStatus、personalBaselines、bodyStatusAuthorized。

hrvDetailLevel 决定 HRVStatusCard 呈现模式 suggestionOnly / dataAndSuggestion / chartAndData。

首次启用时，HomeView 调用 HRVOnboardingView 三页介绍 HRV 是什么、隐私保护与授权确认。

---

## 8. 可定制主页

HomeLayoutPreference 为 Codable struct，持久化到 UserDefaults。HomeView 每一次 body 评估时都从 UserDefaults 读取，按启用顺序渲染启用的卡片。iPad 使用两栏 LazyVGrid，iPhone 使用单列 VStack。

HomeCardType 包括：
- hrvStatus：HRV 状态。
- unregisteredExamsReminder：未注册考试提醒，空时隐藏。
- quickActions：快速动作。
- studySuggestions：学习建议。
- trendChart：趋势图。
- upcomingExams：即将到来的考试。
- dailyQuote：每日金句。
- recentGrades：近期成绩。

HomeLayoutSettingsView 提供拖动重新排序与每项启用 / 禁用开关，然后保存回 UserDefaults。HomeLayoutPreference 的 mergeWithDefault 当未来版本新增卡片类型时保留用户的选择。

---

## 9. 图像、OCR 与 CSV 管线

图像管线：
- 拍摄：PhotoCaptureView（相机）或 ImagePicker（照片库）。
- 处理：压缩为 JPEG 数据，通过 DataManager.saveGradeImage(:gradeId:) 或 saveAvatar(:) 写入 ~/Documents/images/。
- 显示：从 ImageCache 读取缩略图（NSCache 最多 50 项，最大 300px，nonisolated）。AvatarView / WelcomeHeaderView / SettingsView 中的头像加载切换为异步 Task，避免阻塞主线程。
- 全屏：ZoomableImageView（双指缩放与双击缩放）。

OCR 管线：
- OCRManager.shared.recognizeText(in:completion:) 使用 VNRecognizeTextRequest，recognitionLevel = .accurate，recognitionLanguages = ["zh-Hans", "en"]。

CSV 管线：
- DataExportManager（@MainActor enum）按年级 / 错题 / 考试 / 综合考试导出 CSV，使用正确的 CSV 转义规则。
- CSVDocument（FileDocument）把 CSV 字符串包装成可共享文件，通过 UIActivityViewController 共享。

日志导出管线：
- LogStore 在内存中累积 LogEntry（NSLock 线程安全，5000 条上限）。
- LogDocument（FileDocument）把 LogStore 序列化为文本行（时间戳 + subsystem + category + level + message），供 .fileExporter 导出。
- DataManagementSettingsView 提供「Export Log」按钮触发导出，便于用户反馈问题时附带运行期日志。

---

## 10. iPad 适配

ContentView 在水平 size class 为 regular 时使用 NavigationSplitView；iPhone 使用 TabView。iPad 侧栏使用 NavigationLink(value: tab) 选择标签。

Views/Helpers/iPadLayout.swift 提供：
- adaptiveMaxWidth(_:) 修饰符（默认 720），在 iPad 上居中内容，iPhone 上全宽。
- AdaptiveHStack：iPad 为 HStack，iPhone 为 VStack。
- AdaptiveGridColumns(compact:regular:spacing:)：在 compact 尺寸下 compact 栏数，regular 尺寸下 regular 栏数。
- adaptiveCardPadding()：iPhone 加 20pt 外间距，iPad 不加。

各页面的 iPad 最大宽度：PreferencesView 为 640；SettingsView 为 720；ExamView 为 800；TrendsView 为 900；MistakeView 为 900；HomeView 为 1100（使用两栏网格呈现动态卡片）。

适配原则：
- iPhone 布局保持不变；所有 iPad 分支都在 horizontalSizeClass == .regular 或 UIDevice.current.userInterfaceIdiom == .pad 下判断。
- 内容居中而非拉伸。
- 视图层只调用 iPadLayout 辅助组件，不内联写 size class 分支。

---

## 11. 本地化

Localizable.strings 放在 en.lproj / zh-Hans.lproj / zh-Hant.lproj / ja.lproj / ko.lproj 目录。所有用户可见字符串使用 .localized() 扩展（定义在 StringsLocalized.swift）。应用在 AppEnvironmentManager.setLanguage(_:) 中通过修改 UserDefaults 的 AppleLanguages 切换语言，applyLanguageOnLaunch() 在应用启动时读取并应用。

---

## 12. 隐私权限

需要 Info.plist 与 entitlements 声明以下权限键：
- NSCameraUsageDescription：用于拍摄错题照片。
- NSPhotoLibraryUsageDescription：用于从照片库选择照片。
- NSCalendarsUsageDescription：用于添加考试到系统日历。
- NSHealthShareUsageDescription：用于读取 HRV / 心率 / 呼吸率 / 睡眠 / Apple 锻炼时间。
- com.apple.developer.healthkit：在 entitlements 文件开启 HealthKit 能力。
- com.apple.security.application-groups：App Group group.com.chenkai.gao.studypulse，主应用与 StudyPulseWidgetExtension 共享小组件数据。
注意 NSHealthUpdateUsageDescription 未使用，应用不向 HealthKit 写入数据。

---

## 13. WidgetKit 扩展

StudyPulseWidget/ 目录已作为 StudyPulseWidgetExtension 目标接入 StudyPulse.xcodeproj，scheme：StudyPulseWidgetExtension。Bundle id 为 Gao.Chenkai.StudyPulse.Widget，部署目标 iOS 18.6。

提供三个小组件：
1. ExamWidget：即将到来的考试。
2. TrendWidget：科目成绩趋势折线图。
3. HRVWidget：HRV 准备度（与 HomeView HRVStatusCard 视觉一致）。

每个小组件都有自己的 *WidgetData.swift 与 *WidgetSyncManager.swift（位于 StudyPulse/Managers/），主应用在合适时机调用 sync*() 写入 App Group。StudyPulseWidgetBundle 是 @main bundle，组合上述三个 widget。

每个小组件都完成了 en / zh-Hans / zh-Hant / ja / ko 五种语言本地化，字符串位于 StudyPulseWidget/{lang}.lproj/Localizable.strings。

启用步骤（已就绪，无需手工操作）：
1. Xcode 中已存在 StudyPulseWidgetExtension 目标，bundle id 为 Gao.Chenkai.StudyPulse.Widget，部署目标 iOS 18.6。
2. 主应用与小组件目标都已启用 App Group group.com.chenkai.gao.studypulse（StudyPulse.entitlements + StudyPulseWidgetExtension.entitlements）。
3. 若修改 App Group 名称，更新 AppGroupConfig.identifier。
4. 在主应用的 Exam 添加 / 编辑后调用 WidgetDataSyncManager.syncExamsToWidget()；成绩变化后调用 TrendWidgetSyncManager.syncTrend(grades:subjects:)。StudyPulseApp.scenePhase == .active 时会统一调用所有 sync*()，并在 dataManager.isReady == true 时才执行。
5. 使用 WidgetCenter.shared.reloadAllTimelines() 触发刷新。

ExamWidgetData / HRVWidgetData / TrendWidgetData 为小的 Codable struct，由对应的 WidgetDataStore 在各自 *WidgetData.swift 中管理读写。

---

## 14. 依赖（SPM）

使用 Swift Package Manager 管理依赖：
- WSOnBoarding：本地包，用于首次启动欢迎流程。
- swift-markdown-ui：本地包，用于错题 Markdown 预览。
- NetworkImage：远程包（gonzalezreal/NetworkImage @ 6.0.1），用于异步加载网络图像。
- cmark-gfm：Swift 项目内部使用的 Markdown 解析核心。

解析包的方式：在 Xcode 中 File → Packages → Resolve Package Versions；或在命令行执行 xcodebuild -resolvePackageDependencies -project StudyPulse.xcodeproj。

Apple 框架：SwiftUI、Charts、Vision、EventKit、UserNotifications、HealthKit、WidgetKit、UniformTypeIdentifiers。

---

## 15. 构建与运行

构建辅助脚本 scripts/build.sh 提供以下选项：
- 默认：调试构建，iPhone 17 模拟器。
- release：发布构建。
- clean：清理构建目录。
- list：列出可用模拟器。
- help：显示所有选项。

直接使用 xcodebuild 命令：
```bash
xcodebuild -project StudyPulse.xcodeproj -scheme StudyPulse -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

可用 scheme：StudyPulse、MarkdownUI。可用配置：Debug、Release。

---

## 16. 代码规范

架构与编码规范：
- 视图层通过 @EnvironmentObject 注入 DataManager / AppEnvironmentManager / HealthKitManager，不直接持有这些单例。
- 模型为 Codable 与 nonisolated value type，可安全地跨 actor 传递。
- 拥有 @Published 状态的管理器使用 @MainActor；纯辅助（DataFileIO / WidgetDataStore / EducationConfig / ImageCache / SubjectConfig / EducationRegion）为 nonisolated。
- SwiftUI 视图放在 Views/ 目录下；Components/、Helpers/、Admin/、OnBoarding/ 作为子目录。
- 字符串永远使用 .localized() 扩展。
- 颜色与日期通过 ColorExtensions / DateExtensions 包装。
- 图像文件保存在 images/ 目录，不要内联到 JSON（旧的 Grade.image 字段已在 DataManager.asyncInit 中迁移为文件）。
- MistakeDetailEditView 使用 EditSection 枚举驱动四个编辑块（Question / Reason / Wrong / Correct）。
- EducationConfig 为 nonisolated enum，提供全球教育系统数据。
- SubjectConfig 使用 required(...) / elective(...) 工厂方法构造。

---

## 17. 性能说明

- 应用启动使用 asyncInit() 异步在 .task 后台加载 JSON（含 health_history.json），避免阻塞主线程；同步的 load*() 方法为向后兼容保留。DataManager 暴露 isReady @Published，主数据加载完成后才允许写入 widget 与调用 HealthKitManager.bootstrap()。
- ImageCache 提供 NSCache 缓存的缩略图（最多 50 项，最大 300px），完全线程安全（nonisolated）。
- DataFileIO.imagesDir 用 NSLock 缓存路径，避免每次访问都 stat。
- ExamRowView / ComprehensiveExamRowView / UpcomingExamCard 使用 daysRemaining 计算属性替代 @State + onAppear，避免不必要的重渲染。
- iPad HomeView 使用 LazyVGrid 呈现仪表盘，保持内存占用低，即使启用了大量卡片。
- HomeView 采用分帧渲染（phased rendering），把动态卡片拆到多个 RunLoop 帧绘制，把首帧 long task 拆成多个小任务，让主线程保持响应。
- AvatarView / WelcomeHeaderView / SettingsView 的头像加载改为异步 Task，不再在主线程同步读文件 / 解码图片。
- LagMonitor.shared 持续监测主线程帧间隔，连续丢帧时把详细堆栈 / 时间戳写入 LogStore，便于事后通过 Export Log 复盘卡顿。

---

## 18. 已知问题与待办

已知问题：
- App Group 标识符 group.com.chenkai.gao.studypulse 需在 Apple Developer 门户创建并分别启用主应用与 StudyPulseWidgetExtension 的 App Group 能力。
- 目前没有 iCloud 同步 —— 所有数据仅本地存储在设备沙盒。
- NewMistakeSheet.swift / Views/Sheets/ 目录已移除 —— 新的流程使用 NewMistakeSetView。
- StudyReadinessAlgorithm 的「5 强度 × 5 重点」理论上 25 种组合，但实际可达组合是 HRV 硬覆盖 + 评分规则的子集；未覆盖组合统一回退到 steady / balanced。如需新增组合请同步更新 docs/AlgorithmIntroduction.md。

---

## 19. Agent 工作规则

AI 代理在本仓库工作时遵循以下规则：
- 每次非 trivial 代码修改后，运行构建（Xcode Cmd+B 或 ./scripts/build.sh）确认通过，留下语法或类型错误。
- 遵循文件布局：新视图放在 Views/，可复用组件放在 Views/Components/，视图辅助放在 Views/Helpers/，开发者页面放在 Views/Admin/，数据结构放在 Models/，服务放在 Managers/。Settings 相关子页放在 Views/Settings/，小组件相关 *WidgetData / *WidgetSyncManager 放在 StudyPulse/Managers/，小组件本体放在 StudyPulseWidget/。
- 使用 nonisolated value-type 模型：新 Codable 模型必须 nonisolated 与 Sendable，以便跨 actor 传递。
- 本地化所有用户可见字符串：永远不要在源码中直接写英语文本，新文案必须同步添加到 en / zh-Hans / zh-Hant / ja / ko 五份 Localizable.strings 文件（主应用与 StudyPulseWidget 各一份）。
- 持久化图像作为文件而非 JSON 内联：使用 DataManager.saveGradeImage / saveAvatar。
- 优先使用 iPadLayout 辅助而不是在视图里内联写 size class 分支。
- 不要手工修改 StudyPulse.xcodeproj/project.pbxproj —— 让 Xcode 管理。新增 Swift 文件后在 Xcode 中 Add Files to StudyPulse... / 拖入项目即可。
- 涉及新功能 / 新增配置时同步检查 docs/AlgorithmIntroduction.md / docs/SPEC.md / docs/DESIGN.md / README.md 是否需要更新；修改 StudyReadinessAlgorithm 评分规则必须同步更新 docs/AlgorithmIntroduction.md。
- 写入 widget 前确认 dataManager.isReady == true，避免在主数据加载完成前写入空数据。

---

## 20. 变更记录

近期变更（给 Agent 参考）：
- 移除 WSOnBoarding 依赖，OnBoarding 改为原生 iOS 26 风格：新增 Views/OnBoarding/OnboardingConfig.swift（数据模型）+ OnboardingView.swift（TabView 分页 + 渐变背景 + 玻璃质感卡片，iOS 26+ 使用 `glassEffect`、老版本回退到 `.regularMaterial`），VersionedWelcomeModifier 改用 OnboardingView，project.pbxproj 移除 WSOnBoarding 包引用与 Link 阶段配置。
- 接入 StudyPulseWidgetExtension 目标 + 三个小组件（ExamWidget / TrendWidget / HRVWidget）及其 *WidgetData.swift / *WidgetSyncManager.swift，每个 widget 完整本地化 en/zh-Hans/zh-Hant/ja/ko。
- 新增 HealthKit 扩展：BodyStatus（心率 / 呼吸率 / 深睡+REM / 锻炼）、HealthHistory（DailyHealthSnapshot）、HealthHistoryStore（30 天滚动持久化 ~/Documents/health_history.json）、StudyReadinessAlgorithm（5 强度 × 5 重点）；详见 docs/AlgorithmIntroduction.md。
- 新增 Log.swift（LogLevel / LogEntry / LogStore，5000 条上限，NSLock 线程安全）+ LogDocument（FileDocument）+ DataManagementSettingsView 的 Export Log 按钮，统一 os.Logger + 内存双写日志。
- 新增 LagMonitor.swift（CADisplayLink 主线程卡顿检测器），连续丢帧写入 LogStore。
- HomeView 引入分帧渲染（phased rendering），拆分首帧 long task；AvatarView / WelcomeHeaderView / SettingsView 头像加载改为异步 Task。
- DataManager 暴露 isReady @Published，所有 widget 同步在 scenePhase == .active && isReady == true 时执行；asyncInit() 完成后才调用 HealthKitManager.bootstrap()。
- DataFileIO.imagesDir 用 NSLock 缓存路径。
- 新增版本感知欢迎页 Views/OnBoarding/VersionedWelcomeModifier.swift（首次启动 → 欢迎页；版本号变化 → 新功能介绍页；同版本不显示）。
- 重构 Settings：原 SettingsView 拆为 Views/Settings/ 下 6 个聚焦子页（Profile / Appearance / Health / Data / About / FAQ），SettingsCategory 枚举驱动 5 段式导航；EditSubjectsView 改为 NavigationLink push。
- 新增视图：AboutView、CopyrightView、ProfileEditView、SectionHeader；新增 Sections/AboutSettingsView / AppearanceSettingsView / DataManagementSettingsView / HealthSettingsView / ProfileSettingsView / QASettingsView / SettingsCategory。
- Exam / comprehensiveExam 新增 examEndDate?（多日考试）与 timeSlot（ExamTimeSlot?，用于 CalendarManager 同步系统日历）。
- ExamPrepareNotifications 调整默认提醒窗口；Localizable.strings 在 5 种语言下统一增量更新。
- AGENTS.md / docs/CODE_WIKI.md / docs/CODE_WIKI_CN.md / README.md / docs/SPEC.md / docs/DESIGN.md 随新功能更新；新增 docs/AlgorithmIntroduction.md 专门解释 StudyReadinessAlgorithm。

更早变更：
- iPad 适配（TARGETED_DEVICE_FAMILY = "1,2"）通过 iPadLayout.swift 辅助组件（adaptiveMaxWidth / AdaptiveHStack / AdaptiveGridColumns / adaptiveCardPadding）。
- 视图层全面重构与设计系统骨架。
- 多语言：en / zh-Hans / zh-Hant / ja / ko。
- 错题模块启动：四块错题编辑、每块照片 + OCR、Markdown 预览、日历 / 通知自动调度、可缩放图像查看。
- 全球教育系统（15+ 种体系）。
