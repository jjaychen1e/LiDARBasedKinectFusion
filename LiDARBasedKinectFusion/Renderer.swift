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
    var currentParameterUniformBuffer: MetalBuffer<CameraParameterUniforms> {
        cameraParameterUniformsBuffer[currentBufferIndex]
    }
    lazy var relaxedStencilState: MTLDepthStencilState = makeRelaxedStencilState()!
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    
    public var depthTexture: CVMetalTexture?
    public var confidenceTexture: CVMetalTexture?
    public var vertexTexture: Texture?
    public var normalTexture: Texture?
    
    private var cameraImageRenderer: CameraImageRenderer!
    private var depthToVertexRenderer: DepthToVertexRenderer!
    
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
        self.depthToVertexRenderer = DepthToVertexRenderer(renderer: self)
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
            
            cameraImageRenderer.encodeCommands(into: commandBuffer)
            
            if let currentFrame = session.currentFrame {
                let camera = currentFrame.camera
                /// Camera space to image space. Camera's intrinsics uses pihole model, whose Y-Axis is upside-down, so we need to flip it.
                let cameraIntrinsicsInversed = rotateToARCamera * camera.intrinsics.inverse
                /// World space to camera space.
                let viewMatrix = camera.viewMatrix(for: orientation)
                /// Camera space to world space.
                let viewMatrixInversed = viewMatrix.inverse
                // Camera space to NDC space(used via Metal)
                let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
                
                cameraParameterUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
                cameraParameterUniforms.cameraToWorld = viewMatrixInversed
                cameraParameterUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
                cameraParameterUniforms.cameraResolution = Float2(Float(currentFrame.camera.imageResolution.width), Float(currentFrame.camera.imageResolution.height))
                cameraParameterUniformsBuffer[currentBufferIndex][0] = cameraParameterUniforms
                if updateDepthTextures(frame: currentFrame) {
                    // Unproject Points
                    depthToVertexRenderer.encodeCommands(into: commandBuffer)
                }
            }
            
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
    
    static private func cameraToDisplayRotation(orientation: UIInterfaceOrientation) -> Int {
        switch orientation {
        case .landscapeLeft:
            return 180
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return -90
        default:
            return 0
        }
    }
    
    /// Camera's intrisics matrix is based on pinhole model. And in the implementation, Y-Axis is upside-down, so we need to
    /// flip Y-Axis too.
    static private func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> Float3x3 {
        // flip to ARKit Camera's coordinate
        let flipYZ = Float3x3(
            [1, 0,  0],
            [0, -1, 0],
            [0, 0, -1]
        )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * Float3x3(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
    }
    
    private func updateDepthTextures(frame: ARFrame) -> Bool {
        guard let depthMap = frame.sceneDepth?.depthMap,
            let confidenceMap = frame.sceneDepth?.confidenceMap else {
                return false
        }
        
        depthTexture = createTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0)
        confidenceTexture = createTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0)
        
        return true
    }
}
