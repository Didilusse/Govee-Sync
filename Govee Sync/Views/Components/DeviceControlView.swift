//
//  DeviceControlView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import SwiftUI

struct DeviceControlView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack(spacing: 20) {
            if !bleManager.isDeviceControlReady {
                VStack {
                    Spacer()
                    ProgressView("Initializing device...")
                        .controlSize(.large)
                    Spacer()
                }
            } else {
                Form {
                    Section {
                        Toggle(isOn: Binding(
                            get: { bleManager.isDeviceOn },
                            set: { bleManager.setPower(isOn: $0) }
                        )) {
                            Label("Power", systemImage: "power")
                                .font(.body)
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 8)
                    } header: {
                        Text("System")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                    
                    Section {
                        // Brightness Control
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Brightness", systemImage: "sun.max.fill")
                                Spacer()
                                Text("\(Int(bleManager.currentBrightness))%")
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(bleManager.currentBrightness) },
                                set: { newValue in bleManager.setLiveBrightness(level: UInt8(newValue)) }
                            ), in: 0...100, step: 1, onEditingChanged: { isEditing in
                                if !isEditing { bleManager.setFinalBrightness(level: bleManager.currentBrightness) }
                            })
                            .disabled(bleManager.activeDeviceMode == .screenMirroring)
                        }
                        .padding(.vertical, 8)
                        
                        // Color Control
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Color", systemImage: "paintpalette.fill")
                            
                            HStack(spacing: 16) {
                                ColorPicker(selection: Binding(
                                    get: { Color.fromRGB(r: bleManager.currentColorRGB.r, g: bleManager.currentColorRGB.g, b: bleManager.currentColorRGB.b) },
                                    set: { newColor in
                                        #if canImport(AppKit)
                                        let nsColor = NSColor(newColor)
                                        let components = nsColor.cgColor.components ?? [0,0,0]
                                        let r = UInt8((components[0] * 255).rounded())
                                        let g = UInt8((components[1] * 255).rounded())
                                        let b = UInt8((components[2] * 255).rounded())
                                        bleManager.setColor(r: r, g: g, b: b)
                                        #else
                                        let rgb = newColor.toRGBBytes()
                                        bleManager.setColor(r: rgb.r, g: rgb.g, b: rgb.b)
                                        #endif
                                    }
                                ), supportsOpacity: false) {
                                    Text("")
                                }
                                .frame(width: 60, height: 60)
                                .disabled(bleManager.activeDeviceMode == .screenMirroring)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Color")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("RGB: \(bleManager.currentColorRGB.r), \(bleManager.currentColorRGB.g), \(bleManager.currentColorRGB.b)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Manual Control")
                            .font(.headline)
                            .padding(.top, 8)
                    } footer: {
                        Text("Adjusting these will switch to Manual mode.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                }
                .formStyle(.grouped)
            }
            
            // Disconnect Button
            Button(role: .destructive) {
                bleManager.disconnect()
            } label: {
                Label("Disconnect from \(bleManager.connectedPeripheral?.name ?? "Device")", systemImage: "xmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DisconnectButtonStyle())
            .padding(.top, 10)
        }
    }
}
