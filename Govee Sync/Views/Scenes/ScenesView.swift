//
//  ScenesView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import SwiftUI

struct ScenesView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
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
                        
                        // Check if the current mode is the one we want to disable.
                        let isWIP = mode == .musicVisualizer
                        
                        Button(action: {
                            // Only change the mode if it's not a work-in-progress feature.
                            if !isWIP {
                                bleManager.activeDeviceMode = mode
                            }
                        }) {
                            SceneButtonView(mode: mode, isSelected: bleManager.activeDeviceMode == mode)
                                // Apply visual effects to gray it out.
                                .opacity(isWIP ? 0.4 : 1.0)
                                .saturation(isWIP ? 0.2 : 1.0)
                                // Add the "Work in Progress" overlay.
                                .overlay(
                                    ZStack {
                                        if isWIP {
                                            // Semi-transparent background for the text
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .fill(Color.black.opacity(0.5))
                                            
                                            VStack(spacing: 4) {
                                                Image(systemName: "wrench.and.screwdriver.fill")
                                                Text("WIP")
                                                    .font(.caption)
                                                    .bold()
                                            }
                                            .foregroundColor(.white)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isWIP) // Fully disable the button's action.
                    }
                }
                .padding()
            }
        }
        .disabled(bleManager.connectedPeripheral == nil || !bleManager.isDeviceControlReady)
    }
}

// NOTE: The SceneButtonView itself remains unchanged.
// The logic is all handled within the main ScenesView.
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
