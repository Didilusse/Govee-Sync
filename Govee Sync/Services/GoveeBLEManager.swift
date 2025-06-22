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

class GoveeBLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    // MARK: - Published Properties
    @Published var isScanning: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var connectionStatus: String = "App Started. Initializing Bluetooth..."
    @Published var isDeviceControlReady: Bool = false
    
    @Published var lastConnectedPeripheral: CBPeripheral?
    
    
    @Published var isDeviceOn: Bool = false
    @Published var currentBrightness: UInt8 = 100
    @Published var currentColorRGB: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    
    @Published var activeDeviceMode: DeviceMode = .manual {
        didSet {
            if oldValue != activeDeviceMode {
                DispatchQueue.main.async {
                    self.handleModeChange(from: oldValue, to: self.activeDeviceMode)
                }
            }
        }
    }
    @Published var availableDisplays: [SCDisplay] = []
    @Published var selectedDisplayID: CGDirectDisplayID?
    
    // MARK: - Private Properties
    private var cbManager: CBCentralManager!
    private var controlCharacteristic: CBCharacteristic?
    private let screenColorService: ScreenColorService
    private let audioCaptureService: AudioCaptureService
    
    private var keepAliveTimer: Timer?
    private var activeEffectTimer: Timer?
    private let appSettings: AppSettings
    
    // Caching and Throttling
    private var lastSentColorRGB: (r: UInt8, g: UInt8, b: UInt8)?
    private var lastSentBrightness: UInt8?
    private var lastBrightnessUpdateTime: Date = .distantPast
    private let brightnessUpdateThrottle: TimeInterval = 0.1
    
    // Effect state properties
    private var effectPhase: Double = 0.0
    private var effectBaseColor: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    
    
    init(settings: AppSettings) {
        self.appSettings = settings
        self.screenColorService = ScreenColorService(settings: settings)
        self.audioCaptureService = AudioCaptureService()
        super.init()
        cbManager = CBCentralManager(delegate: self, queue: nil)
        
        self.screenColorService.onNewAverageColor = { [weak self] avgColorTuple in
            guard let self = self, self.activeDeviceMode == .screenMirroring, let color = avgColorTuple else { return }
            self.sendScreenColorToDevice(newScreenColorRGB: color)
        }
        
        Task { await self.updateAvailableDisplays() }
    }
    
    // MARK: - Mode & Effect Handling
    @MainActor private func handleModeChange(from oldMode: DeviceMode, to newMode: DeviceMode) {
        print("[ModeChange] Switching from \(oldMode.description) to \(newMode.description)")
        stopAllModes() // Always stop old timers
        
        if newMode != .manual && !isDeviceOn {
            self._internal_setPower(isOn: true)
        }
        
        switch newMode {
        case .screenMirroring:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard self.activeDeviceMode == .screenMirroring else { return }
                self.startScreenMirroringInternal()
            }
        case .musicVisualizer:
            // Start the audio service when this scene is selected
            Task {
                await audioCaptureService.startMonitoring()
            }
            connectionStatus = "Scene Active: Music Sync"
        case .rainbow:
            startEffect(selector: #selector(updateRainbowEffect), interval: 0.1)
        case .pulse:
            preparePulseAndBreatheEffect()
            startEffect(selector: #selector(updatePulseEffect), interval: 0.05)
        case .breathe:
            preparePulseAndBreatheEffect()
            startEffect(selector: #selector(updateBreatheEffect), interval: 0.1)
        case .strobe:
            startEffect(selector: #selector(updateStrobeEffect), interval: 0.1)
        case .candlelight:
            startEffect(selector: #selector(updateCandlelightEffect), interval: 0.15)
        case .aurora:
            startEffect(selector: #selector(updateAuroraEffect), interval: 0.1)
        case .thunderstorm:
            startEffect(selector: #selector(updateThunderstormEffect), interval: 0.1)
        case .manual:
            if self.isDeviceOn {
                self._internal_setColor(r: currentColorRGB.r, g: currentColorRGB.g, b: currentColorRGB.b)
                self._internal_setFinalBrightness(level: currentBrightness)
            }
            break
        }
    }
    
    private func stopAllModes() {
        screenColorService.stopMonitoring()
        audioCaptureService.stopMonitoring()
        activeEffectTimer?.invalidate()
        activeEffectTimer = nil
    }
    
    private func startEffect(selector: Selector, interval: TimeInterval) {
        DispatchQueue.main.async {
            self.connectionStatus = "Scene Active: \(self.activeDeviceMode.description)"
            self.activeEffectTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: selector, userInfo: nil, repeats: true)
        }
    }
    
    private func preparePulseAndBreatheEffect() {
        self.effectBaseColor = self.currentColorRGB
        self.effectPhase = 0.0
    }
    
    // MARK: - Scene Update Logic
    private func updateMusicVisualizer(level: Float) {
        // Map volume to brightness. A lower bound prevents the light from turning off completely.
        let brightness = UInt8(max(level * 254.0, 25.0))
        
        // Map volume to color. Quiet = Blue/Purple, Loud = Red/Orange
        let hue = 0.7 - (CGFloat(level) * 0.7)
        let color = Color(hue: hue, saturation: 1.0, brightness: 1.0)
        let rgb = color.toRGBBytes()
        
        // Send the commands to the device
        sendBrightnessCommand(rawDeviceLevel: brightness)
        sendColorCommand(r: rgb.r, g: rgb.g, b: rgb.b)
        
        // Update the UI
        DispatchQueue.main.async {
            self.currentBrightness = UInt8(max(level * 100.0, 10.0))
            self.currentColorRGB = (r: rgb.r, g: rgb.g, b: rgb.b)
        }
    }
    
    @objc private func updateRainbowEffect() {
        effectPhase += 0.01; if effectPhase > 1.0 { effectPhase -= 1.0 }
        let color = Color(hue: effectPhase, saturation: 1.0, brightness: 1.0); let rgb = color.toRGBBytes()
        sendColorCommand(r: rgb.r, g: rgb.g, b: rgb.b)
    }
    
    @objc private func updatePulseEffect() {
        effectPhase += 0.1; if effectPhase > .pi * 2 { effectPhase -= .pi * 2 }
        let brightnessMultiplier = (sin(effectPhase) + 1) / 2 * 0.9 + 0.1
        let brightness = UInt8(brightnessMultiplier * 254)
        sendBrightnessCommand(rawDeviceLevel: brightness)
        sendColorCommand(r: effectBaseColor.r, g: effectBaseColor.g, b: effectBaseColor.b)
    }
    
    @objc private func updateBreatheEffect() {
        effectPhase += 0.05; if effectPhase > .pi * 2 { effectPhase -= .pi * 2 }
        let brightnessMultiplier = (sin(effectPhase) + 1) / 2 * 0.9 + 0.1
        let brightness = UInt8(brightnessMultiplier * 254)
        sendBrightnessCommand(rawDeviceLevel: brightness)
        sendColorCommand(r: effectBaseColor.r, g: effectBaseColor.g, b: effectBaseColor.b)
    }
    
    @objc private func updateStrobeEffect() {
        self._internal_setPower(isOn: !self.isDeviceOn)
    }
    
    @objc private func updateCandlelightEffect() {
        let randomBrightness = UInt8.random(in: 30...80)
        let randomRed = UInt8.random(in: 230...255)
        let randomGreen = UInt8.random(in: 100...160)
        sendBrightnessCommand(rawDeviceLevel: UInt8(round(Double(randomBrightness)/100.0 * 254.0)))
        sendColorCommand(r: randomRed, g: randomGreen, b: 10)
    }
    
    @objc private func updateAuroraEffect() {
        effectPhase += 0.005; if effectPhase > 1.0 { effectPhase -= 1.0 }
        let hue = 0.5 + (sin(effectPhase * .pi * 2) * 0.2)
        let color = Color(hue: hue, saturation: 1.0, brightness: 1.0); let rgb = color.toRGBBytes()
        sendColorCommand(r: rgb.r, g: rgb.g, b: rgb.b)
    }
    
    @objc private func updateThunderstormEffect() {
        sendColorCommand(r: 50, g: 50, b: 180)
        sendBrightnessCommand(rawDeviceLevel: 40)
        
        if Int.random(in: 0...100) > 95 {
            sendColorCommand(r: 255, g: 255, b: 255)
            sendBrightnessCommand(rawDeviceLevel: 254)
        }
    }
    
    // MARK: - Public Control Methods
    func setPower(isOn: Bool) {
        if !isOn {
            stopAllModes()
        }
        self._internal_setPower(isOn: isOn)
        if activeDeviceMode != .manual {
            activeDeviceMode = .manual
        }
    }
    
    func setLiveBrightness(level: UInt8) {
        self.currentBrightness = level
        guard Date().timeIntervalSince(lastBrightnessUpdateTime) > brightnessUpdateThrottle else { return }
        lastBrightnessUpdateTime = Date()
        setFinalBrightness(level: level)
    }
    
    func setFinalBrightness(level: UInt8) {
        if activeDeviceMode != .manual {
            activeDeviceMode = .manual
        }
        self._internal_setFinalBrightness(level: level)
    }
    
    func setColor(r: UInt8, g: UInt8, b: UInt8) {
        if activeDeviceMode != .manual {
            activeDeviceMode = .manual
        }
        self._internal_setColor(r: r, g: g, b: b)
    }
    
    // MARK: - Internal Commands & Helpers
    private func _internal_setPower(isOn: Bool) {
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [isOn ? 0x01 : 0x00])
        self.isDeviceOn = isOn
    }
    
    private func _internal_setFinalBrightness(level: UInt8) {
        let clampedLevel = min(max(level, 0), 100)
        let devicePayloadLevel = UInt8(round((Double(clampedLevel) / 100.0) * 254.0))
        sendBrightnessCommand(rawDeviceLevel: devicePayloadLevel)
        if self.currentBrightness != clampedLevel {
            DispatchQueue.main.async { self.currentBrightness = clampedLevel }
        }
    }
    
    private func _internal_setColor(r: UInt8, g: UInt8, b: UInt8) {
        sendColorCommand(r: r, g: g, b: b)
        DispatchQueue.main.async { self.currentColorRGB = (r, g, b) }
    }
    
    private func sendBrightnessCommand(rawDeviceLevel: UInt8) {
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x04, payload: [rawDeviceLevel])
    }
    
    private func sendColorCommand(r: UInt8, g: UInt8, b: UInt8) {
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x05, payload: [0x02, r, g, b])
    }
    
    private func startScreenMirroringInternal() {
        guard isDeviceControlReady, let displayID = selectedDisplayID, let display = availableDisplays.first(where: { $0.displayID == displayID }) else {
            DispatchQueue.main.async { self.connectionStatus = "Error: Select a display to mirror."; self.activeDeviceMode = .manual }
            return
        }
        DispatchQueue.main.async { self.connectionStatus = "Screen Mirroring: Active"; self.screenColorService.startMonitoring(for: display) }
    }
    
    private func sendScreenColorToDevice(newScreenColorRGB: (r: UInt8, g: UInt8, b: UInt8)) {
        guard activeDeviceMode == .screenMirroring, lastSentColorRGB == nil || hasColorChangedSignificantly(from: lastSentColorRGB!, to: newScreenColorRGB, threshold: 10) else { return }
        sendColorCommand(r: newScreenColorRGB.r, g: newScreenColorRGB.g, b: newScreenColorRGB.b)
        self.lastSentColorRGB = newScreenColorRGB
        DispatchQueue.main.async { self.currentColorRGB = newScreenColorRGB }
    }
    
    @MainActor func updateAvailableDisplays() {
        Task {
            do {
                let content = try await SCShareableContent.current
                self.availableDisplays = content.displays.filter { $0.width > 0 && $0.height > 0 }
                if self.selectedDisplayID == nil { self.selectedDisplayID = CGMainDisplayID() }
            } catch { print("[DisplayManager] Could not get shareable content: \(error.localizedDescription)") }
        }
    }
    
    func startScanning() {
        guard cbManager.state == .poweredOn else { isScanning = false; return }
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
            self._internal_setPower(isOn: false)
        }
        let delay = appSettings.powerOffDisconnect ? 0.15 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.stopAllModes()
            self.stopKeepAliveTimer()
            self.isDeviceControlReady = false
            self.connectionStatus = "Disconnecting from \(peripheral.name ?? "device")..."
            self.cbManager.cancelPeripheralConnection(peripheral)
        }
    }
    
    private func sendGoveePacket(head: UInt8, cmd: UInt8, payload: [UInt8]) {
        guard let peripheral = connectedPeripheral, let char = controlCharacteristic, payload.count <= 17 else { return }
        var frame: [UInt8] = [head, cmd]; frame.append(contentsOf: payload)
        let padding = [UInt8](repeating: 0, count: 19 - frame.count); frame.append(contentsOf: padding)
        let checksum = frame.reduce(0, ^)
        let data = Data(frame + [checksum])
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }
    
    @objc private func sendKeepAliveCommand() { sendGoveePacket(head: GOVEE_KEEP_ALIVE_HEAD, cmd: 0x01, payload: [0x01]) }
    
    private func startKeepAliveTimer() {
        stopKeepAliveTimer()
        DispatchQueue.main.async {
            self.keepAliveTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.sendKeepAliveCommand), userInfo: nil, repeats: true)
        }
    }
    
    private func stopKeepAliveTimer() { keepAliveTimer?.invalidate(); keepAliveTimer = nil }
    
    private func hasColorChangedSignificantly(from o: (r:UInt8,g:UInt8,b:UInt8), to n: (r:UInt8,g:UInt8,b:UInt8), threshold: Int) -> Bool { abs(Int(o.r)-Int(n.r)) + abs(Int(o.g)-Int(n.g)) + abs(Int(o.b)-Int(n.b)) > threshold }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            switch central.state {
            case .poweredOn:
                self.connectionStatus = "Bluetooth is On. Ready to scan."
                
                if let lastIDString = self.appSettings.lastConnectedDeviceID, let uuid = UUID(uuidString: lastIDString) {
                    let knownPeripherals = central.retrievePeripherals(withIdentifiers: [uuid])
                    if let lastPeripheral = knownPeripherals.first {
                        // We found it! Update our property so the UI can show it.
                        self.lastConnectedPeripheral = lastPeripheral
                    }
                }
                
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
        if connectedPeripheral != nil { disconnect() }
        self.isScanning = false
        self.discoveredPeripherals.removeAll()
        self.isDeviceControlReady = false
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
            if !self.discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals.append(peripheral)
            }
            
            
            if peripheral.identifier.uuidString == self.appSettings.lastConnectedDeviceID {
                self.lastConnectedPeripheral = peripheral
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connected. Discovering services..."
            self.connectedPeripheral = peripheral
            peripheral.delegate = self
            
            self.appSettings.lastConnectedDeviceID = peripheral.identifier.uuidString
            self.lastConnectedPeripheral = peripheral
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
                self.connectionStatus = "Govee Sync ready!"
                self.startKeepAliveTimer()
                if self.appSettings.powerOnConnect { self._internal_setPower(isOn: true) }
            }
        }
    }
}

