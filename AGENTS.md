# StudyPulse — AI Agent Guide

> 一份面向 AI 代理的完整开发指南。
> 本文件仅使用纯文本和代码块描述架构，不使用任何表格或 ASCII 流程图。

---

## 1. 项目速览

StudyPulse 是一个使用 SwiftUI 构建的 iOS 学业管理应用，帮助学生
追踪成绩、管理错题、规划考试、与 HealthKit 同步 HRV 数据并分析学习趋势。支持多种全球教育体系（中国大陆、浙江、上海、台湾、香港、新加坡、UK IGCSE 与 A-Level、IB DP、US AP / SAT / ACT、GRE / GMAT、TOEFL / IELTS 等）。

平台：iOS 18.6+，同时支持 iPhone 与 iPad。
语言：Swift 6.0。
架构：MVVM 与 @EnvironmentObject，通过 ObservableObject 向视图层注入 DataManager。
并发：Swift 6 Strict Concurrency，默认 Actor 隔离为 MainActor。
构建：Xcode 26.x。
依赖：本地包 WSOnBoarding、swift-markdown-ui；远程包 NetworkImage（GitHub）；内建 cmark-gfm。
存储：业务模型序列化为 JSON 文件保存在 ~/Documents/；图片以独立文件保存在 ~/Documents/images/；偏好设置与主页顺序保存在 UserDefaults。
应用组：group.com.chenkai.gao.studypulse，用于小组件数据同步。
本地化：English、简体中文、繁體中文、日本語、한국。
图表：SwiftUI Charts。
OCR：Vision 框架 VNRecognizeTextRequest。
日历：EventKit。
健康：HealthKit HRV / SDNN。
小组件：WidgetKit，源码已提供，目标暂未接入 Xcode 工程。
工程文件：StudyPulse.xcodeproj。

---

## 2. 仓库布局

仓库根目录包含以下核心内容：

- StudyPulse.xcodeproj：Xcode 工程，单目标 StudyPulse。
- StudyPulse/：主应用源代码目录。
  - StudyPulseApp.swift：@main 入口，请求通知授权并以 .task 启动 DataManager.asyncInit()。
  - StudyPulse.entitlements：开启 com.apple.developer.healthkit 权限。
  - Assets.xcassets：AccentColor、AppIcon。
  - Models/：数据模型定义。
    - DataModels.swift：Subject、Grade、MistakeNote、Exam、comprehensiveExam、UserProfile，以及教育系统相关枚举与结构（EducationStage、EducationCategory、SubjectConfig、EducationRegion）。
    - AppPreferences.swift：应用偏好（语言与色彩方案）。
    - HomeLayoutPreference.swift：主页卡片顺序与启用标记（按名称顺序存储，持久化到 UserDefaults）。
  - Managers/：业务逻辑层。
    - DataManager.swift：@MainActor ObservableObject，中央状态管理器。管理 grades、subjects、mistakeSets、examSets、comprehensiveExamSets、profile 等 @Published 属性，提供 asyncInit() 与各 save/loadAsync/load 方法。
    - AppEnvironmentManager.swift：全局语言与主题管理。
    - AppStyle.swift：应用设计系统骨架。
    - CalendarManager.swift：EventKit 集成。
    - DataExportManager.swift：CSV 导出（@MainActor enum）。
    - EducationConfig.swift：全球教育体系静态配置（nonisolated enum）。
    - ExamWidgetData.swift：小组件数据模型、AppGroupConfig、WidgetDataStore（App Group 读写）。
    - HealthKitManager.swift：HRV（SDNN）准备度、14 天基线、日级历史。
    - ImageCache.swift：nonisolated class，NSCache + 缩略图，单例 50 条缓存。
    - OCRManager.swift：Vision 文字识别。
    - StringsLocalized.swift：字符串本地化扩展 .localized()。
    - SubjectInfo.swift：展示名称与颜色、满分回退。
    - WidgetDataSyncManager.swift：App Group 数据同步（编码并写入）。
  - Views/：SwiftUI 视图。
    - ContentView.swift：根视图，iPhone 使用 TabView（5 个标签），iPad 使用自定义 NavigationSplitView 侧栏。
    - HomeView.swift：主页仪表盘（欢迎头、统计卡、动态卡片、每日金句、图表、即将到来的考试、近期成绩）。
    - TrendsView.swift：趋势分析（每科目趋势与需要关注的科目）。
    - MistakeView.swift：错题列表（建议复习、搜索、卡片布局）。
    - ExamView.swift：考试列表（单科与综合考试）。
    - SettingsView.swift：设置（资料、偏好、教育信息、数据管理、关于）。
    - PreferencesView.swift：语言与外观。
    - HomeLayoutSettingsView.swift：主页卡片重新排序与开关。
    - HRVOnboardingView.swift：HRV 介绍、隐私与授权三页。
    - AddGradeView.swift：添加成绩模态。
    - NewExamSetView.swift：新增 / 编辑考试（单科或综合）。
    - NewMistakeSetView.swift：新增错题（带照片与 OCR）。
    - ExamDetailView.swift：单科考试详情（关联错题）。
    - ExamDetailEditView.swift：编辑考试。
    - MistakeDetailEditView.swift：四块错题编辑（每块独立照片 + OCR + Markdown 预览）。
    - SubjectScoreCard.swift：可复用的科目成绩卡。
    - Components/：组件目录（GradeChartView、HRVStatusCard、SectionHeader、SubjectPickerView）。
    - Helpers/：视图辅助（AvatarView、ImagePicker、PhotoCaptureView、ScoreColor、ZoomableImageView、iPadLayout）。
    - Admin/：开发者页面（DataAdminView）。
    - OnBoarding/：启动引导（WelcomeConfig）。
  - Extensions/：ColorExtensions.swift、DateExtensions.swift。
  - NotificationsControl/：ExamPrepareNotifications.swift（本地通知）。
- StudyPulseWidget/：WidgetKit 小组件源码（目标暂未接入 Xcode 工程）。
  - ExamWidget.swift：Widget 定义。
  - ExamWidgetData.swift：共享数据模型。
  - ExamWidgetEntry.swift：时间轴条目。
  - ExamWidgetProvider.swift：时间轴提供者。
  - ExamWidgetViews.swift：S / M / L 三种尺寸视图。
  - StudyPulseWidgetBundle.swift：@main bundle。
  - Info.plist：小组件 Info.plist。
  - Assets.xcassets：AccentColor、AppIcon、WidgetBackground。
- TestData/：示例 CSV 与生成脚本。
- en.lproj、zh-Hans.lproj、zh-Hant.lproj、ja.lproj、ko.lproj：各语言本地化字符串。
- AGENTS.md / CODE_WIKI.md / CODE_WIKI_CN.md / README.md / LICENSE：文档与许可。
- scripts/build.sh：构建辅助脚本。

---

## 3. 架构说明

应用遵循 MVVM 模式，通过 @EnvironmentObject 在视图层注入 DataManager、AppEnvironmentManager 与 HealthKitManager。视图层负责展示与用户交互，业务逻辑层集中在 Managers/下的管理器，数据层为 Codable 的 value type。数据流从视图触发 DataManager.save*()，DataManager 将变更发布到 @Published 属性，触发 SwiftUI 重渲染；同时写入 ~/Documents/{file}.json。涉及考试的写入还会通过 WidgetDataSyncManager 同步到 App Group。

视图层目录：
- 根视图使用 ContentView。iPhone 以 TabView 五标签呈现 HomeView、TrendsView、MistakeView、ExamView、SettingsView；iPad 以自定义 NavigationSplitView 呈现侧栏 + 详情，保持 iPhone 布局不变而内容居中。HomeView 动态卡片由 HomeLayoutPreference 的启用顺序渲染，iPad 使用两栏 LazyVGrid，iPhone 使用单列 VStack。模态面板为 AddGradeView、NewExamSetView、NewMistakeSetView、MistakeDetailEditView、ExamDetailEditView、HRVOnboardingView、HomeLayoutSettingsView、DataAdminView，通过 .sheet 或 .navigationDestination 展示。

业务 / 服务层目录：
- DataManager（@MainActor ObservableObject）集中保存并对外暴露 grades / subjects / mistakeSets / examSets / comprehensiveExamSets / profile；提供 asyncInit()、save*()、load*Async() 与 saveGradeImage() / loadGradeImage() / deleteGradeImage()、saveAvatar() / loadAvatar() / deleteAvatar()，以及 fullScore(for:)、displayName(for:)、applySmartSubjectRecommendation(stage:regionCode:)。
- AppEnvironmentManager（@MainActor ObservableObject 单例）持有 AppPreferences，并提供 effectiveColorScheme、setLanguage、setColorScheme 等计算属性与方法。
- HealthKitManager（@MainActor ObservableObject 单例）持有 HRVReadiness（Z-score、分类、建议）、dailyHRVHistory、lastSampleCount、hrvDetailLevel，负责 enable() / disable() / refreshReadiness()。
- CalendarManager：EventKit 单例，负责添加考试到系统日历。
- OCRManager：Vision 文本识别（recognitionLanguages = ["zh-Hans", "en"]）。
- ImageCache：nonisolated class，单例 NSCache 50 项、300px 缩略图。
- EducationConfig：nonisolated enum，提供全球教育系统配置。
- SubjectInfo：科目显示辅助。
- WidgetDataSyncManager：App Group 同步。

数据层目录：
- 模型为 nonisolated value type，Codable 与 Sendable，可无 ceremony 跨 actor 传递。Subject、Grade、MistakeNote、Exam、comprehensiveExam、UserProfile、AppPreferences、HomeLayoutPreference。
- 持久化层写入 ~/Documents/ 下的对应 JSON；图片以 grade_UUID.jpg 写入 ~/Documents/images/；头像写入 avatar_UUID.jpg。UserDefaults 保存 AppPreferences、HomeLayoutPreference、hrv 相关偏好；App Group 容器保存 widgetUpcomingExams。

扩展与通知目录：
- ColorExtensions、DateExtensions、StringsLocalized 提供跨层使用的辅助；ExamPrepareNotifications 使用 UNUserNotificationCenter 调度本地通知，默认提醒天数 [1, 3, 5, 10, 30]。

---

## 4. 模块依赖关系

模块依赖顺序为：视图层依赖 DataManager（通过 @EnvironmentObject 注入），DataManager 再依赖辅助管理器与模型；模型本身不依赖其它层。

视图层到 DataManager 的调用示例：
- HomeView、TrendsView、MistakeView、ExamView、SettingsView 通过 @EnvironmentObject 读写 DataManager。
- DataManager 通过 CalendarManager / OCRManager / ImageCache / EducationConfig / SubjectInfo / WidgetDataSyncManager 等辅助组件。
- 辅助组件不反向调用视图层。
- 所有辅助组件与视图层解耦，便于单独测试。

小组件（StudyPulseWidget）通过 App Group 容器读取主应用写入的 ExamWidgetData 数据，自身不依赖 DataManager，依赖链不跨越进程边界。

---

## 5. 导航流程

应用入口在 StudyPulseApp：
- 设置 NotificationCoordinator 作为 UNUserNotificationCenter delegate。
- 请求通知授权。
- 调用 AppEnvironmentManager.shared.applyLanguageOnLaunch() 恢复语言设置。
- 使用 .task { dataManager.asyncInit() } 后台加载数据。

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
- PreferencesView：语言与外观。
- ProfileEditView：编辑用户资料（学校、年级、班级、学号、入学年、考试年、目标学校、目标分数）。
- EditSubjectsView：每科目满分自定义。
- DataAdminView：开发者数据管理。
- AboutView / CopyrightView：关于与版权。

---

## 6. 数据层说明

DataManager 为 @MainActor ObservableObject，作为视图层的 @EnvironmentObject 被注入。
@Published 属性包括 grades、subjects、mistakeSets、examSets、comprehensiveExamSets，外加 profile 与辅助属性。
生命周期方法包括 init()（同步加载，为向后兼容保留）、asyncInit()（Task.detached 在后台线程加载，通过 MainActor.run 回主线程，同时迁移 Grade.image 内联数据为独立文件）。
持久化时，各模型写入 ~/Documents/ 下单独文件，各模型对应 JSON；图片（成绩与头像）写入 ~/Documents/images/ 目录；Widget 数据通过 WidgetDataSyncManager 写入 App Group。

DataFileIO 为 nonisolated enum，负责 getDocsDir()、getImagesDir()、load<T: Codable>(url:) 等纯 I/O 方法。

图像文件命名：
- 成绩快照：images/grade_UUID.jpg。
- 头像：images/avatar_UUID.jpg。

持久化数据流：
- 应用启动：StudyPulseApp 在 .task 中调用 dataManager.asyncInit()。asyncInit 内部在后台 Task.detached（优先级 .userInitiated）并行加载 profile.json、grades.json、mistakes.json、exams.json、comprehensiveExams.json、subjects.json。回到主 Actor 后把结果分配给 @Published 并初始化默认科目。
- 用户编辑：视图调用 DataManager.save()，序列化写入文件并同步更新 @Published 变更触发 SwiftUI 重渲染。如果 save 涉及考试，还会调用 WidgetDataSyncManager.syncExamsToWidget() 触发 WidgetKit reloadTimelines。

核心模型说明：
- Subject：name、displayName、enabled、fullScore。
- Grade：subject、score、rawScore?、ranking?、importance（1..5）、image?（legacy 字段）、imageFileName?、date、examName、fullScore?。
- MistakeNote：title、subject、originalQuestion、source、date、errorReason、wrongSolution、correctSolution，以及每区块的文件名数组。
- Exam：subject（String）。
- comprehensiveExam：subject（[String]）。
- UserProfile：username、realName、age、gender、school / grade / class / studentId、enrollmentYear / examYear、educationStage、regionCode、theme、avatarFileName、selectedSubjects、targetSchool、targetScore。
- AppPreferences：appLanguage（可选）、colorScheme（ColorSchemeOption）。
- HomeLayoutPreference：有序 items（HomeCardItem 数组，每块带 enabled flag），持久化到 UserDefaults。

---

## 7. HRV / HealthKit 子系统

HealthKitManager 为 @MainActor ObservableObject 单例，负责读取 HKHealthStore 的 HRV（SDNN）数据，为用户提供当日学习状态的准备度建议。

采样窗口：14 天 HKQuantitySample （ heartRateVariabilitySDNN）。
按日历日聚合：取每个日历日的第一个样本，按日期降序。
基线计算：仅统计 ≥ 7 个不同天数的样本，计算过去 14 天均值与标准差。
Z-score：（当日 SDNN − 均值） / 标准差。
分类：excellent（z > 1）、normal（-1 ≤ z ≤ 1）、low（z < -1）、insufficient（少于 7 天）、noAuthorization（无授权）、queryFailed（查询失败）。

对外状态：hrvEnabled、hrvOnboardingCompleted、isAuthorized、readiness、dailyHRVHistory、lastSampleCount、hrvDetailLevel。

enable() 方法请求 HealthKit 授权（read heartRateVariabilitySDNN），disable() 禁用，refreshReadiness() 重新计算。hrvDetailLevel 决定 HRVStatusCard 的呈现模式 suggestionOnly / dataAndSuggestion / chartAndData。

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
- 显示：从 ImageCache 读取缩略图（NSCache 最多 50 项，最大 300px，nonisolated）。
- 全屏：ZoomableImageView（双指缩放与双击缩放）。

OCR 管线：
- OCRManager.shared.recognizeText(in:completion:) 使用 VNRecognizeTextRequest，recognitionLevel = .accurate，recognitionLanguages = ["zh-Hans", "en"]。

CSV 管线：
- DataExportManager（@MainActor enum）按年级 / 错题 / 考试 / 综合考试导出 CSV，使用正确的 CSV 转义规则。
- 通过 CSVDocument（FileDocument）与 UIActivityViewController 共享。

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
- NSHealthShareUsageDescription：用于读取 HRV 数据。
- com.apple.developer.healthkit：在 entitlements 文件开启 HealthKit 能力。
注意 NSHealthUpdateUsageDescription 未使用，应用不向 HealthKit 写入数据。

---

## 13. WidgetKit 扩展

StudyPulseWidget/ 目录提供完整的 WidgetKit 源码：ExamWidget（Widget 定义）、ExamWidgetData（共享数据模型）、ExamWidgetEntry（时间轴条目）、ExamWidgetProvider（时间轴提供者）、ExamWidgetViews（三种尺寸视图）、StudyPulseWidgetBundle（@main bundle）与 Info.plist。注意 WidgetKit 目标尚未添加到 StudyPulse.xcodeproj，需要在 Xcode 中新建 Widget Extension 目标并配置。

启用步骤：
1. 在 Xcode 中新建 Widget Extension 目标，bundle id 设置为 Gao.Chenkai.StudyPulse.Widget，部署目标 iOS 18.6。
2. 在主应用与小组件目标上启用 App Group group.com.chenkai.gao.studypulse。
3. 若修改 App Group 名称，更新 AppGroupConfig.identifier。
4. 在主应用的 Exam 添加 / 编辑后调用 WidgetDataSyncManager.syncExamsToWidget()，以及在应用变为活跃时也调用。
5. 使用 WidgetCenter.shared.reloadAllTimelines() 触发刷新。

ExamWidgetData 为小的 Codable struct（name、subject、examDate、daysRemaining），由 WidgetDataStore 在 ExamWidgetData.swift 中管理读写。

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

可用 scheme：StudyPulse、MarkdownUI、WSOnBoarding。可用配置：Debug、Release。

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

- 应用启动使用 asyncInit() 异步在 .task 后台加载 JSON，避免阻塞主线程；同步的 load*() 方法为向后兼容保留。
- ImageCache 提供 NSCache 缓存的缩略图（最多 50 项，最大 300px），完全线程安全（nonisolated）。
- ExamRowView / ComprehensiveExamRowView / UpcomingExamCard 使用 daysRemaining 计算属性替代 @State + onAppear，避免不必要的重渲染。
- iPad HomeView 使用 LazyVGrid 呈现仪表盘，保持内存占用低，即使启用了大量卡片。

---

## 18. 已知问题与待办

已知问题：
- Widget 目标尚未接入 StudyPulse.xcodeproj —— 源码已提交但构建时未使用。
- App Group 标识符需要在 Apple Developer 门户创建并在主应用与（未来的）小组件目标上启用。
- 目前没有 iCloud 同步 —— 所有数据仅本地存储在设备沙盒。
- NewMistakeSheet.swift / Views/Sheets/ 目录已移除 —— 新的流程使用 NewMistakeSetView。

---

## 19. Agent 工作规则

AI 代理在本仓库工作时遵循以下规则：
- 每次非 trivial 代码修改后，运行构建（Xcode Cmd+B 或 ./scripts/build.sh）确认通过，留下语法或类型错误。
- 遵循文件布局：新视图放在 Views/，可复用组件放在 Views/Components/，视图辅助放在 Views/Helpers/，开发者页面放在 Views/Admin/，数据结构放在 Models/，服务放在 Managers/。
- 使用 nonisolated value-type 模型：新 Codable 模型必须 nonisolated 与 Sendable，以便跨 actor 传递。
- 本地化所有用户可见字符串：永远不要在源码中直接写英语文本，新文案必须同步添加到 en / zh-Hans / zh-Hant / ja / ko 五份 Localizable.strings 文件。
- 持久化图像作为文件而非 JSON 内联：使用 DataManager.saveGradeImage / saveAvatar。
- 优先使用 iPadLayout 辅助而不是在视图里内联写 size class 分支。
- 不要手工修改 StudyPulse.xcodeproj/project.pbxproj —— 让 Xcode 管理。

---

## 20. 变更记录

近期变更（给 Agent 参考）：
- 新增 HealthKitManager.swift / HRVOnboardingView.swift / HRVStatusCard.swift，用于 HRV（SDNN）准备度（14 天基线 + Z-score 分类）。
- 新增 HomeLayoutPreference.swift 与 HomeLayoutSettingsView.swift，用于卡片启用 / 禁用与拖动重新排序（持久化到 UserDefaults）。
- 新增 Views/Admin/DataAdminView.swift，用于开发者批量数据操作。
- 重写 ContentView，使用自定义 NavigationSplitView 为 iPad 提供侧栏（替代 .sidebarAdaptable）；iPhone 保持经典 TabView。
- HomeView 从 HomeLayoutPreference.load().enabledTypes 按 HomeCardType 组合动态卡片。
- 新增“未注册考试提醒”卡片（考试后 3–7 天窗口内未录入成绩的提醒）。
- StudyPulse.entitlements 新增 com.apple.developer.healthkit。
- AGENTS.md / CODE_WIKI.md / CODE_WIKI_CN.md / README.md 重写以匹配新结构。

更早变更：
- iPad 适配（TARGETED_DEVICE_FAMILY = "1,2"）通过 iPadLayout.swift 辅助组件（adaptiveMaxWidth / AdaptiveHStack / AdaptiveGridColumns / adaptiveCardPadding）。
- 视图层全面重构与设计系统骨架。
- 多语言：en / zh-Hans / zh-Hant / ja / ko。
- 错题模块启动：四块错题编辑、每块照片 + OCR、Markdown 预览、日历 / 通知自动调度、可缩放图像查看。
- 全球教育系统（15+ 种体系）。
