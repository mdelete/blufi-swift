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

class WifiTableViewController: UITableViewController {

    public var networks : [BluFiWifi]?
    public var connectedNetwork : String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "wificell")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BluFiManager.shared.disconnect()
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
                cell.textLabel?.text = "n/a" // FIXME: use bssid
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
