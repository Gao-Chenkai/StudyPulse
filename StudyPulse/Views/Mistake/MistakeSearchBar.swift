//
//  MistakeSearchBar.swift
//  StudyPulse
//
//  错题搜索 + 标签区:横向 chip 列表 + 标签图谱入口。
//  选中 chip 会把 `#tag` 写回 searchText,触发父视图的过滤。
//
//  Mistake search + tag section: horizontal chip list with a "tag graph"
//  entry point. Selecting a chip writes "#tag" back to `searchText` to
//  trigger the parent view's filter.
//

import SwiftUI

/// 错题搜索 + 标签区:横滚 chip + tag graph 入口。
/// Mistake search + tag section: horizontally-scrolling chip list with
/// a "tag graph" entry point.
struct MistakeTagSectionView: View {
    /// 可用的标签集合
    /// Available tag list.
    let tags: [String]
    /// 父视图的搜索文本(绑定),点击 chip 会写入 "#tag"
    /// Parent view's search text (binding). Tapping a chip writes "#tag".
    @Binding var searchText: String
    /// 可选:打开"标签图谱"sheet 的回调
    /// Optional callback to open the "tag graph" sheet.
    var onShowTagGraph: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.purple)
                Text("Tags".localized())
                    .font(.headline)
                Spacer()
                if let onShowTagGraph = onShowTagGraph {
                    Button(action: onShowTagGraph) {
                        Label("Tag Graph".localized(), systemImage: "circle.hexagongrid")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.purple)
                    }
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            searchText = "#\(tag)"
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                    .font(.caption2)
                                Text(tag)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color.purple.opacity(0.85))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
