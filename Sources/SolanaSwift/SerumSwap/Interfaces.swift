//
//  Interfaces.swift
//  SolanaSwift
//
//  Created by Chung Tran on 09/08/2021.
//

import Foundation
import RxSwift
import BufferLayoutSwift

public protocol SerumSwapAPIClient {
    func getAccountInfo<T: DecodableBufferLayout>(
        account: String,
        decodedTo: T.Type
    ) -> Single<SerumSwap.BufferInfo<T>>
    func getMintData(
        mintAddress: String,
        programId: String
    ) -> Single<SerumSwap.Mint>
    func getMinimumBalanceForRentExemption(
        span: UInt64
    ) -> Single<UInt64>
    func getProgramAccounts<T: DecodableBufferLayout>(
        publicKey: String,
        configs: SerumSwap.RequestConfiguration?,
        decodedTo: T.Type
    ) -> Single<SerumSwap.ProgramAccounts<T>>
    // Returns the `usdxMint` quoted market address *if* no open orders account already exists.
    func getMarketAddressIfNeeded(
        usdxMint: SerumSwap.PublicKey,
        baseMint: SerumSwap.PublicKey
    ) -> Single<SerumSwap.PublicKey>
    func getMarketAddress(
        usdxMint: SerumSwap.PublicKey,
        baseMint: SerumSwap.PublicKey
    ) -> Single<SerumSwap.PublicKey>
    func getMarketAddresses(
        usdxMint: SerumSwap.PublicKey,
        baseMint: SerumSwap.PublicKey
    ) -> Single<[SerumSwap.PublicKey]>
    func usdcPathExists(
        fromMint: SerumSwap.PublicKey,
        toMint: SerumSwap.PublicKey
    ) -> Single<Bool>
    func prepareValidAccountAndInstructions(
        myAccount: SerumSwap.PublicKey,
        address: SerumSwap.PublicKey?,
        mint: SerumSwap.PublicKey,
        initAmount: SerumSwap.Lamports,
        feePayer: SerumSwap.PublicKey,
        closeAfterward: Bool
    ) -> Single<SerumSwap.AccountInstructions>
    func serializeAndSend(
        instructions: [SerumSwap.TransactionInstruction],
        recentBlockhash: String?,
        signers: [SerumSwap.Account],
        isSimulation: Bool
    ) -> Single<String>
    func serializeTransaction(
        instructions: [SerumSwap.TransactionInstruction],
        recentBlockhash: String?,
        signers: [SerumSwap.Account],
        feePayer: SerumSwap.PublicKey?
    ) -> Single<String>
}

extension SerumSwapAPIClient {
    func getDecimals(mintAddress: SerumSwap.PublicKey) -> Single<SerumSwap.Decimals> {
        getMintData(
            mintAddress: mintAddress.base58EncodedString,
            programId: SerumSwap.PublicKey.tokenProgramId.base58EncodedString
        )
            .map {$0.decimals}
    }
}

public protocol SerumSwapAccountProvider {
    func getAccount() -> SerumSwap.Account?
    func getNativeWalletAddress() -> SerumSwap.PublicKey?
}

public protocol SerumSwapTokenListContainer {
    func getTokensList() -> Single<[SerumSwap.Token]>
}

public protocol SerumSwapSignatureNotificationHandler {
    func observeSignatureNotification(signature: String) -> Completable
}

public protocol SerumSwapProcessingOrderStorage {
    func getProcessingOrdersForMarket(_ market: SerumSwap.PublicKey) -> [SerumSwap.PublicKey]
    func saveProcessingOrder(_ order: SerumSwap.PublicKey, forMarket market: SerumSwap.PublicKey)
}

public struct SerumSwapProcessingOrderStorageUserDefault: SerumSwapProcessingOrderStorage {
    private let key = "SerumSwapProcessingOrder"
    
    public func getProcessingOrdersForMarket(_ market: SerumSwap.PublicKey) -> [SerumSwap.PublicKey] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let orders = try? JSONDecoder().decode([SerumSwap.ProcessingOpenOrder].self, from: data)
        else {
            return []
        }
        return orders.filter {$0.market == market}.map {$0.openOrder}
    }
    
    public func saveProcessingOrder(_ order: SerumSwap.PublicKey, forMarket market: SerumSwap.PublicKey) {
        // check if order exists
        let existedOrders = getProcessingOrdersForMarket(market)
        if existedOrders.contains(order) {return}
        
        // save
        var orders = [SerumSwap.ProcessingOpenOrder]()
        if let data = UserDefaults.standard.data(forKey: key) {
            orders = (try? JSONDecoder().decode([SerumSwap.ProcessingOpenOrder].self, from: data)) ?? []
        }
        
        orders.append(.init(market: market, openOrder: order))
        UserDefaults.standard.set(try? JSONEncoder().encode(orders), forKey: key)
    }
}
