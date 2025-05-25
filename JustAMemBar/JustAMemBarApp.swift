//
//  JustAMemBarApp.swift
//  JustAMemBar
//
//  Created by Bryan Le on 5/24/25.
//

import SwiftUI
import os.log

@main
struct JustAMemBarApp: App {
    @StateObject private var menuBarManager = MenuBarManager()
    
    var body: some Scene {
        // We don't need a window scene for a menu bar app
        // The MenuBarManager handles all the UI
        Settings {
            EmptyView()
        }
    }
}
