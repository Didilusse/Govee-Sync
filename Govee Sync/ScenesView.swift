//
//  ScenesView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//  Updated with a robust pattern to fix compiler errors.
//

import SwiftUI

struct ScenesView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    // Defines the grid layout for the scene buttons, adapting to window size.
    let columns = [
        GridItem(.adaptive(minimum: 120))
    ]

    var body: some View {
        VStack {
            Text("Scenes")
                .font(.title)
                .fontWeight(.medium)
                .padding(.top)
                
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(DeviceMode.allCases.filter { $0.isScene }) { mode in
 
                        Button(action: {
                            bleManager.activeDeviceMode = mode
                        }) {
                            SceneButtonView(mode: mode, isSelected: bleManager.activeDeviceMode == mode)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        // The view is disabled if no device is connected, preventing user interaction.
        .disabled(bleManager.connectedPeripheral == nil || !bleManager.isDeviceControlReady)
    }
}

/// A purely visual component for displaying a scene. It no longer has an action closure.
struct SceneButtonView: View {
    let mode: DeviceMode
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: mode.icon)
                .font(.largeTitle)
                .foregroundColor(isSelected ? .accentColor : .primary)
            Text(mode.description)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .padding()
        .frame(minWidth: 120, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
    }
}

struct ScenesView_Previews: PreviewProvider {
    static var previews: some View {
        ScenesView()
            .environmentObject(GoveeBLEManager(settings: AppSettings()))
            .frame(width: 400, height: 400)
    }
}
