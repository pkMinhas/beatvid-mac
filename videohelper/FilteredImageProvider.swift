//
//  PixelBufferProvider.swift
//  videohelper
//
//  Created by Preet Minhas on 01/07/22.
//

import Foundation
import AVFoundation
import CoreImage.CIFilterBuiltins


protocol PixelBufferProvider {
    func generatePixelBuffer(forFrame frame: Int) -> CVPixelBuffer?
}

class FilteredImageProvider : PixelBufferProvider {
    enum EffectType : Equatable {
        case none, vintage(Int), negative(Int), radialBlur(Int), pixellate(Int), exposure(Int), hueAdjust(Int), noise(Int)
        
        var value : Int {
            switch self {
            case .none:
                return 0
            case .vintage(_):
                return 1
            case .negative( _):
                return 2
            case .radialBlur(_):
                return 3
            case .pixellate(_):
                return 4
            case .exposure(_):
                return 5
            case .hueAdjust(_):
                return 6
            case .noise(_):
                return 7
            }
        }
        
        static func fromValue(_ value: Int) -> EffectType {
            switch value {
            case 0:
                return EffectType.none
            case 1:
                return EffectType.vintage(3)
            case 2:
                return EffectType.negative(3)
            case 3:
                return EffectType.radialBlur(3)
            case 4:
                return EffectType.pixellate(3)
            case 5:
                return EffectType.exposure(3)
            case 6:
                return EffectType.hueAdjust(3)
            case 7:
                return EffectType.noise(3)
            default:
                return EffectType.none
            }
        }
    }
    
    private var image : CIImage
    private var effectType : EffectType
    
    init(image: CIImage, effectType: EffectType) {
        self.image = image
        self.effectType = effectType
    }
    
    fileprivate func vintageLook(bias: CGFloat) -> CIImage? {
        let sepia = CIFilter.sepiaTone()
        sepia.inputImage = image
        sepia.intensity = 1
        
        //random generator return 512x512
        let randomFilter = CIFilter.randomGenerator()
        let randomImage = randomFilter.outputImage
        
        //recolor noise
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.rVector = CIVector(x: 0, y: 1, z: 0, w:0)
        colorMatrix.gVector = CIVector(x: 0, y: 1, z: 0, w:0)
        colorMatrix.bVector = CIVector(x: 0, y: 1, z: 0, w:0)
        colorMatrix.aVector = CIVector(x:0, y:0.00005, z:0, w:0.001 + bias * 0.1)
        colorMatrix.biasVector = CIVector(x: 0, y: 0, z: 0, w:0)
        colorMatrix.inputImage = randomImage
        
        let blend1 = CIFilter.sourceOverCompositing()
        blend1.inputImage = colorMatrix.outputImage
        blend1.backgroundImage = sepia.outputImage
        
        let scratchFilter = CIFilter.randomGenerator()
        let scratchImage = scratchFilter.outputImage
        let scratchesTransformed = scratchImage?.transformed(by: CGAffineTransform(scaleX: 1.5,
                                                                                   y: 25 + 5.0 * bias))
        
        colorMatrix.inputImage = scratchesTransformed
        colorMatrix.rVector = CIVector(x: 4, y: 0, z: 0, w: 0)
        colorMatrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.biasVector = CIVector(x: 0, y: 1, z: 1, w: 1)
        
        let darkenScratch = CIFilter.minimumComponent()
        darkenScratch.inputImage = colorMatrix.outputImage
        
        let finalBlend = CIFilter.multiplyCompositing()
        finalBlend.backgroundImage = blend1.outputImage
        finalBlend.inputImage = darkenScratch.outputImage
        
        return finalBlend.outputImage
    }
    
    fileprivate func noiseLook(bias: CGFloat) -> CIImage? {
        let randomGenerator = CIFilter.randomGenerator()
        let noiseImage = randomGenerator.outputImage
        
        let movingNoise = noiseImage?.transformed(by: CGAffineTransform.init(translationX: bias, y: bias * 0.2))
        
        let whitenVector = CIVector(x: 0, y: 1, z: 0, w: 0)
        let fineGrain = CIVector(x:0, y:0.005, z:0, w:0)
        let zeroVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        let whiteningFilter = CIFilter.colorMatrix()
        whiteningFilter.inputImage = movingNoise
        whiteningFilter.rVector = whitenVector
        whiteningFilter.gVector = whitenVector
        whiteningFilter.bVector = whitenVector
        whiteningFilter.aVector = fineGrain
        whiteningFilter.biasVector = zeroVector
        let whiteSpecks = whiteningFilter.outputImage
        
        
        let finalBlend = CIFilter.multiplyBlendMode()
        finalBlend.backgroundImage = self.image
        finalBlend.inputImage = movingNoise
        
        return finalBlend.outputImage
    }
    
    fileprivate func negativeLook(bias: CGFloat) -> CIImage? {
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.rVector = CIVector(x: bias, y: 0, z: 0, w:0)
        colorMatrix.gVector = CIVector(x: 0, y: bias, z: 0, w:0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: bias, w:0)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        colorMatrix.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        colorMatrix.inputImage = self.image
        
        return colorMatrix.outputImage
    }
    
    fileprivate func colorMixer(bias: CGFloat) -> CIImage? {
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.rVector = CIVector(x: bias * 0.3, y: 0, z: 0, w:0)
        colorMatrix.gVector = CIVector(x: 0, y: bias * 0.6, z: 0, w:0)
        colorMatrix.bVector = CIVector(x: 0, y: 0, z: bias * 0.1, w:0)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        colorMatrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        colorMatrix.inputImage = self.image
        
        return colorMatrix.outputImage
    }
    
    fileprivate func radialBlur(bias: CGFloat) -> CIImage? {
        guard let radialMask = CIFilter(name:"CIRadialGradient") else {
            return nil
        }
        let w = self.image.extent.size.width
        let h = self.image.extent.size.height
        let imageCenter = CIVector(x:0.5 * w, y: 0.5 * h)
        radialMask.setValue(imageCenter, forKey:kCIInputCenterKey)
        radialMask.setValue(bias * h, forKey:"inputRadius0")
        radialMask.setValue(bias * h, forKey:"inputRadius1")
        radialMask.setValue(CIColor(red:0, green:1, blue:0, alpha:0),
                            forKey:"inputColor0")
        radialMask.setValue(CIColor(red:0, green:1, blue:0, alpha:1),
                            forKey:"inputColor1")
        
        guard let maskedVariableBlur = CIFilter(name:"CIMaskedVariableBlur") else {
            return nil
        }
        maskedVariableBlur.setValue(self.image, forKey: kCIInputImageKey)
        maskedVariableBlur.setValue(10, forKey: kCIInputRadiusKey)
        maskedVariableBlur.setValue(radialMask.outputImage, forKey: "inputMask")
        let selectivelyFocusedCIImage = maskedVariableBlur.outputImage
        
        return selectivelyFocusedCIImage
    }
    
    fileprivate func pixelatedLook(bias: Float) -> CIImage? {
        let filter  = CIFilter.pixellate()
        filter.inputImage = self.image
        filter.center = CGPoint(x: 0.5 * self.image.extent.width, y: 0.5 * self.image.extent.height)
        filter.scale = bias
        
        //overlay on original image to preserve size & border colors
        let cropped = filter.outputImage?.cropped(to: self.image.extent)
        
        let blend = CIFilter.sourceOverCompositing()
        blend.inputImage = cropped
        blend.backgroundImage = self.image
        return blend.outputImage
    }
    
    fileprivate func expose(bias: Float) -> CIImage? {
        let filter = CIFilter.exposureAdjust()
        filter.inputImage = self.image
        filter.ev = bias
        
        return filter.outputImage
    }
    
    fileprivate func hueAdjust(angle: Float) -> CIImage? {
        let filter = CIFilter.hueAdjust()
        filter.inputImage = self.image
        filter.angle = angle
        return filter.outputImage
    }
    
    func generateCIImage(forFrame frame: Int) -> CIImage? {
        var result : CIImage?
        
        switch(effectType) {
        case .none:
            result = self.image
        case .vintage(let effectDuration):
            let bias = abs(sin(CGFloat(frame)/CGFloat(Constants.FPS * effectDuration)))
            result = vintageLook(bias:bias)
        case .negative(let effectDuration):
            let bias = -1 * abs(sin(CGFloat(frame)/CGFloat(Constants.FPS * effectDuration)))
            result = negativeLook(bias: bias - 0.75)
        case .radialBlur(let effectDuration):
            let bias = abs(sin(CGFloat(frame)/CGFloat(Constants.FPS * effectDuration)))
            result = radialBlur(bias: bias)
        case .pixellate(let effectDuration):
            let bias = abs(sin(Float(frame)/Float(Constants.FPS * effectDuration)))
            if bias < 0.15 {
                result = self.image
            } else {
                result = pixelatedLook(bias: bias * 70)
            }
            
        case .exposure(let effectDuration):
            let bias = sin(Float(frame)/Float(Constants.FPS * effectDuration)) * 2
            result = expose(bias: bias)
            
        case .hueAdjust(let effectDuration):
            let angle = sin(Float(frame)/Float(Constants.FPS * effectDuration)) * Float.pi
            result = hueAdjust(angle: angle)
        case .noise:
            result = noiseLook(bias: CGFloat(arc4random() / 100000))
        }
        let cropped = result?.cropped(to: self.image.extent)
        return cropped
    }
    
    func generatePixelBuffer(forFrame frame: Int) -> CVPixelBuffer? {
        return generateCIImage(forFrame: frame)?.createPixelBuffer()
    }
}
