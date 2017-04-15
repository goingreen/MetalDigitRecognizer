//
//  AdaptiveThreshold.swift
//  DigitRecognizer
//
//  Created by Артур Антонов on 07.05.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import Metal

class AdaptiveThreshold: ImageFilter {
    
    let computeState: MTLComputePipelineState
    
    var weightsTexture: MTLTexture!
    var c: Float
    
    init(device: MTLDevice, kernelSize: Int, C: Int) {
        let function = device.newDefaultLibrary()!.makeFunction(name: "adaptive_threshold")!
        computeState = try! device.makeComputePipelineState(function: function)
        c = Float(C) / 255
        makeWeightsTexture(size: kernelSize)
    }
    
    func encode(to commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, destinationTexture: MTLTexture) {
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()
        computeEncoder.setComputePipelineState(computeState)
        computeEncoder.setTexture(sourceTexture, at: 0)
        computeEncoder.setTexture(destinationTexture, at: 1)
        computeEncoder.setTexture(weightsTexture, at: 2)
        computeEncoder.setBytes(&c, length: MemoryLayout<Float>.size, at: 0)
        
        let threadGroup = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroupsCount = MTLSize(width: (sourceTexture.width + 15) / 16, height: (sourceTexture.height + 15) / 16, depth: 1)
        
        computeEncoder.dispatchThreadgroups(threadGroupsCount, threadsPerThreadgroup: threadGroup)
        
        computeEncoder.endEncoding()
    }
    
    func makeWeightsTexture(size: Int) {
        var weights = [Float](repeating: 0, count: size*size)
        
        let radius = size / 2
        let sigma: Float = (Float(size - 1) * 0.5 - 1) * 0.3 + 0.8
        
        let expScale = -1 / (2 * sigma * sigma)
        
        var weightSum: Float = 0
        
        for y in -radius...radius {
            for x in -radius...radius {
                let weight = expf(Float(y*y + x*x) * expScale)
                weights[(y + radius) * size + (x + radius)] = weight
                weightSum += weight
            }
        }
        weights = weights.map { $0 / weightSum }
        
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: size, height: size, mipmapped: false)
        
        weightsTexture = computeState.device.makeTexture(descriptor: textureDescr)
        
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: size, height: size, depth: 1))
        weightsTexture.replace(region: region, mipmapLevel: 0, withBytes: weights, bytesPerRow: size * MemoryLayout<Float>.size)
    }
}
