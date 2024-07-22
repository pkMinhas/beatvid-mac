//
//  Util.swift
//  videohelper
//
//  Created by Preet Minhas on 30/06/22.
//

import Foundation
import Cocoa

struct Constants {
    static let FPS = 30
}

extension NSImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)
        
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {return nil}
        
        let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return resultPixelBuffer
    }
    
    func ciImage() -> CIImage? {
        guard let data = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            return nil
        }
        let ci = CIImage(bitmapImageRep: bitmap)
        return ci
    }
    
    
    func asCGImage() -> CGImage? {
        var rect = NSRect(origin: CGPoint(x: 0, y: 0), size: self.size)
        return self.cgImage(forProposedRect: &rect, context: NSGraphicsContext.current, hints: nil)
    }
}

extension NSImage {
    func resized(to newSize: NSSize, preserveAspect: Bool = false) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            if !preserveAspect {
                draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            } else {
                //preserve the aspect ratio
                let originalAspectRatio = size.width / size.height
                let newW = newSize.width
                let newH = newW / originalAspectRatio
                
                draw(in: NSRect(x: 0, y: 0.5 * (newSize.height - newH), width: newW, height: newH), from: .zero, operation: .copy, fraction: 1.0)
            }
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }
    
}


extension CIImage {
    func createPixelBuffer() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let width:Int = Int(extent.size.width)
        let height:Int = Int(extent.size.height)
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)
        let context = CIContext()
        context.render(self, to: pixelBuffer!)
        
        return pixelBuffer!
    }
}



func mergeImages(bg: NSImage, fg: NSImage, fraction: CGFloat = 1) -> CGImage? {

    let size = bg.size
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        print("Unable to create bitmap")
        return nil
    }

    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    bg.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height), from: .zero, operation: .copy, fraction: 1.0)
    
    let rect = NSRect(origin: CGPoint(x: 0.5*(1920 - 1080), y: 0), size: NSSize(width: 1080, height: 1080))
    let originRect = NSRect(origin: .zero, size: fg.size)
    fg.draw(in: rect, from: originRect, operation: .sourceOver, fraction: fraction)
    NSGraphicsContext.restoreGraphicsState()

    guard let result = bitmapRep.cgImage
        else {fatalError("Failed to create image.")}

    return result;
}

func addWatermark(bgCGImage: CGImage) -> CGImage? {
    let bg = NSImage(cgImage: bgCGImage, size: CGSize(width: bgCGImage.width, height: bgCGImage.height))
    
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(bg.size.width), pixelsHigh: Int(bg.size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        print("Unable to create bitmap")
        return nil
    }
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    
    bg.draw(in: NSRect(x: 0, y: 0, width: bg.size.width, height: bg.size.height), from: .zero, operation: .copy, fraction: 1.0)
    
    //watermark will be merged in top-right
    //wtermark dimensions - 300 x 150
    let rect = NSRect(origin: CGPoint(x: 1920-350, y: 1080-150), size: NSSize(width: 300, height: 150))
    let watermark = WatermarkHelper.watermarkImage()
    let originRect = NSRect(origin: .zero, size: watermark.size)
    watermark.draw(in: rect, from: originRect, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    guard let result = bitmapRep.cgImage
        else {fatalError("Failed to create image.")}

    return result;
}


struct WatermarkHelper {
    //We keep the watermark as part of the binary to ensure that user cannot replace the watermark file
    static let base64Watermark = "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LTwVc0R4WbxaR3cNiXhOJDxOB+ldcYon61bgZBKUIyuZAqJM1qlQkQvqiLibvxrF/s44jjoH/aEHjwTJlucXDTy6cZcuok/bF0QbUgSOgcC0eVjsx77q0L9j4f2PSyZYQuco613h7ZYgJPIPObRGZs7jck8oJS/x3sKgCdNCH/tQ5X4dN8EEKQl5gYzEg8KpyfQvQ1ayOx22+WBAufKHaV8UHa4af0e1MLB10I8e6A3KW//8tC07v7Dlhor3MnutQRFQBGYLAtNKWN9Lop1tcfT9uabwK3EC0gAx8aWrJKQaKdVIjHnSFqd4LuURva5KxGkhrxaS8UBGkMntOtQUz4rH1qsSwuKUEGq80ldFxMst4qiMrOmGs9VZ9gYeHjLJjw+WBref/8zFtcdg4MErGhQBRWD2IVDjg2ns17Y3/uUVrWHTn4KS1mIPVksBWxQMiIVXCWtTQqQyrQOJ0aUi6TC1i+h8uN+85kVeOG8puArTQt5bSELiVE8ICmTlpn2yKx1lfBArpo/VqDoYJebJalzuBEndN+glW7Yu6X7yrVveqitTgEiDIjDbEZhWD4tg3GEG7n1X1etoKZYuDGJ/DaaAbdg9yrgcNz6DwMLaRM+RlSAIMpJATwyPnKkMeiGf+V7k7YngXBKc2wRKkpLIaR/yUQSnKnkeTz/djmdPbSn75sGDzf2dr3n8st0wmXjPWdOaKAKKwKxHACN6ZsKtl9/a9Lr5R5aWhsLWoOy1gXTOMEmyptmErUnkt8XV+DR4YAvDJAwCu/DOPVqcRIb4N2/uUrw+4BQQFW7V4S50WURHar2quIql/djfFZu4sxwnD/QlQ1t2ll7Y8fpHr9GVqZn5yLVVReCEEZgxwhrZ829ddUtp4VBhCe4WXGkGvTaswa8C+axp8kBoIDA82nelic0pIDA8syHw5hVP8cJmTAu9ptq2BLs+hUX0I1if2lGNKlsrSXL/C+Fg512lJ56+gYvoGhQBReCkRmDWENZIFO+6/K6wOdi+uKm/tKJQwZTRC1YVk2B1k1dow2ve20p+U+u8wtIlJW9eE54CkVSieE+c+NsqXvnhwar38HPe0PbX7bhi2p6VPrL/eqwIKAKTj8CsJayRp7pp06bgQz1XtszBVLEQFdqKcdi6yF+0utm0tIKoBste9EivV916T7Xnieu6rusbWV+PFQFF4ORH4KQhrEZQf+uiWxasHDhjMW7vKW/Y/lZuRuBSvQZFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUVAEVAEFAFFQBFQBBQBRUARUAQUAUXglYDA/weu2popYsiqOwAAAABJRU5ErkJggg=="
    
    static func watermarkImage() -> NSImage {
        let data = Data(base64Encoded: base64Watermark)!
        let image = NSImage(data: data)!
        return image
    }
}


struct IAPIdentifier {
    static let watermarkIap = "com.marchingbytes.beatvid.removeWatermark"
}
