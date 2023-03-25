//
//  File.swift
//  
//
//  Created by Paolo Polidori on 07/10/22.
//

import Foundation

struct KeyboardState : Codable, CustomStringConvertible {
    var lang: String
    
    init(lang: String) {
        self.lang = lang
    }
    
    public var description: String { return "\(lang)" }
}
