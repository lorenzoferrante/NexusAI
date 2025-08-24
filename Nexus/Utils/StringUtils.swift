//
//  StringUtils.swift
//  Nexus
//
//  Created by Lorenzo Ferrante on 8/22/25.
//

import Foundation

extension String? {
    
    public func isNilOrEmpty() -> Bool {
        if self == nil {
            return true
        } else {
            return self!.isEmpty
        }
    }
    
}
