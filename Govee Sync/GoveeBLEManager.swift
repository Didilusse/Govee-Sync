//
//  GoveeBLEManager.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 5/29/25.
//


import SwiftUI
import CoreBluetooth
import Combine
import ScreenCaptureKit

// MARK: - Constants and Extensions

let GOVEE_CONTROL_CHARACTERISTIC_UUID = CBUUID(string: "00010203-0405-0607-0809-0a0b0c0d2b11")
let GOVEE_COMMAND_HEAD: UInt8 = 0x33
let GOVEE_KEEP_ALIVE_HEAD: UInt8 = 0xAA

extension CBManagerState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .poweredOff: return "Powered Off"
        case .poweredOn: return "Powered On"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unknown: return "Unknown"
        case .unsupported: return "Unsupported"
        @unknown default: return "Error: Unknown CBManagerState (\(self.rawValue))"
        }
    }
}

// MARK: - GoveeBLEManager

class GoveeBLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Published State Properties
    
    // Connection & Scanning
    @Published var isScanning: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var connectionStatus: String = "App Started. Initializing Bluetooth..."
    @Published var isDeviceControlReady: Bool = false
    
    // Device State
    @Published var isDeviceOn: Bool = false
    @Published var currentBrightness: UInt8 = 100
    @Published var currentColorRGB: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    
    // Feature State
    @Published var activeLightMode: LightMode = .manual {
        didSet {
            DispatchQueue.main.async {
                self.handleModeChange(from: oldValue, to: self.activeLightMode)
            }
        }
    }
    @Published var availableDisplays: [SCDisplay] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    
    // MARK: - Private Properties
    
    private var cbManager: CBCentralManager!
    private var controlCharacteristic: CBCharacteristic?
    private let appSettings: AppSettings
    // Services & Timers
    private let screenColorService: ScreenColorService
    private var keepAliveTimer: Timer?
    private var activeEffectTimer: Timer?
    
    // Effect-specific state
    private var currentHue: CGFloat = 0.0 // For rainbow effect
    
    // Caching to reduce redundant BLE commands
    private var lastSentColorRGB: (r: UInt8, g: UInt8, b: UInt8)?
    private var lastSentBrightness: UInt8?
    
    private var lastBrightnessUpdateTime: Date = .distantPast
    private let brightnessUpdateThrottle: TimeInterval = 0.1 // Send updates at most every 100ms (10hz)
    
    
    
    // MARK: - Light Mode Management
    
    enum LightMode: CaseIterable, Identifiable {
        case manual
        case screenMirroring
        case rainbow
        
        var id: Self { self }
        
        var description: String {
            switch self {
            case .manual: return "Manual"
            case .screenMirroring: return "Screen Sync"
            case .rainbow: return "Rainbow"
            }
        }
    }
    
    init(settings: AppSettings) {
        // The screen color service is now initialized with the settings.
        self.appSettings = settings
        self.screenColorService = ScreenColorService(settings: settings)
        super.init()
        cbManager = CBCentralManager(delegate: self, queue: nil)
        
        self.screenColorService.onNewAverageColor = { [weak self] avgColorTuple in
            guard let self = self, self.activeLightMode == .screenMirroring, let color = avgColorTuple else { return }
            self.sendScreenColorToDevice(newScreenColorRGB: color)
        }
        
        Task {
            await self.updateAvailableDisplays()
        }
    }
    
    private func handleModeChange(from oldMode: LightMode, to newMode: LightMode) {
        if oldMode == newMode { return }
        
        print("[ModeChange] Switching from \(oldMode) to \(newMode)")
        stopAllModes()
        
        if newMode != .manual && !isDeviceOn {
            setPower(isOn: true, internalOnly: true)
        }
        
        switch newMode {
        case .screenMirroring:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard self.activeLightMode == .screenMirroring else { return }
                self.startScreenMirroringInternal()
            }
        case .rainbow:
            startRainbowEffectInternal()
        case .manual:
            setColor(r: currentColorRGB.r, g: currentColorRGB.g, b: currentColorRGB.b)
            // Use setFinalBrightness to ensure the value is sent
            setFinalBrightness(level: currentBrightness)
            break
        }
    }
    
    /// Stops all timers and services associated with dynamic modes.
    private func stopAllModes() {
        screenColorService.stopMonitoring()
        activeEffectTimer?.invalidate()
        activeEffectTimer = nil
        lastSentColorRGB = nil
        lastSentBrightness = nil
    }
    
    // MARK: - Public Control Methods
    
    func setPower(isOn: Bool) {
        // This is a user action, so switch to manual mode.
        if activeLightMode != .manual {
            activeLightMode = .manual
        }
        setPower(isOn: isOn, internalOnly: false)
    }
    
    
    
    // ** NEW FUNCTION for live, throttled updates **
    func setLiveBrightness(level: UInt8) {
        // Immediately update the UI for a responsive feel
        self.currentBrightness = level
        
        // Throttle the BLE command
        guard Date().timeIntervalSince(lastBrightnessUpdateTime) > brightnessUpdateThrottle else {
            return
        }
        
        // If enough time has passed, send the command
        lastBrightnessUpdateTime = Date()
        sendBrightnessCommand(level: level)
    }
    
    // ** RENAMED/UPDATED FUNCTION for final, guaranteed updates **
    func setFinalBrightness(level: UInt8) {
        // Ensure the mode is manual
        if activeLightMode != .manual {
            activeLightMode = .manual
        }
        // Always send the final command, ignoring the throttle
        sendBrightnessCommand(level: level)
    }
    
    func setColor(r: UInt8, g: UInt8, b: UInt8) {
        if activeLightMode != .manual {
            activeLightMode = .manual
        }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x05, payload: [0x02, r, g, b])
        DispatchQueue.main.async { self.currentColorRGB = (r, g, b) }
    }
    
    // MARK: - Screen Mirroring
    
    private func startScreenMirroringInternal() {
        guard isDeviceControlReady else { return }
        
        guard let displayID = selectedDisplayID, let display = availableDisplays.first(where: { $0.displayID == displayID }) else {
            print("[ScreenColorService] No selected or available display to mirror.")
            DispatchQueue.main.async {
                self.connectionStatus = "Error: Select a display to mirror."
                self.activeLightMode = .manual // Revert on failure
            }
            return
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = "Screen Mirroring: Active"
            self.screenColorService.startMonitoring(for: display)
        }
    }
    
    private func sendScreenColorToDevice(newScreenColorRGB: (r: UInt8, g: UInt8, b: UInt8)) {
        guard activeLightMode == .screenMirroring else { return }
        
        // Determine if color has changed enough to warrant sending an update
        let colorChanged = lastSentColorRGB == nil || hasColorChangedSignificantly(from: lastSentColorRGB!, to: newScreenColorRGB, threshold: 10)
        
        if colorChanged {
            sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x05, payload: [0x02, newScreenColorRGB.r, newScreenColorRGB.g, newScreenColorRGB.b])
            self.lastSentColorRGB = newScreenColorRGB
            DispatchQueue.main.async {
                self.currentColorRGB = newScreenColorRGB
            }
        }
    }
    
    // MARK: - Rainbow Effect
    
    private func startRainbowEffectInternal() {
        guard isDeviceControlReady else { return }
        self.currentHue = 0.0
        DispatchQueue.main.async {
            self.connectionStatus = "Effect Active: Rainbow"
            self.activeEffectTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.updateRainbowEffect), userInfo: nil, repeats: true)
        }
    }
    
    @objc private func updateRainbowEffect() {
        currentHue += 0.01 // Adjust for speed
        if currentHue > 1.0 { currentHue -= 1.0 }
        
        let color = Color(hue: currentHue, saturation: 1.0, brightness: 1.0)
        let rgb = color.toRGBBytes()
        
        // No need for change detection here, we always want a smooth transition
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x05, payload: [0x02, rgb.r, rgb.g, rgb.b])
        lastSentColorRGB = (rgb.r, rgb.g, rgb.b)
        
        DispatchQueue.main.async {
            self.currentColorRGB = (rgb.r, rgb.g, rgb.b)
        }
    }
    
    // MARK: - Display Management
    
    @MainActor
    func updateAvailableDisplays() {
        Task {
            do {
                let content = try await SCShareableContent.current
                self.availableDisplays = content.displays.filter { $0.width > 0 && $0.height > 0 }
                if selectedDisplayID == nil {
                    self.selectedDisplayID = CGMainDisplayID()
                }
                print("[DisplayManager] Found \(self.availableDisplays.count) displays.")
            } catch {
                print("[DisplayManager] Could not get shareable content: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendBrightnessCommand(level: UInt8) {
        guard isDeviceControlReady else { return }
        
        // Switch to manual mode if not already
        if activeLightMode != .manual {
            DispatchQueue.main.async { self.activeLightMode = .manual }
        }
        
        let clampedLevel = min(max(level, 0), 100)
        let devicePayloadLevel = UInt8(round((Double(clampedLevel) / 100.0) * 254.0))
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x04, payload: [devicePayloadLevel])
        
        // Update the published property for the UI text, if it's not already set
        if self.currentBrightness != clampedLevel {
            DispatchQueue.main.async { self.currentBrightness = clampedLevel }
        }
    }
    
    
    // MARK: - BLE Core Logic
    
    func startScanning() {
        guard cbManager.state == .poweredOn else {
            isScanning = false
            return
        }
        connectionStatus = "Scanning for Govee devices..."
        discoveredPeripherals.removeAll()
        cbManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if self.isScanning { self.stopScanning() }
        }
    }
    
    func stopScanning() {
        if isScanning {
            cbManager.stopScan()
            isScanning = false
            if discoveredPeripherals.isEmpty {
                connectionStatus = "No devices found. Try scanning again."
            }
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionStatus = "Connecting to \(peripheral.name ?? "device")..."
        cbManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        if appSettings.powerOffDisconnect {
            self.setPower(isOn: false, internalOnly: true)
        }
        
        let delay = appSettings.powerOffDisconnect ? 0.15 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 3. Stop all timers and services.
            self.stopAllModes()
            self.stopKeepAliveTimer()
            self.isDeviceControlReady = false
            self.connectionStatus = "Disconnecting from \(peripheral.name ?? "device")..."
            
            // 4. Finally, cancel the peripheral connection.
            self.cbManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    // MARK: - Internal Helpers
    
    /// A version of setPower for internal mode changes that doesn't alter the light mode.
    private func setPower(isOn: Bool, internalOnly: Bool) {
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [isOn ? 0x01 : 0x00])
        DispatchQueue.main.async { self.isDeviceOn = isOn }
    }
    
    private func sendGoveePacket(head: UInt8, cmd: UInt8, payload: [UInt8]) {
        guard let peripheral = connectedPeripheral, let char = controlCharacteristic, payload.count <= 17 else { return }
        
        var frame: [UInt8] = [head, cmd]
        frame.append(contentsOf: payload)
        let padding = [UInt8](repeating: 0, count: 19 - frame.count)
        frame.append(contentsOf: padding)
        
        let checksum = frame.reduce(0, ^)
        let data = Data(frame + [checksum])
        
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }
    
    @objc private func sendKeepAliveCommand() {
        sendGoveePacket(head: GOVEE_KEEP_ALIVE_HEAD, cmd: 0x01, payload: [0x01])
    }
    
    private func startKeepAliveTimer() {
        stopKeepAliveTimer()
        DispatchQueue.main.async {
            self.keepAliveTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.sendKeepAliveCommand), userInfo: nil, repeats: true)
        }
    }
    
    private func stopKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }
    
    private func hasColorChangedSignificantly(from o: (r:UInt8,g:UInt8,b:UInt8), to n: (r:UInt8,g:UInt8,b:UInt8), threshold: Int) -> Bool {
        abs(Int(o.r)-Int(n.r)) + abs(Int(o.g)-Int(n.g)) + abs(Int(o.b)-Int(n.b)) > threshold
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.connectionStatus = "Bluetooth is On. Ready to scan."
                if self.connectedPeripheral == nil {
                    self.startScanning()
                }
            case .poweredOff:
                self.connectionStatus = "Bluetooth is Off. Please turn it on."
                self.cleanupOnBluetoothError()
            case .unauthorized:
                self.connectionStatus = "Bluetooth access unauthorized. Go to System Settings > Privacy & Security > Bluetooth."
                self.cleanupOnBluetoothError()
            default:
                self.connectionStatus = "Bluetooth is \(central.state.description)."
                self.cleanupOnBluetoothError()
            }
        }
    }
    
    private func cleanupOnBluetoothError() {
        disconnect()
        self.isScanning = false
        self.discoveredPeripherals.removeAll()
        self.isDeviceControlReady = false
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connected. Discovering services..."
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to connect: \(error?.localizedDescription ?? "Unknown")"
            self.connectedPeripheral = nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Disconnected. Scan to find devices."
            self.connectedPeripheral = nil
            self.controlCharacteristic = nil
            self.isDeviceControlReady = false
            self.stopKeepAliveTimer()
            self.stopAllModes()
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        DispatchQueue.main.async {
            guard let services = peripheral.services else { return }
            self.connectionStatus = "Services found. Discovering characteristics..."
            for service in services {
                peripheral.discoverCharacteristics([GOVEE_CONTROL_CHARACTERISTIC_UUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        DispatchQueue.main.async {
            guard let characteristics = service.characteristics else { return }
            if let controlChar = characteristics.first(where: { $0.uuid == GOVEE_CONTROL_CHARACTERISTIC_UUID }) {
                self.controlCharacteristic = controlChar
                self.isDeviceControlReady = true
                self.connectionStatus = "Govee control ready!"
                self.startKeepAliveTimer()
                
                if self.appSettings.powerOnConnect {
                    self.setPower(isOn: true, internalOnly: true)
                }
            }
        }
    }
}
