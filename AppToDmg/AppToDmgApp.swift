//
//  AppToDmgApp.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import SwiftUI

@main
struct AppToDmgApp: App {
    init() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 400, height: 680)
        }
        .windowResizability(.contentSize)
    }
}
