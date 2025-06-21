//
//  ConnectionView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Scan Button
            Button(action: {
                bleManager.isScanning ? bleManager.stopScanning() : bleManager.startScanning()
            }) {
                Label(bleManager.isScanning ? "Stop Scanning" : "Scan for Devices", systemImage: "wifi")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(isActive: bleManager.isScanning))
            .keyboardShortcut("s", modifiers: .command)
            
            // Scanning Indicator
            if bleManager.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching for devices...")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            // Device List
            if !bleManager.discoveredPeripherals.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            HStack {
                                Image(systemName: "lightbulb.led")
                                    .font(.title3)
                                    .frame(width: 36)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text("Tap to connect")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { bleManager.connect(to: peripheral) }) {
                                    Text("Connect")
                                        .font(.callout)
                                }
                                .buttonStyle(BorderedButtonStyle())
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Material.regular)
                                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 8)
                }
            } else if !bleManager.isScanning {
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                    Text("No devices found")
                        .font(.headline)
                    Text("Ensure your Govee light is powered on and within Bluetooth range.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: 300)
                }
                .padding(.vertical, 40)
            }
            
            Spacer()
        }
    }
}
