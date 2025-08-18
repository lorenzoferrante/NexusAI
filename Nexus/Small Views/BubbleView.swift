//
//  BubbleView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/3/25.
//

import SwiftUI
internal import Combine

struct BubbleView: View {
    @State var question = "What would happen if gravity suddenly disappeared for 5 seconds?"
    
    var body: some View {
        Text(question)
            .fontDesign(.serif)
            .foregroundStyle(.secondary)
            .padding()
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
            .preferredColorScheme(.dark)
            .opacity(0.7)
    }
}

struct CarouselView: View {
    @State var questions: [String] = [
        "What would happen if gravity suddenly disappeared for 5 seconds?",
        "How would the world look today if electricity had never been invented?",
        "If you could send one message back in time, what would it say?",
        "Describe a civilization that evolved underwater instead of on land.",
        "What would Earth be like if dinosaurs had never gone extinct?",
        "Explain a plausible scenario in which robots gain genuine human-like emotions.",
        "Create a bedtime story about a robot who dreams of being human.",
        "What would happen if animals could suddenly speak human languages?",
        "Invent an entirely new type of sport for a zero-gravity environment.",
        "How would our lives change if sleep became optional?",
        "Describe the taste of colors to someone who can’t see.",
        "Explain the internet to someone from Ancient Rome.",
        "If pets could write reviews of their humans, what would they say?",
        "Imagine discovering Atlantis today. What would the news headline be?",
        "If you had access to a portal that could take you anywhere, but only once, where would you go and why?",
        "Explain the internet to someone from Ancient Rome",
    ]
    
    let rows: [GridItem] = [
        GridItem(.flexible())
    ]
    
    @State private var currentIndex: Int = 0
    /// Auto‑scroll every 2 seconds
    private let autoScroll = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows) {
                        ForEach(Array(questions.enumerated()), id: \.offset) { index, item in
                            BubbleView(question: item)
                                .padding([.leading, .trailing])
                                .frame(width: geo.size.width)
                                .id(index)
                        }
                    }
                }
                .frame(height: geo.size.height)
                .onAppear {
                    proxy.scrollTo(0, anchor: .leading)
                }
                .onReceive(autoScroll) { _ in
                    withAnimation(.easeInOut(duration: 1)) {
                        currentIndex = (currentIndex + 1) % questions.count
                        proxy.scrollTo(currentIndex, anchor: .leading)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    
}

#Preview {
    ZStack {
        BackView()
        VStack {
            CarouselView()
        }
    }
}
