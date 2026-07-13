//
//  SectionHeader.swift
//  StudyPulse

import SwiftUI

/// 通用分节标题组件(蓝色加粗 + 顶部 padding)。
/// Generic section-header component (blue bold + top padding).
struct SectionHeader: View {
    /// 标题文案
    /// Header text.
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.blue)
            .padding(.top, 10)
    }
}
