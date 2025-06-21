//
//  DisconnectButtonStyle.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//


import SwiftUI

struct DisconnectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.red.opacity(0.8) : Color.red.opacity(0.15))
            )
            .foregroundColor(configuration.isPressed ? .white : .red)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
