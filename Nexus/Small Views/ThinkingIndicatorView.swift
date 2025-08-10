//
//  ThinkingIndicatorView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 31/07/25.
//

import SwiftUI

struct ThinkingIndicatorView: View {
    @State private var isAnimating = false
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var timer: Timer?

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .scaleEffect(isAnimating ? 0.9 : 0.6)
            .opacity(isAnimating ? 1.0 : 0.7)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear {
//                feedbackGenerator.prepare()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    isAnimating.toggle()
//                    feedbackGenerator.impactOccurred()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
}

// Preview
struct ThinkingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            ThinkingIndicatorView()
        }
        .preferredColorScheme(.dark)
    }
}
