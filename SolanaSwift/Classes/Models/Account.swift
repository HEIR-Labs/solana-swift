//
//  Account.swift
//  p2p wallet
//
//  Created by Chung Tran on 10/22/20.
//

import Foundation
import TweetNacl

public extension SolanaSDK {
    struct Account: Codable {
        public let phrase: [String]
        public let publicKey: PublicKey
        public let secretKey: Data
        
        /// Create account with seed phrase
        /// - Parameters:
        ///   - phrase: secret phrase for an account, leave it empty for new account
        ///   - network: network in which account should be created
        /// - Throws: Error if the derivation is not successful
        public init(phrase: [String] = [], network: Network) throws {
            fatalError()
//            let mnemonic: Mnemonic
//            var phrase = phrase.filter {!$0.isEmpty}
//            if !phrase.isEmpty {
//                mnemonic = try Mnemonic(phrase: phrase)
//            } else {
//                // change from 12-words to 24-words (128 to 256)
//                mnemonic = Mnemonic()
//                phrase = mnemonic.phrase
//            }
//            self.phrase = phrase
//
//            let keychain = try Keychain(seedString: phrase.joined(separator: " "), network: network.cluster)
//
//            let derivationPath: DerivationPath
//            if phrase.count == 12 {
//                // deprecated derivation path
//                derivationPath = .deprecated
//            } else {
//                // current derivation path
//                derivationPath = .bip44
//            }
//
//            guard let seed = try keychain.derivedKeychain(at: derivationPath.rawValue).privateKey else {
//                throw Error.other("Could not derivate private key")
//            }
//
//            let keys = try NaclSign.KeyPair.keyPair(fromSeed: seed)
//
//            self.publicKey = try PublicKey(data: keys.publicKey)
//            self.secretKey = keys.secretKey
        }
        
        public init(secretKey: Data) throws {
            fatalError()
//            let keys = try NaclSign.KeyPair.keyPair(fromSecretKey: secretKey)
//            self.publicKey = try PublicKey(data: keys.publicKey)
//            self.secretKey = keys.secretKey
//            let phrase = try Mnemonic.toMnemonic(secretKey.bytes)
//            self.phrase = phrase
        }
    }
}

public extension SolanaSDK.Account {
    struct Meta: Decodable, CustomDebugStringConvertible {
        public let publicKey: SolanaSDK.PublicKey
        public var isSigner: Bool
        public var isWritable: Bool
        
        // MARK: - Decodable
        enum CodingKeys: String, CodingKey {
            case pubkey, signer, writable
        }
        
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            publicKey = try SolanaSDK.PublicKey(string: try values.decode(String.self, forKey: .pubkey))
            isSigner = try values.decode(Bool.self, forKey: .signer)
            isWritable = try values.decode(Bool.self, forKey: .writable)
        }
        
        // Initializers
        public init(publicKey: SolanaSDK.PublicKey, isSigner: Bool, isWritable: Bool) {
            self.publicKey = publicKey
            self.isSigner = isSigner
            self.isWritable = isWritable
        }
        
        public var debugDescription: String {
            "{\"publicKey\": \"\(publicKey.base58EncodedString)\", \"isSigner\": \(isSigner), \"isWritable\": \(isWritable)}"
        }
    }
}
