//
//  AppSettings.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import Foundation

import SwiftUI


class AppSettings: ObservableObject {
    
    // MARK: - Accent Color
    // We store the raw components of the color because Color itself is not storable in AppStorage.
    @AppStorage("accentColorRed") private var accentColorRed: Double = 0.0 // Default to blue
    @AppStorage("accentColorGreen") private var accentColorGreen: Double = 0.478
    @AppStorage("accentColorBlue") private var accentColorBlue: Double = 1.0

    // The rest of the app will use this computed property to get the accent color.
    var accentColor: Color {
        get {
            Color(red: accentColorRed, green: accentColorGreen, blue: accentColorBlue)
        }
        set {
            // When a new color is set, we break it down into its storable components.
            let components = newValue.toRGBComponents()
            accentColorRed = components.r
            accentColorGreen = components.g
            accentColorBlue = components.b
            objectWillChange.send() // Notify the UI to update.
        }
    }
    
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
}
fileprivate extension Color {
    struct RGBComponents {
        let r: Double
        let g: Double
        let b: Double
    }
    
    func toRGBComponents() -> RGBComponents {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var o: CGFloat = 0
        
        #if canImport(AppKit)
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &o)
        #else
        // Fallback for other platforms if needed
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        #endif
        
        return RGBComponents(r: r, g: g, b: b)
    }
}
