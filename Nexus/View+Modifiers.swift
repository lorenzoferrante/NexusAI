//
//  View+Modifiers.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/30/25.
//

import Foundation
import SwiftUI
import VariableBlur

struct ProgressiveBlur: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Rectangle()
                    .fill(.clear)
                    .overlay {
                        VariableBlurView(maxBlurRadius: 5, direction: .blurredBottomClearTop)
                    }
                    .ignoresSafeArea()
            )
    }
}

extension View {
    func progressiveBlur() -> some View {
        self.modifier(ProgressiveBlur())
    }
}
