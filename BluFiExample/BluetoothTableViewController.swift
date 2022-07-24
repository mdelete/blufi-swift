//
//  BluetoothTableViewController.swift
//  BluFiExample
//
//  Created by Marc Delling on 23.07.22.
//  Copyright © 2022 Marc Delling. All rights reserved.
//

import UIKit
import BluFi
import CoreBluetooth

struct AgingRssiPeripheral: Comparable, Hashable {

    let peripheral : CBPeripheral
    let rssi : NSNumber
    let old : Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(peripheral.identifier)
    }
    
    static func == (lhs: AgingRssiPeripheral, rhs: AgingRssiPeripheral) -> Bool {
        return lhs.peripheral.identifier == rhs.peripheral.identifier
    }
    
    static func < (lhs: AgingRssiPeripheral, rhs: AgingRssiPeripheral) -> Bool {
        return lhs.rssi.decimalValue < rhs.rssi.decimalValue
    }
}

class BluetoothTableViewController: UITableViewController, UIPopoverPresentationControllerDelegate {

    var peripherals = Set<AgingRssiPeripheral>()
    var peripheralArray = [AgingRssiPeripheral]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "bluficell")

        self.navigationItem.title = "BluFi Devices"
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        let scanImage = UIImage(named: "scan")?.scale(to: CGSize(width: 25, height: 25))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: scanImage, style: .plain, target: self, action: #selector(qrScanAction(sender:)))
        
        BluFiManager.shared.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.refreshControl = UIRefreshControl()
        self.refreshControl?.addTarget(self, action: #selector(refreshControlAction), for: UIControl.Event.valueChanged)
    }
    
    // MARK: - Actions
    
    @objc func refreshControlAction() {
        peripherals.removeAll()
        BluFiManager.shared.scan()
    }
    
    @objc func qrScanAction(sender: UITapGestureRecognizer) {
        let scannerViewController = QRCodeScannerController()
        scannerViewController.modalPresentationStyle = UIModalPresentationStyle.popover
        scannerViewController.delegate = self
        let popover = scannerViewController.popoverPresentationController
        //popover?.sourceView = imageView
        //popover?.sourceRect = imageView.bounds
        popover?.barButtonItem = self.navigationItem.rightBarButtonItem
        popover?.permittedArrowDirections = [.up]
        popover?.delegate = self
        present(scannerViewController, animated: true, completion: nil)
    }
    
    // MARK: - Popover Delegates
    
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.fullScreen
    }
    
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        let navigationController = UINavigationController(rootViewController: controller.presentedViewController)
        let done = UIBarButtonItem(title: NSLocalizedString("Fertig", comment: ""), style: .done, target: self, action: #selector(dismissPopover))
        navigationController.topViewController?.navigationItem.rightBarButtonItem = done
        return navigationController
    }
    
    @objc func dismissPopover() {
        print("dismiss")
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "bluficell", for: indexPath)
        cell.textLabel?.text = peripheralArray[indexPath.row].peripheral.name ?? peripheralArray[indexPath.row].peripheral.identifier.uuidString
        cell.detailTextLabel?.text = peripheralArray[indexPath.row].rssi.stringValue
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        SwiftSpinner.show("Connecting to device...")
        BluFiManager.shared.connect(peripheralArray[indexPath.row].peripheral)
    }

}

extension BluetoothTableViewController: BluFiManagerDelegate {
    func didStopScanning(_ manager: BluFiManager) {
        DispatchQueue.main.async {
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
            print("stopped scanning")
        }
    }
    
    func didConnect(_ manager: BluFiManager, _ peripheral: CBPeripheral?) {
        print("didConnect")
        BluFiManager.shared.writeDisconnectAP()
        BluFiManager.shared.triggerWifiList()
    }
    
    func didDisconnect(_ manager: BluFiManager) {
        print("didDisconnect")
        DispatchQueue.main.async {
            self.navigationController?.popToRootViewController(animated: false)
            SwiftSpinner.hide()
        }
    }
    
    func didDiscover(_ manager: BluFiManager, _ peripheral: CBPeripheral, _ rssi: NSNumber) {
        let agingPeripheral = AgingRssiPeripheral(peripheral: peripheral, rssi: rssi, old: false)
        peripherals.insert(agingPeripheral)
        peripheralArray = peripherals.sorted(by: <)
        //let index = peripheralArray.firstIndex(of: agingPeripheral)
        //if let index = index {
        //    let indexPath = IndexPath(row: index, section: 0)
        //    self.tableView.insertRows(at: [indexPath], with: UITableView.RowAnimation.right)
        //}
    }
    
    func didReceiveError(_ manager: BluFiManager, error: BluFiError) {
        print("didReceiveError: \(error)")
        DispatchQueue.main.async {
            SwiftSpinner.hide()
        }
    }
    
    func didReceiveNetworks(_ manager: BluFiManager, _ peripheral: CBPeripheral?, _ networks: [BluFiWifi]) {
        print("didReceiveNetworks")
        DispatchQueue.main.async {
            
            if type(of: self.navigationController?.visibleViewController) == WifiTableViewController.self{
                    print("Already presentingXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")
            }
            SwiftSpinner.hide()
            
            let wifiTableViewController = WifiTableViewController()
            wifiTableViewController.networks = networks
            wifiTableViewController.title = peripheral?.name
            self.navigationController?.pushViewController(wifiTableViewController, animated: true)
        }
    }
    
    func didReceiveInfo(_ manager: BluFiManager, deviceInfo: BluFiDeviceInfo) {
        print("didReceiveInfo: \(deviceInfo)")
        if deviceInfo.opmode == 1, deviceInfo.sta == 0, let ssid = deviceInfo.ssid {
            print("Connected to network \(ssid)")
        }
    }
}

extension BluetoothTableViewController: QRScannerCodeDelegate {
    
    func qrScanner(_ controller: UIViewController, scanDidComplete result: String) {
        if result.hasPrefix("WIFI:"),
           let ssid = result.firstMatchFor(regex: "S:((?:\\\\;|[^;])*)"),
           let password = result.firstMatchFor(regex: "P:((?:\\\\;|[^;])*)") {
            Keychain.save(key: ssid.unescapeWifiQrCode(), passphrase: password.unescapeWifiQrCode())
        }
    }
    
    func qrScannerDidFail(_ controller: UIViewController, error: String) {
        print("qrScannerDidFail")
    }
    
    func qrScannerDidCancel(_ controller: UIViewController) {
        print("qrScannerDidCancel")
    }
}

extension UIImage {
    func scale(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension String {

    func firstMatchFor(regex: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: regex, options: []) {
            let nsString = self as NSString
            if let result = regex.firstMatch(in: self, range: NSMakeRange(0, self.count)) {
                return nsString.substring(with: result.range(at: 1))
            }
        } else {
            print("invalid regex: \(regex)")
        }
        return nil
    }
    
    func unescapeWifiQrCode() -> String {
        var result = self.replacingOccurrences(of: #"\;"#, with: #";"#)
        result = result.replacingOccurrences(of: #"\:"#, with: #":"#)
        result = result.replacingOccurrences(of: #"\\"#, with: #"\"#)
        return result
    }

}
