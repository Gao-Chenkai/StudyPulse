//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

//
//  MarkupPostParsingRewriter.swift
//  MarkdownText
//
//  Created by Jun Yan on 6/13/25.
//
import Markdown

protocol MarkupPostParsingRewriter {
  func rewriteIfApplicable(document: Markdown.Document) -> Markdown.Document?
}

final class PartialStrongMarkupPostParsingRewriter: MarkupPostParsingRewriter {
  private let scanner: PartialEmphasisScanner

  init() {
    self.scanner = PartialEmphasisScanner()
  }

  func rewriteIfApplicable(document: Markdown.Document) -> Markdown.Document? {
    guard let paragraph = scanner.scan(document: document) else {
      return nil
    }

    var rewriter = PartialEmphasisRewriter(targetNode: paragraph)
    return rewriter.visit(document) as? Markdown.Document
  }
}

final class PartialTableMarkupPostParsingRewriter: MarkupPostParsingRewriter {
  private let scanner: PartialTableScanner

  init() {
    self.scanner = PartialTableScanner()
  }

  func rewriteIfApplicable(document: Markdown.Document) -> Markdown.Document? {
    guard let paragraph = scanner.scan(document: document) else {
      return nil
    }

    var rewriter = PartialTableRewriter(targetParagraph: paragraph)
    return rewriter.visit(document) as? Markdown.Document
  }
}
