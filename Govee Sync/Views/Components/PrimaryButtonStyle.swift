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
            .background(
                RoundedRectangle(cornerRadius: 8)
                    // Use the accentColor from the environment.
                    .fill(isActive ? LinearGradient(colors: [appSettings.accentColor.opacity(0.8), appSettings.accentColor], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            )
            .foregroundColor(isActive ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    // Use the accentColor for the border as well.
                    .stroke(isActive ? appSettings.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
