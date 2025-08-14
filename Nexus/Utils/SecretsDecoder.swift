//
//  SecretsDecoder.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 14/08/25.
//

import Foundation

enum Secrets {
    static var openRouterAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPEN_ROUTER_API_KEY") as? String else {
            fatalError("Please add the OPEN_ROUTER_API_KEY key.")
        }
        return key
    }
    
    static var supabaseAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_API_KEY") as? String else {
            fatalError("Please add the SUPABASE_API_KEY key.")
        }
        return key
    }
    
    static var exaAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "EXA_API_KEY") as? String else {
            fatalError("Please add the EXA_API_KEY key.")
        }
        return key
    }
}
