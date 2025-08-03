//
//  SettingsView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/3/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                BackView()
                
                VStack(spacing: 20) {
                    VStack {
                        cell(
                            "Profile",
                             icon: "person.crop.circle.fill",
                             destination: AnyView(CreateProfileView())
                        )
                    }
                    .padding()
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    
                    VStack {
                        cell("Default model", icon: "gear")
                        cell("Theme color", icon: "swatchpalette.fill")
                    }
                    .padding()
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(.dark)
    }
    
    private func cell(
        _ value: String,
        icon: String,
        destination: AnyView = AnyView(EmptyView())) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(value)
                    .font(.default)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
        .padding(10)
    }
}

#Preview {
    SettingsView()
}
