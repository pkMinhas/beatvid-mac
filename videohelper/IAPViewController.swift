//
//  IAPViewController.swift
//  BeatVid
//
//  Created by Preet Minhas on 06/07/22.
//

import Foundation
import Cocoa
import StoreKit

enum StoreError : Error {
    case failedVerification
}

class IAPViewController : NSViewController {
    var removeWatermarkProduct: Product?
    
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var purchaseButton: NSButton!
    @IBOutlet weak var detailLabel: NSTextField!
    @IBOutlet weak var titleLabel: NSTextField!
    
    override func viewDidLoad() {
        progressIndicator.startAnimation(nil)
        purchaseButton.isHidden = true
        titleLabel.stringValue = "Loading purchase info..."
        detailLabel.stringValue = ""
        Task {
            if let products = await Store.shared.requestProducts(), !products.isEmpty {
                self.removeWatermarkProduct = products[0]
                self.showProductInfo()
            } else {
                self.showAlert(title: "Error loading store!", message: "Please try again later")
            }
        }
    }
    
    func showProductInfo() {
        guard let removeWatermarkProduct = removeWatermarkProduct else {
            return
        }

        progressIndicator.stopAnimation(nil)
        titleLabel.stringValue = removeWatermarkProduct.displayName
        detailLabel.stringValue = removeWatermarkProduct.description
        purchaseButton.isHidden = false
        purchaseButton.title = "Upgrade for \(removeWatermarkProduct.displayPrice)"
        purchaseButton.bezelColor = NSColor.systemBlue
        //check whether it is already purchased
        if Store.shared.isPurchased(IAPIdentifier.watermarkIap) {
            purchaseButton.title = "Purchase Active"
            purchaseButton.isEnabled = false
            purchaseButton.bezelColor = NSColor.systemGreen
        }
    }
    
    
    @IBAction func purchaseAction(_ sender: Any) {
        guard let removeWatermarkProduct = removeWatermarkProduct else {
            return
        }
        purchaseButton.isEnabled = false
        progressIndicator.startAnimation(nil)
        Task {
            do {
                let _ = try await Store.shared.purchaseProduct(removeWatermarkProduct)
            } catch {
                self.showAlert(title: "Error!", message: error.localizedDescription)
            }
            purchaseButton.isEnabled = true
            progressIndicator.stopAnimation(nil)
            updateUIPostPurchase()
        }
        
    }
    
    func updateUIPostPurchase() {
        if Store.shared.isPurchased(IAPIdentifier.watermarkIap) {
            purchaseButton.title = "Purchase Active"
            purchaseButton.isEnabled = false
            purchaseButton.bezelColor = NSColor.systemGreen
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
        
    }
}
