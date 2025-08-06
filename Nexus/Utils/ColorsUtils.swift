//
//  ColorsUtils.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 06/08/25.
//

import Foundation
import SwiftUI

enum ThemeColors: String, CaseIterable {
    case defaultRed
    case bronze
    case realPurple
    case darkGray
    case brightBlue
    case soTeal
    case gold
    case leafGreen
    
    static func from(color: ThemeColors) -> Color {
        switch color {
        case .defaultRed: return .red
        case .bronze: return .bronze
        case .realPurple: return .realPurple
        case .darkGray: return .darkGray
        case .brightBlue: return .brightBlue
        case .soTeal: return .soTeal
        case .gold: return .gold
        case .leafGreen: return .leafGreen
        }
    }
    
    static func toString(color: ThemeColors) -> String {
        switch color {
        case .defaultRed: return "Default Red"
        case .bronze: return "Bronze"
        case .realPurple: return "Haze"
        case .darkGray: return "Metal"
        case .brightBlue: return "BrightBlue"
        case .soTeal: return "So Teal"
        case .gold: return "Gold"
        case .leafGreen: return "Leaf Green"
        }
    }
}

extension Color {
    
    static let bronze = fromHex("#ffa763")
    static let realPurple = fromHex("#ef5eff")
    static let darkGray = fromHex("#797b7d")
    static let brightBlue = fromHex("#1e8cfa")
    static let soTeal = fromHex("#5effdc")
    static let gold = fromHex("#ffec5e")
    static let leafGreen = fromHex("#93ff61")
    
    static func fromHex(_ hex: String) -> Self {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        
        var rgb: UInt64 = 0
        
        var r: Double = 0.0
        var g: Double = 0.0
        var b: Double = 0.0
        var a: Double = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return .clear }
        
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return .clear
        }
        
        return self.init(red: r, green: g, blue: b, opacity: a)
    }
}
