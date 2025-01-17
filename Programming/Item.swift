//
//  Item.swift
//  Programming
//
//  Created by Kyle Aitken on 2025-01-16.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
