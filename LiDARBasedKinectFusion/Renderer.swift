//
//  Renderer.swift
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/1/6.
//

import Foundation
import Metal
import MetalKit
import ARKit

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

// The max number of command buffers in flight
let kMaxBuffersInFlight: Int = 3

class Renderer {
    
    // The current viewport size
    private var viewportSize: CGSize = CGSize()
    // We only use landscape orientation in this app
    private let orientation = UIInterfaceOrientation.landscapeRight
    
    let session: ARSession
    var renderDestination: RenderDestinationProvider
    let device: MTLDevice
    let library: MTLLibrary
    let commandQueue: MTLCommandQueue!
    private let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    // This is the current frame number modulo kMaxBuffersInFlight
    var currentBufferIndex: Int = 0
    private lazy var textureCache = makeTextureCache()
    
    private lazy var cameraParameterUniforms: CameraParameterUniforms = {
        var cameraParameterUniforms = CameraParameterUniforms()
        let viewToCamera = session.currentFrame!.displayTransform(for: orientation, viewportSize: viewportSize).inverted()
        cameraParameterUniforms.viewToCamera.copy(from: viewToCamera)
        return cameraParameterUniforms
    }()
    var cameraParameterUniformsBuffer = [MetalBuffer<CameraParameterUniforms>]()
    lazy var relaxedStencilState: MTLDepthStencilState = makeRelaxedStencilState()!
    
    private var cameraImageRenderer: CameraImageRenderer!
    
    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination
        self.library = device.makeDefaultLibrary()!
        self.commandQueue = device.makeCommandQueue()!
                
        self.renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
        
        for _ in 0..<kMaxBuffersInFlight {
            cameraParameterUniformsBuffer.append(.init(device: device, count: MemoryLayout<CameraParameterUniforms>.size, index: kBufferIndexCameraParameterUniforms.rawValue, label: "SharedUniformBuffer", options: .storageModeShared))
        }
        
        self.cameraImageRenderer = CameraImageRenderer(renderer: self)
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    func update() {
        // Wait to ensure only kMaxBuffersInFlight are getting processed by any stage in the Metal
        //   pipeline (App, Metal, Drivers, GPU, etc)
        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // Create a new command buffer for each renderpass to the current drawable
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"
            
            commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
            }
            
            currentBufferIndex = (currentBufferIndex + 1) % kMaxBuffersInFlight
            
            if let currentFrame = session.currentFrame {
                cameraParameterUniformsBuffer[currentBufferIndex][0] = cameraParameterUniforms
            }
            
            cameraImageRenderer.encodeCommands(into: commandBuffer)
            
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }
}

extension Renderer {
    
    /// Relaxed means no compare.
    private func makeRelaxedStencilState() -> MTLDepthStencilState? {
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        return device.makeDepthStencilState(descriptor: relaxedStateDescriptor)
    }
    
    private func makeTextureCache() -> CVMetalTextureCache {
        // Create captured image texture cache
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        
        return cache
    }
    
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
        
        if status != kCVReturnSuccess {
            texture = nil
        }
        
        return texture
    }
    
}
