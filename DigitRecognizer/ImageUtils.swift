//
//  ImageUtils.swift
//  DigitRecognizer
//
//  Created by Артур Антонов on 05.05.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import UIKit
import AVFoundation

struct ImageUtils {
    
    static func image(fromPixelValues pixelValues: [UInt8], width: Int, height: Int) -> CGImage?
    {
        var imageRef: CGImage?
        
        let bitsPerComponent = 8
        let bytesPerPixel = 1
        let bitsPerPixel = bytesPerPixel * bitsPerComponent
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = height * bytesPerRow
        
        imageRef = pixelValues.withUnsafeBytes { data -> CGImage? in
            var imageRef: CGImage?
            let colorSpaceRef = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo())
            let releaseData: CGDataProviderReleaseDataCallback = {
                (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
            }
            
            if let providerRef = CGDataProvider(dataInfo: nil, data: data.baseAddress!, size: totalBytes, releaseData: releaseData) {
                imageRef = CGImage(width: width,
                                   height: height,
                                   bitsPerComponent: bitsPerComponent,
                                   bitsPerPixel: bitsPerPixel,
                                   bytesPerRow: bytesPerRow,
                                   space: colorSpaceRef,
                                   bitmapInfo: bitmapInfo,
                                   provider: providerRef,
                                   decode: nil,
                                   shouldInterpolate: false,
                                   intent: CGColorRenderingIntent.defaultIntent)
            }
            
            return imageRef
        }
        
        return imageRef
    }
    
    static func prepare(cgImage: CGImage) -> CGImage {
        let cropSize = CGSize(width: 24, height: 24)
        
        let bitsPerComponent = 8
        let bytesPerRow = 28
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        let context = CGContext(data: nil, width: 28, height: 28, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)!
        
        context.interpolationQuality = CGInterpolationQuality.high
        
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 28, height: 28))
        
        var drawRect = AVMakeRect(aspectRatio: CGSize(width: cgImage.width, height: cgImage.height), insideRect: CGRect(origin: CGPoint.zero, size: cropSize))
        
        drawRect.origin = CGPoint(x: 14 - drawRect.width / 2, y: 14 - drawRect.height / 2)
        
        context.draw(cgImage, in: context.convertToUserSpace(drawRect), byTiling: false)
        
        let resizedCGImage = context.makeImage()?.cropping(to: CGRect(x: 0, y: 0, width: 28, height: 28))!
        
        return resizedCGImage!
    }
}
