//
//  EducationConfig.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/7.
//

import Foundation

// MARK: - Education Stage (教育阶段)

/// 用户所处的教育阶段
/// 每个阶段对应不同的教育体系和科目配置
nonisolated enum EducationStage: String, CaseIterable, Identifiable, Codable, Sendable {
    case primarySchool = "Primary School"              /// 小学
    case middleSchool = "Middle School"                /// 初中
    case highSchool = "High School"                    /// 高中
    case internationalHighSchool = "International High School"  /// 国际高中
    case university = "University"                     /// 大学
    case graduate = "Graduate"                         /// 研究生
    
    var id: String { rawValue }
    
    /// 用于本地化的 Key
    var localizedKey: String {
        switch self {
        case .primarySchool: return "primary_school"
        case .middleSchool: return "middle_school"
        case .highSchool: return "high_school"
        case .internationalHighSchool: return "international_high_school"
        case .university: return "university"
        case .graduate: return "graduate"
        }
    }
    
    /// 判断该阶段属于国内还是国际体系
    var category: EducationCategory {
        switch self {
        case .primarySchool, .middleSchool, .highSchool:
            return .domestic
        case .internationalHighSchool, .university, .graduate:
            return .international
        }
    }
}

// MARK: - Education Category (教育体系分类)

/// 教育体系分类：国内 / 国际
nonisolated enum EducationCategory: String, CaseIterable, Codable, Sendable {
    case domestic = "Domestic"        /// 国内体系（中国大陆、台湾、香港、新加坡等）
    case international = "International"  /// 国际体系（IB、AP、A-Level、SAT、ACT 等）
}

// MARK: - Education Region (地区教育体系配置)

/// 代表一个地区的教育体系配置（如：浙江高中 3+3、IB Diploma 等）
/// 包含该体系下的所有科目配置
nonisolated struct EducationRegion: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    /// 内部标识名（如 "zhejiang", "ib_dp"）
    let name: String
    /// 显示名称（如 "浙江 (3+3)"）
    let displayName: String
    /// 体系分类（国内/国际）
    let category: EducationCategory
    /// 对应教育阶段
    let stage: EducationStage
    /// 体系标准代号（如 "CN-ZJ-3+3", "IB-DP"）
    let systemCode: String
    /// 该体系包含的科目配置
    let subjects: [SubjectConfig]
    /// 体系备注说明
    let notes: String
}

// MARK: - Subject Config (科目配置)

/// 单个科目的配置信息，用于教育体系中的科目定义
nonisolated struct SubjectConfig: Identifiable, Codable, Hashable, Sendable {
    var id: String { name }
    /// 科目内部标识名（英文）
    let name: String
    /// 科目显示名称（支持中文）
    let displayName: String
    /// 科目满分
    let fullScore: Double
    /// 是否必修
    let isRequired: Bool
    /// 是否选考
    let isElective: Bool
    /// 科目分类（如 IB Group 1-6、A-Level Sciences 等）
    let category: String?
    
    /// 标准初始化
    init(name: String, displayName: String, fullScore: Double,
         isRequired: Bool = false, isElective: Bool = false,
         category: String? = nil) {
        self.name = name
        self.displayName = displayName
        self.fullScore = fullScore
        self.isRequired = isRequired
        self.isElective = isElective
        self.category = category
    }
    
    /// 快捷构造：必修课
    static func required(_ name: String, displayName: String, fullScore: Double, category: String? = nil) -> SubjectConfig {
        SubjectConfig(name: name, displayName: displayName, fullScore: fullScore, isRequired: true, isElective: false, category: category)
    }
    
    /// 快捷构造：选修/选考课
    static func elective(_ name: String, displayName: String, fullScore: Double, category: String? = nil) -> SubjectConfig {
        SubjectConfig(name: name, displayName: displayName, fullScore: fullScore, isRequired: false, isElective: true, category: category)
    }
}

// MARK: - Education Configuration Manager (教育体系配置管理器)
nonisolated enum EducationConfig {
    
    // MARK: - 中国大陆（初中）
    nonisolated private static let cnMiddleSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 120),
        .required("Mathematics", displayName: "数学", fullScore: 120),
        .required("English", displayName: "英语", fullScore: 120),
        .elective("Physics", displayName: "物理", fullScore: 100),
        .elective("Chemistry", displayName: "化学", fullScore: 100),
        .elective("Biology", displayName: "生物", fullScore: 100),
        .elective("Politics", displayName: "政治", fullScore: 100),
        .elective("History", displayName: "历史", fullScore: 100),
        .elective("Geography", displayName: "地理", fullScore: 100)
    ]
    
    // MARK: - 中国大陆（高中）
    nonisolated private static let cnHighSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 150),
        .required("Mathematics", displayName: "数学", fullScore: 150),
        .required("English", displayName: "英语", fullScore: 150),
        .elective("Physics", displayName: "物理", fullScore: 100),
        .elective("Chemistry", displayName: "化学", fullScore: 100),
        .elective("Biology", displayName: "生物", fullScore: 100),
        .elective("Politics", displayName: "政治", fullScore: 100),
        .elective("History", displayName: "历史", fullScore: 100),
        .elective("Geography", displayName: "地理", fullScore: 100)
    ]
    
    // MARK: - 浙江初中（合并科：社会 + 科学）
    nonisolated private static let zhejiangMiddleSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 120),
        .required("Mathematics", displayName: "数学", fullScore: 120),
        .required("English", displayName: "英语", fullScore: 120),
        .required("Science", displayName: "科学", fullScore: 160),
        .required("History & Society", displayName: "历史与社会·道德与法治", fullScore: 100)
    ]
    
    // MARK: - 浙江高中（3+3 模式）
    nonisolated private static let zhejiangHighSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 150),
        .required("Mathematics", displayName: "数学", fullScore: 150),
        .required("English", displayName: "英语", fullScore: 150),
        .elective("Physics", displayName: "物理", fullScore: 100),
        .elective("Chemistry", displayName: "化学", fullScore: 100),
        .elective("Biology", displayName: "生物", fullScore: 100),
        .elective("Politics", displayName: "政治", fullScore: 100),
        .elective("History", displayName: "历史", fullScore: 100),
        .elective("Geography", displayName: "地理", fullScore: 100),
        .elective("Information Technology", displayName: "信息技术", fullScore: 100),
        .elective("General Technology", displayName: "通用技术", fullScore: 100)
    ]
    
    // MARK: - 上海初中
    nonisolated private static let shanghaiMiddleSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 150),
        .required("Mathematics", displayName: "数学", fullScore: 150),
        .required("English", displayName: "英语", fullScore: 150),
        .required("Physics", displayName: "物理", fullScore: 90),
        .required("Chemistry", displayName: "化学", fullScore: 60),
        .required("History & Society", displayName: "社会", fullScore: 100)
    ]
    
    // MARK: - 上海高中
    nonisolated private static let shanghaiHighSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "语文", fullScore: 150),
        .required("Mathematics", displayName: "数学", fullScore: 150),
        .required("English", displayName: "英语", fullScore: 150),
        .elective("Physics", displayName: "物理", fullScore: 100),
        .elective("Chemistry", displayName: "化学", fullScore: 100),
        .elective("Biology", displayName: "生物", fullScore: 100),
        .elective("Politics", displayName: "政治", fullScore: 100),
        .elective("History", displayName: "历史", fullScore: 100),
        .elective("Geography", displayName: "地理", fullScore: 100)
    ]
    
    // MARK: - 台湾高中（学测：数学A/数学B 分卷）
    nonisolated private static let taiwanHighSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "國文", fullScore: 100),
        .elective("Mathematics A", displayName: "數學 A", fullScore: 100, category: "A卷"),
        .elective("Mathematics B", displayName: "數學 B", fullScore: 100, category: "B卷"),
        .required("English", displayName: "英文", fullScore: 100),
        .required("History & Society", displayName: "社會", fullScore: 100),
        .elective("Physics", displayName: "物理", fullScore: 100),
        .elective("Chemistry", displayName: "化學", fullScore: 100),
        .elective("Biology", displayName: "生物", fullScore: 100),
        .elective("History", displayName: "歷史", fullScore: 100),
        .elective("Geography", displayName: "地理", fullScore: 100),
        .elective("Politics", displayName: "公民與社會", fullScore: 100)
    ]
    
    // MARK: - 台湾初中
    nonisolated private static let taiwanMiddleSchool: [SubjectConfig] = [
        .required("Chinese", displayName: "國文", fullScore: 100),
        .required("Mathematics", displayName: "數學", fullScore: 100),
        .required("English", displayName: "英文", fullScore: 100),
        .required("Physics", displayName: "理化", fullScore: 100),
        .required("History & Society", displayName: "社會", fullScore: 100)
    ]
    
    // MARK: - 香港（DSE 模式）
    nonisolated private static let hkDSE: [SubjectConfig] = [
        // 4 核心 + 2-3 选修
        .required("Chinese", displayName: "中國語文", fullScore: 7, category: "核心"),
        .required("English", displayName: "英國語文", fullScore: 7, category: "核心"),
        .required("Mathematics", displayName: "數學", fullScore: 7, category: "核心"),
        .required("Liberal Studies", displayName: "通識教育", fullScore: 7, category: "核心"),
        // 选修
        .elective("Physics", displayName: "物理", fullScore: 7, category: "選修"),
        .elective("Chemistry", displayName: "化學", fullScore: 7, category: "選修"),
        .elective("Biology", displayName: "生物", fullScore: 7, category: "選修"),
        .elective("History", displayName: "歷史", fullScore: 7, category: "選修"),
        .elective("Geography", displayName: "地理", fullScore: 7, category: "選修"),
        .elective("Economics", displayName: "經濟", fullScore: 7, category: "選修"),
        .elective("Chinese History", displayName: "中國歷史", fullScore: 7, category: "選修"),
        .elective("Visual Arts", displayName: "視覺藝術", fullScore: 7, category: "選修"),
        .elective("Music", displayName: "音樂", fullScore: 7, category: "選修")
    ]
    
    // MARK: - 新加坡 O-Level / N-Level
    nonisolated private static let sgOLevel: [SubjectConfig] = [
        .required("English", displayName: "English Language", fullScore: 100),
        .required("Mother Tongue", displayName: "Mother Tongue (Chinese/Malay/Tamil)", fullScore: 100),
        .required("Mathematics", displayName: "Elementary Mathematics", fullScore: 100),
        .elective("Additional Mathematics", displayName: "Additional Mathematics", fullScore: 100),
        .elective("Physics", displayName: "Physics", fullScore: 100),
        .elective("Chemistry", displayName: "Chemistry", fullScore: 100),
        .elective("Biology", displayName: "Biology", fullScore: 100),
        .elective("Combined Science", displayName: "Combined Science", fullScore: 100),
        .elective("History", displayName: "History", fullScore: 100),
        .elective("Geography", displayName: "Geography", fullScore: 100),
        .required("Social Studies", displayName: "Social Studies", fullScore: 100)
    ]
    
    // MARK: - 英国 GCSE / IGCSE
    nonisolated private static let ukIGCSE: [SubjectConfig] = [
        // 核心必修
        .required("English Language", displayName: "English Language", fullScore: 100),
        .elective("English Literature", displayName: "English Literature", fullScore: 100),
        .required("Mathematics", displayName: "Mathematics", fullScore: 100),
        .elective("Combined Science", displayName: "Combined Science (Double Award)", fullScore: 200),
        // 选修
        .elective("Physics", displayName: "Physics", fullScore: 100),
        .elective("Chemistry", displayName: "Chemistry", fullScore: 100),
        .elective("Biology", displayName: "Biology", fullScore: 100),
        .elective("History", displayName: "History", fullScore: 100),
        .elective("Geography", displayName: "Geography", fullScore: 100),
        .elective("Computer Science", displayName: "Computer Science", fullScore: 100),
        .elective("Business Studies", displayName: "Business Studies", fullScore: 100),
        .elective("Economics", displayName: "Economics", fullScore: 100),
        .elective("Religious Studies", displayName: "Religious Studies", fullScore: 100),
        .elective("French", displayName: "French (Foreign Language)", fullScore: 100),
        .elective("Spanish", displayName: "Spanish (Foreign Language)", fullScore: 100),
        .elective("Chinese", displayName: "Chinese (Foreign Language)", fullScore: 100),
        .elective("Art & Design", displayName: "Art & Design", fullScore: 100),
        .elective("Music", displayName: "Music", fullScore: 100),
        .elective("Drama", displayName: "Drama", fullScore: 100)
    ]
    
    // MARK: - 英国 A-Level (Cambridge CIE / Edexcel / AQA / OCR)
    nonisolated private static let ukALevel: [SubjectConfig] = [
        // 母语/语言
        .elective("English Literature", displayName: "English Literature", fullScore: 100),
        .elective("English Language", displayName: "English Language", fullScore: 100),
        .elective("Chinese", displayName: "Chinese", fullScore: 100, category: "Languages"),
        .elective("French", displayName: "French", fullScore: 100, category: "Languages"),
        .elective("Spanish", displayName: "Spanish", fullScore: 100, category: "Languages"),
        .elective("German", displayName: "German", fullScore: 100, category: "Languages"),
        // 数学
        .elective("Mathematics", displayName: "Mathematics", fullScore: 100, category: "Math"),
        .elective("Further Mathematics", displayName: "Further Mathematics", fullScore: 100, category: "Math"),
        // 理科
        .elective("Physics", displayName: "Physics", fullScore: 100, category: "Sciences"),
        .elective("Chemistry", displayName: "Chemistry", fullScore: 100, category: "Sciences"),
        .elective("Biology", displayName: "Biology", fullScore: 100, category: "Sciences"),
        .elective("Human Biology", displayName: "Human Biology", fullScore: 100, category: "Sciences"),
        // 人文
        .elective("History", displayName: "History", fullScore: 100, category: "Humanities"),
        .elective("Geography", displayName: "Geography", fullScore: 100, category: "Humanities"),
        .elective("Economics", displayName: "Economics", fullScore: 100, category: "Humanities"),
        .elective("Business", displayName: "Business", fullScore: 100, category: "Humanities"),
        .elective("Psychology", displayName: "Psychology", fullScore: 100, category: "Humanities"),
        .elective("Sociology", displayName: "Sociology", fullScore: 100, category: "Humanities"),
        .elective("Politics", displayName: "Politics", fullScore: 100, category: "Humanities"),
        .elective("Philosophy", displayName: "Philosophy", fullScore: 100, category: "Humanities"),
        // 创意艺术
        .elective("Art & Design", displayName: "Art & Design", fullScore: 100, category: "Creative"),
        .elective("Music", displayName: "Music", fullScore: 100, category: "Creative"),
        .elective("Drama", displayName: "Drama", fullScore: 100, category: "Creative"),
        .elective("Media Studies", displayName: "Media Studies", fullScore: 100, category: "Creative"),
        // 计算机
        .elective("Computer Science", displayName: "Computer Science", fullScore: 100, category: "Tech")
    ]
    
    // MARK: - IB Diploma Programme
    // 6 个 Group: 1-母语、2-外语、3-人文社会、4-实验科学、5-数学、6-艺术
    // 选 6 门：3 门 HL + 3 门 SL，总分 45（6科24分+TOK1分+EE1分+CAS 0分）
    nonisolated private static let ibDP: [SubjectConfig] = [
        // Group 1: Studies in Language and Literature
        .elective("IB English A: Literature", displayName: "IB English A: Literature", fullScore: 7, category: "Group 1"),
        .elective("IB English A: Language & Literature", displayName: "IB English A: Language & Literature", fullScore: 7, category: "Group 1"),
        .elective("IB Chinese A: Literature", displayName: "IB Chinese A: Literature", fullScore: 7, category: "Group 1"),
        .elective("IB Chinese A: Language & Literature", displayName: "IB Chinese A: Language & Literature", fullScore: 7, category: "Group 1"),
        .elective("IB Self-Taught Language A", displayName: "IB Self-Taught Language A", fullScore: 7, category: "Group 1"),
        // Group 2: Language Acquisition
        .elective("IB English B", displayName: "IB English B", fullScore: 7, category: "Group 2"),
        .elective("IB French B", displayName: "IB French B", fullScore: 7, category: "Group 2"),
        .elective("IB Spanish B", displayName: "IB Spanish B", fullScore: 7, category: "Group 2"),
        .elective("IB Mandarin B", displayName: "IB Mandarin B", fullScore: 7, category: "Group 2"),
        .elective("IB Ab Initio French", displayName: "IB Ab Initio French", fullScore: 7, category: "Group 2"),
        .elective("IB Ab Initio Spanish", displayName: "IB Ab Initio Spanish", fullScore: 7, category: "Group 2"),
        // Group 3: Individuals and Societies
        .elective("IB History", displayName: "IB History", fullScore: 7, category: "Group 3"),
        .elective("IB Geography", displayName: "IB Geography", fullScore: 7, category: "Group 3"),
        .elective("IB Economics", displayName: "IB Economics", fullScore: 7, category: "Group 3"),
        .elective("IB Psychology", displayName: "IB Psychology", fullScore: 7, category: "Group 3"),
        .elective("IB Philosophy", displayName: "IB Philosophy", fullScore: 7, category: "Group 3"),
        .elective("IB Business Management", displayName: "IB Business Management", fullScore: 7, category: "Group 3"),
        .elective("IB Global Politics", displayName: "IB Global Politics", fullScore: 7, category: "Group 3"),
        .elective("IB Environmental Systems", displayName: "IB Environmental Systems & Societies", fullScore: 7, category: "Group 3/4"),
        // Group 4: Experimental Sciences
        .elective("IB Physics", displayName: "IB Physics", fullScore: 7, category: "Group 4"),
        .elective("IB Chemistry", displayName: "IB Chemistry", fullScore: 7, category: "Group 4"),
        .elective("IB Biology", displayName: "IB Biology", fullScore: 7, category: "Group 4"),
        .elective("IB Computer Science", displayName: "IB Computer Science", fullScore: 7, category: "Group 4"),
        .elective("IB Design Technology", displayName: "IB Design Technology", fullScore: 7, category: "Group 4"),
        // Group 5: Mathematics
        .elective("IB Mathematics: Analysis & Approaches SL", displayName: "IB Math AA SL", fullScore: 7, category: "Group 5"),
        .elective("IB Mathematics: Analysis & Approaches HL", displayName: "IB Math AA HL", fullScore: 7, category: "Group 5"),
        .elective("IB Mathematics: Applications & Interpretation SL", displayName: "IB Math AI SL", fullScore: 7, category: "Group 5"),
        .elective("IB Mathematics: Applications & Interpretation HL", displayName: "IB Math AI HL", fullScore: 7, category: "Group 5"),
        // Group 6: The Arts
        .elective("IB Visual Arts", displayName: "IB Visual Arts", fullScore: 7, category: "Group 6"),
        .elective("IB Music", displayName: "IB Music", fullScore: 7, category: "Group 6"),
        .elective("IB Theatre", displayName: "IB Theatre", fullScore: 7, category: "Group 6"),
        .elective("IB Film", displayName: "IB Film", fullScore: 7, category: "Group 6"),
        .elective("IB Dance", displayName: "IB Dance", fullScore: 7, category: "Group 6"),
        // Core
        .required("IB TOK", displayName: "IB Theory of Knowledge (TOK)", fullScore: 3, category: "Core"),
        .required("IB Extended Essay", displayName: "IB Extended Essay (EE)", fullScore: 3, category: "Core")
    ]
    
    // MARK: - 美国 AP (College Board)
    // 满分 5 分
    nonisolated private static let usAP: [SubjectConfig] = [
        // 英语
        .elective("AP English Language", displayName: "AP English Language & Composition", fullScore: 5, category: "English"),
        .elective("AP English Literature", displayName: "AP English Literature & Composition", fullScore: 5, category: "English"),
        // 历史与社会
        .elective("AP US History", displayName: "AP United States History", fullScore: 5, category: "History & Social Science"),
        .elective("AP World History", displayName: "AP World History: Modern", fullScore: 5, category: "History & Social Science"),
        .elective("AP European History", displayName: "AP European History", fullScore: 5, category: "History & Social Science"),
        .elective("AP Human Geography", displayName: "AP Human Geography", fullScore: 5, category: "History & Social Science"),
        .elective("AP US Government", displayName: "AP United States Government & Politics", fullScore: 5, category: "History & Social Science"),
        .elective("AP Macroeconomics", displayName: "AP Macroeconomics", fullScore: 5, category: "History & Social Science"),
        .elective("AP Microeconomics", displayName: "AP Microeconomics", fullScore: 5, category: "History & Social Science"),
        .elective("AP Psychology", displayName: "AP Psychology", fullScore: 5, category: "History & Social Science"),
        // 数学与计算机
        .elective("AP Calculus AB", displayName: "AP Calculus AB", fullScore: 5, category: "Math & CS"),
        .elective("AP Calculus BC", displayName: "AP Calculus BC", fullScore: 5, category: "Math & CS"),
        .elective("AP Statistics", displayName: "AP Statistics", fullScore: 5, category: "Math & CS"),
        .elective("AP Precalculus", displayName: "AP Precalculus", fullScore: 5, category: "Math & CS"),
        .elective("AP Computer Science A", displayName: "AP Computer Science A", fullScore: 5, category: "Math & CS"),
        .elective("AP Computer Science Principles", displayName: "AP Computer Science Principles", fullScore: 5, category: "Math & CS"),
        // 理科
        .elective("AP Physics 1", displayName: "AP Physics 1: Algebra-Based", fullScore: 5, category: "Sciences"),
        .elective("AP Physics 2", displayName: "AP Physics 2: Algebra-Based", fullScore: 5, category: "Sciences"),
        .elective("AP Physics C: Mechanics", displayName: "AP Physics C: Mechanics", fullScore: 5, category: "Sciences"),
        .elective("AP Physics C: E&M", displayName: "AP Physics C: Electricity & Magnetism", fullScore: 5, category: "Sciences"),
        .elective("AP Chemistry", displayName: "AP Chemistry", fullScore: 5, category: "Sciences"),
        .elective("AP Biology", displayName: "AP Biology", fullScore: 5, category: "Sciences"),
        .elective("AP Environmental Science", displayName: "AP Environmental Science", fullScore: 5, category: "Sciences"),
        // 外语
        .elective("AP Chinese", displayName: "AP Chinese Language & Culture", fullScore: 5, category: "World Languages"),
        .elective("AP French", displayName: "AP French Language & Culture", fullScore: 5, category: "World Languages"),
        .elective("AP Spanish", displayName: "AP Spanish Language & Culture", fullScore: 5, category: "World Languages"),
        .elective("AP German", displayName: "AP German Language & Culture", fullScore: 5, category: "World Languages"),
        .elective("AP Japanese", displayName: "AP Japanese Language & Culture", fullScore: 5, category: "World Languages"),
        .elective("AP Latin", displayName: "AP Latin", fullScore: 5, category: "World Languages"),
        // 艺术
        .elective("AP Art History", displayName: "AP Art History", fullScore: 5, category: "Arts"),
        .elective("AP Music Theory", displayName: "AP Music Theory", fullScore: 5, category: "Arts"),
        .elective("AP Studio Art 2D", displayName: "AP Studio Art: 2D Design", fullScore: 5, category: "Arts"),
        .elective("AP Studio Art 3D", displayName: "AP Studio Art: 3D Design", fullScore: 5, category: "Arts"),
        .elective("AP Studio Art Drawing", displayName: "AP Studio Art: Drawing", fullScore: 5, category: "Arts")
    ]
    
    // MARK: - SAT Subject Tests (Discontinued but still common in older transcripts)
    // 满分 800
    nonisolated private static let usSATSubject: [SubjectConfig] = [
        .elective("SAT Math Level 1", displayName: "SAT Subject Math Level 1", fullScore: 800),
        .elective("SAT Math Level 2", displayName: "SAT Subject Math Level 2", fullScore: 800),
        .elective("SAT Physics", displayName: "SAT Subject Physics", fullScore: 800),
        .elective("SAT Chemistry", displayName: "SAT Subject Chemistry", fullScore: 800),
        .elective("SAT Biology", displayName: "SAT Subject Biology E/M", fullScore: 800),
        .elective("SAT US History", displayName: "SAT Subject US History", fullScore: 800),
        .elective("SAT World History", displayName: "SAT Subject World History", fullScore: 800),
        .elective("SAT Literature", displayName: "SAT Subject Literature", fullScore: 800),
        .elective("SAT Spanish", displayName: "SAT Subject Spanish", fullScore: 800),
        .elective("SAT French", displayName: "SAT Subject French", fullScore: 800),
        .elective("SAT Chinese", displayName: "SAT Subject Chinese with Listening", fullScore: 800)
    ]
    
    // MARK: - 美国 ACT
    // 满分 36 分（每科 1-36）
    nonisolated private static let usACT: [SubjectConfig] = [
        .elective("ACT English", displayName: "ACT English", fullScore: 36),
        .elective("ACT Math", displayName: "ACT Math", fullScore: 36),
        .elective("ACT Reading", displayName: "ACT Reading", fullScore: 36),
        .elective("ACT Science", displayName: "ACT Science", fullScore: 36),
        .elective("ACT Writing", displayName: "ACT Writing (Optional)", fullScore: 12)
    ]
    
    // MARK: - SAT (新)
    // Evidence-Based Reading and Writing + Math，各 800，总分 1600
    nonisolated private static let usSAT: [SubjectConfig] = [
        .required("SAT EBRW", displayName: "SAT Evidence-Based Reading & Writing", fullScore: 800),
        .required("SAT Math", displayName: "SAT Math", fullScore: 800),
        .elective("SAT Essay", displayName: "SAT Essay (Discontinued)", fullScore: 24)
    ]
    
    // MARK: - 获取所有可选地区
    nonisolated static func availableRegions(for stage: EducationStage) -> [EducationRegion] {
        switch stage {
        case .primarySchool:
            return [
                EducationRegion(
                    name: "mainland_primary",
                    displayName: "中国大陆",
                    category: .domestic,
                    stage: stage,
                    systemCode: "CN-PRIMARY",
                    subjects: [
                        .required("Chinese", displayName: "语文", fullScore: 100),
                        .required("Mathematics", displayName: "数学", fullScore: 100),
                        .required("English", displayName: "英语", fullScore: 100)
                    ],
                    notes: ""
                )
            ]
        case .middleSchool:
            return [
                EducationRegion(name: "mainland", displayName: "中国大陆", category: .domestic, stage: stage,
                                systemCode: "CN-MID", subjects: cnMiddleSchool, notes: ""),
                EducationRegion(name: "zhejiang_mid", displayName: "浙江", category: .domestic, stage: stage,
                                systemCode: "CN-ZJ-MID", subjects: zhejiangMiddleSchool,
                                notes: "初中合并科：社会 + 科学"),
                EducationRegion(name: "shanghai_mid", displayName: "上海", category: .domestic, stage: stage,
                                systemCode: "CN-SH-MID", subjects: shanghaiMiddleSchool, notes: ""),
                EducationRegion(name: "taiwan_mid", displayName: "台湾", category: .domestic, stage: stage,
                                systemCode: "TW-MID", subjects: taiwanMiddleSchool, notes: ""),
                EducationRegion(name: "uk_igcse", displayName: "英国 IGCSE", category: .international, stage: stage,
                                systemCode: "UK-IGCSE", subjects: ukIGCSE,
                                notes: "Cambridge IGCSE / Edexcel International GCSE"),
                EducationRegion(name: "sg_olevel", displayName: "新加坡 O-Level", category: .international, stage: stage,
                                systemCode: "SG-OLEVEL", subjects: sgOLevel,
                                notes: "Singapore-Cambridge GCE O-Level")
            ]
        case .highSchool:
            return [
                EducationRegion(name: "mainland", displayName: "中国大陆", category: .domestic, stage: stage,
                                systemCode: "CN-HS", subjects: cnHighSchool, notes: ""),
                EducationRegion(name: "zhejiang", displayName: "浙江 (3+3)", category: .domestic, stage: stage,
                                systemCode: "CN-ZJ-3+3", subjects: zhejiangHighSchool,
                                notes: "3 门选考按赋分计算（最高100分）"),
                EducationRegion(name: "shanghai", displayName: "上海 (3+3)", category: .domestic, stage: stage,
                                systemCode: "CN-SH-3+3", subjects: shanghaiHighSchool,
                                notes: "3 门选考按赋分计算"),
                EducationRegion(name: "taiwan", displayName: "台湾 (學測)", category: .domestic, stage: stage,
                                systemCode: "TW-GSAT", subjects: taiwanHighSchool,
                                notes: "学测：數學A (理工) / 數學B (文商) 分卷"),
                EducationRegion(name: "hongkong_dse", displayName: "香港 (DSE)", category: .domestic, stage: stage,
                                systemCode: "HK-DSE", subjects: hkDSE,
                                notes: "4 核心 + 2-3 选修，5** = 7 分制"),
                EducationRegion(name: "uk_alevel", displayName: "英国 A-Level", category: .international, stage: stage,
                                systemCode: "UK-ALEVEL", subjects: ukALevel,
                                notes: "CIE / Edexcel / AQA / OCR 通用"),
                EducationRegion(name: "ib_dp", displayName: "IB Diploma", category: .international, stage: stage,
                                systemCode: "IB-DP", subjects: ibDP,
                                notes: "6 门课（3 HL + 3 SL）+ TOK + EE = 45 分"),
                EducationRegion(name: "us_ap", displayName: "美国 AP", category: .international, stage: stage,
                                systemCode: "US-AP", subjects: usAP,
                                notes: "College Board AP 课程，满分 5 分")
            ]
        case .internationalHighSchool:
            return [
                EducationRegion(name: "uk_igcse", displayName: "英国 IGCSE", category: .international, stage: stage,
                                systemCode: "UK-IGCSE", subjects: ukIGCSE, notes: ""),
                EducationRegion(name: "uk_alevel", displayName: "英国 A-Level", category: .international, stage: stage,
                                systemCode: "UK-ALEVEL", subjects: ukALevel, notes: ""),
                EducationRegion(name: "ib_dp", displayName: "IB Diploma", category: .international, stage: stage,
                                systemCode: "IB-DP", subjects: ibDP, notes: ""),
                EducationRegion(name: "us_ap", displayName: "美国 AP", category: .international, stage: stage,
                                systemCode: "US-AP", subjects: usAP, notes: ""),
                EducationRegion(name: "sg_olevel", displayName: "新加坡 O-Level", category: .international, stage: stage,
                                systemCode: "SG-OLEVEL", subjects: sgOLevel, notes: "")
            ]
        case .university:
            return [
                EducationRegion(name: "us_sat", displayName: "美国 SAT", category: .international, stage: stage,
                                systemCode: "US-SAT", subjects: usSAT,
                                notes: "总分 1600：EBRW 800 + Math 800"),
                EducationRegion(name: "us_act", displayName: "美国 ACT", category: .international, stage: stage,
                                systemCode: "US-ACT", subjects: usACT,
                                notes: "总分 36：4 科平均"),
                EducationRegion(name: "us_sat_subj", displayName: "SAT Subject Tests", category: .international, stage: stage,
                                systemCode: "US-SAT-SUBJ", subjects: usSATSubject,
                                notes: "已停办，但旧成绩仍有效"),
                EducationRegion(name: "general", displayName: "通用", category: .international, stage: stage,
                                systemCode: "GENERAL", subjects: [
                                    .required("GPA", displayName: "GPA (4.0 Scale)", fullScore: 4.0),
                                    .elective("Mathematics", displayName: "Mathematics", fullScore: 100),
                                    .elective("English", displayName: "English", fullScore: 100)
                                ], notes: "")
            ]
        case .graduate:
            return [
                EducationRegion(name: "general_grad", displayName: "通用研究生", category: .international, stage: stage,
                                systemCode: "GRAD", subjects: [
                                    .required("GRE Verbal", displayName: "GRE Verbal", fullScore: 170),
                                    .required("GRE Quantitative", displayName: "GRE Quantitative", fullScore: 170),
                                    .required("GRE AW", displayName: "GRE Analytical Writing", fullScore: 6),
                                    .elective("GMAT Total", displayName: "GMAT Total", fullScore: 800),
                                    .elective("TOEFL", displayName: "TOEFL iBT", fullScore: 120),
                                    .elective("IELTS", displayName: "IELTS", fullScore: 9)
                                ], notes: ""),
                EducationRegion(name: "us_gpa", displayName: "美国 GPA", category: .international, stage: stage,
                                systemCode: "US-GPA", subjects: [
                                    .required("GPA", displayName: "GPA (4.0 Scale)", fullScore: 4.0)
                                ], notes: "")
            ]
        }
    }
    
    // MARK: - 按分类获取所有体系
    nonisolated static func availableRegions(category: EducationCategory) -> [EducationRegion] {
        var results: [EducationRegion] = []
        for stage in EducationStage.allCases {
            results.append(contentsOf: availableRegions(for: stage).filter { $0.category == category })
        }
        return results
    }
    
    // MARK: - 根据名称获取地区配置
    nonisolated static func region(named name: String, stage: EducationStage) -> EducationRegion? {
        return availableRegions(for: stage).first { $0.name == name }
    }
    
    // MARK: - 默认地区
    nonisolated static func defaultRegion(for stage: EducationStage) -> EducationRegion {
        return availableRegions(for: stage).first ?? availableRegions(for: stage)[0]
    }
    
    // MARK: - 根据 systemCode 获取
    nonisolated static func region(systemCode: String) -> EducationRegion? {
        for stage in EducationStage.allCases {
            if let region = availableRegions(for: stage).first(where: { $0.systemCode == systemCode }) {
                return region
            }
        }
        return nil
    }
}
