//
//  MarkdownHeadingParser.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import Foundation

// MARK: - 标题节点
struct HeadingNode {
    let text: String
    let originalLevel: Int    // 原始层级（#的数量）
    let normalizedLevel: Int  // 正则化后的层级（从1开始）
    let range: NSRange        // 在原文中的位置
    var children: [HeadingNode] = []
}

// MARK: - 标题树
struct HeadingTree {
    let rootNodes: [HeadingNode]
    let flatList: [HeadingNode]
    
    // 获取目录结构的文本表示
    func getTableOfContents() -> String {
        return generateTOC(nodes: rootNodes, indent: 0)
    }
    
    private func generateTOC(nodes: [HeadingNode], indent: Int) -> String {
        var result = ""
        for node in nodes {
            let indentString = String(repeating: "  ", count: indent)
            result += "\(indentString)- \(node.text)\n"
            result += generateTOC(nodes: node.children, indent: indent + 1)
        }
        return result
    }
}

// MARK: - Markdown 标题解析器
class MarkdownHeadingParser {
    
    // 解析 Markdown 文本中的标题
    static func parseHeadings(from markdown: String) -> HeadingTree {
        let headings = extractHeadings(from: markdown)
        let normalizedHeadings = normalizeHeadingLevels(headings)
        let tree = buildHeadingTree(from: normalizedHeadings)
        
        return HeadingTree(
            rootNodes: tree,
            flatList: normalizedHeadings
        )
    }
    
    // MARK: - 1. 提取标题
    private static func extractHeadings(from markdown: String) -> [HeadingNode] {
        var headings: [HeadingNode] = []
        
        // 正则表达式匹配 # 标题
        let pattern = "^(#{1,6})\\s+(.+?)$"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let nsString = markdown as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        regex.enumerateMatches(in: markdown, options: [], range: range) { match, _, _ in
            guard let match = match else { return }
            
            let hashesRange = match.range(at: 1)
            let textRange = match.range(at: 2)
            
            let hashesString = nsString.substring(with: hashesRange)
            let text = nsString.substring(with: textRange).trimmingCharacters(in: .whitespaces)
            
            let heading = HeadingNode(
                text: text,
                originalLevel: hashesString.count,
                normalizedLevel: hashesString.count, // 后面会重新计算
                range: match.range
            )
            
            headings.append(heading)
        }
        
        return headings
    }
    
    // MARK: - 2. 层级正则化
    private static func normalizeHeadingLevels(_ headings: [HeadingNode]) -> [HeadingNode] {
        guard !headings.isEmpty else { return [] }
        
        // 找到最小的标题层级作为根层级
        let minLevel = headings.map { $0.originalLevel }.min() ?? 1
        
        // 重新计算正则化层级
        return headings.map { heading in
            HeadingNode(
                text: heading.text,
                originalLevel: heading.originalLevel,
                normalizedLevel: heading.originalLevel - minLevel + 1,
                range: heading.range
            )
        }
    }
    
    // MARK: - 3. 构建层级树
    private static func buildHeadingTree(from headings: [HeadingNode]) -> [HeadingNode] {
        guard !headings.isEmpty else { return [] }
        
        var rootNodes: [HeadingNode] = []
        var stack: [HeadingNode] = []
        
        for heading in headings {
            var newHeading = heading
            
            // 清理堆栈，移除层级大于等于当前标题的节点
            while !stack.isEmpty && stack.last!.normalizedLevel >= heading.normalizedLevel {
                stack.removeLast()
            }
            
            if stack.isEmpty {
                // 这是根节点
                rootNodes.append(newHeading)
            } else {
                // 这是子节点，添加到父节点
                let parentIndex = stack.count - 1
                if parentIndex < rootNodes.count {
                    // 直接在根节点中找父节点
                    addChildToParent(&rootNodes, parentStack: Array(stack.dropLast()), child: newHeading)
                }
            }
            
            stack.append(newHeading)
        }
        
        return rootNodes
    }
    
    // 递归添加子节点到父节点
    private static func addChildToParent(_ nodes: inout [HeadingNode], parentStack: [HeadingNode], child: HeadingNode) {
        if parentStack.isEmpty {
            // 添加到根节点的最后一个节点
            if !nodes.isEmpty {
                nodes[nodes.count - 1].children.append(child)
            }
            return
        }
        
        let targetParent = parentStack.last!
        
        // 在根节点中查找目标父节点
        for i in 0..<nodes.count {
            if nodes[i].text == targetParent.text && nodes[i].normalizedLevel == targetParent.normalizedLevel {
                if parentStack.count == 1 {
                    // 直接添加子节点
                    nodes[i].children.append(child)
                } else {
                    // 递归查找更深层的父节点
                    addChildToParentRecursive(&nodes[i].children, parentStack: Array(parentStack.dropLast()), child: child)
                }
                return
            }
        }
    }
    
    private static func addChildToParentRecursive(_ nodes: inout [HeadingNode], parentStack: [HeadingNode], child: HeadingNode) {
        if parentStack.isEmpty {
            if !nodes.isEmpty {
                nodes[nodes.count - 1].children.append(child)
            }
            return
        }
        
        let targetParent = parentStack.last!
        
        for i in 0..<nodes.count {
            if nodes[i].text == targetParent.text && nodes[i].normalizedLevel == targetParent.normalizedLevel {
                if parentStack.count == 1 {
                    nodes[i].children.append(child)
                } else {
                    addChildToParentRecursive(&nodes[i].children, parentStack: Array(parentStack.dropLast()), child: child)
                }
                return
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 获取标题的简化文本（移除特殊字符）
    static func getSimplifiedText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    // 生成目录HTML
    static func generateTOCHTML(from tree: HeadingTree) -> String {
        return "<ul>\n" + generateTOCHTMLRecursive(nodes: tree.rootNodes) + "</ul>"
    }
    
    private static func generateTOCHTMLRecursive(nodes: [HeadingNode]) -> String {
        var html = ""
        for node in nodes {
            let cleanText = getSimplifiedText(node.text)
            html += "<li>\(cleanText)"
            if !node.children.isEmpty {
                html += "\n<ul>\n" + generateTOCHTMLRecursive(nodes: node.children) + "</ul>"
            }
            html += "</li>\n"
        }
        return html
    }
}

// MARK: - 使用示例扩展
extension MarkdownHeadingParser {
    
    // 演示如何处理混乱的标题层级
    static func demonstrateNormalization() -> String {
        let chaotic = """
        ### 第一章
        ##### 第一节
        ### 第二章
        #### 第二章第一节
        ##### 第二章第一节第一小节
        ### 第三章
        """
        
        let tree = parseHeadings(from: chaotic)
        
        var result = "原始混乱的标题层级:\n"
        result += chaotic + "\n\n"
        
        result += "正则化后的目录结构:\n"
        result += tree.getTableOfContents()
        
        result += "\n层级映射说明:\n"
        for heading in tree.flatList {
            result += "- '\(heading.text)': \(heading.originalLevel)级 → \(heading.normalizedLevel)级\n"
        }
        
        return result
    }
}