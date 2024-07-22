//
//  Store.swift
//  BeatVid
//
//  Created by Preet Minhas on 06/07/22.
//

import Foundation
import StoreKit

class Store {
    var updateListenerTask: Task<Void, Error>? = nil
    
    static let shared = Store()
    
    private var purchasedIAPIdentifiers = [String]()
    
    private init() {
        //Start a transaction listener as close to app launch as possible so you don't miss any transactions.
        updateListenerTask = listenForTransactions()

        Task {
            //During store initialization, request products from the App Store.
            let _ = await requestProducts()
            //get the current purchases' status as well
            await updateCustomerProductStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }
    
    
    //start this method as soon as the app starts so that any pending purchases can be accounted for
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            //Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    //Deliver products to the user.
                    self.updatePurchasedIdentifiers(transaction)

                    //Always finish a transaction.
                    await transaction.finish()
                } catch {
                    //StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    func appStoreSync() async throws {
        try await AppStore.sync()
    }
    
    //Basically, App Store automatically syncs the transaction status with user's logged-in systems.
    //This method will update the current state of the IAP based on the latest receipts from the App Store
    @MainActor
    func updateCustomerProductStatus() async {
        
        //Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                //Check whether the transaction is verified. If it isn’t, catch `failedVerification` error.
                let transaction = try checkVerified(result)
                purchasedIAPIdentifiers.append(transaction.productID)
            } catch {
                print(error)
            }
        }
    }
    
    @MainActor
    func requestProducts() async -> [Product]? {
        do {
            let storeProducts = try await Product.products(for: [IAPIdentifier.watermarkIap])
           return storeProducts
        } catch {
            //TODO: alert??
            print("Failed product request: \(error)")
            return nil
        }
    }
    
    func purchaseProduct(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            updatePurchasedIdentifiers(transaction)
            
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            print("Unknown scenario!")
            return nil
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
            //Check whether the JWS passes StoreKit verification.
            switch result {
            case .unverified:
                //StoreKit parses the JWS, but it fails verification.
                throw StoreError.failedVerification
            case .verified(let safe):
                //The result is verified. Return the unwrapped value.
                return safe
            }
        }
    
    func isPurchased(_ productIdentifier: String) -> Bool {
        return purchasedIAPIdentifiers.contains(productIdentifier)
    }
    
    
    func updatePurchasedIdentifiers(_ transaction: Transaction) {
        purchasedIAPIdentifiers.append(transaction.productID)
    }
    
    func isWatermarkIAPUnlocked() -> Bool {
        //removing check for purpose of open-sourcing the app
        return true
//        return isPurchased(IAPIdentifier.watermarkIap)
    }
}
