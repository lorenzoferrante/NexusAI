//
//  ToolsManager.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 08/08/25.
//

import Foundation
import SwiftUI

enum ToolType: CaseIterable {
    case webSearch
    case crawlTool
    case calendarTool
    case genericTool
    case docLookUp
}

struct ToolInfo {
    let name: String
    let icon: String
    let accentColor: Color
}

@MainActor
class ToolsManager {
    
    // MARK: - Properties
    
    /// Registry of all available tools
    private let tools: [Tool]
    
    /// Singleton instance (optional, you can also inject this)
    static let shared = ToolsManager()
    
    // MARK: - Initialization
    
    init() {
        // Register all available tools here
        self.tools = [
            WebSearchTool(),
            CalendarTool(),
            CrawlTool()
//            DocLookupTool(),
        ]
    }
    
    // MARK: - Tool Registry Methods
    
    /// Get all available tools as function definitions
    func getAllToolDefinitions() -> [[String: Any]] {
        tools.map { $0.asFunctionDefinition() }
    }
    
    /// Get a specific tool by name
    func getTool(named name: String) -> Tool? {
        tools.first { $0.name == name }
    }
    
    /// Execute a tool by name with given arguments
    func executeTool(named name: String, arguments: String, other: String? = nil) async throws -> String {
        guard let tool = getTool(named: name) else {
            throw ToolError.toolNotFound(name)
        }
        
        do {
            return try await tool.execute(arguments: arguments, others: other)
        } catch {
            throw ToolError.executionFailed(name, error)
        }
    }
    
    // MARK: - Backward Compatibility Methods
    // Keep these for compatibility with your existing codebase
    
    func makeFunctionTool(
        name: String,
        description: String,
        parameters: [String: Any]
    ) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
    
    func makeWebSearchTool() -> [String: Any] {
        WebSearchTool().asFunctionDefinition()
    }
    
    func executeWebSearch(_ query: String) async throws -> String {
        let args = #"{"query":"\#(query)"}"#
        return try await executeTool(named: "search_web", arguments: args)
    }
    
    func getToolTypeFrom(_ name: String) -> ToolType {
        getTool(named: name)?.type ?? .genericTool
    }
    
    func getInfoFor(_ toolType: ToolType) -> ToolInfo {
        switch toolType {
        case .webSearch:
            return .init(name: "Performing web search", icon: "network", accentColor: .blue)
        case .crawlTool:
            return .init(name: "Reading web page content", icon: "text.page.badge.magnifyingglass", accentColor: .purple)
        case .docLookUp:
            return .init(name: "Analyzing document", icon: "text.document", accentColor: .yellow)
        case .calendarTool:
            return .init(name: "Adding calendar event", icon: "calendar.badge", accentColor: .red)
        case .genericTool:
            return .init(name: "Performing tool call", icon: "cpu.fill", accentColor: .secondary)
        }
    }
    
}

// MARK: - Error Types
enum ToolError: LocalizedError {
    case toolNotFound(String)
    case executionFailed(String, Error)
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found"
        case .executionFailed(let name, let error):
            return "Tool '\(name)' execution failed: \(error.localizedDescription)"
        }
    }
}

