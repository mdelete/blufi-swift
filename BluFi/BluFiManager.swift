//
//  BluFiManager.swift
//  BluFi
//
//  Created by Marc Delling on 21.12.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//


import Foundation
import CoreBluetooth

// MARK: Extensions

extension Data {

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    func chunked(by chunkSize: Int) -> [Data] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            Data(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }

}

extension Bool {
    init(_ b: UInt8) {
        self.init(b != 0)
    }
}

extension Array where Iterator.Element == UInt8 {
    
    init(_ u: UInt16) {
        var s = [UInt8](repeating: 0, count: 2)
        s[1] = UInt8(u >> 8)
        s[0] = UInt8(u & 0x00ff)
        self = s
    }
    
    func chunked(by chunkSize: Int) -> [[UInt8]] {
        return stride(from: 0, to: self.count, by: chunkSize).map {
            [UInt8](self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
    
}

// MARK: BluFi Structs

public struct BluFiError: Error {

    public var state : UInt8
    
    enum State : Int8 {
        case ESP_BLUFI_SEQUENCE_ERROR = 0
        case ESP_BLUFI_CHECKSUM_ERROR
        case ESP_BLUFI_DECRYPT_ERROR
        case ESP_BLUFI_ENCRYPT_ERROR
        case ESP_BLUFI_INIT_SECURITY_ERROR
        case ESP_BLUFI_DH_MALLOC_ERROR
        case ESP_BLUFI_DH_PARAM_ERROR
        case ESP_BLUFI_READ_PARAM_ERROR
    }

    public init(_ state: UInt8) {
        self.state = state
    }

}

public struct BluFiWifi {

    public var ssid: String
    public var rssi: Int8

    public init(_ ssid: String, _ rssi: Int8) {
        self.ssid = ssid
        self.rssi = rssi
    }
}

public struct BluFiDeviceInfo {
    
    public var opmode: UInt8
    public var sta: UInt8
    public var softap: UInt8
    
    public init(_ payload: [UInt8]) {
        self.opmode = payload[0]
        self.sta = payload[1]
        self.softap = payload[2]
    }
}

// MARK: BluFi Delegate Protocol

public protocol BluFiManagerDelegate: NSObjectProtocol {
    func didStopScanning(_ manager: BluFiManager)
    func didConnect(_ manager: BluFiManager)
    func didDisconnect(_ manager: BluFiManager)
    func didUpdate(_ manager: BluFiManager, status: String?)
    func didReceive(_ manager: BluFiManager, error: BluFiError)
    func didReceive(_ manager: BluFiManager, wifi: [BluFiWifi])
    func didReceive(_ manager: BluFiManager, deviceInfo: BluFiDeviceInfo)
}

// MARK: BluFi Manager Singleton

public class BluFiManager: NSObject {
    
    private let BluFiServiceUUID = CBUUID(string: "0000ffff-0000-1000-8000-00805f9b34fb")
    private let BluFiDataOutCharsUUID = CBUUID(string: "0000ff01-0000-1000-8000-00805f9b34fb")
    private let BluFiDataInCharsUUID = CBUUID(string: "0000ff02-0000-1000-8000-00805f9b34fb")
    
    fileprivate var discoveredPeripheral: CBPeripheral!
    fileprivate var dataOutCharacteristic: CBCharacteristic?
    fileprivate var dataInCharacteristic: CBCharacteristic?
    
    //let RSSI_range = -40..<(-15)  // optimal -22dB -> reality -48dB
    
    public static let shared = BluFiManager()
    
    weak var stopScanTimer : Timer?
    public weak var delegate : BluFiManagerDelegate?
    
    fileprivate var _blufiSequence = UInt8(0)
    fileprivate var centralManager: CBCentralManager!
    fileprivate var shouldReconnect = false
    fileprivate var aes : AESCFBNOPAD?
    fileprivate var dh : DH?
    fileprivate var fragmentedResponse = [UInt8]()
    
    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    fileprivate func write(data: Data) {
        if let characteristic = dataOutCharacteristic {
            discoveredPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    fileprivate func applyStopScanTimer() {
        Timer.scheduledTimer(withTimeInterval: TimeInterval(9.0), repeats: false) { (_) in
            if self.centralManager.isScanning {
                self.centralManager.stopScan()
                self.delegate?.didStopScanning(self)
            }
        }
    }
    
    fileprivate func killStopScanTimer() {
        stopScanTimer?.invalidate()
        stopScanTimer = nil
    }
    
    fileprivate func scan() {
        killStopScanTimer()
        centralManager.scanForPeripherals(withServices: [BluFiServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true as Bool)])
        applyStopScanTimer()
        delegate?.didUpdate(self, status: "Scanning...")
    }
    
    fileprivate func cleanup() {
        
        shouldReconnect = false
        killStopScanTimer()
        dataOutCharacteristic = nil
        _blufiSequence = 0
        aes = nil
        dh = nil
        fragmentedResponse.removeAll()
        
        guard let discoveredPeripheral = discoveredPeripheral else {
            return
        }
        
        guard discoveredPeripheral.state != .disconnected, let services = discoveredPeripheral.services else {
            // FIXME: state connecting
            centralManager.cancelPeripheralConnection(discoveredPeripheral)
            return
        }
        
        for service in services {
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    if characteristic.uuid.isEqual(BluFiDataInCharsUUID) {
                        if characteristic.isNotifying {
                            discoveredPeripheral.setNotifyValue(false, for: characteristic)
                            //return // ??? not cancelling if setNotify false succeeds ???
                        }
                    }
                }
            }
        }
        
        centralManager.cancelPeripheralConnection(discoveredPeripheral)
    }
}

// MARK: - Central Manager delegate
extension BluFiManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: scan()
        case .poweredOff, .resetting: cleanup()
        default: return
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        //guard RSSI_range.contains(RSSI.intValue) && discoveredPeripheral != peripheral else { return }
        print("didDiscover \(peripheral) with RSSI \(RSSI.intValue)")
        
        // FIXME: present list, don't connect first found
        
        discoveredPeripheral = peripheral
        centralManager.connect(peripheral, options: [:])
        
        delegate?.didUpdate(self, status: "Discovered \(peripheral.name ?? "blufi device")")
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        cleanup()
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManager.stopScan()
        shouldReconnect = true
        peripheral.delegate = self
        peripheral.discoverServices([BluFiServiceUUID])
        delegate?.didUpdate(self, status: "Connected to " + (peripheral.name ?? "blufi device"))
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if (peripheral == discoveredPeripheral) {
            if shouldReconnect {
                centralManager.connect(peripheral, options: [:])
            } else {
                cleanup()
                delegate?.didDisconnect(self)
            }
        }
    }
    
}

// MARK: - Peripheral Delegate
extension BluFiManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            cleanup()
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([BluFiDataOutCharsUUID, BluFiDataInCharsUUID], for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        if let error = error {
            print(error.localizedDescription)
            cleanup()
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == BluFiDataOutCharsUUID {
                dataOutCharacteristic = characteristic
            } else if characteristic.uuid == BluFiDataInCharsUUID {
                dataInCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        } else if characteristic == dataInCharacteristic {
            guard let newData = characteristic.value else { return }
            //print("Data: \(newData.hexEncodedString())")
            readData(data: newData)
        }
    }
 
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error { print(error.localizedDescription) }
        guard characteristic.uuid == BluFiDataInCharsUUID else { return }
        if characteristic.isNotifying {
            print("Notification began on \(characteristic). Starting security negotiation...")
            startNegotiation()
        } else {
            print("Notification stopped on \(characteristic). Disconnecting...")
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("write: \(error.localizedDescription)")
        }
    }
}

// MARK: Blufi Protocol Functions
extension BluFiManager {
    
    fileprivate var blufiSequence : UInt8 {
        get {
            let seq = _blufiSequence
            _blufiSequence += 1
            return seq
        }
        set {
             _blufiSequence = 0
        }
    }
    
    fileprivate func startNegotiation() {
        
        if self.dh == nil {
            self.dh = DH()
        }
        
        if let negoData = self.dh?.negotiationData {
            
            let len = UInt16(negoData.count)
            
            writeNegotiateLength(len: len)
            
            let dataChunks = Data(negoData).chunked(by: 80)
            
            for (index, chunk) in dataChunks.enumerated() {
                if index == dataChunks.endIndex-1 {
                    writeNegotiateData(data: chunk) // last chunk
                } else {
                    writeNegotiateData(data: chunk, total: len) // first chunks
                }
            }
        }

    }
    
    fileprivate func readData(data: Data) {
        
        let packet = [UInt8](data)
        let type = packet[0] & 0x03
        let subtype = packet[0] >> 2
        let seq = packet[2]
        let frameControl = packet[1]
        let length = Int(packet[3])
        
        let isHash = Bool(frameControl & 0x01)
        let isChecksum = Bool(frameControl & 0x02)
        //let isDirection = Bool(frameControl & 0x04)
        let isAck = Bool(frameControl & 0x08)
        let isAppendPacket = Bool(frameControl & 0x10)
        
        var payload : [UInt8]
        
        if length > 0, packet.count > 4, packet.count > length {
            var payloadLen = packet.count
            if isChecksum {
                payloadLen -= 2
                print("Has CRC16")
            }
            payload = Array(packet[4..<payloadLen])
        } else {
            print("ERROR - packet / payload length mismatch")
            return
        }

        if isHash, let cryptor = self.aes {
            payload = cryptor.decrypt(payload, seq: seq)
        }
        
        if isAck {
            writeAck(seq)
        }
        
        if isAppendPacket {
            print("Fragmented response")
            fragmentedResponse += payload[2..<payload.count]
            return
        } else {
            fragmentedResponse += payload
        }
        
        if type == 0x01 {
            switch subtype {
            case 0x00: // Negotiate_Data_DataSubType
                if let key = self.dh?.exchangeKeyHash(shared: fragmentedResponse) {
                    self.aes = AESCFBNOPAD(key: key)
                    writeSecurity(security: true, checksum: true)
                    delegate?.didUpdate(self, status: "Negotiated AES Key")
                }
            case 0x11: // Wifi_List_DataSubType
                let arrList = fragmentedResponse
                var wifiList = [BluFiWifi]()
                var idx = 0
                while idx < arrList.count {
                    let len = Int(arrList[idx+0])
                    let rssi = Int8(bitPattern: arrList[idx+1])
                    let offsetBegin = idx + 2
                    let offsetEnd = idx + len + 1
                    if offsetEnd > arrList.count {
                        print("Invalid wifi list array len")
                        break
                    }
                    let nameArr = Array(arrList[offsetBegin..<offsetEnd])
                    if let name = String(bytes: nameArr, encoding: .utf8) {
                        wifiList.append(BluFiWifi(name, rssi))
                    }
                    idx = offsetEnd
                }
                delegate?.didReceive(self, wifi: wifiList)
            case 0x12:
                delegate?.didReceive(self, error: BluFiError(payload[0]))
            case 0x0f: // Wifi_Connection_state_Report_DataSubType
                if data.count == 0x13 {
                    if let ssid = String(data: data[13..<payload[12]], encoding: .utf8) {
                        print("SSID: \(ssid)")
                    }
                    let bssid = String(format: "%02x:%02x:%02x:%02x:%02x:%02x", payload[5], payload[6], payload[7], payload[8], payload[9], payload[10])
                    print("BSSID: \(bssid)")
                }
                delegate?.didReceive(self, deviceInfo: BluFiDeviceInfo(payload))
            default: ()
            }
        }
        
        fragmentedResponse.removeAll()
    }

    fileprivate func writeAck(_ seq: UInt8) {
        
        var packet = [UInt8](repeating: 0, count: 5)
        
        packet[0] = (0x00<<2) | 0x00
        packet[1] = 0x08
        packet[2] = blufiSequence
        packet[3] = 0x01
        packet[4] = seq
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeSecurity(security: Bool = false, checksum: Bool = false) {
        
        var packet = [UInt8](repeating: 0, count: 5)
        
        packet[0] = (0x01<<2) | 0x00
        packet[1] = 0x00 | 0x02
        packet[2] = blufiSequence
        packet[3] = 0x01
        
        if security {
            packet[4] |= 0x02
        }
        
        if checksum {
            packet[4] |= 0x01
        }
        
        packet += CRC.crc16(packet)
        
        self.write(data: Data(packet))
    }
    
    public func setSta(ssid: String, password: String) {
        writeOpmode(opmode: 0x01) // STA
        writeStaSSID(ssid: ssid)
        writeStaPassword(password: password)
        writeConnectAP()
    }

    fileprivate func writeOpmode(opmode: UInt8) {
        
        var packet = [UInt8](repeating: 0, count: 5)
        
        packet[0] = (0x02<<2) | 0x00
        packet[1] = 0x00 | 0x02
        packet[2] = blufiSequence
        packet[3] = 0x01
        packet[4] = opmode
        
        packet += CRC.crc16(packet)
        
        print("writeOpmode: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeConnectAP() {
        
        var packet = [UInt8](repeating: 0, count: 3)
        
        packet[0] = (0x03<<2) | 0x00
        packet[1] = 0x00
        packet[2] = blufiSequence
        
        print("writeConnectAP: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    public func writeDisconnectAP() {
        
        var packet = [UInt8](repeating: 0, count: 3)
        
        packet[0] = (0x04<<2) | 0x00
        packet[1] = 0x00
        packet[2] = blufiSequence
        
        print("writeDisconnectAP: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeNegotiateLength(len: UInt16) {
        
        var packet = [UInt8](repeating: 0, count: 7)
        
        packet[0] = (0x00<<2) | 0x01
        packet[1] = 0x00 | 0x02
        packet[2] = blufiSequence
        packet[3] = 0x03
        packet[4] = 0x00
        packet[5] = UInt8(len >> 8)
        packet[6] = UInt8(len & 0x00ff)
        
        packet += CRC.crc16(packet)
        
        print("writeNegotiateLength: \(Data(packet).hexEncodedString())")
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeNegotiateData(data: Data, total: UInt16 = 0) {
        
        if total > 0 {
            var packet = [UInt8](repeating: 0, count: 6)
            packet[0] = (0x00<<2) | 0x01
            packet[1] = 0x10 | 0x02
            packet[2] = blufiSequence
            packet[3] = UInt8(data.count + 2)
            packet[4] = UInt8(total & 0x00ff)
            packet[5] = UInt8(total >> 8)
            packet += [UInt8](data)
            
            packet += CRC.crc16(packet)
            
            print("writeNegotiateDataFragmented: \(Data(packet).hexEncodedString())")
            
            self.write(data: Data(packet))
        } else {
            var packet = [UInt8](repeating: 0, count: 4)
            packet[0] = (0x00<<2) | 0x01
            packet[1] = 0x00 | 0x02
            packet[2] = blufiSequence
            packet[3] = UInt8(data.count)
            packet += [UInt8](data)
            
            packet += CRC.crc16(packet)
            
            print("writeNegotiateData: \(Data(packet).hexEncodedString())")
            
            self.write(data: Data(packet))
        }
    }
    
    fileprivate func writeDisconnect() {
        var packet = [UInt8](repeating: 0, count: 4)
        packet[0] = (0x08<<2) | 0x00
        packet[1] = 0x01
        packet[2] = blufiSequence
        
        print("writeDisconnect: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeStaSSID(ssid: String) {
        
        let data = ssid.data(using: .utf8)!
        var packet = [UInt8](repeating: 0, count: 4)
        
        packet[0] = (0x02<<2) | 0x01
        
        if self.aes != nil {
            packet[1] = 0x01 | 0x02
        } else {
            packet[1] = 0x00 | 0x02
        }
        
        packet[2] = blufiSequence
        packet[3] = UInt8(data.count)
        
        let crc = CRC.crc16(packet + [UInt8](data)) // CRC of unencryped packet
        
        if let cryptor = self.aes {
            packet += cryptor.encrypt([UInt8](data), seq: packet[2])
        } else {
            packet += [UInt8](data)
        }
        
        packet += crc
        
        print("writeStaSSID: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    fileprivate func writeStaPassword(password: String) {
        
        let data = password.data(using: .utf8)!
        var packet = [UInt8](repeating: 0, count: 4)
        
        packet[0] = (0x03<<2) | 0x01
        
        if self.aes != nil {
            packet[1] = 0x01 | 0x02
        } else {
            packet[1] = 0x00 | 0x02
        }
        
        packet[2] = blufiSequence
        packet[3] = UInt8(data.count)
        
        let crc = CRC.crc16(packet + [UInt8](data)) // CRC of unencryped packet
        
        if let cryptor = self.aes {
            packet += cryptor.encrypt([UInt8](data), seq: packet[2])
        } else {
            packet += [UInt8](data)
        }
        
        packet += crc
        
        print("writeStaPassword: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    public func writeCustomData(_ data: Data) {
        
        var packet = [UInt8](repeating: 0, count: data.count)
        
        packet[0] = (0x13<<2) | 0x01
        
        if self.aes != nil {
            packet[1] = 0x01 | 0x02
        } else {
            packet[1] = 0x00 | 0x02
        }
        
        packet[2] = blufiSequence
        packet[3] = UInt8(data.count)
        
        let crc = CRC.crc16(packet + [UInt8](data)) // CRC of unencryped packet
        
        if let cryptor = self.aes {
            packet += cryptor.encrypt([UInt8](data), seq: packet[2])
        } else {
            packet += [UInt8](data)
        }
        
        packet += crc
        
        print("writeCustomData: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    public func triggerDeviceInfo() {
        var packet = [UInt8](repeating: 0, count: 3)
        packet[0] = (0x05 << 2) | 0x00
        if self.aes != nil {
            packet[1] = 0x01
        } else {
            packet[1] = 0x00
        }
        packet[2] = blufiSequence
        
        print("triggerDeviceInfo: \(packet)")
        
        self.write(data: Data(packet))
    }
    
    public func triggerWifiList() {
        var packet = [UInt8](repeating: 0, count: 3)
        packet[0] = (0x09 << 2) | 0x00
        if self.aes != nil {
            packet[1] = 0x01
        } else {
            packet[1] = 0x00
        }
        packet[2] = blufiSequence
        
        print("triggerWifiList: \(packet)")
        
        self.write(data: Data(packet))
    }

}
