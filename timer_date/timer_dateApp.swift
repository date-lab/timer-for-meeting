//
//  timer_dateApp.swift
//  timer_date
//
//  Created by 野口祥生 on 2025/05/23.
//

import SwiftUI

@main
struct TimerDateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { makeWindowFloating() }
        }
        .windowResizability(.contentSize)
    }
}
