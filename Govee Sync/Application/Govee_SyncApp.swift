//
//  Govee_SyncApp.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 5/29/25.
//

import SwiftUI

@main
struct GoveeSyncApp: App {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var bleManager: GoveeBLEManager

    init() {
        let settings = AppSettings()
        _appSettings = StateObject(wrappedValue: settings)
        _bleManager = StateObject(wrappedValue: GoveeBLEManager(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .environmentObject(bleManager)
                .frame(width: 800, height: 600)
                
        }
    }
}
