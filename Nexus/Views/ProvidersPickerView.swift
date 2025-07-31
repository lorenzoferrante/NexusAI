//
//  ProvidersPickerView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 31/07/25.
//

import SwiftUI

struct ProvidersPickerView: View {
    @State var vm = OpenRouterAPI.shared
    @State var providers: Set<Providers> = []
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Material.ultraThin)
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                Spacer()
                ScrollView {
                    ForEach(Array(providers), id: \.rawValue) { provider in
                        Text(provider.rawValue)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            providers = Set(ModelsList.models.map(\.provider))
        }
    }
}

#Preview {
    ZStack {
        BackView()
        
        ProvidersPickerView()
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
