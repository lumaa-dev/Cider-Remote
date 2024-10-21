//
//  Cider_RemoteApp.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

@main
struct Cider_RemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
