# StudyPulse 代码 Wiki

> 一款综合性学习管理应用，帮助学生追踪学业表现、分析学习趋势，并高效管理学习资料。

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 技术栈与环境要求](#2-技术栈与环境要求)
- [3. 项目结构](#3-项目结构)
- [4. 架构设计](#4-架构设计)
- [5. 数据模型](#5-数据模型)
- [6. 核心管理器](#6-核心管理器)
- [7. 视图层](#7-视图层)
- [8. 组件与辅助工具](#8-组件与辅助工具)
- [9. 扩展](#9-扩展)
- [10. 通知系统](#10-通知系统)
- [11. 国际化](#11-国际化)
- [12. 依赖关系](#12-依赖关系)
- [13. 数据流](#13-数据流)
- [14. 运行方式](#14-运行方式)
- [15. 构建配置](#15-构建配置)

---

## 1. 项目概览

| 项目 | 说明 |
|------|------|
| **应用名称** | StudyPulse |
| **Bundle 标识符** | `Gao.Chenkai.StudyPulse` |
| **版本号** | 1.0（市场版本） |
| **开发者** | Gao-Chenkai |
| **许可证** | CC BY-NC-SA 4.0 |

### 核心功能

| 功能 | 说明 |
|------|------|
| **多科目成绩追踪** | 记录多门科目的分数，支持原始分和排名 |
| **交互式图表可视化** | 使用 Apple Charts 框架可视化成绩趋势和排名 |
| **考试管理** | 创建、查看和管理单科与综合考试，支持倒计时 |
| **错题集管理** | 整理错题并进行详细分析（标题、错因、错解、正解） |
| **照片上传** | 拍摄或选择试卷和错题照片 |
| **考试通知** | 本地通知，提供 30/10/5/3/1 天倒计时提醒 |
| **用户档案** | 存储教育阶段、教育体系、地区和所选科目 |
| **每日励志语录** | 14 条轮换的励志语录，显示在主页 |

---

## 2. 技术栈与环境要求

| 层级 | 技术 |
|------|------|
| **UI 框架** | SwiftUI |
| **编程语言** | Swift 6.0 |
| **最低系统版本** | iOS 18.6 |
| **Xcode 版本** | Xcode 26.x |
| **图表** | Apple Charts 框架（原生） |
| **数据持久化** | JSON 文件序列化，存储于 Documents 目录 |
| **引导页** | WSOnBoarding（第三方包） |
| **通知** | UserNotifications 框架 |
| **相机/相册** | UIKit UIImagePickerController（通过 UIViewControllerRepresentable） |

### 支持平台

- iPhone（`iOS`）
- iPad（iPadOS）
- Mac Catalyst：**不支持**

---

## 3. 项目结构

```
StudyPulse/
├── StudyPulse.xcodeproj/          # Xcode 项目配置
│   └── project.pbxproj
│
├── StudyPulse/                    # 主应用源码
│   ├── StudyPulseApp.swift        # 应用入口
│   │
│   ├── Models/
│   │   └── DataModels.swift       # 核心数据模型（Subject, Grade, Exam 等）
│   │
│   ├── Managers/
│   │   ├── DataManager.swift      # 中央数据管理与持久化
│   │   ├── StringsLocalized.swift # 字符串本地化扩展
│   │   └── SubjectInfo.swift      # 按教育阶段计算满分
│   │
│   ├── Extensions/
│   │   ├── ColorExtensions.swift  # UIColor → Color 桥接
│   │   └── DateExtensions.swift   # 日期格式化辅助
│   │
│   ├── NotificationsControl/
│   │   └── ExamPrepareNotifications.swift  # 本地通知调度
│   │
│   ├── Views/
│   │   ├── ContentView.swift      # 主 TabView 导航
│   │   ├── HomeView.swift         # 数据仪表盘，含统计与趋势
│   │   ├── TrendsView.swift       # 成绩趋势图表
│   │   ├── ExamView.swift         # 考试列表，按时间分组
│   │   ├── ExamDetailView.swift   # 单个考试详情展示
│   │   ├── ExamDetailEditView.swift # 编辑考试详情表单
│   │   ├── NewExamSetView.swift   # 创建新考试表单
│   │   ├── AddGradeView.swift     # 添加成绩录入表单
│   │   ├── MistakeView.swift      # 错题集列表
│   │   ├── MistakeDetailEditView.swift # 编辑错题详情
│   │   ├── NewMistakeSetView.swift # 创建新错题条目
│   │   ├── SettingsView.swift     # 用户档案与设置
│   │   ├── SubjectScoreCard.swift # 科目分数卡片，含迷你图表
│   │   │
│   │   ├── Components/
│   │   │   ├── GradeChartView.swift    # 成绩折线图
│   │   │   └── SubjectPickerView.swift # 科目选择器
│   │   │
│   │   ├── Helpers/
│   │   │   ├── BackgroundColors.swift  # 自适应背景色
│   │   │   ├── ImagePicker.swift       # 相册选择器
│   │   │   ├── PhotoCaptureView.swift  # 相机拍摄
│   │   │   └── ScoreColor.swift        # 分数到颜色的映射
│   │   │
│   │   ├── OnBoarding/
│   │   │   └── WelcomeConfig.swift     # 引导页配置
│   │   │
│   │   └── Sheets/
│   │       └── NewMistakeSheet.swift   # 新建错题弹出页
│   │
│   ├── StudyPulseIcon.icon/      # 应用图标配置
│   └── Assets.xcassets/          # 图片与颜色资源
│
├── zh-Hans.lproj/
│   └── Localizable.strings       # 简体中文翻译
├── en.lproj/
│   └── Localizable.strings       # 英文字符串
│
├── README.md                     # 项目说明
├── LICENSE                       # CC BY-NC-SA 4.0 许可证
└── .gitignore
```

---

## 4. 架构设计

StudyPulse 采用**受 MVVM 启发的架构**，结合 SwiftUI 的声明式范式：

```
┌─────────────────────────────────────────────────────────┐
│                     视图层（SwiftUI）                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ HomeView │ │TrendsView│ │ ExamView │ │SettingsView│  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘   │
│       └─────────────┴────────────┴────────────┘         │
│                         │                               │
│              @EnvironmentObject<DataManager>             │
└─────────────────────────┼───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                     管理器层                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐ │
│  │ DataManager  │ │ SubjectInfo  │ │ExamPrepareNotif. │ │
│  │ （可观察对象） │ │ （辅助类）   │ │ （调度器）       │ │
│  └──────┬───────┘ └──────────────┘ └──────────────────┘ │
│         │                                                │
│   JSON 持久化（Documents/）                              │
└─────────┼───────────────────────────────────────────────┘
          │
┌─────────▼───────────────────────────────────────────────┐
│                     模型层                                │
│  ┌────────┐ ┌───────┐ ┌──────────┐ ┌──────────┐        │
│  │ Subject│ │ Grade │ │  Exam    │ │MistakeNote│       │
│  └────────┘ └───────┘ └──────────┘ └──────────┘        │
│  ┌──────────────────┐ ┌──────────┐                      │
│  │comprehensiveExam │ │UserProfile│                     │
│  └──────────────────┘ └──────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### 关键架构模式

| 模式 | 实现方式 |
|------|----------|
| **集中式状态管理** | `DataManager` 作为应用根节点的 `@StateObject`，通过 `@EnvironmentObject` 传递 |
| **可观察数据** | `DataManager` 遵循 `ObservableObject`，使用 `@Published` 属性 |
| **导航** | `TabView` 包含 4 个标签页（主页、趋势、考试、设置）；每个标签页内使用 `NavigationStack` |
| **弹出页展示** | 使用 `.sheet` 修饰符展示表单（AddGradeView、NewExamSetView 等） |
| **数据持久化** | JSON 编码/解码到 `FileManager.default.urls(for: .documentDirectory)` 中的文件 |
| **响应式更新** | `@Published` 在数据变更时自动触发 UI 刷新 |

---

## 5. 数据模型

所有数据模型定义于 [DataModels.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Models/DataModels.swift)，均遵循 `Identifiable`、`Codable` 和 `Equatable` 协议。

### 5.1 Subject（科目）

```swift
class Subject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String      // 如 "Chinese"、"Mathematics"
    var enabled: Bool     // 该科目是否启用
}
```

表示单个学科科目。用于过滤成绩、在考试中选择科目以及配置用户档案。

### 5.2 Grade（成绩）

```swift
struct Grade: Identifiable, Codable, Equatable {
    let id: UUID
    var subject: String        // 科目名称
    var score: Double?         // 标准化分数（0-100 比例）
    var rawScore: Double?      // 原始考试分数（卷面分）
    var ranking: Int?          // 班级/年级排名
    var importance: Int        // 重要程度（1-5 星）
    var image: String?         // 照片文件名
    var date: Date             // 考试日期
    var examName: String       // 所属考试名称
}
```

记录单个科目的成绩条目。同时支持标准化分数和原始分数。

### 5.3 MistakeNote（错题记录）

```swift
struct MistakeNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String                  // 错题标题
    var originalQuestion: String       // 原始题目文本
    var source: String                 // 来源（哪场考试）
    var date: Date                     // 记录日期
    var errorReason: String            // 出错原因
    var wrongSolution: String          // 错误的解答
    var correctSolution: String        // 正确的解答
    var images: [String]               // 关联的照片文件名
}
```

详细的错题记录，采用四段式分析结构。

### 5.4 UserProfile（用户档案）

```swift
struct UserProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var username: String
    var age: Int
    var educationLevel: String      // "Primary School"、"Middle School"、"High School"
    var educationSystem: String     // 如 "Chinese"、"IB" 等
    var region: String              // 地理区域
    var selectedSubjects: [String]  // 已选科目名称
    var theme: String               // UI 主题偏好
}
```

存储用户的个人和学业信息。用于分数标准化和个性化展示。

### 5.5 Exam（考试）

```swift
struct Exam: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var examDate: Date
    var importance: Int             // 1-5 星
    var subject: String             // 单科
    var examName: String            // 所属考试名称
    var masteryDegree: Double       // 0.0 - 1.0 掌握程度百分比
}
```

单科考试条目，支持倒计时和掌握程度追踪。

### 5.6 ComprehensiveExam（综合考试）

```swift
struct ComprehensiveExam: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var examDate: Date
    var importance: Int
    var subject: [String]           // 多科目
    var examName: String
    var masteryDegree: Double
}
```

多科目考试，将多个科目捆绑在一个考试事件下。

---

## 6. 核心管理器

### 6.1 DataManager（数据管理器）

**文件：** [DataManager.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/DataManager.swift)

中央数据管理中枢。遵循 `ObservableObject`，通过 JSON 持久化管理所有应用数据。

#### 已发布属性（@Published）

| 属性 | 类型 | 说明 |
|------|------|------|
| `grades` | `[Grade]` | 所有已记录的成绩 |
| `subjects` | `[Subject]` | 可用的学科科目 |
| `mistakeSets` | `[MistakeNote]` | 所有错题记录 |
| `examSets` | `[Exam]` | 所有单科考试 |
| `comprehensiveExamSets` | `[ComprehensiveExam]` | 所有综合考试 |
| `profile` | `UserProfile` | 当前用户档案 |

#### 核心方法

| 方法 | 说明 |
|------|------|
| `init()` | 初始化默认科目并从 JSON 文件加载所有数据 |
| `loadData()` | 从 Documents 目录读取所有 JSON 文件并解码为数组 |
| `saveData()` | 将所有数据数组编码为 JSON 文件保存到 Documents 目录 |
| `getDocumentsDirectory()` | 返回应用 Documents 目录的 URL |
| `addGrade(_:)` | 添加成绩并保存 |
| `removeGrade(_:)` | 删除成绩并保存 |
| `addSubject(_:)` | 添加科目并保存 |
| `removeSubject(_:)` | 删除科目并保存 |
| `toggleSubject(_:)` | 切换科目的启用/禁用状态 |
| `addMistakeSet(_:)` | 添加错题记录并保存 |
| `removeMistakeSet(_:)` | 删除错题记录并保存 |
| `addExamSet(_:)` | 添加考试并保存 |
| `removeExamSet(_:)` | 删除考试并保存 |
| `addComprehensiveExam(_:)` | 添加综合考试并保存 |
| `removeComprehensiveExam(_:)` | 删除综合考试并保存 |
| `updateExam(_:)` | 更新现有考试并保存 |
| `updateComprehensiveExam(_:)` | 更新现有综合考试并保存 |
| `updateProfile(_:)` | 更新用户档案并保存 |

#### 数据持久化格式

每种数据类型存储为独立的 JSON 文件：

| 文件 | 内容 |
|------|------|
| `grades.json` | Grade 对象数组 |
| `subjects.json` | Subject 对象数组 |
| `mistakeSets.json` | MistakeNote 对象数组 |
| `examSets.json` | Exam 对象数组 |
| `comprehensiveExamSets.json` | ComprehensiveExam 对象数组 |
| `profile.json` | 单个 UserProfile 对象 |

#### 默认科目

首次启动时初始化：

| 科目 | 是否启用 |
|------|----------|
| 语文（Chinese） | 是 |
| 数学（Mathematics） | 是 |
| 英语（English） | 是 |
| 科学（Science） | 是 |
| 历史与社会（History & Society） | 是 |
| 物理（Physics） | 是 |
| 化学（Chemistry） | 是 |
| 生物（Biology） | 是 |
| 历史（History） | 是 |
| 地理（Geography） | 是 |
| 政治（Politics） | 是 |
| 信息技术（Information Technology） | 是 |
| 通用技术（General Technology） | 是 |
| 美术（Art） | 是 |
| 音乐（Music） | 是 |
| 体育与健康（PE & Health） | 是 |

### 6.2 SubjectInfo（科目信息）

**文件：** [SubjectInfo.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/SubjectInfo.swift)

辅助类，根据教育阶段和科目计算最高可能分数。

```swift
func getMaxScore(level: String, subject: String) -> Double
```

| 教育阶段 | 科目 | 满分 |
|----------|------|------|
| 小学 | 所有科目 | 100 |
| 初中 | 语文、数学、英语 | 120 |
| 初中 | 科学 | 160 |
| 初中 | 其他科目 | 100 |
| 高中 | 语文、数学、英语 | 150 |
| 高中 | 其他科目 | 100 |

用于分数标准化（将原始分转换为百分比分数）。

### 6.3 StringsLocalized（字符串本地化）

**文件：** [StringsLocalized.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Managers/StringsLocalized.swift)

对 `String` 的简单扩展，提供 `NSLocalizedString` 的简写形式：

```swift
extension String {
    func localized() -> String {
        return NSLocalizedString(self, comment: "")
    }
}
```

---

## 7. 视图层

### 7.1 应用入口

**文件：** [StudyPulseApp.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/StudyPulseApp.swift)

```swift
@main
struct StudyPulseApp: App
```

#### 职责

1. 创建并持有 `DataManager` 作为 `@StateObject`
2. 通过 `NotificationCoordinator` 配置 `UNUserNotificationCenter` 代理
3. 启动时请求通知权限
4. 用 `WSOnBoarding` 引导页包装 `ContentView`
5. 将 `DataManager` 注入环境

#### NotificationCoordinator

实现 `UNUserNotificationCenterDelegate`：
- `willPresent`：以横幅形式展示通知，附带声音和角标
- `didReceive`：用户点击通知时清除角标数量

### 7.2 ContentView（主视图）

**文件：** [ContentView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ContentView.swift)

主标签页导航容器。

| 标签页 | 图标 | 视图 | 标签值 |
|--------|------|------|--------|
| 主页 | `house.fill` | HomeView | 0 |
| 趋势 | `chart.bar.fill` | TrendsView | 1 |
| 考试 | `list.bullet.clipboard` | ExamView | 3 |
| 设置 | `gearshape.fill` | SettingsView | 4 |

> 注意：错题标签页（标签值 2）当前已被注释/禁用。

使用 `UIImpactFeedbackGenerator` 在标签页切换时提供触觉反馈。

### 7.3 HomeView（主页）

**文件：** [HomeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/HomeView.swift)

主数据仪表盘页面。应用中最大的视图文件（约 783 行）。

#### 关键组件

| 组件 | 说明 |
|------|------|
| `WelcomeCardView` | 顶部卡片，含问候语、每日语录和快捷统计 |
| `StatCardView` | 可复用的统计展示卡片（图标、标签、数值） |
| `GradeDetailView` | 可滚动的近期成绩列表，含分数详情 |
| `UpcomingExamCard` | 显示两周内即将到来的考试 |
| `HomeMainInfoView` | 主页所有区域的容器 |
| `DailyQuoteCard` | 显示每日励志语录 |

#### 每日语录系统

- `dailyQuotes`：包含 14 条励志语录的数组
- `dailyQuote`：计算属性，根据一年中的第几天选择一条语录（循环遍历数组）

#### 显示的统计数据

| 统计卡片 | 数据来源 |
|----------|----------|
| 考试总次数 | `dataManager.examSets.count + dataManager.comprehensiveExamSets.count` |
| 即将到来的考试 | 2 周内的考试 |
| 整体平均分 | 所有成绩分数的平均值 |
| 最新成绩 | 最近一次录入的成绩 |

### 7.4 TrendsView（趋势页）

**文件：** [TrendsView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/TrendsView.swift)

成绩趋势分析与可视化页面。

#### 功能

| 功能 | 说明 |
|------|------|
| 分数/排名切换 | 在分数和排名显示模式之间切换 |
| 时间范围筛选 | 全部 / 3 个月 / 6 个月 / 1 年 |
| 科目详情视图 | 每个科目可展开的详细信息 |
| Charts 集成 | 使用 Apple Charts 框架绘制折线/点标记 |

#### SubjectDetailView

内部视图，展示特定科目的图表和成绩列表：
- X 轴为日期、Y 轴为分数/排名的折线图
- 可滚动的单项成绩列表，分数带颜色编码
- 通过滑动手势支持删除

### 7.5 ExamView（考试页）

**文件：** [ExamView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamView.swift)

考试管理列表视图。

#### 功能

| 功能 | 说明 |
|------|------|
| 合并显示 | 将 `examSets` 和 `comprehensiveExamSets` 合并为 `allExams` |
| 时间分组 | 将考试分为：一周内、一个月内、后续 |
| 滑动删除 | 支持左滑删除并确认 |
| 倒计时显示 | 显示距离每场考试的剩余天数 |

#### ExamRowView

显示单个考试行，包含：
- 考试名称和日期
- 科目标签（综合考试为多个）
- 重要程度星标（1-5）
- 掌握程度进度条
- 剩余天数倒计时

### 7.6 ExamDetailView（考试详情页）

**文件：** [ExamDetailView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamDetailView.swift)

只读考试详情展示。

#### 布局区域

| 区域 | 内容 |
|------|------|
| 概览 | 考试名称、日期、科目标签 |
| 指标 | 重要程度（星形图标）、掌握程度（进度条） |
| 倒计时 | 大字号剩余天数展示 |

### 7.7 ExamDetailEditView（考试详情编辑页）

**文件：** [ExamDetailEditView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/ExamDetailEditView.swift)

用于编辑现有考试详情的表单。字段包括：
- 考试名称（TextField）
- 科目（禁用，显示当前科目）
- 日期（DatePicker）
- 重要程度（1-5 星选择器）
- 掌握程度（滑块）
- 备注（TextEditor）

### 7.8 NewExamSetView（新建考试页）

**文件：** [NewExamSetView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/NewExamSetView.swift)

创建新考试的表单。

#### 功能

| 功能 | 说明 |
|------|------|
| 考试类型切换 | 单科 vs 综合考试 |
| 科目多选 | 为综合考试选择多个科目 |
| 日期选择器 | 选择考试日期 |
| 重要程度选择器 | 1-5 星评分 |
| 掌握程度滑块 | 0-100% 滑块 |

### 7.9 AddGradeView（添加成绩页）

**文件：** [AddGradeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/AddGradeView.swift)

录入新成绩的表单。

#### 功能

| 功能 | 说明 |
|------|------|
| 考试类型 | 单科或综合考试 |
| 考试选择 | 从已有考试中选择 |
| 科目选择器 | 选择科目（综合考试可多选） |
| 分数输入 | 标准化分数输入 |
| 原始分开关 | 可选的原始分/卷面分录入 |
| 排名开关 | 可选的排名录入 |
| 重要程度选择器 | 1-5 星评分 |
| 图片上传 | 附加考试照片 |

#### ScoreControlView / RankingControlView

AddGradeView 内的辅助子视图，用于分数和排名输入，带 +/- 增减按钮。

### 7.10 MistakeView（错题页）

**文件：** [MistakeView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/MistakeView.swift)

错题集列表和详情视图。

#### 功能

| 功能 | 说明 |
|------|------|
| 列表视图 | 显示所有错题记录，含标题、来源和日期 |
| 详情视图 | 完整的四段式错题分析 |
| 导航 | NavigationStack 支持详情页推送 |

### 7.11 MistakeDetailEditView（错题详情编辑页）

**文件：** [MistakeDetailEditView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/MistakeDetailEditView.swift)

详细的错题编辑表单，包含四个可折叠区域：

| 区域 | 用途 |
|------|------|
| 题目 | 原始考试题目 |
| 错因 | 出错原因分析 |
| 错解 | 尝试过的错误解答 |
| 正解 | 正确答案 |

每个区域通过开关独立展开/折叠。

### 7.12 NewMistakeSetView（新建错题页）

**文件：** [NewMistakeSetView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/NewMistakeSetView.swift)

创建新错题条目的表单。

#### 字段

| 字段 | 类型 |
|------|------|
| 标题 | TextField |
| 科目 | Picker（从已启用的科目中选择） |
| 日期 | DatePicker |
| 重要程度 | 星形选择器（1-5） |
| 来源 | TextField（哪场考试） |
| 题目 | 可折叠 TextEditor |
| 错因 | 可折叠 TextEditor |
| 错解 | 可折叠 TextEditor |
| 正解 | 可折叠 TextEditor |
| 图片 | 相机拍摄/相册选择支持 |

### 7.13 NewMistakeSheet（新建错题弹出页）

**文件：** [NewMistakeSheet.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Sheets/NewMistakeSheet.swift)

基于 `.sheet` 弹出的新建错题表单版本。将类似 `NewMistakeSetView` 的内容包裹在带导航栏的弹出页中。

### 7.14 SettingsView（设置页）

**文件：** [SettingsView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/SettingsView.swift)

应用设置与配置页面。与设置相关的最大文件（约 576 行）。

#### 区域

| 区域 | 内容 |
|------|------|
| **用户档案** | 用户名、年龄、教育阶段、教育体系、地区 |
| **学业信息** | 编辑科目（启用/禁用）、已选科目 |
| **关于** | 应用描述、功能列表、GitHub 链接 |
| **版权信息** | CC BY-NC-SA 4.0 许可证详情 |
| **测试** | 5 秒后发送测试通知（用于调试） |

#### 子视图

| 视图 | 说明 |
|------|------|
| `EditSubjectsView` | 切换单个科目的启用/禁用 |
| `ProfileEditView` | 编辑用户档案字段 |
| `AboutView` | 应用信息、功能和 GitHub 链接 |
| `CopyrightView` | 许可证信息 |
| `LicenseDetailView` | 完整的 CC BY-NC-SA 4.0 许可证文本 |
| `SectionHeader` | 可复用的区域标题，含可选操作按钮 |

### 7.15 SubjectScoreCard（科目分数卡片）

**文件：** [SubjectScoreCard.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/SubjectScoreCard.swift)

可复用的卡片组件，用于展示科目的分数信息。

#### 功能

| 功能 | 说明 |
|------|------|
| 分数/排名切换 | 切换显示模式 |
| 分数历史 | 该科目过往成绩列表 |
| 迷你图表 | 显示趋势的小型折线图（miniChartView） |
| 删除支持 | 滑动删除单项成绩 |

#### ChartDataPoint

用于图表渲染的内部结构体：
```swift
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}
```

---

## 8. 组件与辅助工具

### 8.1 GradeChartView（成绩图表视图）

**文件：** [GradeChartView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Components/GradeChartView.swift)

使用 Apple Charts 框架为特定科目成绩绘制简单折线图。

```swift
struct GradeChartView: View {
    let grades: [Grade]
    let subject: String
    // 按科目过滤成绩，按日期排序，渲染折线 + 点标记
}
```

### 8.2 SubjectPickerView（科目选择器）

**文件：** [SubjectPickerView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Components/SubjectPickerView.swift)

可复用的选择器，仅显示已启用的科目：

```swift
struct SubjectPickerView: View {
    @Binding var selectedSubject: String
    let subjects: [Subject]
    // 按 .enabled 属性过滤科目
}
```

### 8.3 BackgroundColors（背景色）

**文件：** [BackgroundColors.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/BackgroundColors.swift)

根据配色方案自适应背景色：

```swift
func getBackgroundColor(_ colorScheme: ColorScheme) -> Color
// 浅色模式：systemGray6
// 深色模式：systemBackground
```

### 8.4 ImagePicker（图片选择器）

**文件：** [ImagePicker.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/ImagePicker.swift)

`UIViewControllerRepresentable` 包装器，用于 `UIImagePickerController` 从相册选择图片。

### 8.5 PhotoCaptureView（相机拍摄视图）

**文件：** [PhotoCaptureView.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/PhotoCaptureView.swift)

`UIViewControllerRepresentable` 包装器，用于 `UIImagePickerController`，设置 `sourceType = .camera` 进行直接相机拍摄。

### 8.6 ScoreColor（分数颜色）

**文件：** [ScoreColor.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/Helpers/ScoreColor.swift)

将数值分数映射到语义化颜色：

| 分数范围 | 颜色 |
|----------|------|
| >= 120 | systemGreen（绿色） |
| >= 90 | systemBlue（蓝色） |
| >= 60 | systemOrange（橙色） |
| < 60 | systemRed（红色） |

---

## 9. 扩展

### 9.1 ColorExtensions（颜色扩展）

**文件：** [ColorExtensions.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Extensions/ColorExtensions.swift)

将 UIKit 的 UIColor 常量桥接到 SwiftUI 的 Color：

| 扩展 | 映射到 |
|------|--------|
| `Color.systemBackground` | `UIColor.systemBackground` |
| `Color.secondarySystemBackground` | `UIColor.secondarySystemBackground` |
| `Color.systemGray6` | `UIColor.systemGray6` |

### 9.2 DateExtensions（日期扩展）

**文件：** [DateExtensions.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Extensions/DateExtensions.swift)

日期格式化的便捷方法：

```swift
extension Date {
    func formatted(date style: DateFormatter.Style, time style2: DateFormatter.Style) -> String
}
```

---

## 10. 通知系统

**文件：** [ExamPrepareNotifications.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/NotificationsControl/ExamPrepareNotifications.swift)

管理考试倒计时提醒的本地通知。

### 核心方法

| 方法 | 说明 |
|------|------|
| `requestAuthorization()` | 请求用户的本地通知权限 |
| `scheduleNotifications(for: examName, date: examDate)` | 调度一系列倒计时通知 |
| `cancelNotifications(for: examName)` | 取消特定考试的所有通知 |

### 通知调度计划

| 距离考试天数 | 通知内容 |
|--------------|----------|
| 30 天 | "距离 [examName] 还有 30 天" |
| 10 天 | "距离 [examName] 还有 10 天" |
| 5 天 | "距离 [examName] 还有 5 天" |
| 3 天 | "距离 [examName] 还有 3 天" |
| 1 天 | "距离 [examName] 还有 1 天" |

每条通知均调度在对应倒计时日的上午 8:00，使用日历组件进行周期性投递。

### 使用流程

1. 在 `NewExamSetView` 中创建新考试时，调用 `ExamPrepareNotifications.scheduleNotifications(for: date:)`
2. 删除考试时，调用 `ExamPrepareNotifications.cancelNotifications(for:)`
3. `SettingsView` 中包含一个调试选项，可在 5 秒后发送测试通知

---

## 11. 国际化

StudyPulse 支持两种语言环境：

| 语言 | 文件 | 状态 |
|------|------|------|
| 英语（en） | [en.lproj/Localizable.strings](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/en.lproj/Localizable.strings) | 最小化（回退语言） |
| 简体中文（zh-Hans） | [zh-Hans.lproj/Localizable.strings](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/zh-Hans.lproj/Localizable.strings) | 完整翻译 |

### 本地化分类

| 分类 | 键值 |
|------|------|
| AddGradeView | GROUP、Exam Details、Exam Name、Score、Ranking 等 |
| ContentView | Home、Trends、Mistakes、Exams、Settings |
| ExamView | Within 1 Week、Within 1 Month、Later、Delete 等 |
| HomeView | Welcome back、Total Exams、Dashboard 等 |
| SettingsView | User Information、Edit Profile、About、Copyright 等 |
| Subjects | 全部 16 个科目名称（Chinese、Mathematics、English 等） |

使用方式：
```swift
"Total Exams".localized()  // 在 zh-Hans 下返回 "考试总次数"
```

---

## 12. 依赖关系

### 第三方包

| 包名 | 仓库地址 | 用途 |
|------|----------|------|
| **WSOnBoarding** | [github.com/Jewel591/WSOnBoarding](https://github.com/Jewel591/WSOnBoarding) | 引导页/欢迎页面，展示功能亮点 |

### WSOnBoarding 配置

**文件：** [WelcomeConfig.swift](file:///Users/chenkaigao/Documents/Program/Swift/StudyPulse/StudyPulse/Views/OnBoarding/WelcomeConfig.swift)

| 功能项 | 图标 | 颜色 |
|--------|------|------|
| 图表分析 | `list.clipboard` | 蓝色 |
| 毫秒级响应 | `bolt.fill` | 橙色 |
| 离线支持 | `wifi.slash` | 绿色 |

应用图标：`graduationcap.fill`，主色调：蓝色

### 使用的原生框架

| 框架 | 用途 |
|------|------|
| `SwiftUI` | UI 框架 |
| `Charts` | 数据可视化 |
| `UserNotifications` | 本地通知 |
| `UIKit` | 图片选择器、视图控制器 |
| `AVFoundation` | 相机支持 |
| `Combine` | 响应式编程（SubjectInfo） |
| `Foundation` | 数据类型、JSON 编码、日期处理 |

---

## 13. 数据流

### 13.1 添加成绩

```
用户在主页/趋势页点击 + 按钮
       │
       ▼
以 .sheet 形式弹出 AddGradeView
       │
       ▼
用户填写表单（考试、科目、分数、排名、重要程度）
       │
       ▼
用户点击"保存"
       │
       ▼
dataManager.addGrade(newGrade)
       │
       ├──► grades.append(newGrade)
       ├──► saveData() → grades.json
       │
       ▼
@Published 触发自动 UI 更新
       │
       ▼
弹出页关闭，视图以新数据刷新
```

### 13.2 创建考试

```
用户在考试页点击 + 按钮
       │
       ▼
以 .sheet 形式弹出 NewExamSetView
       │
       ▼
用户选择考试类型（单科/综合）、科目、日期等
       │
       ▼
用户点击"保存"
       │
       ├──► dataManager.addExamSet() 或 .addComprehensiveExam()
       ├──► ExamPrepareNotifications.scheduleNotifications(for: date)
       │
       ▼
视图刷新，通知已调度
```

### 13.3 数据持久化周期

```
应用启动
    │
    ▼
DataManager.init()
    │
    ├──► 初始化默认科目（16 个科目）
    ├──► loadData()
    │       │
    │       ├──► 读取 grades.json → 解码 → grades[]
    │       ├──► 读取 subjects.json → 解码 → subjects[]
    │       ├──► 读取 mistakeSets.json → 解码 → mistakeSets[]
    │       ├──► 读取 examSets.json → 解码 → examSets[]
    │       ├──► 读取 comprehensiveExamSets.json → 解码 → comprehensiveExamSets[]
    │       └──► 读取 profile.json → 解码 → profile
    │
    ▼
应用就绪

任意数据修改
    │
    ▼
saveData()
    │
    ├──► 编码 grades[] → grades.json
    ├──► 编码 subjects[] → subjects.json
    ├──► 编码 mistakeSets[] → mistakeSets.json
    ├──► 编码 examSets[] → examSets.json
    ├──► 编码 comprehensiveExamSets[] → comprehensiveExamSets.json
    └──► 编码 profile → profile.json
```

---

## 14. 运行方式

### 前置要求

| 要求 | 版本 |
|------|------|
| macOS | 最新版（兼容 Xcode 26） |
| Xcode | 26.x |
| iOS 部署目标 | 18.6+ |
| Swift | 6.0 |

### 步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/Gao-Chenkai/StudyPulse
   cd StudyPulse
   ```

2. **在 Xcode 中打开**
   ```bash
   open StudyPulse.xcodeproj
   ```

3. **解析 Swift Package 依赖**
   - Xcode 应自动从 `https://github.com/Jewel591/WSOnBoarding` 解析 WSOnBoarding
   - 如未自动解析：`File` → `Packages` → `Resolve Package Versions`

4. **选择目标设备**
   - 选择 iPhone 模拟器（iOS 18.6+）或物理设备

5. **构建并运行**
   - 按 `Cmd + R` 或点击运行按钮
   - 首次运行时应用将展示 WSOnBoarding 引导页

### 命令行构建

```bash
# 为模拟器构建
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build

# 为真机构建（需要签名）
xcodebuild -project StudyPulse.xcodeproj \
  -scheme StudyPulse \
  -sdk iphoneos \
  -configuration Release \
  build
```

### 调试技巧

- **测试通知**：前往设置页 → "在 5 秒后进行本地通知接收测试"
- **数据位置**：JSON 文件存储在应用的 Documents 目录中。使用 Xcode 的 Devices & Simulators 窗口下载容器文件。
- **重置数据**：删除应用并重新安装即可重新开始（所有 JSON 文件将被清除）

---

## 15. 构建配置

### 项目设置

| 设置项 | 值 |
|--------|-----|
| **Bundle 标识符** | `Gao.Chenkai.StudyPulse` |
| **Swift 版本** | 6.0 |
| **C++ 标准** | gnu++20 |
| **C 标准** | gnu17 |
| **开发团队** | D2G8858WRZ |
| **代码签名方式** | 自动（Automatic） |

### 部署目标

| 平台 | 版本 |
|------|------|
| iOS | 18.6 |
| Xcode 构建目标 | 26.0 |

### 构建配置

| 设置项 | Debug（调试） | Release（发布） |
|--------|---------------|-----------------|
| 优化级别 | `-Onone` | `wholemodule` |
| 调试信息 | `dwarf` | `dwarf-with-dsym` |
| 断言 | 启用 | 禁用 |
| 可测试性 | 启用 | 禁用 |
| 产品验证 | 否 | `VALIDATE_PRODUCT = YES` |

### 编译器标志

| 标志 | 值 |
|------|-----|
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | YES |
| `SWIFT_EMIT_LOC_STRINGS` | YES |
| `CLANG_ENABLE_MODULES` | YES |
| `CLANG_ENABLE_OBJC_ARC` | YES |
| `ENABLE_STRICT_OBJC_MSGSEND` | YES |

### Info.plist 键值（自动生成）

| 键 | 值 |
|-----|-----|
| `UIApplicationSceneManifest_Generation` | YES |
| `UIApplicationSupportsIndirectInputEvents` | YES |
| `UILaunchScreen_Generation` | YES |
| 支持的屏幕方向（iPhone） | 竖屏、横屏左、横屏右 |
| 支持的屏幕方向（iPad） | 竖屏、竖屏倒置、横屏左、横屏右 |

### 支持的设备系列

- iPhone
- iPad
- Mac Catalyst：**已禁用**（`SUPPORTS_MACCATALYST = NO`）







This WIKI is Created by Trea, Qwen3.6-Plus.

Final Revision & Release Approver: Gao Chenkai
