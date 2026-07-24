//
//  AutoMindMapViewModel.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/13.
//  Copyright © 2026 Chenkai Gao. All rights reserved.
//

import Foundation
import SwiftUI
import os

/// 思维导图布局节点的数据结构
/// Mind map layout node data structure.
struct MindMapLayoutNode: Identifiable, Equatable {
    /// 节点的唯一标识符
    /// Unique identifier for the node.
    let id: String
    
    /// 节点的类型（根节点、主题、知识点、具体错题）
    /// The node's kind (root, theme, knowledge point, or mistake).
    let kind: Kind
    
    /// 节点在 Canvas 坐标系中的中心位置
    /// Node's center position in the Canvas coordinate space.
    let position: CGPoint
    
    /// 节点所处的层级 (0 = 根, 1 = 主题, 2 = 知识点, 3 = 错题)
    /// Node depth level (0 = root, 1 = theme, 2 = knowledge point, 3 = mistake).
    let level: Int
    
    enum Kind: Equatable {
        case root(title: String)
        case theme(name: String)
        case knowledgePoint(name: String)
        case mistake(note: MistakeNote)
        
        /// 获取节点的显示文本
        /// Get the display text for the node.
        var title: String {
            switch self {
            case .root(let title): return title
            case .theme(let name): return name
            case .knowledgePoint(let name): return name
            case .mistake(let note): return note.title
            }
        }
    }
}

/// 思维导图的边（连接线）数据结构
/// Mind map layout edge data structure.
struct MindMapLayoutEdge: Identifiable, Equatable {
    /// 边的唯一标识符 (通常是 "id1-id2")
    /// Unique identifier for the edge (usually "id1-id2").
    var id: String { "\(fromNodeId)-\(toNodeId)" }
    
    /// 起始节点的 ID
    /// Source node ID.
    let fromNodeId: String
    
    /// 起始节点的位置
    /// Source node position.
    let from: CGPoint
    
    /// 目标节点的 ID
    /// Target node ID.
    let toNodeId: String
    
    /// 目标节点的位置
    /// Target node position.
    let to: CGPoint
}

/// 思维导图的业务逻辑与坐标布局管理器
/// Mind map business logic and layout manager.
@MainActor
@Observable
final class AutoMindMapViewModel {
    // MARK: - Published States / 发布状态
    
    /// 是否正在加载中（包括大模型网络请求）
    /// True if currently loading (including LLM requests).
    private(set) var isLoading = false
    
    /// 错误信息，为 nil 表示一切正常
    /// Error message; nil means normal.
    private(set) var errorMessage: String? = nil
    
    /// 计算完成后的所有可视化节点集合
    /// All layout nodes computed for visualization.
    private(set) var nodes: [MindMapLayoutNode] = []
    
    /// 计算完成后的所有边（连线）集合
    /// All layout edges computed for drawing.
    private(set) var edges: [MindMapLayoutEdge] = []
    
    /// 是否正在使用规则降级（当大模型未配置或出错时启用）
    /// True if degraded to the local rules-based fallback.
    private(set) var isUsingFallback = false
    
    /// 错题 UUID 到知识点名称的逆向映射
    /// Reverse lookup from mistake UUID string to knowledge point name.
    private(set) var mistakeToKP: [String: String] = [:]
    
    // MARK: - Dependencies & Cache / 依赖与缓存
    
    /// 所有的原始错题
    /// All raw mistakes.
    private let sourceMistakes: [MistakeNote]
    
    /// 过滤且截取前 25 条后的错题
    /// Sorted and capped mistakes (max 25 items).
    private var targetMistakes: [MistakeNote] = []
    
    /// 错题 UUID 到错题实例的映射，加速查找
    /// Lookup map from mistake UUID string to MistakeNote.
    private var mistakeLookup: [String: MistakeNote] = [:]
    
    /// 主题的归类名称（如果是单一科目，作为 root 的名称）
    /// Subject or theme title (e.g., subject name if single subject is mapped).
    private let contextTitle: String
    
    // MARK: - Initializer / 初始化
    
    /// 初始化 ViewModel
    /// Initialize the ViewModel.
    /// - Parameters:
    ///   - mistakes: 输入的错题集 (会自动按时间排序并截取最近 25 题)
    ///   - contextTitle: 视图标题 (若为单一学科则传入学科名，否则默认为 "My Mistakes")
    init(mistakes: [MistakeNote], contextTitle: String = "My Mistakes") {
        self.sourceMistakes = mistakes
        self.contextTitle = contextTitle.isEmpty ? "My Mistakes" : contextTitle
        
        // 1. 过滤并按录入时间降序排列，截取最近 25 条错题以控制大模型 Token 消耗
        // 1. Sort descending by date and limit to 25 items to manage token consumption.
        let sorted = mistakes.sorted(by: { $0.date > $1.date })
        self.targetMistakes = Array(sorted.prefix(25))
        
        // 2. 建立哈希表方便按 UUID String 进行查找
        // 2. Populate lookup map for quick retrieval by UUID string.
        for m in self.targetMistakes {
            self.mistakeLookup[m.id.uuidString] = m
        }
    }
    
    // MARK: - Pipeline / 核心处理流程
    
    /// 启动大模型解析与布局计算管线
    /// Start the LLM generation and layout computation pipeline.
    func generate(config: LLMConfig) async {
        guard !targetMistakes.isEmpty else {
            self.nodes = []
            self.edges = []
            return
        }
        
        self.isLoading = true
        self.errorMessage = nil
        
        let currentIds = targetMistakes.map { $0.id.uuidString }
        
        // 1. 尝试从本地缓存中加载
        // 1. Try to load from local cache
        let cache = AutoMindMapCacheStore.loadAll()
        if let entry = cache[contextTitle] {
            let cachedIdsSet = Set(entry.mistakeIds)
            let currentIdsSet = Set(currentIds)
            
            if cachedIdsSet == currentIdsSet {
                // 缓存的内容完全一致，无需发请求，直接使用缓存
                // Cache content matches exactly, no need to request, use cache directly.
                Log.llm.info("AutoMindMap: cache hit for \(self.contextTitle). Skipping LLM request.")
                self.isUsingFallback = false
                computeLayout(themes: entry.themes)
                self.isLoading = false
                return
            }
            
            // 2. 如果不一致但大模型已配置，可以进行 Delta 增量更新
            // 2. If mismatch but LLM is configured, run delta updates.
            if config.isConfigured {
                Log.llm.info("AutoMindMap: cache mismatch. Triggering delta update.")
                
                // 计算新增与删除
                // Calculate additions and deletions
                let added = targetMistakes.filter { !cachedIdsSet.contains($0.id.uuidString) }
                let deleted = entry.mistakeIds.filter { !currentIdsSet.contains($0) }
                
                do {
                    let prompt = AutoMindMapLLM.makeDeltaPrompt(
                        existingThemes: entry.themes,
                        addedMistakes: added,
                        deletedIds: deleted
                    )
                    Log.llm.info("AutoMindMap delta request: added=\(added.count), deleted=\(deleted.count)")
                    
                    let rawJSON = try await LLMClient.shared.complete(
                        prompt: prompt,
                        config: config,
                        caller: "AutoMindMapDelta"
                    )
                    
                    let cleanJSON = cleanJSONString(rawJSON)
                    if let data = cleanJSON.data(using: .utf8),
                       let themes = try? JSONDecoder().decode([MindMapTheme].self, from: data),
                       !themes.isEmpty {
                        self.isUsingFallback = false
                        // 写入最新缓存
                        AutoMindMapCacheStore.save(
                            contextTitle: contextTitle,
                            mistakeIds: currentIds,
                            themes: themes
                        )
                        computeLayout(themes: themes)
                        self.isLoading = false
                        return
                    } else {
                        Log.llm.warning("AutoMindMap: delta parse failed. Re-generating full map.")
                    }
                } catch {
                    Log.llm.error("AutoMindMap delta error: \(error.localizedDescription). Re-generating full map.")
                }
            }
        }
        
        // 3. 判断大模型是否配置，未配置直接走本地规则降级
        // 3. If LLM is not configured, directly fall back to local rules.
        guard config.isConfigured else {
            Log.llm.info("AutoMindMap: LLM not configured, using fallback.")
            self.isUsingFallback = true
            let fallbackThemes = buildFallbackThemes()
            computeLayout(themes: fallbackThemes)
            self.isLoading = false
            return
        }
        
        // 4. 进行完整大模型生成 (无有效缓存或 Delta 失败时)
        // 4. Perform full LLM generation (when no valid cache exists or delta updates fail).
        do {
            let prompt = AutoMindMapLLM.makePrompt(mistakes: targetMistakes)
            Log.llm.info("AutoMindMap: requesting LLM for full generation with \(self.targetMistakes.count) mistakes.")
            
            let rawJSON = try await LLMClient.shared.complete(
                prompt: prompt,
                config: config,
                caller: "AutoMindMap"
            )
            
            let cleanJSON = cleanJSONString(rawJSON)
            Log.llm.info("AutoMindMap: received JSON response.")
            
            if let data = cleanJSON.data(using: .utf8),
               let themes = try? JSONDecoder().decode([MindMapTheme].self, from: data),
               !themes.isEmpty {
                self.isUsingFallback = false
                
                // 写入最新缓存
                AutoMindMapCacheStore.save(
                    contextTitle: contextTitle,
                    mistakeIds: currentIds,
                    themes: themes
                )
                
                computeLayout(themes: themes)
            } else {
                // 解析失败时降级
                // Fall back if parsing fails.
                Log.llm.warning("AutoMindMap: parse failed. Falling back to local layout.")
                self.isUsingFallback = true
                let fallbackThemes = buildFallbackThemes()
                computeLayout(themes: fallbackThemes)
            }
        } catch {
            Log.llm.error("AutoMindMap error: \(error.localizedDescription)")
            // 网络或模型报错时也进行降级，保证界面可用性
            // Fall back to rule-based layout on network or model errors.
            self.isUsingFallback = true
            let fallbackThemes = buildFallbackThemes()
            computeLayout(themes: fallbackThemes)
        }
        
        self.isLoading = false
    }
    
    // MARK: - Layout Calculation / 布局算法
    
    /// 计算极坐标系下的放射状思维导图布局
    /// Compute the radial mind map layout in polar coordinates.
    private func computeLayout(themes: [MindMapTheme]) {
        var computedNodes: [MindMapLayoutNode] = []
        var computedEdges: [MindMapLayoutEdge] = []
        var computedMistakeToKP: [String: String] = [:]
        
        let activeThemes = themes.filter { theme in
            // 过滤掉没有有效错题的空主题
            // Filter out empty themes with no valid mistakes in target set.
            theme.knowledgePoints.contains { kp in
                kp.mistakeIds.contains { self.mistakeLookup[$0] != nil }
            }
        }
        
        let themeCount = activeThemes.count
        
        if themeCount == 0 {
            self.nodes = []
            self.edges = []
            return
        }
        
        // 场景 A: 单一主题（如查看某一科目的错题图谱）
        // Scenario A: Single Theme (e.g., viewing mind map under a specific subject).
        if themeCount == 1 {
            let singleTheme = activeThemes[0]
            // 以该主题名称直接作为根节点
            // Use the single theme name directly as the root node.
            let rootId = "root"
            let rootNode = MindMapLayoutNode(
                id: rootId,
                kind: .root(title: singleTheme.theme),
                position: .zero,
                level: 0
            )
            computedNodes.append(rootNode)
            
            // 过滤出有有效错题的二级知识点
            // Keep only knowledge points with active mistakes.
            let activeKps = singleTheme.knowledgePoints.filter { kp in
                kp.mistakeIds.contains { self.mistakeLookup[$0] != nil }
            }
            
            let kpCount = activeKps.count
            let radiusKP: CGFloat = 180.0
            let radiusMistake: CGFloat = 360.0
            
            for (j, kp) in activeKps.enumerated() {
                // 知识点均匀环绕分布在 360 度圆周上
                // Knowledge points are distributed evenly across the 360-degree circle.
                let angleKP = (2.0 * CGFloat.pi * CGFloat(j)) / CGFloat(kpCount)
                let kpPos = CGPoint(
                    x: radiusKP * cos(angleKP),
                    y: radiusKP * sin(angleKP)
                )
                let kpId = "kp-\(kp.name)"
                let kpNode = MindMapLayoutNode(
                    id: kpId,
                    kind: .knowledgePoint(name: kp.name),
                    position: kpPos,
                    level: 2
                )
                computedNodes.append(kpNode)
                computedEdges.append(MindMapLayoutEdge(fromNodeId: rootId, from: .zero, toNodeId: kpId, to: kpPos))
                
                // 筛选出真实的错题
                // Resolve active mistakes under this knowledge point.
                let validMistakeIds = kp.mistakeIds.filter { self.mistakeLookup[$0] != nil }
                let mCount = validMistakeIds.count
                
                // 给错题分配一个相对知识点居中的放射圆弧
                // Assign mistakes to a radial arc centered around the parent knowledge point's angle.
                let arcWidth = (2.0 * CGFloat.pi / CGFloat(kpCount)) * 0.8
                for (k, mId) in validMistakeIds.enumerated() {
                    guard let mistake = self.mistakeLookup[mId] else { continue }
                    
                    // 记录错题到其所属知识点的映射
                    // Record mapping from mistake ID to its parent knowledge point name.
                    computedMistakeToKP[mId] = kp.name
                    
                    let angleMistake: CGFloat
                    if mCount == 1 {
                        angleMistake = angleKP
                    } else {
                        angleMistake = angleKP - (arcWidth / 2.0) + arcWidth * (CGFloat(k) / CGFloat(mCount - 1))
                    }
                    
                    let mPos = CGPoint(
                        x: radiusMistake * cos(angleMistake),
                        y: radiusMistake * sin(angleMistake)
                    )
                    let mNodeId = "m-\(mistake.id.uuidString)"
                    let mNode = MindMapLayoutNode(
                        id: mNodeId,
                        kind: .mistake(note: mistake),
                        position: mPos,
                        level: 3
                    )
                    computedNodes.append(mNode)
                    computedEdges.append(MindMapLayoutEdge(fromNodeId: kpId, from: kpPos, toNodeId: mNodeId, to: mPos))
                }
            }
        }
        // 场景 B: 多个主题（查看全局跨科目的错题图谱）
        // Scenario B: Multiple Themes (viewing cross-subject mind map).
        else {
            let rootId = "root"
            let rootNode = MindMapLayoutNode(
                id: rootId,
                kind: .root(title: contextTitle),
                position: .zero,
                level: 0
            )
            computedNodes.append(rootNode)
            
            let radiusTheme: CGFloat = 160.0
            let radiusKP: CGFloat = 320.0
            let radiusMistake: CGFloat = 480.0
            
            for (i, theme) in activeThemes.enumerated() {
                // 主题在一级圆周上均匀分布
                // Themes are distributed evenly on the level-1 circle.
                let angleTheme = (2.0 * CGFloat.pi * CGFloat(i)) / CGFloat(themeCount)
                let themePos = CGPoint(
                    x: radiusTheme * cos(angleTheme),
                    y: radiusTheme * sin(angleTheme)
                )
                let themeId = "theme-\(theme.theme)"
                let themeNode = MindMapLayoutNode(
                    id: themeId,
                    kind: .theme(name: theme.theme),
                    position: themePos,
                    level: 1
                )
                computedNodes.append(themeNode)
                computedEdges.append(MindMapLayoutEdge(fromNodeId: rootId, from: .zero, toNodeId: themeId, to: themePos))
                
                // 该主题下的有效知识点
                // Resolve active knowledge points under this theme.
                let activeKps = theme.knowledgePoints.filter { kp in
                    kp.mistakeIds.contains { self.mistakeLookup[$0] != nil }
                }
                let kpCount = activeKps.count
                
                // 知识点在主题扇区中放射分布
                // Knowledge points are radiated inside the parent theme's sector.
                let themeArcWidth = (2.0 * CGFloat.pi / CGFloat(themeCount)) * 0.8
                for (j, kp) in activeKps.enumerated() {
                    let angleKP: CGFloat
                    if kpCount == 1 {
                        angleKP = angleTheme
                    } else {
                        angleKP = angleTheme - (themeArcWidth / 2.0) + themeArcWidth * (CGFloat(j) / CGFloat(kpCount - 1))
                    }
                    
                    let kpPos = CGPoint(
                        x: radiusKP * cos(angleKP),
                        y: radiusKP * sin(angleKP)
                    )
                    let kpId = "kp-\(theme.theme)-\(kp.name)"
                    let kpNode = MindMapLayoutNode(
                        id: kpId,
                        kind: .knowledgePoint(name: kp.name),
                        position: kpPos,
                        level: 2
                    )
                    computedNodes.append(kpNode)
                    computedEdges.append(MindMapLayoutEdge(fromNodeId: themeId, from: themePos, toNodeId: kpId, to: kpPos))
                    
                    // 知识点下的有效错题
                    // Resolve active mistakes under this knowledge point.
                    let validMistakeIds = kp.mistakeIds.filter { self.mistakeLookup[$0] != nil }
                    let mCount = validMistakeIds.count
                    
                    // 错题在更窄的子圆弧扇区中分布
                    // Mistakes are radiated inside a narrower child arc sector.
                    let kpArcWidth = (themeArcWidth / CGFloat(max(1, kpCount))) * 0.8
                    for (k, mId) in validMistakeIds.enumerated() {
                        guard let mistake = self.mistakeLookup[mId] else { continue }
                        
                        // 记录错题到其所属知识点的映射
                        // Record mapping from mistake ID to its parent knowledge point name.
                        computedMistakeToKP[mId] = kp.name
                        
                        let angleMistake: CGFloat
                        if mCount == 1 {
                            angleMistake = angleKP
                        } else {
                            angleMistake = angleKP - (kpArcWidth / 2.0) + kpArcWidth * (CGFloat(k) / CGFloat(mCount - 1))
                        }
                        
                        let mPos = CGPoint(
                            x: radiusMistake * cos(angleMistake),
                            y: radiusMistake * sin(angleMistake)
                        )
                        let mNodeId = "m-\(mistake.id.uuidString)"
                        let mNode = MindMapLayoutNode(
                            id: mNodeId,
                            kind: .mistake(note: mistake),
                            position: mPos,
                            level: 3
                        )
                        computedNodes.append(mNode)
                        computedEdges.append(MindMapLayoutEdge(fromNodeId: kpId, from: kpPos, toNodeId: mNodeId, to: mPos))
                    }
                }
            }
        }
        
        self.nodes = computedNodes
        self.edges = computedEdges
        self.mistakeToKP = computedMistakeToKP
    }
    
    // MARK: - Helper Utilities / 辅助工具
    
    /// 本地规则降级：按 科目 -> 标签 归纳错题
    /// Rule-based fallback: organize mistakes by Subject -> Tag.
    private func buildFallbackThemes() -> [MindMapTheme] {
        var subjectToTags: [String: [String: [String]]] = [:] // Subject -> [Tag: [MistakeID]]
        
        for m in targetMistakes {
            let sub = m.subject.isEmpty ? "General".localized() : m.subject
            let tags = m.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            
            if tags.isEmpty {
                // 没有标签时归类到“其它”
                // No tags: group under "Other".
                subjectToTags[sub, default: [:]]["Other".localized(), default: []].append(m.id.uuidString)
            } else {
                for tag in tags {
                    subjectToTags[sub, default: [:]][tag, default: []].append(m.id.uuidString)
                }
            }
        }
        
        return subjectToTags.map { (subject, tagMap) in
            let kps = tagMap.map { (tagName, ids) in
                MindMapKnowledgePoint(name: tagName, mistakeIds: ids)
            }.sorted { $0.name < $1.name }
            return MindMapTheme(theme: subject, knowledgePoints: kps)
        }.sorted { $0.theme < $1.theme }
    }
    
    /// 清理 JSON 中的 Markdown 格式（如 ```json ... ```），只保留纯文本 JSON
    /// Strip markdown code blocks (e.g. ```json ... ```) from raw LLM output.
    private func cleanJSONString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstLineEnd = cleaned.firstIndex(of: "\n") {
                cleaned.removeSubrange(cleaned.startIndex...firstLineEnd)
            }
            if cleaned.hasSuffix("```") {
                cleaned.removeLast(3)
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
