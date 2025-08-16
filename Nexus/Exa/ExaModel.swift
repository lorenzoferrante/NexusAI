//
//  ExaModel.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 08/08/25.
//

import Foundation

// MARK: - Models

public struct ExaResult: Decodable {
    public let id: String
    public let title: String?
    public let url: String
    public let publishedDate: String?
    public let author: String?
    public let text: String?
    public let image: String?
}

public struct ExaSearchResponse: Decodable {
    let data: ExaData
}

public struct ExaData: Decodable {
    let results: [ExaResult]
}

// Request payload
public struct ExaSearchPayload: Encodable {
    let query: String
    let type: String
    let numResults: Int
    let contents: Contents
    
    struct Contents: Encodable {
        let text: Bool
        let context: Bool
    }
}

// Payload for `/contents` endpoint
public struct ExaContentsPayload: Encodable {
    let ids: [String]
    let text: Bool?
}
