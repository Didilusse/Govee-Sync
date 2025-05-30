// ContentView.swift
import SwiftUI


struct ContentView: View {
    @StateObject private var bleManager = GoveeBLEManager()
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Govee LED Controller")
                .font(.title)
                .padding(.top)
            
            Text(bleManager.connectionStatus)
                .padding()
                .multilineTextAlignment(.center)
                .foregroundColor(bleManager.connectionStatus.lowercased().contains("unauthorized") || bleManager.connectionStatus.lowercased().contains("off") || bleManager.connectionStatus.lowercased().contains("error") ? .red : .primary)
                .fixedSize(horizontal: false, vertical: true)
            
            if bleManager.connectedPeripheral == nil {
                Button(bleManager.isScanning ? "Stop Scan" : "Scan for Devices") {
                    if bleManager.isScanning { bleManager.stopScanning() } else { bleManager.startScanning() }
                }
                .padding().buttonStyle(.borderedProminent)
                
                if bleManager.isScanning && bleManager.discoveredPeripherals.isEmpty {
                    ProgressView("Scanning...").padding()
                } else if !bleManager.discoveredPeripherals.isEmpty {
                    List {
                        Section("Discovered Devices") {
                            ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                                HStack { Text(peripheral.name ?? "Unknown (\(peripheral.identifier.uuidString.prefix(4)))"); Spacer(); Button("Connect") { bleManager.connect(to: peripheral) }.buttonStyle(.bordered) }
                            }
                        }
                    }.frame(maxHeight: 200)
                } else if !bleManager.isScanning { Text("No devices found. Try scanning.").padding() }
                
            } else {
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Connected to: \(bleManager.connectedPeripheral?.name ?? "Govee Device")")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    if bleManager.isDeviceControlReady {
                        
                        Toggle("Power", isOn: Binding(
                            get: { bleManager.isDeviceOn },
                            set: { bleManager.setPower(isOn: $0) }
                        ))
                        
                        HStack {
                            Text("Brightness: \(Int(bleManager.currentBrightness))%")
                            Slider(value: Binding(
                                get: { Double(bleManager.currentBrightness) },
                                set: { newValueFromSlider in
                                    let newBrightnessUInt8 = UInt8(newValueFromSlider.rounded())
                                    bleManager.setBrightness(level: newBrightnessUInt8)
                                }
                            ),
                                   in: 0...100, step: 1,
                                   onEditingChanged: { editingFinished in
                                if editingFinished { bleManager.setBrightness(level: bleManager.currentBrightness) }
                            })
                        }
                        
                        // Screen Mirroring Toggle
                        Toggle("Screen Mirroring", isOn: $bleManager.isScreenMirroringActive.animation())
                            .onChange(of: bleManager.isScreenMirroringActive) { newValue in
                                bleManager.toggleScreenMirroring()
                            }
                        
                        ColorPicker("Manual Color", selection: Binding(
                            get: { Color.fromRGB(r: bleManager.currentColorRGB.r,
                                                 g: bleManager.currentColorRGB.g,
                                                 b: bleManager.currentColorRGB.b) },
                            set: { newColor in
                                if bleManager.isScreenMirroringActive {
                                    bleManager.stopScreenMirroring()
                                }
                                let rgbBytes = newColor.toRGBBytes()
                                bleManager.setColor(r: rgbBytes.r, g: rgbBytes.g, b: rgbBytes.b)
                            }
                        ), supportsOpacity: false)
                        .disabled(bleManager.isScreenMirroringActive)
                        
                    } else {
                        Text("Device connected, waiting for control service...").padding(.vertical)
                        ProgressView()
                    }
                    
                    Spacer()
                    Button(action: {
                        bleManager.disconnect()
                    }) {
                        Text("Disconnect")
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                }
                .padding()
            }
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 450)
    }
}
