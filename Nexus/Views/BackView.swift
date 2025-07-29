//
//  BackView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation
import SwiftUI

struct BackView: View {
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.red)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
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

#Preview {
    BackView()
}
