//
//  AppToDmgApp.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import SwiftUI

@main
struct AppToDmgApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 450, minHeight: 400)
        }
        .windowResizability(.contentMinSize)
    }
}
