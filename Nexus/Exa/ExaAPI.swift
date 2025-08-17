//
//  ExaAPI.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 08/08/25.
//


import Foundation

// MARK: - Client

public final class ExaClient {
    private let apiKey: String = Secrets.exaAPIKey
    private let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Performs a search and returns only the `data.results` array.
    @discardableResult
    public func search(
        query: String,
        numResults: Int = 5,
        type: String = "keyword",
        includeText: Bool = true,
        includeContext: Bool = true
    ) async throws -> [ExaResult] {
        guard let url = URL(string: "https://api.exa.ai/search") else {
            throw ExaClientError.invalidURL
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        let payload = ExaSearchPayload(
            query: query,
            type: type,
            numResults: numResults,
            contents: .init(text: includeText, context: includeContext)
        )
        
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(payload)
        
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ExaClientError.badStatus(http.statusCode, body)
        }
        
        do {
            let decoder = JSONDecoder()

            if let direct = try? decoder.decode(ExaData.self, from: data) {
                return direct.results
            }

            throw ExaClientError.decoding(NSError(
                domain: "ExaClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode response as ExaSearchResponse or ExaData."]
            ))
        } catch {
            throw ExaClientError.decoding(error)
        }
    }

    // MARK: - Crawl (Contents)
    /// Fetches full page contents for the given URLs/IDs via Exa's `/contents` endpoint.
    /// - Parameters:
    ///   - ids: A list of document IDs or URLs to fetch (as accepted by Exa).
    ///   - includeText: Whether to include the full extracted text in the response (defaults to `true`).
    /// - Returns: The `data.results` array from Exa.
    @discardableResult
    public func crawl(
        ids: [String],
        includeText: Bool = true
    ) async throws -> [ExaResult] {
        guard let url = URL(string: "https://api.exa.ai/contents") else {
            throw ExaClientError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let payload = ExaContentsPayload(ids: ids, text: includeText)
        let encoder = JSONEncoder()
        req.httpBody = try encoder.encode(payload)

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ExaClientError.badStatus(http.statusCode, body)
        }

        do {
            let decoder = JSONDecoder()
            if let direct = try? decoder.decode(ExaData.self, from: data) {
                return direct.results
            }
            throw ExaClientError.decoding(NSError(
                domain: "ExaClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to decode response as ExaData (contents)."]
            ))
        } catch {
            throw ExaClientError.decoding(error)
        }
    }
}
