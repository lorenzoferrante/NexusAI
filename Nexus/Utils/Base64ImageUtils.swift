//
//  Base64ImageUtils.swift
//  Nexus
//
//  Created by Codex on 09/23/25.
//

import UIKit

enum Base64ImageUtils {
    /// Converts a data URL (e.g., "data:image/png;base64,AAA...") or raw base64 string into a UIImage.
    static func uiImage(fromDataURL dataURL: String) -> UIImage? {
        let cleanString: String
        if let comma = dataURL.firstIndex(of: ",") {
            cleanString = String(dataURL[dataURL.index(after: comma)...])
        } else {
            cleanString = dataURL
        }
        guard let data = Data(base64Encoded: cleanString, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
    }
}

