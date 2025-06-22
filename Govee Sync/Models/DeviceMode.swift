//
//  DeviceMode.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//


import Foundation
import SwiftUI

/// Defines the controllable modes for the Govee device, including manual, sync, and special effect scenes.
enum DeviceMode: CaseIterable, Identifiable {
    // Basic Mode
    case manual
    
    // Scene Effects
    case screenMirroring
    case musicVisualizer
    case rainbow
    case pulse
    case breathe
    case strobe
    case candlelight
    case aurora
    case thunderstorm

    var id: Self { self }

    var description: String {
        switch self {
        case .manual: return "Manual"
        case .screenMirroring: return "Screen Sync"
        case .musicVisualizer: return "Music Sync"
        case .rainbow: return "Rainbow"
        case .pulse: return "Pulse"
        case .breathe: return "Breathe"
        case .strobe: return "Strobe"
        case .candlelight: return "Candlelight"
        case .aurora: return "Aurora"
        case .thunderstorm: return "Thunderstorm"
        }
    }
    
    /// A helper property to distinguish scenes from the basic manual control mode.
    var isScene: Bool {
        return self != .manual
    }
    
    /// Provides a standard SF Symbol name for each mode's icon.
    var icon: String {
        switch self {
        case .manual: return "hand.tap.fill"
        case .screenMirroring: return "display"
        case .musicVisualizer: return "music.note"
        case .rainbow: return "rainbow"
        case .pulse: return "waveform.path.ecg"
        case .breathe: return "lungs.fill"
        case .strobe: return "bolt.fill"
        case .candlelight: return "flame.fill"
        case .aurora: return "sparkles"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        }
    }
}
