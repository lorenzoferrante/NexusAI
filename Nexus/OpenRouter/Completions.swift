//
//  Completions.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 04/08/25.
//

import Foundation

struct Choice: Decodable {
    let text: String
    let index: Int?
    let finish_reason: String?
}

struct CompletionResponse: Decodable {
    let id: String
    let choices: [Choice]
}
