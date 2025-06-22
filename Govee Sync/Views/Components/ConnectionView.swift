//
//  ConnectionView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//


import SwiftUI
import CoreBluetooth

struct ConnectionView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    // A computed property to filter out the last connected device from the main discovery list.
    private var otherDiscoveredDevices: [CBPeripheral] {
        bleManager.discoveredPeripherals.filter {
            $0.identifier != bleManager.lastConnectedPeripheral?.identifier
        }
    }
    
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
                    ProgressView().controlSize(.small)
                    Text("Searching for devices...").foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            
            // --- UI LOGIC ---
            if !bleManager.discoveredPeripherals.isEmpty || bleManager.lastConnectedPeripheral != nil {
                List {
                    // Last Connected Section
                    if let lastConnected = bleManager.lastConnectedPeripheral {
                        Section(header: Text("Last Connected")) {
                            DeviceRowView(peripheral: lastConnected)
                        }
                    }
                    
                    // Other Devices Section
                    if !otherDiscoveredDevices.isEmpty {
                        // ** THIS IS THE FIX **
                        // We explicitly tell ForEach to use the `identifier` property of each
                        // peripheral as its unique ID, since CBPeripheral isn't Identifiable.
                        Section(header: Text(bleManager.lastConnectedPeripheral != nil ? "Other Devices" : "Discovered Devices")) {
                            ForEach(otherDiscoveredDevices, id: \.identifier) { peripheral in
                                DeviceRowView(peripheral: peripheral)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            } else if !bleManager.isScanning {
                // "No devices found" view
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

// A new, reusable view for displaying a device row to avoid code duplication.
struct DeviceRowView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    let peripheral: CBPeripheral
    
    var body: some View {
        HStack {
            Image(systemName: "lightbulb.led")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                Text(bleManager.lastConnectedPeripheral?.identifier == peripheral.identifier ? "Last connected" : "Ready to connect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Connect") { bleManager.connect(to: peripheral) }
                .font(.callout)
                .buttonStyle(BorderedButtonStyle())
        }
        .padding(.vertical, 8)
    }
}
