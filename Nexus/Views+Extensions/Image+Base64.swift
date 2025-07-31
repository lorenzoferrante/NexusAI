//
//  Base64Image.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 31/07/25.
//

import SwiftUI

extension Image {
    init(base64DataString: String) {
        self = Image.imageFromBase64(base64DataString) ?? Image(systemName: "photo.fill")
    }
    
    private static func imageFromBase64(_ data: String) -> Image? {
        let cleanString: String
        if let commaIndex = data.firstIndex(of: ",") {
            cleanString = String(data[data.index(after: commaIndex)...])
        } else {
            cleanString = data
        }
        
        guard let imageData = Data(base64Encoded: cleanString) else { return nil }
        
        guard let uiImage = UIImage(data: imageData) else { return nil }
        return Image(uiImage: uiImage)
    }
}
