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

struct MetalShimmer: ViewModifier {
    var speed: Double = 0.9          // sweeps per second
    var angle: Angle = .degrees(20)
    var width: Double = 0.28
    var strength: Double = 0.22

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceNow * speed
            content.colorEffect(
                ShaderLibrary.shimmerColor(
                    .float(Float(t)),
                    .float(Float(angle.radians)),
                    .float(Float(width)),
                    .float(Float(strength))
                )
            )
        }
    }
}

extension View {
    func metalShimmer(
        speed: Double = 0.9,
        angle: Angle = .degrees(20),
        width: Double = 0.28,
        strength: Double = 0.22
    ) -> some View {
        modifier(MetalShimmer(speed: speed, angle: angle, width: width, strength: strength))
    }
}

