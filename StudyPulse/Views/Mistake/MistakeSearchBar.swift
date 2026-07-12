//
//  MistakeSearchBar.swift
//  StudyPulse
//
//  Created for the MistakeView refactoring.
//

import SwiftUI

struct MistakeTagSectionView: View {
    let tags: [String]
    @Binding var searchText: String
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
