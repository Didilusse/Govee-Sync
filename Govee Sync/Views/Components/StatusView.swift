//
//  StatusView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import SwiftUI
struct StatusView: View {
    let status: String
    
    var body: some View {
        Text(status)
            .font(.callout)
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Material.regular)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}
