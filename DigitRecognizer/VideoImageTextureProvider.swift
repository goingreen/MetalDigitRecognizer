//
//  VideoTextureProvider.swift
//  DigitRecognizer
//
//  Created by Artur on 22.04.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import UIKit
import AVFoundation

/// Provides an interface for sending/receiving a stream of Metal textures.
protocol VideoImageTextureProviderDelegate: class {
    func videoImageTextureProvider(_: VideoImageTextureProvider, didProvideTexture texture: MTLTexture)
}

class VideoImageTextureProvider: NSObject {
    var textureCache : CVMetalTextureCache?
    let captureSession = AVCaptureSession()
    var camera: AVCaptureDevice!
    let sampleBufferCallbackQueue = DispatchQueue(label: "VideoImageTextureProviderQueue")
    weak var delegate: VideoImageTextureProviderDelegate!
    
    public var size = CGSize(width: 720, height: 1280)
    

    required init?(device: MTLDevice, delegate: VideoImageTextureProviderDelegate) {
        super.init()
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                  nil,
                                  device,
                                  nil,
                                  &textureCache)
        self.delegate = delegate
        
        if(!didInitializeCaptureSession()) {
            return nil
        }
    }

    func didInitializeCaptureSession() -> Bool {
        
        captureSession.sessionPreset = AVCaptureSessionPresetiFrame1280x720
        
        guard let camera = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                         mediaType: AVMediaTypeVideo,
                                                         position: .back)
            else {
                print("Unable to access camera.")
                return false
        }
        self.camera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if(captureSession.canAddInput(input)) {
                captureSession.addInput(input)
            }
            else {
                print("Unable to add camera input.")
                return false
            }
        }
        catch let error as NSError {
            print("Error accessing camera input: \(error)")
            return false
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferCallbackQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            if let connection = videoOutput.connections.first as? AVCaptureConnection {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        else {
            print("Unable to add camera input.")
            return false
        }
        
        return true
    }
    
    // MARK: Capture Session Controls
    func startRunning() {
        sampleBufferCallbackQueue.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopRunning() {
        captureSession.stopRunning()
    }
    
    func setFocus(point: CGPoint) {
        do {
            try camera.lockForConfiguration()
            camera.focusPointOfInterest = point
            camera.focusMode = .continuousAutoFocus
            camera.unlockForConfiguration()
        } catch {}
    }
}

extension VideoImageTextureProvider: AVCaptureVideoDataOutputSampleBufferDelegate
{
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
        
        guard
            let cameraTextureCache = textureCache,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
        }
        
        /** Given a pixel buffer, the following code populates a Metal texture with the contents of the captured video frame.
         */
        var cameraTexture: CVMetalTexture?
        let cameraTextureWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let cameraTextureHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  cameraTextureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  MTLPixelFormat.bgra8Unorm,
                                                  cameraTextureWidth,
                                                  cameraTextureHeight,
                                                  0,
                                                  &cameraTexture)
        
        if let cameraTexture = cameraTexture,
            let metalTexture = CVMetalTextureGetTexture(cameraTexture) {
            // Call the delegate method whenever a new video frame has been converted into a Metal texture
            delegate.videoImageTextureProvider(self, didProvideTexture: metalTexture)
        }
    }
}
