//
//  ClickableImageView.swift
//  BeatVid
//
//  Created by Preet Minhas on 06/07/22.
//

import Foundation
import Cocoa

class ClickableImageView : NSImageView {
    func initLayer() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = 2
    }
    
    func highlight(_ shouldHighlight: Bool) {
        if shouldHighlight {
            self.layer?.borderColor = NSColor.systemBlue.cgColor
        } else {
            self.layer?.borderColor = NSColor.white.cgColor
        }
    }
    
    
    var clickHandler : ((Any) -> Void?)?
    override func mouseDown(with event: NSEvent) {
        if isEnabled {
            clickHandler?(self)
        }
    }
}
