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
    var imageData: String?

    func asDictionary() -> [String: Any] {
        guard let imageData = imageData else {
            return ["role": role.rawValue, "content": content]
        }
        return [
            "role": role.rawValue,
            "content": [
                [
                    "type": "text",
                    "text": content
                ],
                [
                    "type": "image_url",
                    "image_url": imageData
                ]
            ]
        ]
    }
}
