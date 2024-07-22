//
//  AppDelegate.swift
//  videohelper
//
//  Created by Preet Minhas on 29/06/22.
//

import Cocoa
import StoreKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        //just initialize the store by creating the shared object
        let _ = Store.shared
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    
    //Menu actions
    @IBAction func restoreIAP(_ sender: Any) {
        Task {
            try? await Store.shared.appStoreSync()
        }
    }
    
    @IBAction func openWebsite(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/pkMinhas")!)
    }
    @IBAction func sendMailAction(_ sender: Any) {
        let versionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        var subject = "BeatVid v\(versionNumber)(\(buildNumber)) Feedback"
        subject = subject.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        NSWorkspace.shared.open(URL(string: "mailto:preet@marchingbytes.com?subject=\(subject)")!)
    }
    
    @IBAction func writeAReviewAction(_ sender: Any) {
        SKStoreReviewController.requestReview()
    }
    
    @IBAction func openPrivacyPolicy(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/pkMinhas")!)
    }
    @IBAction func openTnC(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/pkMinhas")!)
    }
    
    @IBAction func loadHelpUrl(_ sender:Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/pkMinhas")!)
    }
}

