//
//  AppSettings.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import Foundation

import SwiftUI


class AppSettings: ObservableObject {
    
    
    // MARK: - Screen Sync Settings
    
    @AppStorage("captureFPS")
    var captureFPS: Int = 10 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("captureWidth")
    var captureWidth: Int = 64 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("captureHeight")
    var captureHeight: Int = 36 {
        didSet { objectWillChange.send() }
    }
    
    // MARK: - Automation Settings
    
    @AppStorage("powerOnConnect")
    var powerOnConnect: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("powerOffDisconnect")
    var powerOffDisconnect: Bool = true {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage("lastConnectedDeviceID") var lastConnectedDeviceID: String?
}
