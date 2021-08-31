//
//  SerumSwapTransitiveSwapTests.swift
//  SolanaSwift_Tests
//
//  Created by Chung Tran on 31/08/2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import XCTest

class SerumSwapTransitiveSwapTests: SerumSwapTests {
    /// Swaps ETH -> BTC on the Serum orderbook.
    func testSwapETHToBTC() throws {
        let tx = try serumSwap.swap(
            fromWallet: ethWallet,
            toWallet: btcWallet,
            amount: 0.00005,
            slippage: defaultSlippage,
            isSimulation: true
        ).toBlocking().first()
        XCTAssertNotNil(tx)
    }
}
