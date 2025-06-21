//
//  ControlsView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//
import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    @EnvironmentObject var appSettings: AppSettings

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.led.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [appSettings.accentColor.opacity(0.7), appSettings.accentColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Govee Sync")
                        .font(.system(size: 24, weight: .bold))
                }
                
                StatusView(status: bleManager.connectionStatus)
            }
            .padding(.top, 20)
            
            // Content Area - This will now correctly switch between the two views.
            if bleManager.connectedPeripheral == nil {
                ConnectionView()
            } else {
                DeviceControlView()
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}
