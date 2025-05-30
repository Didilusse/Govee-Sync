//
//  RGBBytes.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 5/29/25.
//

import SwiftUI
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

extension Color {
    struct RGBBytes {
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }

    func toRGBBytes() -> RGBBytes {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var opacity: CGFloat = 0

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSColor(self).usingColorSpace(.sRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &opacity) ?? {
            
            print("Warning: Could not convert color to sRGB for component extraction. Using direct components if available.")
            NSColor(self).getRed(&red, green: &green, blue: &blue, alpha: &opacity)
        }()
        #else
        if let cgColor = self.cgColor {
            if cgColor.numberOfComponents >= 3 {
                 let components = cgColor.components
                 red = components?[0] ?? 0
                 green = components?[1] ?? 0
                 blue = components?[2] ?? 0
                 // opacity = components.count >= 4 ? (components?[3] ?? 1) : 1
            } else if cgColor.numberOfComponents == 2 { // Grayscale
                 let white = cgColor.components?[0] ?? 0
                 red = white; green = white; blue = white
                 // opacity = cgColor.components?[1] ?? 1
            }
        } else {
             print("Warning: CGColor not available for Color to RGB conversion.")
        }
        #endif
        
        return RGBBytes(r: UInt8(max(0,min(1,red)) * 255.0), 
                        g: UInt8(max(0,min(1,green)) * 255.0),
                        b: UInt8(max(0,min(1,blue)) * 255.0))
    }

    static func fromRGB(r: UInt8, g: UInt8, b: UInt8) -> Color {
        Color(red: Double(r) / 255.0,
              green: Double(g) / 255.0,
              blue: Double(b) / 255.0)
    }
}
