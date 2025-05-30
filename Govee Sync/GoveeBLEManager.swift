//
//  GoveeBLEManager.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 5/29/25.
//


import SwiftUI
import CoreBluetooth
import Combine

let GOVEE_CONTROL_CHARACTERISTIC_UUID = CBUUID(string: "00010203-0405-0607-0809-0a0b0c0d2b11")
let GOVEE_COMMAND_HEAD: UInt8 = 0x33
let GOVEE_KEEP_ALIVE_HEAD: UInt8 = 0xAA

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

extension CBManagerState {
    var description: String {
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
    private var cbManager: CBCentralManager!
    
    @Published var isScanning: Bool = false
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var connectionStatus: String = "App Started. Initialize Bluetooth..."
    
    @Published var isDeviceOn: Bool = false
    @Published var currentBrightness: UInt8 = 50
    @Published var currentColorRGB: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
    @Published var isDeviceControlReady: Bool = false
    
    @Published var isScreenMirroringActive: Bool = false
    
    private var controlCharacteristic: CBCharacteristic? = nil
    private var keepAliveTimer: Timer?
    private let keepAliveInterval: TimeInterval = 5
    private let screenColorService: ScreenColorService
    private var bleUpdateTimer: Timer?
    private let bleMirrorUpdateInterval: TimeInterval =  1.0 / 10.0
    private var currentScreenAvgColor: (r: UInt8, g: UInt8, b: UInt8)? = nil
    private var lastSentScreenMirrorColorRGB: (r: UInt8, g: UInt8, b: UInt8)? = nil
    private var lastSentScreenMirrorBrightness: UInt8? = nil
    
    override init() {
        self.screenColorService = ScreenColorService()
        super.init()
        cbManager = CBCentralManager(delegate: self, queue: nil)
        self.screenColorService.onNewAverageColor = { [weak self] avgColorTuple in
            DispatchQueue.main.async {
                self?.currentScreenAvgColor = avgColorTuple
            }
        }
    }
    
    private func calculateChecksum(frame: [UInt8]) -> UInt8 {
        var checksum: UInt8 = 0
        for byteVal in frame { checksum ^= byteVal }
        return checksum
    }
    
    private func sendGoveePacket(head: UInt8, cmd: UInt8, payload: [UInt8]) {
        guard let peripheral = connectedPeripheral, let char = controlCharacteristic else { return }
        guard payload.count <= 17 else { return }
        
        var frame: [UInt8] = [head, cmd]
        frame.append(contentsOf: payload)
        let paddingLength = 19 - frame.count
        if paddingLength > 0 { frame.append(contentsOf: [UInt8](repeating: 0, count: paddingLength)) }
        
        let checksum = calculateChecksum(frame: frame)
        var packet = frame
        packet.append(checksum)
        let data = Data(packet)
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }
    
    @objc private func sendKeepAliveCommand() {
        sendGoveePacket(head: GOVEE_KEEP_ALIVE_HEAD, cmd: 0x01, payload: [])
    }
    
    private func startKeepAliveTimer() {
        stopKeepAliveTimer()
        guard connectedPeripheral != nil, controlCharacteristic != nil else { return }
        DispatchQueue.main.async {
            self.sendKeepAliveCommand()
            self.keepAliveTimer = Timer.scheduledTimer(timeInterval: self.keepAliveInterval, target: self, selector: #selector(self.sendKeepAliveCommand), userInfo: nil, repeats: true)
        }
    }
    
    private func stopKeepAliveTimer() {
        DispatchQueue.main.async {
            self.keepAliveTimer?.invalidate()
            self.keepAliveTimer = nil
        }
    }
    
    func setPower(isOn: Bool) {
        if isScreenMirroringActive { stopScreenMirroring() }
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [isOn ? 0x01 : 0x00])
        DispatchQueue.main.async { self.isDeviceOn = isOn }
    }
    
    func setBrightness(level: UInt8) {
        if isScreenMirroringActive { stopScreenMirroring() }
        guard isDeviceControlReady else { return }
        let clampedLevel = min(max(level, 0), 100)
        let devicePayloadLevel = UInt8(round((Double(clampedLevel) / 100.0) * 254.0))
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x04, payload: [devicePayloadLevel])
        DispatchQueue.main.async { self.currentBrightness = clampedLevel }
    }
    
    func setColor(r: UInt8, g: UInt8, b: UInt8) {
        guard isDeviceControlReady else { return }
        sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x05, payload: [0x02, r, g, b])
        DispatchQueue.main.async { self.currentColorRGB = (r, g, b) }
    }
    
    func userManuallySetColor(r: UInt8, g: UInt8, b: UInt8) {
        if isScreenMirroringActive { stopScreenMirroring() }
        setColor(r: r, g: g, b: b)
    }
    
    func toggleScreenMirroring() {
        if isScreenMirroringActive {
            stopScreenMirroring()
        } else {
            startScreenMirroring()
        }
    }
    
    func startScreenMirroring() {
        guard isDeviceControlReady, !isScreenMirroringActive else { return }
        DispatchQueue.main.async {
            if !self.isDeviceOn {
                self.sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [0x01])
                self.isDeviceOn = true
            }
            self.isScreenMirroringActive = true
            self.connectionStatus = "Screen Mirroring: Active"
            self.lastSentScreenMirrorColorRGB = nil
            self.lastSentScreenMirrorBrightness = nil
            self.currentScreenAvgColor = nil
            self.screenColorService.startMonitoring()
            self.bleUpdateTimer?.invalidate()
            self.bleUpdateTimer = Timer.scheduledTimer(
                timeInterval: self.bleMirrorUpdateInterval,
                target: self,
                selector: #selector(self.sendScreenColorToDevice),
                userInfo: nil,
                repeats: true
            )
        }
    }
    
    func stopScreenMirroring() {
        DispatchQueue.main.async {
            guard self.isScreenMirroringActive || self.bleUpdateTimer != nil else { return }
            self.isScreenMirroringActive = false
            self.screenColorService.stopMonitoring()
            self.bleUpdateTimer?.invalidate()
            self.bleUpdateTimer = nil
            if self.connectedPeripheral != nil && self.isDeviceControlReady {
                self.connectionStatus = "Connected: Govee control ready!"
            }
        }
    }
    
    @objc private func sendScreenColorToDevice() {
        guard isScreenMirroringActive, let newScreenColorRGB = currentScreenAvgColor else { return }
        let screenLuminance = max(newScreenColorRGB.r, newScreenColorRGB.g, newScreenColorRGB.b)
        let targetBrightnessPercent = UInt8(round((Double(screenLuminance) / 255.0) * 100.0))
        let targetPowerState = targetBrightnessPercent >= 3
        
        if targetBrightnessPercent < 3 {
            if self.isDeviceOn {
                sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [0x00])
                DispatchQueue.main.async { self.isDeviceOn = false }
                lastSentScreenMirrorBrightness = 0
                lastSentScreenMirrorColorRGB = (0,0,0)
                DispatchQueue.main.async {
                    self.currentBrightness = 0
                    self.currentColorRGB = (0,0,0)
                }
                return
            }
        } else {
            if !self.isDeviceOn {
                sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x01, payload: [0x01])
                DispatchQueue.main.async { self.isDeviceOn = true }
                lastSentScreenMirrorColorRGB = nil
                lastSentScreenMirrorBrightness = nil
            }
        }
        
        if self.isDeviceOn {
            let brightnessChanged = lastSentScreenMirrorBrightness == nil ||
            abs(Int(lastSentScreenMirrorBrightness!) - Int(targetBrightnessPercent)) > 2
            let colorChanged = lastSentScreenMirrorColorRGB == nil ||
            hasColorChangedSignificantly(from: lastSentScreenMirrorColorRGB!, to: newScreenColorRGB, threshold: 15)
            
            if brightnessChanged {
                let scaledDeviceBrightness = UInt8(round((Double(targetBrightnessPercent) / 100.0) * 254.0))
                sendGoveePacket(head: GOVEE_COMMAND_HEAD, cmd: 0x04, payload: [scaledDeviceBrightness])
                DispatchQueue.main.async { self.currentBrightness = targetBrightnessPercent }
                lastSentScreenMirrorBrightness = targetBrightnessPercent
            }
            
            if colorChanged {
                setColor(r: newScreenColorRGB.r, g: newScreenColorRGB.g, b: newScreenColorRGB.b)
                lastSentScreenMirrorColorRGB = newScreenColorRGB
            }
        }
    }
    
    private func hasColorChangedSignificantly(from o: (r:UInt8,g:UInt8,b:UInt8), to n: (r:UInt8,g:UInt8,b:UInt8), threshold: Int) -> Bool {
        abs(Int(o.r)-Int(n.r))+abs(Int(o.g)-Int(n.g))+abs(Int(o.b)-Int(n.b)) > threshold
    }
    
    func startScanning() {
        guard cbManager.state == .poweredOn else {
            isScanning = false
            return
        }
        connectionStatus = "Scanning for Govee devices..."
        discoveredPeripherals.removeAll()
        cbManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            if self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        if isScanning {
            cbManager.stopScan()
            isScanning = false
        }
    }
    
    func connect(to peripheral: CBPeripheral) {
        if let existing = connectedPeripheral, existing.identifier == peripheral.identifier, (existing.state == .connected || existing.state == .connecting) {
            return
        }
        if peripheral.state == .connecting {
            return
        }
        stopScanning()
        connectionStatus = "Connecting to \(peripheral.name ?? "device")..."
        cbManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            connectionStatus = "Not connected to any device."
            return
        }
        stopKeepAliveTimer()
        stopScreenMirroring()
        isDeviceControlReady = false
        connectionStatus = "Disconnecting from \(peripheral.name ?? "device")..."
        cbManager.cancelPeripheralConnection(peripheral)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            var newStatus = self.connectionStatus
            var shouldClearAndStopActivities = false
            
            switch central.state {
            case .poweredOn: newStatus = "Bluetooth is On. Ready to scan."
            case .poweredOff: newStatus = "Bluetooth is Off. Please turn it on."; shouldClearAndStopActivities = true
            case .unauthorized: newStatus = "Bluetooth access unauthorized. Go to System Settings > Privacy & Security > Bluetooth."; shouldClearAndStopActivities = true
            case .unsupported: newStatus = "Bluetooth is not supported on this Mac."; shouldClearAndStopActivities = true
            case .resetting: newStatus = "Bluetooth is resetting. Please wait."; if self.isScanning { self.stopScanning() }
            case .unknown: newStatus = "Bluetooth state is unknown."; shouldClearAndStopActivities = true
            @unknown default: newStatus = "An unexpected Bluetooth state: \(central.state.rawValue)."; shouldClearAndStopActivities = true
            }
            
            self.connectionStatus = newStatus
            if shouldClearAndStopActivities {
                self.isScanning = false
                self.discoveredPeripherals.removeAll()
                self.stopKeepAliveTimer()
                self.stopScreenMirroring()
                self.isDeviceControlReady = false
                if self.connectedPeripheral != nil {
                    self.connectedPeripheral = nil
                    self.controlCharacteristic = nil
                }
                self.isDeviceOn = false
                self.currentBrightness = 50
                self.currentColorRGB = (255,255,255)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        DispatchQueue.main.async {
            if let index = self.discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
                self.discoveredPeripherals[index] = peripheral
            } else {
                self.discoveredPeripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connected to \(peripheral.name ?? "device"). Discovering services..."
            self.connectedPeripheral = peripheral
            self.controlCharacteristic = nil
            self.isDeviceControlReady = false
            peripheral.delegate = self
            peripheral.discoverServices(nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionStatus = "Failed to connect to \(peripheral.name ?? "device"): \(error?.localizedDescription ?? "Unknown")"
            if self.connectedPeripheral?.identifier == peripheral.identifier {
                self.connectedPeripheral = nil
                self.controlCharacteristic = nil
                self.isDeviceControlReady = false
                self.stopKeepAliveTimer()
                self.stopScreenMirroring()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            let name = peripheral.name ?? "device"
            if let err = error {
                self.connectionStatus = "Disconnected from \(name): \(err.localizedDescription)"
            } else {
                self.connectionStatus = "Disconnected from \(name)."
            }
            
            if self.connectedPeripheral?.identifier == peripheral.identifier {
                self.connectedPeripheral = nil
                self.controlCharacteristic = nil
                self.isDeviceControlReady = false
                self.stopKeepAliveTimer()
                self.stopScreenMirroring()
                self.isDeviceOn = false
                self.currentBrightness = 50
                self.currentColorRGB = (255, 255, 255)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        DispatchQueue.main.async {
            if let err = error {
                self.connectionStatus = "Error discovering services on \(peripheral.name ?? ""): \(err.localizedDescription)"
                return
            }
            guard let services = peripheral.services, !services.isEmpty else {
                self.connectionStatus = "No services found on \(peripheral.name ?? "")."
                self.isDeviceControlReady = false
                return
            }
            self.connectionStatus = "Services found. Looking for Govee control characteristic..."
            for service in services {
                peripheral.discoverCharacteristics([GOVEE_CONTROL_CHARACTERISTIC_UUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        DispatchQueue.main.async {
            if let err = error {
                self.connectionStatus = "Error discovering characteristics for service \(service.uuid.uuidString): \(err.localizedDescription)"
                return
            }
            guard let chars = service.characteristics, !chars.isEmpty else {
                return
            }
            for char in chars {
                if char.uuid == GOVEE_CONTROL_CHARACTERISTIC_UUID {
                    self.controlCharacteristic = char
                    self.isDeviceControlReady = true
                    self.connectionStatus = "Connected: Govee control ready!"
                    self.startKeepAliveTimer()
                    return
                }
            }
        }
    }
}
