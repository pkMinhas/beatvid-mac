//
//  Constants.swift
//  BeatVid
//
//  Created by Preet Minhas on 06/07/22.
//

import Foundation

//Our Enums have associated value so we cant have raw values! Hence, the added work of value prop and fromValue methods
enum BgType {
    case black, white, image(String), customColor
    
    var value : Int {
        switch self {
        case .black:
            return 0
        case .white:
            return 1
        case .image( _):
            return 2
        case .customColor:
            return 3
        }
    }
    
    static func fromValue(_ value: Int) -> BgType {
        switch value {
        case 0:
            return BgType.black
        case 1:
            return BgType.white
        case 2:
            return BgType.image("")
        case 3:
            return BgType.customColor
        default:
            return BgType.black
        }
    }
}

enum FgType {
    case none, image(String), logo
    
    var value : Int {
        switch self {
        case .none:
            return 0
        case .image(_):
            return 1
        case .logo:
            return 2
        }
    }
    
    static func fromValue(_ value: Int) -> FgType {
        switch value {
        case 0:
            return FgType.none
        case 1:
            return FgType.image("")
        case 2:
            return FgType.logo
        default:
            return FgType.none
        }
    }
}

struct Key {
    static let effectDuration = "effectDuration"
    static let effectType = "effectType"
    static let bgType = "bgType"
    static let fgType = "fgType"
    static let showWatermark = "showWatermark"
}
