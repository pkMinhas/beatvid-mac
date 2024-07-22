//
//  Video.swift
//  videohelper
//
//  Created by Preet Minhas on 30/06/22.
//

import Foundation
import AVFoundation
import CoreImage.CIFilterBuiltins

enum VideoCreatorError : Error {
    case runtimeError(String)
}

class VideoCreator {
    init() {
        
    }
    
    fileprivate func directoryExistsAtPath(_ path: String) -> Bool {
        var isDirectory : ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    fileprivate func getTempDirPath() -> String {
        return NSTemporaryDirectory()
    }
    
    func createVideo(pixelBufferProvider: PixelBufferProvider, audioFilePath: String, outDirPath: String, progressCallback: @escaping (Bool, Float, URL?) -> Void) throws {
        //check whether the audio file and the output dir exists
        if !directoryExistsAtPath(outDirPath) {
            throw VideoCreatorError.runtimeError("Output directory does not exist!")
        }
        
        if !FileManager.default.fileExists(atPath: audioFilePath) {
            throw VideoCreatorError.runtimeError("Audio file does not exist!")
        }
        
        try createSilentVideo(pixelBufferProvider: pixelBufferProvider,
                              audioFilePath: audioFilePath,
                              progressCallback: { progress in
            progressCallback(false, progress, nil)
        }, onComplete: { videoAsset, audioAsset in
            
            //Now we merge the audio and video
            let fileName = audioFilePath.split(separator: "/").last
            let fileNamewithoutExtension = fileName!.split(separator: ".").first
            let timeString = Date.now.timeIntervalSince1970
            let outFileName = "\(fileNamewithoutExtension!)-\(timeString).mp4"
            do {
                try self.mergeAssets(videoAsset: videoAsset,
                                audioAsset: audioAsset,
                                outDirPath: outDirPath,
                                outFileName: outFileName,
                                completion: {
                    progressCallback(true,1, NSURL.fileURL(withPathComponents: [outDirPath, outFileName]))
                    print("Merged asset ready at: \(outDirPath)/\(outFileName)")
                })
                
            } catch VideoCreatorError.runtimeError(let errMsg) {
                //TODO: how to propogate this error?
                print(errMsg)
            }
            catch {
                //TODO: how to propogate this error?
                print(error.localizedDescription)
            }
        })
    }
    
    ///Generates a 30fps video with duration = audio length
    ///Callback has isFinished, progress %age
    ///Second callback has video, audio asset
    fileprivate func createSilentVideo(pixelBufferProvider: PixelBufferProvider, audioFilePath: String, progressCallback: @escaping (Float) -> Void, onComplete: @escaping (AVAsset, AVAsset) -> Void) throws {
        
        let audioAsset = AVAsset(url: URL(fileURLWithPath: audioFilePath))
        let audioDuration = audioAsset.duration
        
        //STEP 1: Create silent movie with audio duration
        let tempFileName = UUID().uuidString + ".mp4"
        guard let silentMovieUrl = NSURL.fileURL(withPathComponents: [getTempDirPath(), tempFileName]) else {
            throw VideoCreatorError.runtimeError("Unable to create temp files!")
        }
        //create an assetwriter instance
        guard let assetwriter = try? AVAssetWriter(outputURL: silentMovieUrl, fileType: .mov) else {
            throw VideoCreatorError.runtimeError("Unable to create movie!")
        }
        //generate 1080p settings
        let preset = AVOutputSettingsAssistant(preset: .preset1920x1080)
        
        //create a single video input
        let assetWriterInput = AVAssetWriterInput(mediaType: .video,
                                                  outputSettings: preset?.videoSettings)
        //create an adaptor for the pixel buffer
        let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
        //add the input to the asset writer
        assetwriter.add(assetWriterInput)
        
        //begin the session
        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: CMTime.zero)
        //determine how many frames we need to generate
        let framesPerSecond = Constants.FPS
        //duration is the number of seconds for the final video
        let totalFrames = Int(ceil(audioDuration.seconds)) * framesPerSecond
        var frameCount = 0
        
        assetWriterInput.requestMediaDataWhenReady(on: DispatchQueue.main) {
            if frameCount < totalFrames {
                let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
                //append the contents of the pixelBuffer at the correct time
                if let pixelBuffer = pixelBufferProvider.generatePixelBuffer(forFrame: frameCount) {
                    assetWriterAdaptor.append(pixelBuffer, withPresentationTime: frameTime)
                    frameCount+=1
                    
                    //report progress
                    progressCallback(Float(frameCount)/Float(totalFrames))
                }
            } else {
                //close everything
                assetWriterInput.markAsFinished()
                assetwriter.finishWriting {
                    //outputMovieURL now has the video
                    print("Finished silent video location: \(silentMovieUrl)")
                    let videoAsset = AVAsset(url: silentMovieUrl)
                    onComplete(videoAsset, audioAsset)
                }
            }
        }
        
        
        
    }
    
    //merges the given audio and video
    fileprivate func mergeAssets(videoAsset : AVAsset, audioAsset: AVAsset, outDirPath: String, outFileName: String,
                     completion: @escaping () -> Void) throws {
        let mixComposition = AVMutableComposition()
        guard
          let videoTrack = mixComposition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
          else {
            throw VideoCreatorError.runtimeError("Unable to compose video track")
        }
            
        do {
          try videoTrack.insertTimeRange(
            CMTimeRangeMake(start: .zero, duration: videoAsset.duration),
            of: videoAsset.tracks(withMediaType: .video)[0],
            at: .zero)
        } catch {
            throw VideoCreatorError.runtimeError("Failed to load video track")
        }

        let audioTrack = mixComposition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: 0)
        do {
            try audioTrack?.insertTimeRange(
                CMTimeRangeMake(
                    start: .zero,
                    duration: audioAsset.duration),
                of: audioAsset.tracks(withMediaType: .audio)[0],
                at: .zero)
        } catch {
            throw VideoCreatorError.runtimeError("Failed to load Audio track")
        }
        
        //export
        guard let exporter = AVAssetExportSession(
          asset: mixComposition,
          presetName: AVAssetExportPreset1920x1080)
          else { return }
        
        //create url with given file name
        let url = NSURL.fileURL(withPathComponents: [outDirPath, outFileName])!
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = true

        exporter.exportAsynchronously {
          DispatchQueue.main.async {
            completion()
          }
        }
    }
}
