//
//  PublicKeys.swift
//  SolanaSwift
//
//  Created by Chung Tran on 20/01/2021.
//

import Foundation

public extension SolanaSDK.PublicKey {
    static let splTokenProgramId: SolanaSDK.PublicKey = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    static let candyMachineId: SolanaSDK.PublicKey = "8xJcC1CFRjGgdQfm7zcWtaP3t8mUpyWEvVWziYD4ZNPK"

    static let metadataProgramId: SolanaSDK.PublicKey = "metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s"
    static let sysvarClock: SolanaSDK.PublicKey = "SysvarC1ock11111111111111111111111111111111"
    static let recentBlockhashId: SolanaSDK.PublicKey = "SysvarRecentB1ockHashes11111111111111111111"
    static let instructionSysvarId: SolanaSDK.PublicKey = "Sysvar1nstructions1111111111111111111111111"

    static let tokenProgramId: SolanaSDK.PublicKey = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    static let sysvarRent: SolanaSDK.PublicKey = "SysvarRent111111111111111111111111111111111"
    static let programId: SolanaSDK.PublicKey = "11111111111111111111111111111111"
    static let wrappedSOLMint: SolanaSDK.PublicKey = "So11111111111111111111111111111111111111112"
    static let solMint: SolanaSDK.PublicKey = "Ejmc1UB4EsES5oAaRN63SpoxMJidt3ZGBrqrZk49vjTZ" // Arbitrary mint to represent SOL (not wrapped SOL).
    static let ownerValidationProgramId: SolanaSDK.PublicKey = "4MNPdKu9wFMvEeZBMt3Eipfs5ovVWTJb31pEXDJAAxX5"
    static let swapHostFeeAddress: SolanaSDK.PublicKey = "AHLwq66Cg3CuDJTFtwjPfwjJhifiv6rFwApQNKgX57Yg"
    static let splAssociatedTokenAccountProgramId: SolanaSDK.PublicKey = "ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL"
    static let renBTCMint: SolanaSDK.PublicKey = "CDJWUqTcYTVAKXAVXoQZFes5JUFc7owSeq7eMQcDSbo5"
    static let renBTCMintDevnet: SolanaSDK.PublicKey = "FsaLodPu4VmSwXGr3gWfwANe4vKf8XSZcCh1CEeJ3jpD"
    
    static func orcaSwapId(version: Int = 2) -> SolanaSDK.PublicKey {
        switch version {
        case 2:
            return "9W959DqEETiGZocYWCQPaJ6sBmUzgfxXfqGeTEdp3aQP"
        default:
            return "DjVE6JNiYqPL2QXyCUUh8rNjHrbz9hXHNYt99MQ59qw1"
        }
    }
}
