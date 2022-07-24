//
//  Keychain.swift
//  BluFiExample
//
//  Created by Marc Delling on 29.08.20.
//  Copyright © 2020 Marc Delling. All rights reserved.
//

import Foundation
import Security

public class Keychain {
    
    // Constant Identifiers
    static let userAccount = "AuthenticatedUser" as NSString
    static let accessGroup = "SecurityService" as NSString
    static let kSecClassValue = NSString(format: kSecClass)
    static let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
    static let kSecValueDataValue = NSString(format: kSecValueData)
    static let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
    static let kSecAttrServiceValue = NSString(format: kSecAttrService)
    static let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
    static let kSecReturnDataValue = NSString(format: kSecReturnData)
    static let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)
    
    public class func preload() {
        if let path = Bundle.main.path(forResource: "Credentials", ofType: "plist"), let creds = NSDictionary(contentsOfFile: path) as? [String:String] {
            for (k, v) in creds {
                print("\(k):\(v)")
                Keychain.save(key: k, passphrase: v)
            }
        }
    }
    
    public class func save(key: String, passphrase: String) {
        let dataFromString = passphrase.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue), allowLossyConversion: false)! as NSData
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, key as NSString, userAccount, dataFromString],
                                                                     forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecValueDataValue])
        SecItemDelete(keychainQuery as CFDictionary)
        SecItemAdd(keychainQuery as CFDictionary, nil)
    }
    
    public class func load(key: String) -> String? {

        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, key as NSString, userAccount, kCFBooleanTrue!, kSecMatchLimitOneValue], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecReturnDataValue, kSecMatchLimitValue])
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var contentsOfKeychain: NSString? = nil
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? NSData {
                contentsOfKeychain = NSString(data: retrievedData as Data, encoding: String.Encoding.utf8.rawValue)
            }
        } else {
            print("Nothing was retrieved from the keychain. Status code \(status)")
        }
        
        return contentsOfKeychain as String?
    }
}
