import SwiftUI
import ScreenCaptureKit

struct ContentView: View {
    // Create the AppSettings object as a StateObject at the root of the view hierarchy.
    @StateObject private var appSettings = AppSettings()
    
    // The BLE Manager is now initialized with the settings object.
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
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        // Pass the objects into the environment for easy access by child views.
        .environmentObject(appSettings)
        .environmentObject(bleManager)
        .frame(minWidth: 450, idealWidth: 500, maxWidth: 600, minHeight: 500, idealHeight: 550, maxHeight: 650)
    }
}

// MARK: - Controls Tab View

struct ControlsView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Govee Sync")
                .font(.title)
                .fontWeight(.medium)
                .padding(.top)

            StatusView(status: bleManager.connectionStatus)
            
            if bleManager.connectedPeripheral == nil {
                ConnectionView()
            } else {
                DeviceControlView()
            }
        }
        .padding([.horizontal, .bottom])
    }
}

// MARK: - Subviews (Status, Connection, DeviceControl)

struct StatusView: View {
    let status: String
    
    var body: some View {
        Text(status)
            .padding(10)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            .padding(.vertical)
    }
}

struct ConnectionView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack {
            Button(bleManager.isScanning ? "Stop Scan" : "Scan for Devices") {
                if bleManager.isScanning { bleManager.stopScanning() }
                else { bleManager.startScanning() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            if bleManager.isScanning {
                ProgressView("Scanning...")
            }
            
            if !bleManager.discoveredPeripherals.isEmpty {
                List {
                    Section("Discovered Devices") {
                        ForEach(bleManager.discoveredPeripherals, id: \.identifier) { peripheral in
                            HStack {
                                Text(peripheral.name ?? "Unknown Device")
                                Spacer()
                                Button("Connect") { bleManager.connect(to: peripheral) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(maxHeight: .infinity)
            } else if !bleManager.isScanning {
                Text("No devices found.\nEnsure your Govee light is on and in range.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct DeviceControlView: View {
    @EnvironmentObject var bleManager: GoveeBLEManager
    
    var body: some View {
        VStack {
            if !bleManager.isDeviceControlReady {
                Spacer()
                ProgressView("Initializing device controls...")
                Spacer()
            } else {
                Form {
                    Section(header: Text("Main Controls")) {
                        Toggle(isOn: Binding(
                            get: { bleManager.isDeviceOn },
                            set: { bleManager.setPower(isOn: $0) }
                        )) {
                            Label("Power", systemImage: "power")
                        }
                        
                        HStack {
                            Label("Brightness", systemImage: "sun.max.fill")
                            Slider(value: Binding(
                                get: { Double(bleManager.currentBrightness) },
                                set: { newValue in bleManager.setLiveBrightness(level: UInt8(newValue)) }
                            ), in: 0...100, step: 1, onEditingChanged: { isEditing in
                                if !isEditing { bleManager.setFinalBrightness(level: bleManager.currentBrightness) }
                            })
                            Text("\(Int(bleManager.currentBrightness))%")
                                .frame(width: 40)
                        }
                    }
                    
                    Section(header: Text("Light Mode")) {
                        Picker("Mode", selection: $bleManager.activeLightMode) {
                            ForEach(GoveeBLEManager.LightMode.allCases) { mode in
                                Text(mode.description).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        switch bleManager.activeLightMode {
                        case .manual:
                            ColorPicker(selection: Binding(
                                get: { Color.fromRGB(r: bleManager.currentColorRGB.r, g: bleManager.currentColorRGB.g, b: bleManager.currentColorRGB.b) },
                                set: { newColor in let rgb = newColor.toRGBBytes(); bleManager.setColor(r: rgb.r, g: rgb.g, b: rgb.b) }
                            ), supportsOpacity: false) {
                                Label("Color", systemImage: "paintpalette.fill")
                            }
                        case .screenMirroring:
                            Picker(selection: $bleManager.selectedDisplayID) {
                                ForEach(bleManager.availableDisplays, id: \.displayID) { display in
                                    Text("Display \(display.displayID): \(display.width)x\(display.height)").tag(display.displayID as CGDirectDisplayID?)
                                }
                            } label: { Label("Source Display", systemImage: "display") }
                            .onAppear(perform: bleManager.updateAvailableDisplays)

                        case .rainbow:
                            Label("A dynamic, colorful effect.", systemImage: "rainbow")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(role: .destructive) {
                bleManager.disconnect()
            } label: {
                Text("Disconnect from \(bleManager.connectedPeripheral?.name ?? "Device")")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
