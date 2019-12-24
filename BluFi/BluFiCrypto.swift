//
//  BluFiCrypto.swift
//  BluFi
//
//  Created by Marc Delling on 21.12.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//


import Foundation
import CommonCrypto

class DH {

    private let DH_P =
        "cf5cf5c38419a724957ff5dd323b9c45c3cdd261eb740f69aa94b8bb1a5c9640" +
        "9153bd76b24222d03274e4725a5406092e9e82e9135c643cae98132b0d95f7d6" +
        "5347c68afc1e677da90e51bbab5f5cf429c291b4ba39c6b2dc5e8c7231e46aa7" +
        "728e87664532cdf547be20c9a3fa8342be6e34371a27c06f7dc0edddd2f86373"
    private let DH_G = "2"
    private let P, G, s, p : BigUInt!
    
    init() {
        G = BigUInt(DH_G, radix: 16)
        P = BigUInt(DH_P, radix: 16)
        s = BigUInt.randomInteger(withExactWidth: 1024)
        p = G.power(s, modulus: P)
    }
    
    func exchangeKey(shared: String) -> String {
        let x = BigUInt(shared, radix: 16)
        return String(x!.power(s, modulus: P), radix: 16)
    }
    
    func exchangeKeyHash(shared: [UInt8]) -> [UInt8] {
        let x = BigUInt(Data(shared))
        let k = x.power(s, modulus: P).serialize()
        return MD.md5(for: [UInt8](k))
    }
    
    var publicKey : String {
        return String(p, radix: 16)
    }
    
    var negotiationData : [UInt8] {
        var data = [UInt8](repeating: 0x01, count: 1)

        let dP = P.serialize()
        data += len(dP)
        data += [UInt8](dP)

        let dG = G.serialize()
        data += len(dG)
        data += [UInt8](dG)

        let dp = p.serialize()
        data += len(dp)
        data += [UInt8](dp)

        return data
    }
    
    var description : String {
        var str = "\nP: " + P.serialize().hexEncodedString(options: [.upperCase])
        str += "\nG:  " + G.serialize().hexEncodedString(options: [.upperCase])
        str += "\nPUB: " + p.serialize().hexEncodedString(options: [.upperCase])
        str += "\nPRIV: " + s.serialize().hexEncodedString(options: [.upperCase]) + "\n\n"
        
        return str
    }
    
    internal func len(_ data: Data) -> [UInt8] {
        let u = UInt16(data.count)
        var s = [UInt8](repeating: 0, count: 2)
        s[0] = UInt8(u >> 8)
        s[1] = UInt8(u & 0x00ff)
        return s
    }

}

public class CRC {
    
    public static func crc16(_ data: [UInt8]) -> [UInt8] {
        let crc = update(crc: 0xFFFF, data: data, table: makeTable())
        return [UInt8](crc ^ 0xFFFF)
    }
    
    internal static func update(crc: UInt16, data: [UInt8], table: [UInt16]) -> UInt16 {
        var crcRet = crc
        let skippedLeadingBytes = Array(data[2..<data.count]) // FIXME: orignal protocol skips the two leading bytes, this is a bad place to do this
        for d in skippedLeadingBytes {
            let idx = Int(UInt8(crcRet>>8)^UInt8(d))
            crcRet = crcRet<<8 ^ table[idx]
        }
        return crcRet
    }
    
    internal static func makeTable() -> [UInt16] {
        var table = [UInt16]()
        let poly: UInt16 = 0x1021
        for n in 0..<256 {
            var crc = UInt16(n) << 8
            for _ in 0..<8 {
                let bit = (crc & 0x8000) != 0
                crc <<= 1
                if bit {
                    crc ^= poly
                }
            }
            table.append(crc)
        }
        return table
    }

}

class MD {
    public static func md5(for data: [UInt8]) -> [UInt8] {
        var digestData = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(data, CC_LONG(data.count), &digestData)
        return digestData
    }
}

class AESCFBNOPAD {

    private let key : [UInt8]!
    
    init(key: [UInt8]) {
        self.key = key
    }
    
    func encrypt(_ data: [UInt8], seq: UInt8) -> [UInt8] {
        return cc(data: data, seq: seq, kCCEncrypt)
    }
    
    func decrypt(_ data: [UInt8], seq: UInt8) -> [UInt8] {
        return cc(data: data, seq: seq, kCCDecrypt)
    }
    
    internal func cc(data: [UInt8], seq: UInt8, _ operation: Int) -> [UInt8] {
        
        var iv = [UInt8](repeating: 0, count: 16)
        iv[0] = seq
        var cryptData = [UInt8]()
        var cryptor : CCCryptorRef!
        var result = CCCryptorCreateWithMode(CCOperation(operation),
                                             CCMode(kCCModeCFB),
                                             CCAlgorithm(kCCAlgorithmAES128),
                                             CCPadding(ccNoPadding),
                                             iv,
                                             key,
                                             kCCKeySizeAES128,
                                             nil,
                                             0,
                                             0,
                                             0,
                                             &cryptor);

        if result == kCCSuccess {
            var numBytesEncrypted : size_t = 0
            let cryptLen = CCCryptorGetOutputLength(cryptor, data.count, true);
            
            cryptData = [UInt8](repeating: 0, count: cryptLen)
            
            result = CCCryptorUpdate(cryptor,
            data,
            data.count,
            &cryptData,
            cryptLen,
            &numBytesEncrypted);
            
            if result == kCCSuccess {
                cryptData.removeSubrange(numBytesEncrypted..<cryptData.count)
            } else {
                fatalError("AES Operation failed")
            }
        } else {
            fatalError("AES Allocation failed")
        }
        
        CCCryptorRelease(cryptor);

        return cryptData;
    }

}
