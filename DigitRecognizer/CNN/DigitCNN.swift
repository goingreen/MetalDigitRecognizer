//
//  DigitCNN.swift
//  DigitRecognizer
//
//  Created by Артур Антонов on 03.05.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import MetalPerformanceShaders
import Accelerate

// Model structure: src -> conv1 -> maxPool -> conv2 -> maxPool -> fc1 -> fc2 -> softmax
class DigitCNN {
    
    // MPSImages and layers declared
    var srcImage, c1Image, p1Image, c2Image, p2Image, fc1Image, dstImage: MPSImage
    var conv1, conv2: MPSCNNConvolution
    var fc1, fc2: MPSCNNFullyConnected
    var pool: MPSCNNPoolingMax
    var softmax : MPSCNNSoftMax
    var relu: MPSCNNNeuronReLU
    
    let did = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 1, height: 1, featureChannels: 10)
    
    let commandQueue : MTLCommandQueue
    let device : MTLDevice
    
    init(commandQueue: MTLCommandQueue) {
        self.commandQueue = commandQueue
        device = commandQueue.device
        
        // Images
        let sid = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.unorm8, width: 28, height: 28, featureChannels: 1)
        srcImage = MPSImage(device: device, imageDescriptor: sid)
        
        let c1id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 28, height: 28, featureChannels: 32)
        c1Image = MPSImage(device: device, imageDescriptor: c1id)
        
        let p1id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 14, height: 14, featureChannels: 32)
        p1Image = MPSImage(device: device, imageDescriptor: p1id)
        
        let c2id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 14, height: 14, featureChannels: 64)
        c2Image = MPSImage(device: device, imageDescriptor: c2id)
        
        let p2id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 7 , height: 7 , featureChannels: 64)
        p2Image = MPSImage(device: device, imageDescriptor: p2id)
        
        let fc1id = MPSImageDescriptor(channelFormat: MPSImageFeatureChannelFormat.float16, width: 1 , height: 1 , featureChannels: 1024)
        fc1Image = MPSImage(device: device, imageDescriptor: fc1id)
        
        dstImage = MPSImage(device: device, imageDescriptor: did)
        
        relu = MPSCNNNeuronReLU(device: device, a: 0)
        
        conv1 = SlimMPSCNNConvolution(kernelWidth: 5,
                                      kernelHeight: 5,
                                      inputFeatureChannels: 1,
                                      outputFeatureChannels: 32,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv1")
        
        pool = MPSCNNPoolingMax(device: device, kernelWidth: 2, kernelHeight: 2, strideInPixelsX: 2, strideInPixelsY: 2)
        pool.offset = MPSOffset(x: 1, y: 1, z: 0);
        pool.edgeMode = MPSImageEdgeMode.clamp
        
        conv2 = SlimMPSCNNConvolution(kernelWidth: 5,
                                      kernelHeight: 5,
                                      inputFeatureChannels: 32,
                                      outputFeatureChannels: 64,
                                      neuronFilter: relu,
                                      device: device,
                                      kernelParamsBinaryName: "conv2")
        
        fc1 = SlimMPSCNNFullyConnected(kernelWidth: 7,
                                       kernelHeight: 7,
                                       inputFeatureChannels: 64,
                                       outputFeatureChannels: 1024,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "fc1")
        
        fc2 = SlimMPSCNNFullyConnected(kernelWidth: 1,
                                       kernelHeight: 1,
                                       inputFeatureChannels: 1024,
                                       outputFeatureChannels: 10,
                                       neuronFilter: nil,
                                       device: device,
                                       kernelParamsBinaryName: "fc2")
        
        softmax = MPSCNNSoftMax(device: device)
    }
    
    func recognizeDigit(inputImage: MPSImage, resultHandler: @escaping (Int?)-> ()) {
        assert(inputImage.width == 28 && inputImage.height == 28)
        
        autoreleasepool {
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            // output will be stored in this image
            let finalLayer = MPSImage(device: commandBuffer.device, imageDescriptor: did)
            
            // encode layers to metal commandBuffer
            conv1.encode  (commandBuffer: commandBuffer, sourceImage: inputImage, destinationImage: c1Image)
            pool.encode   (commandBuffer: commandBuffer, sourceImage: c1Image   , destinationImage: p1Image)
            conv2.encode  (commandBuffer: commandBuffer, sourceImage: p1Image   , destinationImage: c2Image)
            pool.encode   (commandBuffer: commandBuffer, sourceImage: c2Image   , destinationImage: p2Image)
            fc1.encode    (commandBuffer: commandBuffer, sourceImage: p2Image   , destinationImage: fc1Image)
            fc2.encode    (commandBuffer: commandBuffer, sourceImage: fc1Image  , destinationImage: dstImage)
            softmax.encode(commandBuffer: commandBuffer, sourceImage: dstImage  , destinationImage: finalLayer)
            
            commandBuffer.addCompletedHandler { _ in
                let label = self.getLabel(finalLayer: finalLayer)
                resultHandler(label)
            }
            commandBuffer.commit()
        }
    }
    
    private func getLabel(finalLayer: MPSImage) -> Int? {
        var result_half_array = [UInt16](repeating: 0, count: 12)
        var result_float_array = [Float](repeating: 0, count: 10)
        for i in 0...2 {
            finalLayer.texture.getBytes(&(result_half_array[4*i]),
                                        bytesPerRow: MemoryLayout<UInt16>.size*1*4,
                                        bytesPerImage: MemoryLayout<UInt16>.size*1*1*4,
                                        from: MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                                                        size: MTLSize(width: 1, height: 1, depth: 1)),
                                        mipmapLevel: 0,
                                        slice: i)
        }
        
        // Metal GPUs use float16 and swift float is 32-bit
        var fullResultVImagebuf = vImage_Buffer(data: &result_float_array, height: 1, width: 10, rowBytes: 10*4)
        var halfResultVImagebuf = vImage_Buffer(data: &result_half_array , height: 1, width: 10, rowBytes: 10*2)
        
        if vImageConvert_Planar16FtoPlanarF(&halfResultVImagebuf, &fullResultVImagebuf, 0) != kvImageNoError {
            print("Error in vImage")
        }

        var max:Float = 0
        var mostProbableDigit = 10
        for i in 0...9 {
            if(max < result_float_array[i]){
                max = result_float_array[i]
                mostProbableDigit = i
            }
        }
        // return label only if prob more than 32%
        return max > 0.32 ? mostProbableDigit : nil
    }
}
