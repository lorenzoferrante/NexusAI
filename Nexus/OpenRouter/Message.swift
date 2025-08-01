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
    var fileData: String?
    var pdfData: String?
    var fileName: String?
    

    func asDictionary() -> [String: Any] {
        if let imageData = imageData {
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
        
        if let fileData = fileData {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": "This is the content of a file attached by the user: \(fileData)"
                    ],
                    [
                        "type": "text",
                        "text": content
                    ]
                ]
            ]
        }
        
        if let pdfData = pdfData {
            return [
                "role": role.rawValue,
                "content": [
                    [
                        "type": "text",
                        "text": content
                    ],
                    [
                        "type": "file",
                        "file": [
                            "filename": fileName ?? "file.pdf",
                            "file_data": pdfData
                        ]
                    ]
                ]
            ]
        }
        
        return ["role": role.rawValue, "content": content]
        
    }
}
