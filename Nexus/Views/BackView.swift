//
//  BackView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

struct BackView: View {
    @State var defaultsManager = DefaultsManager.shared
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
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
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.45),
                                Color.black.opacity(0.55),
                                Color.black.opacity(0.65),
                                Color.black.opacity(0.75),
                                Color.black.opacity(0.8),
                                Color.black.opacity(0.85),
                                Color.black.opacity(0.9),
                                Color.black.opacity(0.95),
                                Color.black.opacity(1),
                                Color.black
                            ],
                            startPoint: .top,
                            endPoint: .bottom)
                    )
                    
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    BackView()
}
