//
//  LoadingView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/8/25.
//

import SwiftUI

struct LoadingView: View {
    @State private var time: Float = 0
    
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { context in
                ZStack {
                    BackView()
                        .ignoresSafeArea()
                    
                    VStack {
                        ProgressView()
                        Text("Fetching your data...")
                            .foregroundStyle(.primary)
//                            .layerEffect(
//                                ShaderLibrary.shimmer(
//                                    .float(context.date.timeIntervalSinceNow),
//                                    .float2(Float(proxy.size.width), Float(proxy.size.height))
//                                ),
//                                maxSampleOffset: .zero
//                            )
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    LoadingView()
}
