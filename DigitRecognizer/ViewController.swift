//
//  ViewController.swift
//  DigitRecognizer
//
//  Created by Artur on 16.04.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

import UIKit
import MetalKit
import MetalPerformanceShaders

import Accelerate

class ViewController: UIViewController {
    
    @IBOutlet var mtkView: MTKView!
    @IBOutlet var rectDrawer: RectDrawerView!
    
    
    @IBOutlet weak var debugView: UIView!
    @IBOutlet weak var debugConstr: NSLayoutConstraint!
    @IBOutlet var blurSwitch: UISwitch!
    @IBOutlet var dilitationSwitch: UISwitch!
    @IBOutlet var erosionSwitch: UISwitch!
    @IBOutlet weak var adapCLabel: UILabel!
    
    
    var debugPresented: Bool { return debugConstr.constant != 0 }
    
    var needExtract = false
    
    
    let device = MTLCreateSystemDefaultDevice()!
    var commandQueue: MTLCommandQueue!
    
    
    var filterChain: ImageFiltersChain!
    var adaptiveThreshold: AdaptiveThreshold!
    var dilitation: MPSImageDilate!
    var erosion: MPSImageErode!
    
    var filterFinalTexture: MTLTexture!
    
    var videoCapture: VideoImageTextureProvider!
    
    var sourceTexture: MTLTexture?
    
    var deepCNN: DigitCNN!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoCapture = VideoImageTextureProvider(device: device, delegate: self)
        setupMetal()
        
        let swipeGR = UISwipeGestureRecognizer(target: self, action: #selector(hideDebug))
        swipeGR.direction = .down
        debugView.addGestureRecognizer(swipeGR)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        videoCapture.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        videoCapture.stopRunning()
    }
    
    func setupMetal() {
        commandQueue = device.makeCommandQueue()
        
        let clipRect = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: Int(videoCapture.size.width), height: Int(videoCapture.size.height), depth: 1))
        
        let gausBlur = MPSImageGaussianBlur(device: device, sigma: 1.2)
        gausBlur.clipRect = clipRect
        
        adaptiveThreshold = AdaptiveThreshold(device: device, kernelSize: 11, C: 12)
        
        let dilitateWeights: [Float] = [0.3, 0, 0.3,
                               0, 0, 0,
                               0.3, 0, 0.3]
        
        dilitation = MPSImageDilate(device: device, kernelWidth: 3, kernelHeight: 3, values: dilitateWeights)
        dilitation.clipRect = clipRect
        
        erosion = MPSImageErode(device: device, kernelWidth: 3, kernelHeight: 3, values: dilitateWeights)
        erosion.clipRect = clipRect
        
        
        filterChain = ImageFiltersChain(device: device, size: videoCapture.size)
        
        filterChain.filters.append(gausBlur)
        filterChain.filters.append(adaptiveThreshold)
        filterChain.filters.append(dilitation)
        filterChain.filters.append(erosion)
        
        let textDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 720, height: 1280, mipmapped: false)
        
        filterFinalTexture = device.makeTexture(descriptor: textDescr)
        
        deepCNN = DigitCNN(commandQueue: commandQueue)
        
        mtkView.framebufferOnly = false
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isPaused = true
        mtkView.delegate = self
    }
    
    @IBAction func tapRecording(_ sender: UIButton) {
        if (!sender.isSelected) {
            sender.backgroundColor = .red
            needExtract = false
            rectDrawer.rectsToLabels = [:]
            videoCapture.startRunning()
        } else {
            sender.backgroundColor = .gray
            needExtract = true
        }
        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func tapDebug(_ sender: UIButton) {
        debugConstr.constant = 96;
        UIView.animate(withDuration: 0.3) { 
            self.view.layoutIfNeeded()
        }
    }
    
    func hideDebug() {
        debugConstr.constant = 0;
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func changeAdapC(_ sender: UIButton) {
        if (sender.tag == 0) {
            adapCLabel.text = "\(Int(adapCLabel.text!)! - 1)"
        } else {
            adapCLabel.text = "\(Int(adapCLabel.text!)! + 1)"
        }
    }
    
}

extension ViewController: MTKViewDelegate
{
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let sourceTexture = sourceTexture, let currentDrawable = mtkView.currentDrawable else {
            return;
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let destinationTexture = currentDrawable.texture
        
        filterChain.activeFilters[0] = blurSwitch.isOn
        filterChain.activeFilters[3] = erosionSwitch.isOn
        filterChain.activeFilters[2] = dilitationSwitch.isOn
        
        if let c = Float(adapCLabel.text ?? "") {
            adaptiveThreshold.c = c / 255
        }
        filterChain.encode(to: commandBuffer, sourceTexture: sourceTexture, destinationTexture: filterFinalTexture)
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder.copy(from: !debugPresented ? sourceTexture : filterFinalTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: 720, height: 1280, depth: 1),
                         to: destinationTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        
        commandBuffer.addCompletedHandler { (buffer) in
            guard buffer.status == .completed else {
                print(buffer.error ?? "")
                return
            }
            guard self.needExtract else { return }
            
            self.videoCapture.stopRunning()
            self.needExtract = false
            
            let size = Int(self.videoCapture.size.width * self.videoCapture.size.height * 4)
            let bytesPerRow = Int(self.videoCapture.size.width * 4)
            
            var pixelData = [UInt8](repeating: 0, count: size)
            
            pixelData.withUnsafeMutableBytes {
                self.filterFinalTexture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, Int(self.videoCapture.size.width), Int(self.videoCapture.size.height)), mipmapLevel: 0)
            }
            
            var curIndex = 0
            let oneChannelImageData = pixelData.filter({ _ in
                defer { curIndex += 1 }
                return curIndex % 4 == 0
            })
            
            let components = ComponentLabeling.extractComponents(imageData: oneChannelImageData, height: Int(self.videoCapture.size.height), width: Int(self.videoCapture.size.width))
            
            let cgImage = ImageUtils.image(fromPixelValues: oneChannelImageData, width: Int(self.videoCapture.size.width), height: Int(self.videoCapture.size.height))!
            
            self.rectDrawer.rectsToLabels.removeAll()
            
            components.forEach { rect in
                
                //var debugImage = UIImage(cgImage: cgImage)
                
                let blobImage = cgImage.cropping(to: rect)!
                
                //debugImage = UIImage(cgImage: blobImage)
                
                let cnnImage = ImageUtils.prepare(cgImage: blobImage)
                
                //debugImage = UIImage(cgImage: cnnImage)
                
                let textDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: 28, height: 28, mipmapped: false)
                let texture = self.device.makeTexture(descriptor: textDescr)
                
                let inputImage = MPSImage(texture: texture, featureChannels: 1)
                
                inputImage.texture.replace(region: MTLRegionMake2D(0, 0, 28, 28), mipmapLevel: 0,
                                           withBytes: CFDataGetBytePtr(cnnImage.dataProvider!.data!), bytesPerRow: 28)
                
                self.deepCNN.recognizeDigit(inputImage: inputImage) { result in
                    DispatchQueue.main.async {
                        self.rectDrawer.rectsToLabels[CGRect(x: rect.minX / 2, y: rect.minY / 2, width: rect.width / 2, height: rect.height / 2)] = result
                    }
                    print("Rect: \(rect) result: \(String(describing: result))")
                }
            }
        }
        
        commandBuffer.commit()
    }
}

extension ViewController: VideoImageTextureProviderDelegate
{
    func videoImageTextureProvider(_: VideoImageTextureProvider, didProvideTexture texture: MTLTexture) {
        sourceTexture = texture
        mtkView.draw()
    }
}
