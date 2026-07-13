//
//  AutoMindMapLLM.swift
//  StudyPulse
//
//  Created by Antigravity on 2026/7/13.
//  Copyright © 2026 Chenkai Gao. All rights reserved.
//

import Foundation
import os

/// 错题思维导图主题节点数据结构
/// Mistake mind map theme node structure.
struct MindMapTheme: Codable, Hashable, Sendable, Identifiable {
    /// 遵循 Identifiable 协议，使用主题名作为唯一标识
    /// Conforms to Identifiable using theme name as the unique ID.
    var id: String { theme }
    
    /// 主题名或学科名称
    /// Theme name or subject name.
    let theme: String
    
    /// 该主题下的二级知识点列表
    /// List of secondary knowledge points under this theme.
    let knowledgePoints: [MindMapKnowledgePoint]
    
    init(theme: String, knowledgePoints: [MindMapKnowledgePoint]) {
        self.theme = theme
        self.knowledgePoints = knowledgePoints
    }
}

/// 错题思维导图知识点节点数据结构
/// Mistake mind map knowledge point node structure.
struct MindMapKnowledgePoint: Codable, Hashable, Sendable, Identifiable {
    /// 遵循 Identifiable 协议，使用知识点名称作为唯一标识
    /// Conforms to Identifiable using knowledge point name as the unique ID.
    var id: String { name }
    
    /// 知识点或核心概念名称
    /// Knowledge point or core concept name.
    let name: String
    
    /// 该知识点关联的错题 UUID 字符串列表
    /// List of mistake UUID strings associated with this knowledge point.
    let mistakeIds: [String]
    
    init(name: String, mistakeIds: [String]) {
        self.name = name
        self.mistakeIds = mistakeIds
    }
}

/// 错题思维导图缓存条目
/// Mind map cache entry.
struct MindMapCacheEntry: Codable, Sendable {
    /// 导图关联的上下文标题 (如 "My Mistakes" 或 学科名称)
    /// Context title associated with the map (e.g. "My Mistakes" or subject name).
    let contextTitle: String
    
    /// 构成此导图的错题 UUID 字符串列表 (按排好序的前 25 个 ID)
    /// List of mistake UUID strings that made up this mind map.
    let mistakeIds: [String]
    
    /// 已生成的层级结构
    /// Generated hierarchical themes structure.
    let themes: [MindMapTheme]
    
    /// 缓存生成的时间戳
    /// Timestamp when this was generated.
    let timestamp: Date
}

/// 错题思维导图的本地缓存存储器
/// Local cache store for mistake mind maps.
enum AutoMindMapCacheStore {
    static let fileName = "auto_mind_map_cache.json"
    
    static func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(fileName)
    }
    
    /// 加载所有缓存条目，返回以 contextTitle 为 Key 的字典
    /// Load all cache entries as a dictionary keyed by contextTitle.
    static func loadAll() -> [String: MindMapCacheEntry] {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        do {
            let decoded = try JSONDecoder().decode([String: MindMapCacheEntry].self, from: data)
            return decoded
        } catch {
            Log.llm.error("思维导图缓存解码失败 / Mind map cache decode failed: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// 保存/更新某个 context 的缓存
    /// Save or update cache for a specific context.
    static func save(contextTitle: String, mistakeIds: [String], themes: [MindMapTheme]) {
        var all = loadAll()
        let newEntry = MindMapCacheEntry(
            contextTitle: contextTitle,
            mistakeIds: mistakeIds,
            themes: themes,
            timestamp: Date()
        )
        all[contextTitle] = newEntry
        
        guard let url = try? fileURL() else {
            Log.llm.error("思维导图缓存文件路径不可用 / Mind map cache path unavailable")
            return
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(all)
            try data.write(to: url, options: .atomic)
            Log.llm.info("思维导图缓存写入成功 / Saved mind map cache for context: \(contextTitle)")
        } catch {
            Log.llm.error("思维导图缓存写入失败 / Failed to write mind map cache: \(error.localizedDescription)")
        }
    }
}

/// 错题思维导图大模型 Prompt 构造器
/// Mistake mind map LLM prompt builder.
enum AutoMindMapLLM {
    /// 大模型的系统提示词，规定其角色、任务与严格的 JSON 输出结构
    /// LLM system prompt, defining its role, task, and strict JSON output structure.
    static let defaultSystem: String = """
    You are an expert academic tutor. The user will provide a list of mistake notes (each with a UUID, a title, a subject, and details like correct solution or error reason).
    Your task is to analyze these mistakes and build a hierarchical mind map structure.
    
    You must classify the mistakes into high-level themes/subjects, and then into specific knowledge points/concepts under each theme.
    For each knowledge point, associate the corresponding mistake UUIDs.
    
    CRITICAL REQUIREMENTS:
    1. You must ONLY use the exact mistake UUIDs provided in the input. Do not invent or generate any new UUIDs.
    2. Every mistake in the input should be placed in exactly one knowledge point.
    3. Output the result strictly as a JSON array matching this schema:
    [
      {
        "theme": "Theme/Subject Name",
        "knowledgePoints": [
          {
            "name": "Knowledge Point/Concept Name",
            "mistakeIds": ["UUID-1", "UUID-2"]
          }
        ]
      }
    ]
    4. Do not include any markdown formatting or code blocks like ```json. Output raw JSON only.
    """
    
    /// 用于增量（Delta）更新思维导图的系统提示词
    /// System prompt for incremental (Delta) mind map updates.
    static let deltaSystem: String = """
    You are an expert academic tutor. The user will provide:
    1. An existing hierarchical mind map of mistakes (in JSON format).
    2. A list of changes to apply:
       - Added mistakes: [mistakes to insert, each with ID, Title, Subject, Question, Reason].
       - Deleted mistake IDs: [IDs to remove from the mind map].
    
    Your task is to UPDATE the existing mind map to reflect these changes.
    
    CRITICAL REQUIREMENTS:
    1. Remove all deleted mistake IDs from their respective knowledge points. If a knowledge point or theme becomes empty after removal, you must remove that empty node from the hierarchy.
    2. Classify the added mistakes and insert them into appropriate themes and knowledge points. You may reuse existing themes/knowledge points if they fit, or create new ones if necessary.
    3. Keep the overall structure and naming of existing themes and knowledge points as stable as possible. Only modify what is needed.
    4. Output the result strictly as a JSON array matching this schema:
    [
      {
        "theme": "Theme/Subject Name",
        "knowledgePoints": [
          {
            "name": "Knowledge Point/Concept Name",
            "mistakeIds": ["UUID-1", "UUID-2"]
          }
        ]
      }
    ]
    5. Do not include any markdown formatting or code blocks like ```json. Output raw JSON only.
    """
    
    /// 构造生成思维导图的 Prompt 实例
    /// Construct a Prompt instance to generate the mind map.
    /// - Parameter mistakes: 待分类的错题数组 (建议至多 25 题)
    /// - Parameter mistakes: Array of mistakes to classify (suggested max 25).
    /// - Returns: 供 LLMClient 使用 of LLMPrompt
    /// - Returns: LLMPrompt for use with LLMClient.
    static func makePrompt(mistakes: [MistakeNote]) -> LLMPrompt {
        var inputStr = "Mistake List:\n"
        for m in mistakes {
            inputStr += """
            - ID: \(m.id.uuidString)
              Title: \(m.title)
              Subject: \(m.subject)
              Original Question: \(m.originalQuestion)
              Error Reason: \(m.errorReason)
            
            """
        }
        
        let user = """
        Here is the list of mistakes to analyze:
        \(inputStr)
        
        Please construct the hierarchical mind map in the requested JSON format. Keep it concise.
        """
        
        return LLMPrompt(system: defaultSystem, messages: [.user(user)])
    }
    
    /// 构造思维导图增量更新的 Prompt 实例
    /// Construct a Prompt instance for incremental mind map updates.
    static func makeDeltaPrompt(
        existingThemes: [MindMapTheme],
        addedMistakes: [MistakeNote],
        deletedIds: [String]
    ) -> LLMPrompt {
        // 1. 将现有的导图转为 JSON 字符串
        let existingJsonStr: String
        if let data = try? JSONEncoder().encode(existingThemes),
           let str = String(data: data, encoding: .utf8) {
            existingJsonStr = str
        } else {
            existingJsonStr = "[]"
        }
        
        // 2. 构造新增错题的详情文本
        var addedStr = ""
        if addedMistakes.isEmpty {
            addedStr = "None\n"
        } else {
            for m in addedMistakes {
                addedStr += """
                - ID: \(m.id.uuidString)
                  Title: \(m.title)
                  Subject: \(m.subject)
                  Original Question: \(m.originalQuestion)
                  Error Reason: \(m.errorReason)
                
                """
            }
        }
        
        // 3. 构造删除 ID 的列表文本
        let deletedStr = deletedIds.isEmpty ? "None" : deletedIds.joined(separator: ", ")
        
        let userPrompt = """
        Existing Mind Map JSON:
        \(existingJsonStr)
        
        Changes to Apply:
        1. Added Mistakes:
        \(addedStr)
        2. Deleted Mistake IDs:
        \(deletedStr)
        
        Please construct and return the updated mind map matching the requested JSON format. Keep it stable and concise.
        """
        
        return LLMPrompt(system: deltaSystem, messages: [.user(userPrompt)])
    }
}
