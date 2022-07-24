//
//  WifiTableViewController.swift
//  BluFiExample
//
//  Created by Marc Delling on 23.07.22.
//  Copyright © 2022 Marc Delling. All rights reserved.
//

import UIKit
import BluFi
import CoreBluetooth

class WifiTableViewController: UITableViewController, UIPopoverPresentationControllerDelegate {

    public var networks : [BluFiWifi]?
    public var connectedNetwork : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "wificell")
        
        let scanImage = UIImage(named: "scan")?.scale(to: CGSize(width: 25, height: 25))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: scanImage, style: .plain, target: self, action: #selector(qrScanAction(sender:)))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BluFiManager.shared.disconnect()
    }
    
    // MARK: - Actions
    
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
        return networks?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "wificell", for: indexPath)
        
        if let networkName = networks?[indexPath.row].ssid {
            
            if let _ = Keychain.load(key: networkName) {
                cell.textLabel?.isEnabled = true
                cell.selectionStyle = .blue
            } else {
                cell.textLabel?.isEnabled = false
                cell.selectionStyle = .none
            }
            
            if networkName == "" {
                cell.textLabel?.text = "n/a" // FIXME: bssid
            }
            else if let connectedNetwork = connectedNetwork, connectedNetwork == networkName {
                cell.textLabel?.text = networkName + " ☑️"
            }
            else {
               cell.textLabel?.text = networkName
            }
            
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)
        
        if cell?.selectionStyle != UITableViewCell.SelectionStyle.none {
            
            SwiftSpinner.show("Configuring device...")
            
            if let deviceNamePrefix = self.title?.prefix(3), let data = Keychain.load(key: "___OTP_\(deviceNamePrefix)")?.data(using: String.Encoding.ascii) {
                print("found otp for \(deviceNamePrefix)")
                BluFiManager.shared.writeCustomData(data)
            }
            
            if let ssid = networks?[indexPath.row].ssid, let password = Keychain.load(key: ssid) {
                print("found credentials for network \(ssid)")
                BluFiManager.shared.setSta(ssid: ssid, password: password)
            }
        }

    }

}

extension WifiTableViewController: QRScannerCodeDelegate {
    func qrScanner(_ controller: UIViewController, scanDidComplete result: String) {
        // parse and store result string in Keychain
        print("WIFIQR: \(result)") // WIFI:T:WPA;S:HALLO;P:DUDU;H:;  ^WIFI:.*S:(\s+);.*$
        //Keychain.save(key: <#T##String#>, passphrase: <#T##String#>)
        
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
            let results = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
            print("\(results)")
            if let result = results.first {
                return nsString.substring(with: result.range(at: 0)) as String
            }
        } else {
            print("invalid regex: \(regex)")
        }
        return nil
    }

}
