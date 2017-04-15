//
//  CNNUtils.swift
//  DigitRecognizer
//
//  Created by Артур Антонов on 03.05.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import MetalPerformanceShaders

class SlimMPSCNNConvolution: MPSCNNConvolution {

    private var padding = true
    
    init(kernelWidth: UInt, kernelHeight: UInt, inputFeatureChannels: UInt, outputFeatureChannels: UInt, neuronFilter: MPSCNNNeuron? = nil, device: MTLDevice, kernelParamsBinaryName: String, strideXY: (UInt, UInt) = (1, 1)) {
        
        // calculate the size of weights and bias required to be memory mapped into memory
        let countBias = outputFeatureChannels
        let countWeights = inputFeatureChannels * kernelHeight * kernelWidth * outputFeatureChannels
        
        // get the url to this layer's weights and bias
        let wtPath = Bundle.main.path(forResource: "weights_" + kernelParamsBinaryName, ofType: "dat")!
        let bsPath = Bundle.main.path(forResource: "bias_" + kernelParamsBinaryName, ofType: "dat")!
        
        let weights = WeightsLoader(path: wtPath, count: Int(countWeights))!
        let bias = WeightsLoader(path: bsPath, count: Int(countBias))!
        
        // create appropriate convolution descriptor with appropriate stride
        let convDesc = MPSCNNConvolutionDescriptor(kernelWidth: Int(kernelWidth),
                                                   kernelHeight: Int(kernelHeight),
                                                   inputFeatureChannels: Int(inputFeatureChannels),
                                                   outputFeatureChannels: Int(outputFeatureChannels),
                                                   neuronFilter: neuronFilter)
        convDesc.strideInPixelsX = Int(strideXY.0)
        convDesc.strideInPixelsY = Int(strideXY.1)
        
        // initialize the convolution layer by calling the parent's (MPSCNNConvlution's) initializer
        super.init(device: device,
                   convolutionDescriptor: convDesc,
                   kernelWeights: weights.data,
                   biasTerms: bias.data,
                   flags: MPSCNNConvolutionFlags.none)
        self.destinationFeatureChannelOffset = Int(destinationFeatureChannelOffset)
    }
    
    override func encode(commandBuffer: MTLCommandBuffer, sourceImage: MPSImage, destinationImage: MPSImage) {
            let pad_along_height = ((destinationImage.height - 1) * strideInPixelsY + kernelHeight - sourceImage.height)
            let pad_along_width  = ((destinationImage.width - 1) * strideInPixelsX + kernelWidth - sourceImage.width)
            let pad_top = Int(pad_along_height / 2)
            let pad_left = Int(pad_along_width / 2)
            
            self.offset = MPSOffset(x: ((Int(kernelWidth)/2) - pad_left), y: (Int(kernelHeight/2) - pad_top), z: 0)
        
        super.encode(commandBuffer: commandBuffer, sourceImage: sourceImage, destinationImage: destinationImage)
    }
}

class SlimMPSCNNFullyConnected: MPSCNNFullyConnected{

    
    init(kernelWidth: UInt, kernelHeight: UInt, inputFeatureChannels: UInt, outputFeatureChannels: UInt, neuronFilter: MPSCNNNeuron? = nil, device: MTLDevice, kernelParamsBinaryName: String) {
        
        // calculate the size of weights and bias required to be memory mapped into memory
        let countBias = outputFeatureChannels
        let countWeights = inputFeatureChannels * kernelHeight * kernelWidth * outputFeatureChannels
        
        // get the url to this layer's weights and bias
        let wtPath = Bundle.main.path(forResource: "weights_" + kernelParamsBinaryName, ofType: "dat")!
        let bsPath = Bundle.main.path(forResource: "bias_" + kernelParamsBinaryName, ofType: "dat")!
        
        let weights = WeightsLoader(path: wtPath, count: Int(countWeights))!
        let bias = WeightsLoader(path: bsPath, count: Int(countBias))!
        
        // create appropriate convolution descriptor (in fully connected, stride is always 1)
        let convDesc = MPSCNNConvolutionDescriptor(kernelWidth: Int(kernelWidth),
                                                   kernelHeight: Int(kernelHeight),
                                                   inputFeatureChannels: Int(inputFeatureChannels),
                                                   outputFeatureChannels: Int(outputFeatureChannels),
                                                   neuronFilter: neuronFilter)
        
        // initialize the convolution layer by calling the parent's (MPSCNNFullyConnected's) initializer
        super.init(device: device,
                   convolutionDescriptor: convDesc,
                   kernelWeights: weights.data,
                   biasTerms: bias.data,
                   flags: MPSCNNConvolutionFlags.none)
    }
}

fileprivate class WeightsLoader {
    private var fileSize: Int
    private var fd: CInt!
    private var hdr: UnsafeMutableRawPointer!
    private(set) public var data: UnsafeMutablePointer<Float>
    
    public init?(path: String, count: Int) {
        fileSize = count * MemoryLayout<Float>.stride

        fd = open(path, O_RDONLY, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH)
        if fd == -1 {
            print("Error: failed to open \"\(path)\", error = \(errno)")
            return nil
        }
        
        hdr = mmap(nil, fileSize, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0)
        if hdr == nil {
            print("Error: mmap failed, errno = \(errno)")
            return nil
        }
        
        data = hdr.bindMemory(to: Float.self, capacity: count)
        if data == UnsafeMutablePointer<Float>(bitPattern: -1) {
            print("Error: mmap failed, errno = \(errno)")
            return nil
        }
    }
    
    deinit {
        if let hdr = hdr {
            let result = munmap(hdr, Int(fileSize))
            assert(result == 0, "Error: munmap failed, errno = \(errno)")
        }
        if let fd = fd {
            close(fd)
        }
    }
}
