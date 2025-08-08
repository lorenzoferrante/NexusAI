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
        TimelineView(.animation) { context in
            ZStack {
                BackView()
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                    Text("Fetching your data...")
                        .foregroundStyle(.primary)
                        .colorEffect(
                            ShaderLibrary.shimmer(
                                .float(context.date.timeIntervalSinceNow)
                            )
                        )
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LoadingView()
}
