//
//  Profile.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 03/08/25.
//

import Foundation
import Supabase

struct Profile: Codable, Sendable {
    let username: String?
    let fullname: String?
    
    enum CodingKeys: String, CodingKey {
        case username
        case fullname = "full_name"
    }
}
