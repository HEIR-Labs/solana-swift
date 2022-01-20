//
//  SolanaSDK+Send.swift
//  SolanaSwift
//
//  Created by Chung Tran on 25/01/2021.
//

import Foundation
import RxSwift

extension SolanaSDK {
    public typealias SPLTokenDestinationAddress = (destination: PublicKey, isUnregisteredAsocciatedToken: Bool)
    
    /// Send SOL to another account
    /// - Parameters:
    ///   - toPublicKey: destination address
    ///   - amount: amount to send
    ///   - isSimulation: define if this is a simulation or real transaction
    ///   - customProxy: (optional) forward sending to a fee-relayer proxy
    /// - Returns: transaction id
    public func createSendNativeSOLTransaction(
        to destination: String,
        amount: UInt64,
        feePayer: PublicKey? = nil
    ) -> Single<Transaction> {
        guard let account = self.accountStorage.account else {
            return .error(Error.unauthorized)
        }
        
        let feePayer = feePayer ?? account.publicKey
        
        do {
            let fromPublicKey = account.publicKey
            
            if fromPublicKey.base58EncodedString == destination {
                throw Error.other("You can not send tokens to yourself")
            }
            
            // check
            return getAccountInfo(account: destination, decodedTo: EmptyInfo.self)
                .map {info -> Void in
                    guard info.owner == PublicKey.programId.base58EncodedString
                    else {throw Error.other("Invalid account info")}
                    return
                }
                .catch { error in
                    if error.isEqualTo(.couldNotRetrieveAccountInfo) {
                        // let request through
                        return .just(())
                    }
                    throw error
                }
                .flatMap { [weak self] in
                    guard let self = self else { throw Error.unknown }
                    // form instruction
                    let instruction = SystemProgram.transferInstruction(
                        from: fromPublicKey,
                        to: try PublicKey(string: destination),
                        lamports: amount
                    )
                    
                    // get recentBlockhash
                    return self.createTransactionAndSign(
                        instructions: [instruction],
                        signers: [account],
                        feePayer: feePayer
                    )
                }
                .catch {error in
                    var error = error
                    if error.localizedDescription == "Invalid param: WrongSize"
                    {
                        error = Error.other("Wrong wallet address")
                    }
                    throw error
                }
        } catch {
            return .error(error)
        }
    }
    
    /// Send SPLTokens to another account
    /// - Parameters:
    ///   - mintAddress: the mint address to define Token
    ///   - fromPublicKey: source wallet address
    ///   - destinationAddress: destination wallet address, can be native Solana
    ///   - amount: amount to send
    ///   - isSimulation: define if this is a simulation or real transaction
    ///   - customProxy: (optional) forward sending to a fee-relayer proxy
    /// - Returns: Transaction, Real destination token address
    public func createSendSPLTokensTransaction(
        mintAddress: String,
        decimals: Decimals,
        from fromPublicKey: String,
        to destinationAddress: String,
        amount: UInt64,
        feePayer: PublicKey? = nil,
        transferChecked: Bool = false
    ) -> Single<(transaction: Transaction, realDestination: String)> {
        guard let account = self.accountStorage.account else {
            return .error(Error.unauthorized)
        }
        
        let feePayer = feePayer ?? account.publicKey
        
        // Request
        return findSPLTokenDestinationAddress(
            mintAddress: mintAddress,
            destinationAddress: destinationAddress
        )
            .flatMap {splDestinationAddress in
                // get address
                let toPublicKey = splDestinationAddress.destination
                
                // catch error
                if fromPublicKey == toPublicKey.base58EncodedString {
                    throw Error.other("You can not send tokens to yourself")
                }
                
                let fromPublicKey = try PublicKey(string: fromPublicKey)
                
                var instructions = [TransactionInstruction]()
                
                // create associated token address
                if splDestinationAddress.isUnregisteredAsocciatedToken {
                    let mint = try PublicKey(string: mintAddress)
                    let owner = try PublicKey(string: destinationAddress)
                    
                    let createATokenInstruction = AssociatedTokenProgram.createAssociatedTokenAccountInstruction(
                        mint: mint,
                        associatedAccount: toPublicKey,
                        owner: owner,
                        payer: feePayer
                    )
                    instructions.append(createATokenInstruction)
                }
                
                // send instruction
                let sendInstruction: TransactionInstruction
                
                // use transfer checked transaction for proxy, otherwise use normal transfer transaction
                if transferChecked {
                    // transfer checked transaction
                    sendInstruction = TokenProgram.transferCheckedInstruction(
                        programId: .tokenProgramId,
                        source: fromPublicKey,
                        mint: try PublicKey(string: mintAddress),
                        destination: toPublicKey,
                        owner: account.publicKey,
                        multiSigners: [],
                        amount: amount,
                        decimals: decimals
                    )
                } else {
                    // transfer transaction
                    sendInstruction = TokenProgram.transferInstruction(
                        tokenProgramId: .tokenProgramId,
                        source: fromPublicKey,
                        destination: toPublicKey,
                        owner: account.publicKey,
                        amount: amount
                    )
                }
                
                instructions.append(sendInstruction)
                
                return self.createTransactionAndSign(
                    instructions: instructions,
                    signers: [account],
                    feePayer: feePayer
                )
                    .map {(transaction: $0, realDestination: splDestinationAddress.destination.base58EncodedString)}
            }
            .catch {error in
                var error = error
                if error.localizedDescription == "Invalid param: WrongSize"
                {
                    error = Error.other("Wrong wallet address")
                }
                throw error
            }
    }
    
    // MARK: - Helpers
    public func findSPLTokenDestinationAddress(
        mintAddress: String,
        destinationAddress: String
    ) -> Single<SPLTokenDestinationAddress> {
        getAccountInfo(
            account: destinationAddress,
            decodedTo: SolanaSDK.AccountInfo.self
        )
            .map {info -> String in
                let toTokenMint = info.data.mint.base58EncodedString
                
                // detect if destination address is already a SPLToken address
                if mintAddress == toTokenMint {
                    return destinationAddress
                }
                
                // detect if destination address is a SOL address
                if info.owner == PublicKey.programId.base58EncodedString {
                    let owner = try PublicKey(string: destinationAddress)
                    let tokenMint = try PublicKey(string: mintAddress)
                    
                    // create associated token address
                    let address = try PublicKey.associatedTokenAddress(
                        walletAddress: owner,
                        tokenMintAddress: tokenMint
                    )
                    return address.base58EncodedString
                }
                
                // token is of another type
                throw Error.invalidRequest(reason: "Wallet address is not valid")
            }
            .catch { error in
                // let request through if result of getAccountInfo is null (it may be a new SOL address)
                if error.isEqualTo(.couldNotRetrieveAccountInfo) {
                    let owner = try PublicKey(string: destinationAddress)
                    let tokenMint = try PublicKey(string: mintAddress)
                    
                    // create associated token address
                    let address = try PublicKey.associatedTokenAddress(
                        walletAddress: owner,
                        tokenMintAddress: tokenMint
                    )
                    return .just(address.base58EncodedString)
                }
                
                // throw another error
                throw error
            }
            .flatMap {toPublicKey -> Single<SPLTokenDestinationAddress> in
                let toPublicKey = try PublicKey(string: toPublicKey)
                // if destination address is an SOL account address
                if destinationAddress != toPublicKey.base58EncodedString {
                    // check if associated address is already registered
                    return self.getAccountInfo(
                        account: toPublicKey.base58EncodedString,
                        decodedTo: AccountInfo.self
                    )
                        .map {$0 as BufferInfo<AccountInfo>?}
                        .catchAndReturn(nil)
                        .flatMap {info in
                            var isUnregisteredAsocciatedToken = true
                            
                            // if associated token account has been registered
                            if info?.owner == PublicKey.tokenProgramId.base58EncodedString &&
                                info?.data != nil
                            {
                                isUnregisteredAsocciatedToken = false
                            }
                            
                            // if not, create one in next step
                            return .just((destination: toPublicKey, isUnregisteredAsocciatedToken: isUnregisteredAsocciatedToken))
                        }
                }
                return .just((destination: toPublicKey, isUnregisteredAsocciatedToken: false))
            }
    }
}
