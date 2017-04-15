//
//  ImageFiltersChain.swift
//  DigitRecognizer
//
//  Created by Artur on 22.04.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import MetalPerformanceShaders

class ImageFiltersChain: ImageFilter {
    
    let device: MTLDevice
    
    var intermediateTexture1, intermediateTexture2: MTLTexture
    
    public var filters = [ImageFilter]() {
        didSet {
            activeFilters = [Bool](repeating: true, count: filters.count)
        }
    }
    public var activeFilters = [Bool]()
    
    init(device: MTLDevice, size: CGSize) {
        self.device = device
        
        let textDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
        
        intermediateTexture1 = device.makeTexture(descriptor: textDescr)
        intermediateTexture2 = device.makeTexture(descriptor: textDescr)
    }
    
    func encode(to commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        
        var lastIntermediate = sourceTexture
        
        var enabledFilters = [ImageFilter]()
        
        for (index, filter) in filters.enumerated()
        {
            if activeFilters[index] {
                enabledFilters.append(filter)
            }
        }
        
        for (index, filter) in enabledFilters.enumerated()
        {
            if (index == enabledFilters.count - 1) {
                filter.encode(to: commandBuffer, sourceTexture: lastIntermediate, destinationTexture: destinationTexture)
            } else if (index == 0) {
                filter.encode(to: commandBuffer, sourceTexture: sourceTexture, destinationTexture: intermediateTexture1)
            } else {
                filter.encode(to: commandBuffer, sourceTexture: intermediateTexture1, destinationTexture: intermediateTexture2)
                lastIntermediate = intermediateTexture2
                swap(&intermediateTexture1, &intermediateTexture2)
            }
        }
    }
}

protocol ImageFilter {
    func encode(to commandBuffer: MTLCommandBuffer,
                sourceTexture: MTLTexture,
                destinationTexture: MTLTexture)
}

extension MPSUnaryImageKernel: ImageFilter {
    func encode(to commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: destinationTexture)
    }
}
