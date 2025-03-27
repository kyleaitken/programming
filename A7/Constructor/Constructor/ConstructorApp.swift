//
//  ConstructorApp.swift
//  Constructor
//
//  Created by Kyle Aitken on 2025-02-05.
//

import SwiftUI

@main
struct ConstructorApp: App {
    init() {
        // Run your logic here
        Constructor.example()
    }

    var body: some Scene {
        // No content window is created here
        EmptyScene()
    }
}

struct EmptyScene: Scene {
    var body: some Scene {
        // No views here, so nothing will be displayed
        WindowGroup {
            EmptyView()
        }
    }
}
