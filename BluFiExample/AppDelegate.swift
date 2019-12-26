//
//  AppDelegate.swift
//  BluFiExample
//
//  Created by Marc Delling on 24.12.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

import UIKit
import BluFi
import SystemConfiguration.CaptiveNetwork

public func getWifiSsid() -> String? {
    guard let interfaces = CNCopySupportedInterfaces() as? [String] else { return nil }
    let key = kCNNetworkInfoKeySSID as String
    for interface in interfaces {
        guard let interfaceInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? else { continue }
        return interfaceInfo[key] as? String
    }
    return nil
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("\(getWifiSsid() ?? "n/a")")
        
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}
