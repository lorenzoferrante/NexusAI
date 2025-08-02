//
//  SignView.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/2/25.
//

import SwiftUI
import AuthenticationServices
import Supabase

struct SignView: View {
    @State var supabaseClient = SupabaseManager.shared
    
    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    SignView()
}
