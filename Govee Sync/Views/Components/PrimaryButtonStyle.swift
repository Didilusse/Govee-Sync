//
//  PrimaryButtonStyle.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//


import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isActive: Bool
    
    @StateObject private var appSettings = AppSettings()

    
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(12)
            .foregroundColor(isActive ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
