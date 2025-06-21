import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    @StateObject private var appSettings = AppSettings()
    @StateObject private var bleManager: GoveeBLEManager
    
    init() {
        let settings = AppSettings()
        _appSettings = StateObject(wrappedValue: settings)
        _bleManager = StateObject(wrappedValue: GoveeBLEManager(settings: settings))
    }
    
    var body: some View {
        TabView {
            ControlsView()
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
            
            ScenesView()
                .tabItem {
                    Label("Scenes", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environmentObject(appSettings)
        .environmentObject(bleManager)
        .frame(minWidth: 480, idealWidth: 550, maxWidth: 650, minHeight: 500, idealHeight: 550, maxHeight: 650)
    }
}

// MARK: - Controls Tab View
struct ControlsView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lightbulb.led.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
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
            
            // Content Area
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

// MARK: - Subviews
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
                                    .foregroundColor(.blue)
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

// MARK: - Custom Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    var isActive: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [Color.primary.opacity(0.1), Color.primary.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            )
            .foregroundColor(isActive ? .white : .primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

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
