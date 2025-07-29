//
//  Message.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 7/29/25.
//

import Foundation

struct Message: Codable, Identifiable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    var id = UUID()
    let role: Role
    var content: String

    func asDictionary() -> [String: String] {
        ["role": role.rawValue, "content": content]
    }
}
