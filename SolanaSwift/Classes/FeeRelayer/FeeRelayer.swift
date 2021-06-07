//
//  FeeRelayer.swift
//  SolanaSwift
//
//  Created by Chung Tran on 12/05/2021.
//

import Foundation
import RxSwift
import RxAlamofire

public protocol FeeRelayerSolanaAPIClient {
    var accountStorage: SolanaSDKAccountStorage {get}
    func getRecentBlockhash() -> Single<String>
    func getCurrentAccount() -> Single<SolanaSDK.Account>
    func findSPLTokenDestinationAddress(
        mintAddress: String,
        destinationAddress: String
    ) -> Single<SolanaSDK.SPLTokenDestinationAddress>
}
extension SolanaSDK: FeeRelayerSolanaAPIClient {
    public func getRecentBlockhash() -> Single<String> {
        getRecentBlockhash(commitment: nil)
    }
}

extension SolanaSDK {
    public struct FeeRelayer {
        // MARK: - Constants
        private let feeRelayerUrl = "https://fee-relayer.solana.p2p.org"
        private let transferSOLPath     = "/transfer_sol"
        private let transferTokenPath   = "/transfer_spl_token"
        private let solanaAPIClient: FeeRelayerSolanaAPIClient
        
        // MARK: - Initializer
        public init(solanaAPIClient: FeeRelayerSolanaAPIClient)
        {
            self.solanaAPIClient = solanaAPIClient
        }
        
        // MARK: - Methods
        /// Get fee payer for free transaction
        /// - Returns: Account's public key that is responsible for paying fee
        public func getFeePayerPubkey() -> Single<PublicKey>
        {
            RxAlamofire.request(.get, "\(feeRelayerUrl)/fee_payer/pubkey")
                .responseString()
                .map { (response, string) in
                    // Print
                    guard (200..<300).contains(response.statusCode) else {
                        let readableError = string.slice(from: "(", to: ")") ?? string
                        throw Error.invalidResponse(ResponseError(code: response.statusCode, message: readableError, data: nil))
                    }
                    return string
                }
                .map {try SolanaSDK.PublicKey(string: $0)}
                .take(1)
                .asSingle()
                .do(
                    onSuccess: {
                        Logger.log(message: $0.base58EncodedString, event: .response, apiMethod: "fee_payer/pubkey")
                    },
                    onError: {
                        Logger.log(message: $0.readableDescription, event: .error, apiMethod: "fee_payer/pubkey")
                    })
        }
        
        /// Transfer SOL without fee
        /// - Parameters:
        ///   - destination: SOL destination wallet
        ///   - amount: Amount in lamports
        /// - Returns: Transaction id
        public func transferSOL(
            to destination: String,
            amount: SolanaSDK.Lamports
        ) -> Single<TransactionID>
        {
            Single.zip(
                solanaAPIClient.getCurrentAccount(),
                getFeePayerPubkey().map {$0.base58EncodedString},
                solanaAPIClient.getRecentBlockhash()
            )
                .map { result -> (signature: String, blockhash: String, account: Account) in
                    let account = result.0
                    let feePayer = result.1
                    let recentBlockhash = result.2
                    let instruction = SystemProgram.transferInstruction(
                        from: try PublicKey(string: account.publicKey.base58EncodedString),
                        to: try PublicKey(string: destination),
                        lamports: amount
                    )
                    let signature = try self.getSignature(
                        signer: account,
                        feePayer: feePayer,
                        instructions: [instruction],
                        recentBlockhash: recentBlockhash
                    )
                    return (signature: Base58.encode(signature.bytes), blockhash: recentBlockhash, account: account)
                }
                .flatMap {result in
                    self.sendTransaction(
                        path: transferSOLPath,
                        params: TransferSolParams(
                            sender: result.account.publicKey.base58EncodedString,
                            recipient: destination,
                            amount: amount,
                            signature: result.signature,
                            blockhash: result.blockhash
                        )
                    )
                }
        }
        
        /// Send SPL Token without fee
        /// - Parameters:
        ///   - source: source token wallet
        ///   - destination: destination token wallet
        ///   - token: token info
        ///   - amount: amount in lamport
        /// - Returns: Transaction id
        public func transferSPLToken(
            mintAddress: String,
            from source: String,
            to destination: String,
            amount: Lamports,
            decimals: Decimals
        ) -> Single<TransactionID> {
            return Single.zip(
                solanaAPIClient.getCurrentAccount(),
                getFeePayerPubkey(),
                solanaAPIClient.getRecentBlockhash(),
                solanaAPIClient.findSPLTokenDestinationAddress(mintAddress: mintAddress, destinationAddress: destination)
            )
                .map { result -> (account: SolanaSDK.Account, signature: String, blockhash: String, realDestination: String) in
                    // get result of asynchronous requests
                    let account = result.0
                    let feePayer = result.1
                    let recentBlockhash = result.2
                    let splTokenDestinationAddress = result.3
                    
                    // form instructions
                    var instructions = [TransactionInstruction]()
                    
                    // form register instruction for registering associated token if it has not been registered yet
                    if splTokenDestinationAddress.isUnregisteredAsocciatedToken
                    {
                        let createATokenInstruction = AssociatedTokenProgram.createAssociatedTokenAccountInstruction(
                            mint: try PublicKey(string: mintAddress),
                            associatedAccount: splTokenDestinationAddress.destination,
                            owner: try PublicKey(string: destination),
                            payer: feePayer
                        )
                        instructions.append(createATokenInstruction)
                    }
                    
                    // form transfer instruction
                    let transferInstruction = TokenProgram.transferCheckedInstruction(
                        programId: .tokenProgramId,
                        source: try PublicKey(string: source),
                        mint: try PublicKey(string: mintAddress),
                        destination: splTokenDestinationAddress.destination,
                        owner: account.publicKey,
                        multiSigners: [],
                        amount: amount,
                        decimals: decimals
                    )
                    instructions.append(transferInstruction)
                    
                    // get signature from instructions
                    let signature = try self.getSignature(
                        signer: account,
                        feePayer: feePayer.base58EncodedString,
                        instructions: instructions,
                        recentBlockhash: recentBlockhash
                    )
                    
                    // get real destination: if associated token has been registered, then send token to this address, if not, send token to SOL account address
                    var realDestination = destination
                    if !splTokenDestinationAddress.isUnregisteredAsocciatedToken
                    {
                        realDestination = splTokenDestinationAddress.destination.base58EncodedString
                    }
                    
                    // send result to catcher
                    return (account: account, signature: Base58.encode(signature.bytes), blockhash: recentBlockhash, realDestination: realDestination)
                }
                .flatMap {result in
                    self.sendTransaction(
                        path: transferTokenPath,
                        params: TransferSPLTokenParams(
                            sender: source,
                            recipient: result.realDestination,
                            mintAddress: mintAddress,
                            authority: result.account.publicKey.base58EncodedString,
                            amount: amount,
                            decimals: decimals,
                            signature: result.signature,
                            blockhash: result.blockhash
                        )
                    )
                }
        }
        
        // MARK: - Helpers
        /// Get signature from formed instructions
        /// - Parameters:
        ///   - feePayer: the feepayer gotten from getFeePayerPubkey
        ///   - instructions: instructions to get signature from
        ///   - recentBlockhash: recentBlockhash retrieved from server
        /// - Throws: error if signature not found
        /// - Returns: signature
        private func getSignature(
            signer: SolanaSDK.Account,
            feePayer: String,
            instructions: [TransactionInstruction],
            recentBlockhash: String
        ) throws -> Data {
            let feePayer = try PublicKey(string: feePayer)
            var transaction = Transaction(feePayer: feePayer, instructions: instructions, recentBlockhash: recentBlockhash)
            try transaction.sign(signers: [signer])
            
            guard let signature = transaction.findSignature(pubkey: signer.publicKey)?.signature
            else {
                throw Error.other("Signature not found")
            }
            return signature
        }
        
        /// Send transaction to fee relayer
        /// - Parameters:
        ///   - path: additional path for request
        ///   - params: request's parameters
        /// - Returns: transaction id
        private func sendTransaction(
            path: String,
            params: SolanaFeeRelayerTransferParams
        ) -> Single<SolanaSDK.TransactionID> {
            do {
                var urlRequest = try URLRequest(
                    url: "\(feeRelayerUrl)\(path)",
                    method: .post,
                    headers: [.contentType("application/json")]
                )
                urlRequest.httpBody = try JSONEncoder().encode(EncodableWrapper(wrapped: params))
                
                return RxAlamofire.request(urlRequest)
                    .responseString()
                    .map { (response, string) in
                        // Print
                        guard (200..<300).contains(response.statusCode) else {
                            let readableError = string.slice(from: "(", to: ")") ?? string
                            throw Error.invalidResponse(ResponseError(code: response.statusCode, message: readableError, data: nil))
                        }
                        return string
                    }
                    .take(1)
                    .asSingle()
            } catch {
                return .error(error)
            }
        }
    }
}

private extension String {
    func slice(from: String, to: String) -> String? {
        guard let rangeFrom = range(of: from)?.upperBound else { return nil }
        guard let rangeTo = self[rangeFrom...].range(of: to)?.lowerBound else { return nil }
        return String(self[rangeFrom..<rangeTo])
    }
}

