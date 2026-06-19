# StudyPulse - 代码维基（中文版）

> StudyPulse iOS 应用的完整代码参考文档。这是一个支持全球教育体系的学业管理应用，使用 SwiftUI 构建。

================================================================================

## 目录

1. 快速入门
2. 架构概览
3. 目录结构
4. 数据模型参考
5. 管理器参考
6. 视图参考
7. 教育系统
8. 小组件扩展
9. 通知系统
10. OCR 系统
11. 图片缓存系统
12. CSV 导出功能
13. iPad 适配
14. 性能模式
15. 隐私权限
16. 构建命令
17. 编码标准与约定

================================================================================

## 快速入门

### 前置要求

+---------------+--------------+
| 要求          | 版本         |
+---------------+--------------+
| macOS         | 15.0 或更高  |
| Xcode         | 26.3         |
| iOS 部署目标  | 18.6 或更高  |
| Swift         | 6.0          |
| 支持设备      | iPhone 与 iPad（`TARGETED_DEVICE_FAMILY = "1,2"`） |
+---------------+--------------+

### 快速开始命令

```bash
# 1. 进入项目目录
cd StudyPulse/

# 2. 在 Xcode 中打开
open StudyPulse.xcodeproj

# 3. 解析 SPM 包
#    Xcode -> File -> Packages -> Resolve Package Versions

# 4. 构建并运行
#    Cmd + R
```

### 核心概念

+ 架构模式：MVVM，视图由 `@EnvironmentObject` DataManager 驱动
+ 持久化方式：所有数据存储为 `~/Documents/` 下的 JSON 文件
+ 启动方式：应用使用 `asyncInit()` 非阻塞启动
+ 全球教育支持：支持 15+ 教育体系（中国大陆、浙江、上海、台湾、香港、新加坡、UK、IB、AP、SAT、ACT、GRE、GMAT、TOEFL、IELTS）
+ 通用设备支持：iPhone 与 iPad 通用，基于 size class 的自适应布局（详见 [iPad 适配](#ipad-适配)）

================================================================================

## 架构概览

StudyPulse 采用 MVVM（Model-View-ViewModel）模式，使用 SwiftUI 的 `@EnvironmentObject` 进行依赖注入。

### 高级架构图

```
+-------------------------------------------------------------------------------+
|                       StudyPulse iOS 应用 - 高级架构图                        |
+===============================================================================+
|                                                                               |
|  +---表现层（Presentation Layer）-------------------------------------------+  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  |  |     StudyPulseApp            |  |  AppEnvironmentManager         |    |  |
|  |  |  （应用入口）                |  |  （主题 + 语言 + 配色）         |    |  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  +---视图层（View Layer）---------------------------------------------------+  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  |  |    ContentView (TabView)      |  |                               |    |  |
|  |  |  +------+  +------+  +------+ |  |                               |    |  |
|  |  |  | 主页  |  | 趋势  |  | 错题  | |  |   HomeView / TrendsView    |    |  |
|  |  |  +------+  +------+  +------+ |  |   MistakeView / ExamView     |    |  |
|  |  |  +------+  +------+           |  |   SettingsView / AddGradeView |    |  |
|  |  |  | 考试  |  | 设置  |           |  |   NewExamSet / ProfileEdit  |    |  |
|  |  |  +------+  +------+           |  |                               |    |  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  +-------------------------------------------------------------------------+  |
|                                       |                                       |
|  +---业务逻辑层（Business Logic Layer）-----------------------------------+  |
|  |                               +---------------------------------+     |  |
|  |  +--------------------------+ |  DataManager（中央状态管理器）  |     |  |
|  |  |     辅助管理器            | |  - grades / subjects          |     |  |
|  |  |                          | |  - mistakeSets / examSets      |     |  |
|  |  |  +--------------------+   | |  - comprehensiveExamSets      |     |  |
|  |  |  |  CalendarManager   |   | |  - profile                     |     |  |
|  |  |  |  OCRManager        |   | +---------------------------------+     |  |
|  |  |  |  ImageCache        |   |                                         |  |
|  |  |  |  WidgetDataSyncMgr |   |  方法: asyncInit(), save*(),           |  |
|  |  |  |  EducationConfig   |   |        fullScore(), displayName(),      |  |
|  |  |  |  SubjectInfo       |   |        applySmartRec()                 |  |
|  |  |  +--------------------+   |                                         |  |
|  |  +--------------------------+                                         |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  +---数据层（Data Layer）---------------------------------------------------+  |
|  |  +---------------------------+   +----------------------------------+  |  |
|  |  |     模型（Models）         |   |      持久化层（Persistence）      |  |  |
|  |  |  EducationStage           |   |  ~/Documents/                    |  |  |
|  |  |  EducationCategory        |   |  - profile.json                  |  |  |
|  |  |  SubjectConfig            |   |  - grades.json                   |  |  |
|  |  |  EducationRegion          |   |  - exams.json                    |  |  |
|  |  |  Subject / Grade          |   |  - mistakes.json                 |  |  |
|  |  |  UserProfile              |   |  - subjects.json                 |  |  |
|  |  |  MistakeNote              |   |  - comprehensiveExams.json       |  |  |
|  |  |  Exam / comprehensiveExam |   |  - images/ （成绩/头像图片）      |  |  |
|  |  |  AppPreferences           |   |                                  |  |  |
|  |  +---------------------------+   +----------------------------------+  |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  +---小组件扩展（Widget Extension）-----------------------------------------+  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  |  |  ExamWidgetData             |  |  ExamWidget（时间轴刷新）        |    |  |
|  |  |  ExamWidgetEntry            |  |                               |    |  |
|  |  |  ExamWidgetProvider         |  |  ExamWidgetViews (S/M/L)       |    |  |
|  |  |  StudyPulseWidgetBundle     |  |                               |    |  |
|  |  +-------------------------------+  +-------------------------------+    |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
+-------------------------------------------------------------------------------+
```

### 组件交互流程图

```
+-------------------+
|   用户输入操作      |
+---------+---------+
          |
          v
+----------------------------------------------------------+
|                  SwiftUI 视图                            |
|  +-----------+  +-----------+  +-----------+            |
|  |  主页视图   |  | 添加成绩   |  | 设置页面   |            |
|  +-----+-----+  +-----+-----+  +-----+-----+            |
+--------+--------------+--------------+------------------+
         |              |              |
         +--------------+--------------+
                        |
                        v
         +------------------------------+
         |    DataManager（中央）        |
         |   (@EnvironmentObject)        |
         +--------------+---------------+
                        |
         +--------------+--------------+
         |                             |
         v                             v
+----------------------+   +------------------------+
| 更新模型状态         |   | 保存到磁盘（文件I/O）    |
| (SwiftUI 重新渲染)    |   |   JSON + 图片文件       |
+----------------------+   +------------+-----------+
                                        |
                                        v
                         +------------------------------+
                         |  WidgetDataSyncManager       |
                         |   （App Group 数据同步）      |
                         +--------------+---------------+
                                        |
                                        v
                         +------------------------------+
                         |  StudyPulseWidget            |
                         |   （时间轴刷新）              |
                         +------------------------------+
```

### 模块依赖关系图

```
+-------------------------------------------------------------------------------+
|                         模块依赖关系图                                        |
+===============================================================================+
|                                                                               |
|  +------------------+        +------------------+        +------------------+ |
|  |  视图层           | -----> |  DataManager     | -----> |  数据模型         | |
|  |  HomeView        |        |                  |        |  Grade           | |
|  |  TrendsView      |        |  已发布属性:       |        |  MistakeNote     | |
|  |  MistakeView     |        |  grades           |        |  Exam            | |
|  |  ExamView        |        |  subjects         |        |  Subject         | |
|  |  SettingsView    |        |  mistakeSets      |        |  UserProfile     | |
|  |  AddGradeView    |        |  examSets         |        |  SubjectConfig   | |
|  |  NewExamSet      |        |  profile          |        |  EducationRegion | |
|  +------------------+        +---------+--------+        +------------------+ |
|                                         |                                      |
|                                         v                                      |
|                              +---------------------+                          |
|                              |   辅助管理器         |                          |
|                              |                     |                          |
|                              |  +---------------+  |                          |
|                              |  | CalendarMgr   |  |                          |
|                              |  | OCRManager    |  |                          |
|                              |  | ImageCache    |  |                          |
|                              |  | EducationCfg  |  |                          |
|                              |  | SubjectInfo   |  |                          |
|                              |  +---------------+  |                          |
|                              +---------------------+                          |
|                                         |                                      |
|                                         v                                      |
|                              +---------------------+                          |
|                              |   扩展与工具类       |                          |
|                              |  Color/Date/Score/  |                          |
|                              |  Strings 本地化     |                          |
|                              +---------------------+                          |
|                                                                               |
|  依赖方向: 视图 -> DataManager -> 辅助管理器 -> 扩展                            |
|  （视图不直接访问辅助管理器，由 DataManager 中介）                               |
|                                                                               |
+-------------------------------------------------------------------------------+
```

### 数据持久化流程图

```
+-------------------------------------------------------------------------------+
|                      数据持久化流程图                                          |
+===============================================================================+
|                                                                               |
|  [A] 应用启动 (.task -> asyncInit())                                           |
|  +-------------------------------------------------------------------------+  |
|  |  主线程                               后台线程                           |  |
|  |  +-------------------+              +----------------------+           |  |
|  |  | StudyPulseApp     |   async      |  DataManager         |           |  |
|  |  |  .task {          | ------------> |  loadProfileAsync()  |           |  |
|  |  |    dataManager.   |              |  loadGradesAsync()   |           |  |
|  |  |    asyncInit()    |              |  loadExamsAsync()    |           |  |
|  |  |  }                |              |  loadMistakesAsync() |           |  |
|  |  +-------------------+              |  loadSubjectsAsync() |           |  |
|  |                                       +-----------+----------+           |  |
|  |                                                   |                      |  |
|  |                                                   v                      |  |
|  |                                       ~/Documents/（文件存储）            |  |
|  |                                       - profile.json                      |  |
|  |                                       - grades.json                       |  |
|  |                                       - exams.json                        |  |
|  |                                       - mistakes.json                     |  |
|  |                                       - subjects.json                     |  |
|  |                                       +----------------------+           |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  [B] 保存操作（用户操作 -> 保存）                                               |
|  +-------------------------------------------------------------------------+  |
|  |  用户点击"保存"                                                           |  |
|  |     |                                                                   |  |
|  |     v                                                                   |  |
|  |  DataManager.save*() (@MainActor)                                       |  |
|  |   +---- 更新 @Published 属性 -> 触发 SwiftUI 重新渲染                    |  |
|  |   +---- 编码模型 -> JSON Data（JSONEncoder）                             |  |
|  |   +---- 写入 ~/Documents/{file}.json（原子写入）                         |  |
|  |   +---- WidgetDataSyncManager.syncExamsToWidget()                       |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  [C] 文件 I/O 模式（DataFileIO - nonisolated 枚举）                            |
|  +-------------------------------------------------------------------------+  |
|  |  + read(from:) -> Data? （出错时抛出）                                     |  |
|  |  + write(data:to:) -> Bool（通过临时文件 + 重命名实现原子写入）             |  |
|  |  + directoryExists() / createDirectory()                                  |  |
|  |  + 安全支持后台线程执行                                                    |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## 目录结构

```
StudyPulse/
|
+-- Models/                          数据模型定义
|   |-- DataModels.swift             核心数据模型
|   +-- AppPreferences.swift         应用偏好设置模型
|
+-- Managers/                        业务逻辑管理器
|   |-- DataManager.swift            中央状态管理器
|   |-- EducationConfig.swift        教育体系静态配置
|   |-- AppEnvironmentManager.swift  全局偏好管理（语言+主题）
|   |-- CalendarManager.swift        EventKit 日历集成
|   |-- OCRManager.swift             Vision 框架文字识别
|   |-- ImageCache.swift             NSCache 缩略图缓存
|   |-- SubjectInfo.swift            科目显示辅助
|   +-- WidgetDataSyncManager.swift  App Group 数据同步
|
+-- Views/                           SwiftUI 视图和组件
|   |-- ContentView.swift            主 TabView 容器（iPad 侧边栏自适应）
|   |-- HomeView.swift               仪表板主页（iPad 上 4 列统计 + 2 列分区）
|   |-- TrendsView.swift             科目趋势分析
|   |-- ExamView.swift               考试列表
|   |-- ExamDetailView.swift         考试详情
|   |-- MistakeView.swift            错题本
|   |-- AddGradeView.swift           成绩录入表单
|   |-- SettingsView.swift           设置页面
|   |-- ProfileEditView.swift        用户资料编辑
|   |-- EditSubjectsView.swift       科目编辑
|   |-- NewExamSet.swift             新建考试
|   |-- PreferencesView.swift        应用偏好（语言+主题）
|   |-- SubjectScoreCard.swift       可复用科目成绩卡片
|   +-- Helpers/                     辅助视图组件
|       |-- AvatarView.swift         头像视图 + 选择 Sheet
|       |-- ScoreColor.swift         分数颜色工具
|       +-- iPadLayout.swift         iPad 自适应布局辅助（adaptiveMaxWidth、AdaptiveHStack、AdaptiveGridColumns）
|
+-- Extensions/                      颜色和日期扩展
|
+-- Notifications/                   本地通知调度
|   +-- ExamPrepareNotifications.swift  考试提醒调度
|
+-- StudyPulseWidget/                小组件扩展目标
|   |-- ExamWidget.swift             小组件定义
|   |-- ExamWidgetData.swift         共享数据模型
|   |-- ExamWidgetEntry.swift        时间轴条目
|   |-- ExamWidgetProvider.swift     时间轴提供者
|   |-- ExamWidgetViews.swift        小组件 UI 视图（小/中/大）
|   +-- StudyPulseWidgetBundle.swift 小组件 Bundle
|
+-- StudyPulseApp.swift              应用入口点
|
+-- *.lproj/                         本地化资源
|   |-- en.lproj
|   |-- zh-Hans.lproj
|   |-- zh-Hant.lproj
|   |-- ja.lproj
|   +-- ko.lproj
|
+-- Assets.xcassets/                 图像与颜色资源
|
+-- Info.plist / PrivacyInfo.xcprivacy  权限与配置
|
+-- Package.swift                    Swift 包管理器清单
|
+-- StudyPulse.xcodeproj             Xcode 项目文件
|
+-- AGENTS.md                        AI 代理指南
+-- CODE_WIKI.md                     代码维基（英文）
+-- CODE_WIKI_CN.md                  代码维基（中文，本文件）
+-- CONTRIBUTING.md                  贡献指南
+-- README.md                        项目说明
+-- CHANGELOG.md                     版本变更日志
+-- LICENSE                          许可证
```

================================================================================

## 数据模型参考

### 模型快速索引表

+------------------------+-----------------------------------+-----------+
| 模型名称               | 用途                              | 文件      |
+------------------------+-----------------------------------+-----------+
| EducationStage         | 教育阶段枚举                      | DataModels|
| EducationCategory      | 教育体系分类（国内/国际）         | DataModels|
| SubjectConfig          | 单科目配置信息                    | DataModels|
| EducationRegion        | 地区教育体系                      | DataModels|
| Subject                | 用户科目列表                      | DataModels|
| Grade                  | 单条成绩记录                      | DataModels|
| UserProfile            | 用户资料                          | DataModels|
| MistakeNote            | 单条错题笔记                      | DataModels|
| Exam                   | 单科目考试                        | DataModels|
| comprehensiveExam      | 多科目综合考试                    | DataModels|
| AppPreferences         | 应用偏好（语言+主题）             | AppPrefs  |
| ColorSchemeOption      | 配色方案选项                      | AppPrefs  |
+------------------------+-----------------------------------+-----------+

### EducationStage（枚举）

定义用户当前的教育阶段。

```swift
nonisolated enum EducationStage: String, CaseIterable, Identifiable, Codable, Sendable {
    case primarySchool = "Primary School"
    case middleSchool = "Middle School"
    case highSchool = "High School"
    case internationalHighSchool = "International High School"
    case university = "University"
    case graduate = "Graduate"
}
```

### EducationCategory（枚举）

教育体系的分类（国内 / 国际）。

```swift
nonisolated enum EducationCategory: String, CaseIterable, Codable, Sendable {
    case domestic = "Domestic"
    case international = "International"
}
```

### SubjectConfig

单科目配置信息，描述一个教育体系中的标准科目。

```swift
nonisolated struct SubjectConfig: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let fullScore: Double
    let isRequired: Bool
    let isElective: Bool
    let category: String?

    // 工厂方法
    static func required(_ name: String, displayName: String,
                         fullScore: Double, category: String? = nil)
    static func elective(_ name: String, displayName: String,
                         fullScore: Double, category: String? = nil)
}
```

### EducationRegion

代表一个地区的教育体系。

```swift
nonisolated struct EducationRegion: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let category: EducationCategory
    let stage: EducationStage
    let systemCode: String
    let subjects: [SubjectConfig]
    let notes: String
}
```

### Subject

用户科目列表，满分可自定义。

```swift
nonisolated struct Subject: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var displayName: String
    var enabled: Bool
    var fullScore: Double
}
```

### Grade

单条成绩记录。

```swift
nonisolated struct Grade: Identifiable, Codable {
    var id = UUID()
    var subject: String
    var score: Double
    var rawScore: Double?
    var ranking: Int?
    var importance: Int
    var image: Data?
    var imageFileName: String?
    var date: Date
    var examName: String
    var fullScore: Double?

    func scoreRate(subjectFullScore: Double = 100) -> Double
}
```

### UserProfile（已扩展）

用户资料，包含详细学术信息。

```swift
nonisolated struct UserProfile: Codable {
    var username: String = "Student"
    var realName: String = ""
    var age: Int = 16
    var gender: String = "Not Specified"
    var educationLevel: String
    var educationSystem: String
    var region: String
    var educationStage: String
    var regionCode: String
    var selectedSubjects: [Subject] = []
    var theme: String = "Auto"
    var avatarFileName: String?

    var grade: String = ""
    var className: String = ""
    var schoolName: String = ""
    var studentId: String = ""
    var enrollmentYear: Int
    var examYear: Int
    var targetSchool: String = ""
    var targetScore: Double = 0
}
```

### MistakeNote

单条错题笔记。

```swift
nonisolated struct MistakeNote: Identifiable, Codable {
    var id = UUID()
    var title: String
    var subject: String
    var originalQuestion: String
    var source: String
    var date: Date
    var errorReason: String
    var wrongSolution: String
    var correctSolution: String
    var questionImages: [String]
    var reasonImages: [String]
    var wrongSolutionImages: [String]
    var correctSolutionImages: [String]
}
```

### Exam / comprehensiveExam

```swift
nonisolated struct Exam: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subject: String
    var examDate: Date
    var importance: Int
    var masteryDegree: Int
    var notes: String
}

nonisolated struct comprehensiveExam: Identifiable, Codable {
    var id = UUID()
    var name: String
    var subject: [String]
    var examDate: Date
    var importance: Int
    var masteryDegree: Int
    var notes: String
}
```

### AppPreferences

```swift
struct AppPreferences: Codable {
    var appLanguage: String?
    var colorScheme: ColorSchemeOption
}

enum ColorSchemeOption: String, CaseIterable, Codable {
    case system, light, dark
}
```

================================================================================

## 管理器参考

### 管理器索引表

+------------------------+-----------------------------------+--------------------+
| 管理器                 | 主要职责                          | 关键 API           |
+------------------------+-----------------------------------+--------------------+
| DataManager            | 中央状态管理 + 持久化             | asyncInit()        |
|                        |                                   | saveProfile()      |
|                        |                                   | saveGrades()       |
|                        |                                   | fullScore()        |
|                        |                                   | displayName()      |
|                        |                                   | applySmartRec()    |
+------------------------+-----------------------------------+--------------------+
| EducationConfig        | 教育体系静态配置                  | availableRegions() |
|                        |                                   | defaultRegion()    |
|                        |                                   | region(named:)     |
+------------------------+-----------------------------------+--------------------+
| AppEnvironmentManager  | 语言 + 主题偏好                   | setLanguage()      |
|                        |                                   | setColorScheme()   |
+------------------------+-----------------------------------+--------------------+
| CalendarManager        | EventKit 日历集成                 | requestAccess()    |
|                        |                                   | addExamToCalendar()|
+------------------------+-----------------------------------+--------------------+
| OCRManager             | Vision 框架文字识别               | recognizeText()    |
+------------------------+-----------------------------------+--------------------+
| ImageCache             | NSCache 缩略图缓存                | image()            |
|                        |                                   | thumbnail()        |
|                        |                                   | clear()            |
+------------------------+-----------------------------------+--------------------+
| SubjectInfo            | 科目显示辅助                      | getMaxScore()      |
|                        |                                   | SubjectDisplay     |
+------------------------+-----------------------------------+--------------------+
| WidgetDataSyncManager  | App Group 小组件数据同步          | syncExamsToWidget()|
|                        |                                   | loadWidgetData()   |
+------------------------+-----------------------------------+--------------------+

### DataManager（中央状态管理器）

`DataManager` 是中央状态管理器，通过 `ObservableObject` 隐式标记为 `@MainActor`。

#### 已发布属性

+-------------------------+----------------------+--------------------------+
| 属性                    | 类型                 | 说明                     |
+-------------------------+----------------------+--------------------------+
| grades                  | [Grade]              | 成绩记录集合             |
| subjects                | [Subject]            | 用户启用的科目           |
| mistakeSets             | [MistakeNote]        | 错题笔记集合             |
| examSets                | [Exam]               | 单科目考试集合           |
| comprehensiveExamSets   | [comprehensiveExam]  | 多科目综合考试集合       |
| profile                 | UserProfile          | 用户资料                 |
+-------------------------+----------------------+--------------------------+

#### 关键方法

```swift
// 初始化
func asyncInit() async
private func initializeDefaultSubjects()

// 科目辅助
func fullScore(for subjectName: String) -> Double
func displayName(for subjectName: String) -> String
func applySmartSubjectRecommendation(stage: EducationStage, regionCode: String)

// 头像管理
func saveAvatar(_ data: Data) -> String?
func loadAvatar() -> Data?
func deleteAvatar(filename: String)

// 图片管理
func saveGradeImage(_ data: Data) -> String?
func getImage(filename: String) -> UIImage?
func deleteGradeImage(filename: String)

// 持久化
func saveProfile()
func saveGrades()
func saveSubjects()
func saveExams()
func saveComprehensiveExams()
func saveMistakeSets()
```

### EducationConfig（教育体系配置）

`EducationConfig` 是一个 `nonisolated` 枚举，提供对所有支持教育体系的静态访问。

```swift
// 按学段获取地区
static func availableRegions(for stage: EducationStage) -> [EducationRegion]

// 按分类筛选
static func availableRegions(category: EducationCategory) -> [EducationRegion]

// 按名称查找
static func region(named name: String, stage: EducationStage) -> EducationRegion?

// 学段默认地区
static func defaultRegion(for stage: EducationStage) -> EducationRegion

// 按 systemCode 查找
static func region(systemCode: String) -> EducationRegion?
```

### AppEnvironmentManager（全局偏好）

管理应用全局偏好（语言 + 主题）。

```swift
class AppEnvironmentManager: ObservableObject {
    @Published var preferences: AppPreferences
    var effectiveColorScheme: ColorScheme?
    func setLanguage(_ language: String?)
    func setColorScheme(_ scheme: ColorSchemeOption)
}
```

### CalendarManager（日历集成）

EventKit 集成，将考试添加到系统日历。

```swift
class CalendarManager {
    static let shared = CalendarManager()
    func requestAccess() async -> Bool
    func addExamToCalendar(exam: Exam) async throws
}
```

### OCRManager（文字识别）

Vision 框架文字识别，用于错题照片。

```swift
class OCRManager {
    func recognizeText(from image: UIImage) async throws -> String
}
```

### ImageCache（图片缓存）

`nonisolated` 类，提供 NSCache 缩略图缓存。

```swift
nonisolated class ImageCache {
    static let shared = ImageCache()
    func image(for filename: String) -> UIImage?
    func thumbnail(for filename: String) -> UIImage?
    func clear()
}
```

+ 缓存容量：最多 50 条
+ 最大尺寸：缩略图 300 像素
+ 线程安全：nonisolated，可在后台调用

### SubjectInfo（科目信息）

```swift
nonisolated enum SubjectDisplay {
    static func displayName(for name: String, custom: String? = nil) -> String
}

class SubjectInfo: ObservableObject {
    func getMaxScore(level: String, subject: String) -> Double
}
```

### WidgetDataSyncManager（小组件同步）

通过 App Group 与小组件同步数据。

```swift
class WidgetDataSyncManager {
    static let shared = WidgetDataSyncManager()
    func syncExamsToWidget(_ exams: [Exam])
    func loadWidgetData() -> ExamWidgetData?
}
```

### 管理器协作流程图

```
+-------------------------------------------------------------------------------+
|                       管理器协作流程                                          |
+===============================================================================+
|                                                                               |
|  [视图层]                                                                     |
|   HomeView  TrendsView  MistakeView  ExamView  SettingsView  AddGradeView    |
|       |         |          |          |          |              |            |
|       +---------+----------+----------+----------+--------------+            |
|                                  |                                             |
|                                  v                                             |
|                       +-------------------------+                              |
|                       |     DataManager         |                              |
|                       |   （中央状态 + 持久化）   |                              |
|                       +----+-------------+---+--+                              |
|                            |             |   |                                 |
|                            |             |   |                                 |
|             +--------------+             |   +-------------+                   |
|             |                            |                 |                   |
|             v                            v                 v                   |
|  +----------------------+   +----------------------+  +------------+          |
|  |  EducationConfig     |   |  WidgetDataSyncMgr   |  | ImageCache |          |
|  |  （静态配置，只读）    |   |   App Group 同步      |  | NSCache    |          |
|  +----------------------+   +----------------------+  +------------+          |
|                            |              |                                     |
|                +-----------+              +-----------+                        |
|                |                                      |                        |
|                v                                      v                        |
|      +-------------------+            +-------------------------+             |
|      |  CalendarManager  |            |   StudyPulseWidget      |             |
|      |  EventKit         |            |   （时间轴刷新）         |             |
|      +-------------------+            +-------------------------+             |
|                                                                               |
|  [全局]                                                                       |
|   +-------------------+      +-------------+      +-----------------+        |
|   | AppEnvironmentMgr |      | OCRManager  |      | SubjectInfo     |        |
|   | （语言 + 主题）     |      | Vision 框架  |      |（显示辅助）      |        |
|   +-------------------+      +-------------+      +-----------------+        |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## 视图参考

### 标签页结构

```
+----------------------------------------------------------------------+
|                      ContentView (TabView)                           |
|                                                                      |
|  +----------+  +----------+  +----------+  +----------+  +----------+ |
|  |   主页    |  |   趋势    |  |   错题    |  |   考试    |  |   设置    | |
|  | HomeView  |  |TrendsView|  |MistakeView|  | ExamView |  |Settings  | |
|  +----------+  +----------+  +----------+  +----------+  +----------+ |
+----------------------------------------------------------------------+
```

### HomeView（仪表板主页）

+ 欢迎头部（按时段问候 + 头像）
+ 统计卡片：iPhone 2x2 网格（考试计数、成绩计数、错题计数、平均分）
+ iPad：4 个统计卡片在一行排列，呈现仪表板风格
+ 快捷操作按钮（添加成绩、新建考试、新建错题）
+ 即将到来的考试卡片（倒计时显示，iPad 上 2 列并排）
+ 每日激励语
+ 科目趋势图表（5 种选择策略）
+ 最近成绩列表
+ 智能学习建议
+ 整体外层容器 iPad 上 `frame(maxWidth: 1100)` 居中显示
+ 多个分区使用 `AdaptiveHStack` 实现 iPad 双列布局

#### 图表选择策略

+----------------+--------------------------------------------+
| 策略           | 说明                                       |
+----------------+--------------------------------------------+
| Weakest        | 优先展示最低分科目                         |
| Most Data      | 优先展示成绩数据最多的科目                 |
| Recent         | 优先展示最近 30 天最活跃的科目             |
| Improving      | 优先展示进步最大的科目                     |
| Random         | 随机选择科目                               |
+----------------+--------------------------------------------+

### TrendsView（趋势分析）

+ "需要引起重视的科目"提示（平均分 < 70 或下降 > 15 分）
+ 各科成绩卡片（SubjectScoreCard）
+ 分数模式 / 排名模式切换
+ 科目详情页（图表 + 统计 + 历史）

### ExamView + ExamDetailView（考试）

+ 考试列表（按日期排序）
+ 考试详情页
  + 倒计时显示
  + 关联错题区域
  + 日历集成按钮（添加到系统日历）
  + 掌握度显示

### MistakeView（错题本）

+ "建议复习的题目"区域（按优先级排序，可横向滑动）
+ 搜索功能（按标题 / 科目 / 内容搜索）
+ 卡片式列表（渐变 + 动画）
+ 点击查看详情（支持编辑、Markdown 预览、图片缩放）

### AddGradeView（成绩录入表单）

+ 单科目或多科目输入
+ 每个科目自定义满分
+ 分数 / 卷面分 / 排名可选字段
+ 根据科目数自动调整高度
+ 图片附件支持

### SettingsView + ProfileEditView + EditSubjectsView（设置）

+ 用户资料卡（头像+用户名+年龄/学段，点击头像打开选择器）
+ 编辑操作区（编辑资料 / 编辑科目，均为 Sheet 呈现）
+ 偏好设置（NavigationLink 进入 PreferencesView）
+ 学术信息（学校 / 年级·班级 / 教育体系 / 地区 / 目标分数 / 目标学校）
+ 数据管理（导出数据 / 导入数据，均为菜单式，支持成绩 / 错题 / 考试 CSV）
+ 关于（关于 StudyPulse / 版权与许可证 / 测试通知发送）
+ 使用 .insetGrouped 列表样式与统一的 infoRow 辅助视图

### ProfileEditView（用户资料编辑）
+ 用户资料编辑（12+ 字段：用户名、真实姓名、年龄、性别、学段、地区、年级、班级、学校、学号、入学年份、考试年份、目标学校、目标分数）
+ 学段 + 地区选择器（菜单式）
+ 智能科目推荐按钮（一键应用）

### PreferencesView（偏好设置）

+ 主题：浅色 / 深色 / 跟随系统
+ 语言：英文 / 简体中文 / 繁体中文 / 日语 / 韩语 / 跟随系统

### 辅助视图组件

+ AvatarView：头像显示组件（可配置尺寸、边框）
+ AvatarPickerSheet：头像选择 Sheet（相册 / 拍照）
+ ScoreColor：分数颜色工具
+ SubjectScoreCard：可复用科目成绩卡片

#### 分数颜色规则

+---------------------+-------------------+
| 分数占满分的比例    | 颜色              |
+---------------------+-------------------+
| 90% 或更高          | 绿色（优秀）      |
| 75% - 89%           | 蓝色（良好）      |
| 60% - 74%           | 橙色（合格）      |
| 低于 60%            | 红色（需努力）    |
+---------------------+-------------------+

```swift
// 向后兼容（默认按 100 满分）
func scoreColor(_ score: Double) -> Color

// 按满分比例显示颜色
func scoreColor(_ score: Double, fullScore: Double) -> Color

// 格式化输出
func scoreColorText(_ score: Double, fullScore: Double) -> String
```

### 模态表单汇总

+----------------------------+--------------------------------+------------+
| 模态视图                   | 触发方式                       | 层级       |
+----------------------------+--------------------------------+------------+
| AddGradeView               | 主页 -> 添加成绩按钮           | Sheet      |
| NewExamSet                 | 考试页 -> 新建考试按钮         | Sheet      |
| ProfileEditView            | 设置页 -> 编辑资料             | Sheet      |
| EditSubjectsView           | 设置页 -> 编辑科目             | Sheet      |
| MistakeDetailEditView      | 错题页 -> 点击/新建错题        | Sheet      |
| AvatarPickerSheet          | 设置页（头像卡）-> 头像选择    | Sheet      |
| PreferencesView            | 设置页 -> 偏好设置             | Navigation |
| AboutView / CopyrightView  | 设置页 -> 关于/版权与许可证    | Sheet      |
| ExamDetailView             | 考试页 -> 点击考试条目         | Navigation |
+----------------------------+--------------------------------+------------+

================================================================================

## 教育系统

### 教育系统分类树

```
EducationConfig（教育体系配置）
|
+-- 国内
|   |
|   +-- 中国
|   |   +-- 中国大陆标准版
|   |   |   +-- 小学
|   |   |   +-- 初中
|   |   |   +-- 高中
|   |   |
|   |   +-- 浙江
|   |   |   +-- 初中
|   |   |   +-- 高中 3+3
|   |   |
|   |   +-- 上海
|   |   |   +-- 初中
|   |   |   +-- 高中 3+3
|   |   |
|   |   +-- 台湾
|   |   |   +-- 初中
|   |   |   +-- 学测
|   |   |
|   |   +-- 香港
|   |       +-- DSE
|   |
|   +-- 新加坡
|       +-- O-Level
|
+-- 国际
    |
    +-- 英国
    |   +-- IGCSE
    |   +-- A-Level
    |
    +-- IB
    |   +-- Diploma Programme (DP)
    |
    +-- 美国
    |   +-- AP (Advanced Placement)
    |   +-- SAT (Scholastic Assessment Test)
    |   +-- ACT (American College Testing)
    |
    +-- 研究生与语言考试
        +-- GRE (Graduate Record Examination)
        +-- GMAT (Graduate Management Admission Test)
        +-- TOEFL (Test of English as a Foreign Language)
        +-- IELTS (International English Language Testing System)
```

### 覆盖矩阵表

+----------------+------+------+--------------+----------+------+--------+
| 地区           | 小学 | 初中 | 高中         | 国际高中 | 大学 | 研究生 |
+----------------+------+------+--------------+----------+------+--------+
| 中国大陆       |  是  |  是  | 是           |    -     |  -   |   -    |
| 浙江           |  -   |  是  | 是 (3+3)     |    -     |  -   |   -    |
| 上海           |  -   |  是  | 是 (3+3)     |    -     |  -   |   -    |
| 台湾           |  -   |  是  | 是 (学测)    |    -     |  -   |   -    |
| 香港           |  -   |  -   | 是 (DSE)     |    -     |  -   |   -    |
| 新加坡         |  -   |  是  | 是 (O-Level) |    是    |  -   |   -    |
| UK IGCSE       |  -   |  是  | -            |    是    |  -   |   -    |
| UK A-Level     |  -   |  -   | 是           |    是    |  -   |   -    |
| IB Diploma     |  -   |  -   | 是           |    是    |  -   |   -    |
| US AP          |  -   |  -   | 是           |    是    |  -   |   -    |
| US SAT         |  -   |  -   | -            |    -     |  是  |   -    |
| US ACT         |  -   |  -   | -            |    -     |  是  |   -    |
| GRE / GMAT     |  -   |  -   | -            |    -     |  -   |   是   |
| TOEFL / IELTS  |  -   |  -   | -            |    -     |  -   |   是   |
+----------------+------+------+--------------+----------+------+--------+

### 评分制参考表

+-----------------+----------------+---------------------------------+
| 体系            | 评分制         | 示例                            |
+-----------------+----------------+---------------------------------+
| 中国大陆 高中   | 100 / 150      | 语文 150，物理 100              |
| 浙江 高中       | 100（赋分）    | 全部科目 100 满分               |
| 香港 DSE        | 1-7 (5**=7)    | 全部科目 7 满分                 |
| 台湾 学测       | 100            | 数学 A / 数学 B 各 100          |
| UK A-Level      | 100            | A* = 90 分以上                  |
| IB DP           | 1-7            | 6 科 + TOK + EE = 45 总分       |
| US AP           | 1-5            | 5 = 满分                        |
| US SAT          | 200-800        | 1600 总分                       |
| US ACT          | 1-36           | 36 = 满分                       |
| GRE             | 130-170        | 340 总分                        |
| TOEFL           | 0-120          | -                               |
| IELTS           | 0-9            | -                               |
+-----------------+----------------+---------------------------------+

### 特色体系详细说明

#### 浙江初中

+ 合并科目：科学（160 分满分）、历史与社会（100 分满分）
+ 语文、数学、英语各 120 分

#### 台湾学测

+ 数学 A（理工科组）
+ 数学 B（文商科组）
+ 两份不同试卷，科目独立勾选

#### IB Diploma

+ 6 个 Group：母语 / 外语 / 人文社会 / 实验科学 / 数学 / 艺术
+ 3 门 HL + 3 门 SL
+ 总分 45：6 科（42 分）+ TOK（1 分）+ EE（1 分）+ CAS（0 分）

#### UK A-Level

+ 选 3-4 门课
+ 各考试局通用（CIE / Edexcel / AQA / OCR）
+ A* = 90 分以上

#### US AP

+ College Board 课程
+ 5 分制
+ 35+ 门课可选

================================================================================

## 小组件扩展

### 小组件架构图

```
+-------------------------------------------------------------------------------+
|                      StudyPulseWidget - 小组件架构图                          |
+===============================================================================+
|                                                                               |
|  +---主应用（StudyPulse）---------------------------------------------------+  |
|  |  +-----------------------------+                                          |  |
|  |  |     DataManager             |                                          |  |
|  |  |  - examSets                 |                                          |  |
|  |  |  - comprehensiveExamSets    |                                          |  |
|  |  +-------------+---------------+                                          |  |
|  |                |                                                          |  |
|  |                v                                                          |  |
|  |  +-----------------------------+                                          |  |
|  |  |  WidgetDataSyncManager      |                                          |  |
|  |  |  - syncExamsToWidget()       |                                          |  |
|  |  +-------------+---------------+                                          |  |
|  |                |                                                          |  |
|  +----------------+---------------------------------------------------------+  |
|                   |                                                           |
|                   |   App Group 容器                                          |
|                   |   (group.Gao-Chenkai.StudyPulse)                          |
|                   |                                                           |
|  +----------------+---------------------------------------------------------+  |
|  |                v                                                          |  |
|  |  +-----------------------------+     +-----------------------------+     |  |
|  |  |   ExamWidgetData            |     |                             |     |  |
|  |  |  （共享数据模型）            |     |   ExamWidgetProvider        |     |  |
|  |  +-------------+---------------+     |   getTimeline()            |     |  |
|  |                |                     |   placeholder()            |     |  |
|  |                v                     +-------------+--------------+     |  |
|  |  +-----------------------------+                   |                    |  |
|  |  |   ExamWidgetEntry           |                   v                    |  |
|  |  |  （时间轴条目模型）          |     +-----------------------------+     |  |
|  |  +-----------------------------+     |   ExamWidgetViews           |     |  |
|  |                                      |  - Small Widget View        |     |  |
|  |                                      |  - Medium Widget View       |     |  |
|  |                                      |  - Large Widget View        |     |  |
|  |                                      +-----------------------------+     |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  注:                                                                          |
|  数据流向: DataManager -> WidgetDataSyncManager -> App Group 文件             |
|           -> ExamWidgetProvider -> ExamWidgetViews                            |
|  刷新时机: 成绩/考试变更时自动刷新时间轴                                       |
|                                                                               |
+-------------------------------------------------------------------------------+
```

### 小组件文件清单

+-------------------------------+----------------------------------+
| 文件                          | 说明                             |
+-------------------------------+----------------------------------+
| ExamWidget.swift              | 小组件定义（Widget 协议）        |
| ExamWidgetData.swift          | 共享数据模型（App Group）        |
| ExamWidgetEntry.swift         | 时间轴条目（TimelineEntry）      |
| ExamWidgetProvider.swift      | 时间轴提供者（TimelineProvider） |
| ExamWidgetViews.swift         | 小组件 UI 视图（小/中/大）       |
| StudyPulseWidgetBundle.swift  | 小组件 Bundle                    |
+-------------------------------+----------------------------------+

### 数据共享机制

+ 使用 App Group: `group.Gao-Chenkai.StudyPulse`
+ 由 `WidgetDataSyncManager` 处理同步
+ 成绩 / 考试变更时刷新时间轴
+ 数据格式：JSON（通过 `ExamWidgetData` 模型编码）

================================================================================

## 通知系统

### 通知调度流程图

```
+-------------------------------------------------------------------------------+
|                        通知调度流程图                                          |
+===============================================================================+
|                                                                               |
|  [A] 触发条件：用户创建/编辑考试并开启日历通知                                  |
|  +-------------------------------------------------------------------------+  |
|  |                                                                         |  |
|  |  NewExamSetView / ExamDetailView                                        |  |
|  |  +---开关: "添加到日历"（默认开启）                                      |  |
|  |  +---开关: "考试提醒"（默认开启）                                         |  |
|  |                        |                                                 |  |
|  |                        v                                                 |  |
|  |  ExamPrepareNotifications.scheduleExamPrepareNotification(exam: Exam)     |  |
|  |   |                                                                      |  |
|  |   +-- 请求 UNAuthorization (.alert, .sound, .badge)                      |  |
|  |   +-- 创建 UNMutableNotificationContent                                   |  |
|  |   |     +-- title: "明天考试：{exam.name}"                               |  |
|  |   |     +-- body: "别忘了复习！"                                          |  |
|  |   |     +-- sound: .default                                              |  |
|  |   +-- 计算触发日期 (examDate - 1 天)                                      |  |
|  |   +-- 创建 UNCalendarNotificationTrigger                                  |  |
|  |   +-- 创建 UNNotificationRequest (id: "exam_{exam.id}")                  |  |
|  |   +-- UNUserNotificationCenter.add(request)                              |  |
|  |                                                                           |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  [B] 通知生命周期                                                            |
|  +-------------------------------------------------------------------------+  |
|  |                                                                         |  |
|  |  创建考试  ---->  调度通知                                               |  |
|  |                                                                         |  |
|  |  编辑考试（日期变更）----> 取消旧通知 ----> 创建新通知                    |  |
|  |                                                                         |  |
|  |  删除考试  ---->  取消通知（按 id）                                       |  |
|  |                                                                         |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## OCR 系统

### OCR 处理管线图

```
+-------------------------------------------------------------------------------+
|                        OCR 处理管线图                                          |
+===============================================================================+
|                                                                               |
|  触发: 在 MistakeDetailEditView 中点击 "OCR" 按钮                              |
|                                                                               |
|  [第一步] 检查图片可用性                                                      |
|  +-------------------------------------------------------------------------+  |
|  |                                                                         |  |
|  |  + 当前编辑区域有图片数组                                                |  |
|  |  + 获取最后上传的图片文件名                                              |  |
|  |  + 从 ~/Documents/images/{filename} 加载图片                            |  |
|  |  + 如果没有图片 -> 显示提示 "没有可识别的图片"                            |  |
|  |                                                                         |  |
|  +-------------------------------+-----------------------------------------+  |
|                                  |                                            |
|                                  v                                            |
|  [第二步] Vision 框架处理                                                    |
|  +-------------------------------------------------------------------------+  |
|  |                                                                         |  |
|  |  + 创建 VNImageRequestHandler(cgImage: options:)                        |  |
|  |  + 创建 VNRecognizeTextRequest                                          |  |
|  |  |   +-- recognitionLevel: .accurate （较慢，结果更好）                 |  |
|  |  |   +-- usesLanguageCorrection: true                                  |  |
|  |  |   +-- revision: VNRecognizeTextRequestRevision3                     |  |
|  |  + 执行请求 -> 获取 VNRecognizedTextObservation[]                       |  |
|  |  + 从每个 observation 提取 topCandidates(1)                            |  |
|  |  + 用换行符连接所有字符串                                                |  |
|  |                                                                         |  |
|  +-------------------------------+-----------------------------------------+  |
|                                  |                                            |
|                                  v                                            |
|  [第三步] 结果展示                                                            |
|  +-------------------------------------------------------------------------+  |
|  |                                                                         |  |
|  |  + 识别到文字 -> 插入当前 TextEditor 区域                                |  |
|  |    （原题 / 错因 / 错误解法 / 正确解法）                                 |  |
|  |  + 没有文字 -> 显示提示 "图片中未检测到文字"                              |  |
|  |  + 错误处理 -> 显示错误提示                                              |  |
|  |                                                                         |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
|  Vision 框架详情:                                                             |
|  +-------------------------------------------------------------------------+  |
|  |  + 支持语言: 中文（简/繁）、英文、混合                                    |  |
|  |  + 异步模式: await handler.perform([request])                           |  |
|  |  + 在后台线程运行（不阻塞 UI）                                           |  |
|  |  + 精度选项: .accurate 优于 .fast（速度与质量权衡）                      |  |
|  |  + 语言校正: 提升常见词识别效果                                          |  |
|  +-------------------------------------------------------------------------+  |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## 图片缓存系统

### 图片缓存架构图

```
+-------------------------------------------------------------------------------+
|                        图片缓存系统架构图                                      |
+===============================================================================+
|                                                                               |
|  [请求源]                                                                     |
|   HomeView  TrendsView  MistakeView  ProfileEditView                         |
|       |          |          |             |                                   |
|       +----------+----------+-------------+                                   |
|                    |                                                           |
|                    v                                                           |
|   +----------------+---------------+                                           |
|   |     ImageCache（单例）          |                                           |
|   |  nonisolated class              |                                           |
|   |                                  |                                           |
|   |  + image(for filename) -> UIImage? （检查缓存 -> 从磁盘加载）           |
|   |  + thumbnail(for filename) -> UIImage? （缓存缩略图，最大 300 像素）     |
|   |  + clear() -> Void （清空所有缓存）                                     |
|   |                                  |                                           |
|   +---+-----+------------------------+                                           |
|       |     |                                                                    |
|       |     |    [内部实现]                                                       |
|       |     +--> NSCache（内存缓存，最多 50 条）                                 |
|       |          |                                                                |
|       |          +-- Key: filename (String)                                       |
|       |          +-- Value: UIImage（缩略图）                                     |
|       |                                                                          |
|       v                                                                          |
|   +----------------------------------------------------------------------+      |
|   |   磁盘存储（~/Documents/images/）                                      |      |
|   |                                                                       |      |
|   |  avatar_{uuid}.jpg        用户头像文件                                 |      |
|   |  grade_{uuid}.jpg         成绩附件图片                                 |      |
|   |  question_{uuid}.jpg      错题原题图片                                 |      |
|   |  reason_{uuid}.jpg        错题错因图片                                 |      |
|   |  wrong_{uuid}.jpg         错题错误解法图片                             |      |
|   |  correct_{uuid}.jpg       错题正确解法图片                             |      |
|   |                                                                       |      |
|   |  读取: DataFileIO.read(from:)                                         |      |
|   |  写入: DataFileIO.write(data:to:) （原子写入）                         |      |
|   +-----------------------------------------------------------------------+      |
|                                                                               |
|  数据流向:                                                                    |
|    请求 -> ImageCache.image()                                                |
|      |-- 在 NSCache 中查找（命中: 立即返回）                                  |
|      |-- 未命中 -> 从 ~/Documents/images/ 加载 -> 缓存 -> 返回                |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## CSV 导出功能

### CSV 导出流程图

```
+-------------------------------------------------------------------------------+
|                        CSV 导出流程图                                          |
+===============================================================================+
|                                                                               |
|  [触发] 用户在设置页或统计页点击 "导出" 按钮                                    |
|                                                                               |
|  +-- 选择导出范围（成绩 / 错题 / 考试 / 全部）                                  |
|  |                                                                             |
|  v                                                                             |
|  +-- DataManager 读取数据                                                       |
|  |   grades / mistakeSets / examSets / comprehensiveExamSets                  |
|  |                                                                             |
|  v                                                                             |
|  +-- 构建 CSV 行（逐模型转换）                                                 |
|  |                                                                             |
|  |   [成绩记录 Grade]                                                         |
|  |   列: 日期 | 科目 | 分数 | 满分 | 排名 | 考试名称 | 重要性 | 备注            |
|  |                                                                             |
|  |   [错题笔记 MistakeNote]                                                   |
|  |   列: 日期 | 科目 | 标题 | 原题 | 错因 | 错误解法 | 正确解法 | 来源          |
|  |                                                                             |
|  |   [考试 Exam]                                                              |
|  |   列: 日期 | 名称 | 科目 | 重要性 | 掌握度 | 备注                           |
|  |                                                                             |
|  v                                                                             |
|  +-- CSV 格式处理                                                             |
|  |   + 分隔符: 逗号 (,)                                                       |
|  |   + 字符串字段: 包裹在双引号中 (")                                         |
|  |   + 换行符: \n                                                             |
|  |   + 编码: UTF-8                                                            |
|  |   + 表头: 第一行为字段名称                                                  |
|  |                                                                             |
|  v                                                                             |
|  +-- 写入临时文件                                                              |
|  |   ~/Documents/temp_{timestamp}.csv                                         |
|  |                                                                             |
|  v                                                                             |
|  +-- UIActivityViewController 分享（可选）                                     |
|      允许用户保存到文件 / 分享到其他应用                                       |
|                                                                               |
+-------------------------------------------------------------------------------+
```

### CSV 字段格式约定

+----------------+------------------+------------------------------------------+
| 数据类型       | CSV 格式         | 示例                                     |
+----------------+------------------+------------------------------------------+
| 日期 Date      | ISO 8601         | 2026-06-11                               |
| 字符串         | 双引号包裹       | "数学"                                   |
| 数字           | 直接写入         | 92.5                                     |
| 布尔/枚举      | rawValue         | high / required                         |
| UUID           | uuidString       | 550e8400-e29b-41d4-a716-446655440000     |
| 多行文本       | 引号包裹 + \n    | "第一行\n第二行"                         |
+----------------+------------------+------------------------------------------+

================================================================================

## iPad 适配

应用是一个通用二进制目标，同时支持 iPhone 与 iPad
（`TARGETED_DEVICE_FAMILY = "1,2"`）。iPhone 上的布局完全保持原样；iPad 上则
会获得原生侧边栏 Tab Bar 和多列、限宽的布局。

### 总体策略

| 关注点         | iPhone 行为              | iPad 行为                                  |
|----------------|--------------------------|--------------------------------------------|
| Tab Bar        | 底部 5 个 Tab（经典）    | 左侧侧边栏（`.tabViewStyle(.sidebarAdaptable)`） |
| 内容宽度       | 满屏                     | 居中、限制最大宽度                          |
| 分区布局       | 竖直堆叠（VStack）        | 并排显示（HStack），通过 `AdaptiveHStack`  |
| 统计卡片       | 2x2 网格                 | 4 个一行                                   |
| 表单 / 列表    | 满宽                     | 居中、窄列                                 |

### 自适应辅助组件（`Views/Helpers/iPadLayout.swift`）

```swift
// 1) 内容最大宽度
struct AdaptiveContentWidth: ViewModifier {  // var maxWidth: CGFloat = 720
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)        // 居中
    }
}
extension View {
    func adaptiveMaxWidth(_ maxWidth: CGFloat = 720) -> some View
}

// 2) 自适应网格列数（iPhone 1 列，iPad N 列）
struct AdaptiveGridColumns {
    init(compact: Int = 1, regular: Int = 2, spacing: CGFloat = 20)
}

// 3) HStack / VStack 自动切换
struct AdaptiveHStack<Content: View>: View {
    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content)
    // sizeClass == .regular -> HStack
    // else                -> VStack
}

// 4) 卡片外层 padding（iPhone 横向 20pt，iPad 横向 0）
struct AdaptiveCardPadding: ViewModifier
extension View {
    func adaptiveCardPadding() -> some View
}
```

所有辅助组件均通过 `@Environment` 在 `body` 内读取 `horizontalSizeClass`；
该环境值在普通的 View extension property 中无法访问。

### 文件级改动清单

| 文件 | iPad 适配内容 |
|------|---------------|
| `ContentView.swift` | `.tabViewStyle(.sidebarAdaptable)` 显示 iPad 侧边栏 |
| `HomeView.swift` | `frame(maxWidth: 1100)` 容器 + `AdaptiveHStack` 双列分区 + 4 列 `MainStatsCard` |
| `SettingsView.swift` | `.adaptiveMaxWidth(720)` 应用于 List |
| `PreferencesView.swift` | `.adaptiveMaxWidth(640)` 应用于 Form |
| `TrendsView.swift` | `.adaptiveMaxWidth(900)` 应用于 ScrollView |
| `MistakeView.swift` | `.adaptiveMaxWidth(900)` 应用于 `MistakeView` + `SubjectMistakesView` |
| `ExamView.swift` | `.adaptiveMaxWidth(800)` 应用于 List |
| `Helpers/iPadLayout.swift` | **新增** -- 全部自适应辅助组件 |

### 最大宽度参考表

| 视图 | iPad 最大宽度 | 说明 |
|------|---------------|------|
| `SettingsView` | 720 | 单列表单在 600-720pt 范围内可读性最佳 |
| `PreferencesView` | 640 | 紧凑型偏好面板 |
| `ExamView` | 800 | 倒计时 + 备注需要稍宽一些 |
| `TrendsView` | 900 | 图表需要更多水平空间 |
| `MistakeView` | 900 | 长 Markdown 内容适合更宽 |
| `HomeView` | 1100 | 仪表板 / 多列布局可以更宽 |

### HomeView iPad 多列布局示意

```
+---------------------------------------------------+
|  欢迎头部（1100 最大宽度内铺满）                  |
+-----------------+---------------------------------+
|  Stat 1  Stat 2  Stat 3  Stat 4   （一行）         |
+-----------------+---------------------------------+
|  快捷操作       |  即将到来的考试   （双列）       |
|-----------------+---------------------------------|
|  图表 / 趋势    |  学习建议         （双列）       |
+-----------------+---------------------------------+
|  每日激励语 / 最近成绩（满宽）                    |
+---------------------------------------------------+
```

### 设计原则

1. **不破坏 iPhone 布局** -- 所有改动均由 `horizontalSizeClass` 或
   `UIDevice.current.userInterfaceIdiom` 控制。
2. **居中而非拉伸** -- iPad 上内容以最大宽度居中显示，保持可读性。
3. **原生 iPad 体验** -- 侧边栏 Tab Bar + 多列仪表板。
4. **单一来源** -- 所有自适应逻辑集中在 `iPadLayout.swift`，
   业务视图只需调用对应辅助组件。

================================================================================

## 性能模式

### 性能优化措施

+----------------+----------------------------------------------------------+
| 优化项         | 说明                                                     |
+----------------+----------------------------------------------------------+
| 异步数据加载   | asyncInit() 在 .task 修饰符中执行，不阻塞主线程         |
| 图片缓存       | ImageCache（基于 NSCache，最多缓存 50 条缩略图）         |
| 文件存储图片   | 成绩和头像图片存储为独立文件，不嵌入 JSON                |
| 计算属性       | daysRemaining 等使用计算属性，避免 @State + onAppear    |
| Sendable 模型  | 所有模型标记为 nonisolated + Sendable，支持 Swift 6 并发 |
| 工厂方法       | SubjectConfig.required() / .elective() 简洁构造          |
| 后台线程写入   | DataFileIO 为 nonisolated 枚举，安全在后台执行           |
| 原子文件写入   | write() 使用临时文件 + 重命名，避免数据损坏              |
| 懒加载列表     | 长列表（错题 / 成绩 / 考试）使用 LazyVStack / List       |
| 缩略图缓存     | 图片缩略图最大 300 像素，减少内存占用                    |
+----------------+----------------------------------------------------------+

### 主线程与后台线程分工

```
+-------------------------------------------------------------------------------+
|                      主线程 / 后台线程 分工图                                 |
+===============================================================================+
|                                                                               |
|  [主线程（MainActor）]                                                        |
|  +-----------------------------+                                              |
|  |  SwiftUI 视图渲染           |                                              |
|  |  @Published 属性更新        |                                              |
|  |  DataManager.save*()        |                                              |
|  |  动画和交互                 |                                              |
|  +-----------------------------+                                              |
|                                                                               |
|  [后台线程（非 MainActor）]                                                   |
|  +-----------------------------+                                              |
|  |  asyncInit() 加载 JSON      |                                              |
|  |  OCRManager.recognizeText() |                                              |
|  |  CalendarManager 请求       |                                              |
|  |  DataFileIO 读/写           |                                              |
|  |  ImageCache 图片加载        |                                              |
|  |  Widget 数据同步            |                                              |
|  +-----------------------------+                                              |
|                                                                               |
|  数据流向:                                                                    |
|    后台（async/await） -> 主线程（@MainActor 更新 @Published）                 |
|                         -> SwiftUI 自动刷新视图                               |
|                                                                               |
+-------------------------------------------------------------------------------+
```

================================================================================

## 隐私权限

### 权限清单表

+----------------+----------------------------------------------------+
| 权限           | 用途                                                |
+----------------+----------------------------------------------------+
| 相机           | 拍照拍摄错题照片 / 头像照片                         |
| 相册           | 访问相册选择错题照片 / 头像                         |
| 日历           | 将考试添加到系统日历（EventKit）                    |
| 通知           | 考试提醒（UNUserNotificationCenter）                |
+----------------+----------------------------------------------------+

### 权限声明位置

+----------------+----------------------------------+
| 权限           | Info.plist / PrivacyInfo 键       |
+----------------+----------------------------------+
| 相机           | NSCameraUsageDescription         |
| 相册           | NSPhotoLibraryUsageDescription   |
| 相册（写入）   | NSPhotoLibraryAddUsageDescription|
| 日历           | NSCalendarsUsageDescription      |
| 日历（写入）   | NSCalendarsFullAccessUsageDescription |
| 通知           | UNUserNotificationCenter（请求）|
+----------------+----------------------------------+

================================================================================

## 构建命令

### Xcode 构建

```bash
# 在 Xcode 中打开项目
open StudyPulse.xcodeproj

# 解析 Swift 包
# Xcode -> File -> Packages -> Resolve Package Versions

# 构建
# Cmd + B

# 在模拟器或设备上运行
# Cmd + R
```

### 命令行构建（可选）

```bash
# 使用 xcodebuild 构建（模拟器）
xcodebuild -project StudyPulse.xcodeproj \
           -scheme StudyPulse \
           -sdk iphonesimulator \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build

# 使用 xcodebuild 构建（真机）
xcodebuild -project StudyPulse.xcodeproj \
           -scheme StudyPulse \
           -sdk iphoneos \
           build

# 清理构建
xcodebuild -project StudyPulse.xcodeproj -scheme StudyPulse clean
```

### 常见构建目标

+----------------+---------------------------------------------------+
| 目标           | 说明                                               |
+----------------+---------------------------------------------------+
| StudyPulse     | 主 iOS 应用（iOS 18.6+）                          |
| StudyPulseWidget | 小组件扩展目标（与主应用共享 App Group）         |
+----------------+---------------------------------------------------+

================================================================================

## 编码标准与约定

### Swift 代码规范

+---------------------+---------------------------------------------------+
| 项目                | 约定                                              |
+---------------------+---------------------------------------------------+
| 缩进                | 4 空格（不使用 Tab）                              |
| 类名 / 结构体名     | UpperCamelCase（首字母大写）                      |
| 方法 / 变量名       | lowerCamelCase（首字母小写）                      |
| 常量名              | lowerCamelCase（文件级或 static let）             |
| 文件名              | UpperCamelCase.swift（与主要类型同名）            |
| 访问控制            | 默认 internal，必要时使用 public / private        |
| 非隔离              | 纯函数或线程安全类型标记为 nonisolated            |
| 并发安全            | 新类型应符合 Sendable 协议                        |
| 强制解包            | 避免使用 ! ；优先 if let / guard let              |
| 注释                | 公共 API 使用 Markdown 文档注释                   |
| MARK 标记           | 使用 MARK: - / MARK: 分组代码                     |
+---------------------+---------------------------------------------------+

### 模型设计原则

1. Codable 优先：所有持久化模型必须符合 Codable
2. Identifiable：列表呈现的模型必须符合 Identifiable
3. Hashable：用于集合和 SwiftUI 动画的模型应符合 Hashable
4. Sendable：Swift 6 并发兼容，跨线程安全
5. nonisolated：纯数据模型在非隔离上下文中可用
6. 可选字段合理使用：避免滥用 ! 强制解包

### 管理器设计原则

1. 单例模式：辅助管理器（CalendarManager、OCRManager、ImageCache、WidgetDataSyncManager）使用 static let shared
2. 中央状态：DataManager 作为唯一的 @EnvironmentObject
3. async/await：所有耗时操作使用 Swift 并发
4. @MainActor：UI 更新相关的管理器方法标记为主演员
5. 错误处理：throwing 方法向上传递错误，由视图层显示

### 视图设计原则

1. 轻量级视图：视图仅呈现状态，不包含业务逻辑
2. @EnvironmentObject：通过 DataManager 访问共享状态
3. 可复用组件：通用 UI 提取为子视图（SubjectScoreCard、AvatarView 等）
4. 动画与渐变：卡片使用渐变描边，列表使用进场动画
5. NavigationStack：使用现代导航 API
6. .task 修饰符：异步加载数据，不使用 onAppear + @State

### 本地化约定

+-------------------+------------------------------------------------+
| 语言代码          | 说明                                           |
+-------------------+------------------------------------------------+
| en                | English（英文，默认）                          |
| zh-Hans           | 简体中文                                       |
| zh-Hant           | 繁体中文                                       |
| ja                | 日本語                                         |
| ko                | 한국어                                         |
| nil               | 跟随系统                                       |
+-------------------+------------------------------------------------+

+ 字符串全部通过 NSLocalizedString() 访问
+ 新增文案需在所有 .lproj 中同步翻译
+ 键名格式: "section_description"（小写 + 下划线 + 描述性）

### 教育体系扩展指南

添加一个新的教育体系需要以下步骤：

1. 确定教育阶段（EducationStage）和分类（EducationCategory）
2. 设计 SubjectConfig 数组（required + elective 工厂方法）
3. 在 EducationConfig 中添加 EducationRegion 实例
4. 实现 availableRegions(for:) 和 defaultRegion(for:) 覆盖
5. 在数据模型参考和维基文档中添加说明
6. 更新覆盖矩阵表和评分制参考表

================================================================================

## 变更日志

### v2026.06.13 - iPad 适配

- 项目正式支持 iPad（`TARGETED_DEVICE_FAMILY = "1,2"`）
- 新增 `Views/Helpers/iPadLayout.swift`，提供以下自适应辅助组件：
  - `adaptiveMaxWidth(_:)` 修饰符：iPad 上居中并限制最大宽度
  - `AdaptiveHStack`：iPad 上 HStack，iPhone 上 VStack
  - `AdaptiveGridColumns`：按设备形态切换列数
  - `adaptiveCardPadding()`：统一 iPhone/iPad 卡片外边距
- `ContentView` 使用 `.tabViewStyle(.sidebarAdaptable)`（iOS 18+），
  iPad 自动获得原生侧边栏 Tab Bar
- `HomeView`：
  - iPad 上外层容器 `frame(maxWidth: 1100)` 居中
  - `MainStatsCard` 在 iPad 上 4 个统计卡片排成一行（iPhone 为 2x2 网格）
  - 欢迎头部 / 快捷操作 / 考试 / 图表等分区使用 `AdaptiveHStack` 实现双列布局
- `SettingsView`（720）、`PreferencesView`（640）、`TrendsView`（900）、
  `MistakeView`（900）、`ExamView`（800）均使用 `.adaptiveMaxWidth` 保持
  iPad 上表单 / 列表内容居中且可读
- iPhone 布局完全保持原样；所有 iPad 行为均由
  `horizontalSizeClass == .regular` 或 `UIDevice.current.userInterfaceIdiom` 控制
- 在 iPad Pro 11-inch (M5) 模拟器与 iPhone 模拟器上构建通过，无警告

================================================================================

## Git 提交约定

```
<类型>: <简短描述>

<详细描述（可选）>
```

+ 类型: feat（新功能）、fix（修复）、docs（文档）、style（格式）、refactor（重构）、test（测试）、chore（构建/工具）
+ 简短描述: 英文或中文均可，不超过 72 字符