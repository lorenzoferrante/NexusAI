//
//  BackView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

struct BackView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State var defaultsManager = DefaultsManager.shared
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
//                backGradient
            }
            .ignoresSafeArea()
        }
    }
    
    private var backGradient: some View {
        Group {
            Rectangle()
                .fill(ThemeColors.from(color: defaultsManager.selectedThemeColor))
                .colorEffect(
                    ShaderLibrary.default.parameterizedNoise(
                        .float(0.3),
                        .float(0.2),
                        .float(0.99)
                    )
                )
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: getColors(),
                        startPoint: .top,
                        endPoint: .bottom)
                )
        }
    }
    
    private func getColors() -> [Color] {
        var primaryColor = Color.black
        
        if colorScheme == .light {
            primaryColor = .white
            return [
                primaryColor.opacity(0.1),
                primaryColor.opacity(0.25),
                primaryColor.opacity(0.35),
                primaryColor.opacity(0.45),
                primaryColor.opacity(0.55),
                primaryColor.opacity(0.65),
                primaryColor.opacity(0.75),
                primaryColor.opacity(0.78),
            ]
        }
        return [
            primaryColor.opacity(0.3),
            primaryColor.opacity(0.45),
            primaryColor.opacity(0.55),
            primaryColor.opacity(0.65),
            primaryColor.opacity(0.75),
            primaryColor.opacity(0.8),
            primaryColor.opacity(0.85),
            primaryColor.opacity(0.9),
            primaryColor.opacity(0.95),
        ]
    }
}

#Preview {
    BackView()
        .preferredColorScheme(.light)
}
