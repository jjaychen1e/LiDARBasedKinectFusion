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
    var textureOutputDestination: RenderDestinationProvider
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
    private var cameraParameterUniformsBuffer = [MetalBuffer<CameraParameterUniforms>]()
    public var currentCameraParameterUniformBuffer: MetalBuffer<CameraParameterUniforms> {
        cameraParameterUniformsBuffer[currentBufferIndex]
    }
    lazy var relaxedStencilState: MTLDepthStencilState = makeRelaxedStencilState()
    lazy var depthStencilState: MTLDepthStencilState = makeDepthStencilState()
    private lazy var rotateToARCamera = Self.makeRotateToARCameraMatrix(orientation: orientation)
    
    private var computeState = ComputeState.normal
    
    // Depth things
    public var depthTexture: CVMetalTexture?
    public var confidenceTexture: CVMetalTexture?
    public var vertexTexture: Texture?
    
    // TSDF things
    public lazy var tsdfParameterUniformsBuffer: MetalBuffer<TSDFParameterUniforms> = {
        var tsdfParameterUniforms = TSDFParameterUniforms()
        tsdfParameterUniforms.size = simd_uint3(UInt32(TSDF_SIZE), UInt32(TSDF_SIZE), UInt32(TSDF_SIZE))
        tsdfParameterUniforms.sizePerVoxel = Float(TSDF_PER_LENGTH)
        tsdfParameterUniforms.origin = simd_float3(-0.5 * Float(TSDF_SIZE - 1) * Float(TSDF_PER_LENGTH),
                                                   -0.5 * Float(TSDF_SIZE - 1) * Float(TSDF_PER_LENGTH),
                                                   -0.5 * Float(TSDF_SIZE - 1) * Float(TSDF_PER_LENGTH))
//        tsdfParameterUniforms.origin = simd_float3(-0.5 * Float(TSDF_SIZE - 1) * Float(TSDF_PER_LENGTH),
//                                                   -0.5 * Float(TSDF_SIZE - 1) * Float(TSDF_PER_LENGTH),
//                                                   -(Float(TSDF_SIZE) - 0.5) * Float(TSDF_PER_LENGTH))
        tsdfParameterUniforms.truncateThreshold = 3 * Float(TSDF_PER_LENGTH)
        tsdfParameterUniforms.maxWeight = TSDF_MAX_WEIGHT
        
        let buffer = MetalBuffer<TSDFParameterUniforms>(device: device, count: MemoryLayout<TSDFParameterUniforms>.size, index: kBufferIndexTSDFParameterUniforms.rawValue, label: "TSDFParameterUniformsBuffer", options: .storageModeShared)
        buffer.assign(tsdfParameterUniforms)
        
        return buffer
    }()
    public lazy var tsdfBoxBuffer: MetalBuffer<TSDFVoxel> = {
        MetalBuffer<TSDFVoxel>(device: device,
                               array: Array<TSDFVoxel>(repeating: TSDFVoxel(value: 1, weight: 0),
                                                       count: Int(TSDF_SIZE) * Int(TSDF_SIZE) * Int(TSDF_SIZE)),
                               index: kBufferIndexTSDFBox.rawValue,
                               label: "TSDFBoxBuffer",
                               options: .storageModePrivate)
    }()
    
    // Marching Cube Things
    private var frameCount = 0
    private var readyToProcessMarchingCube = true
    public var totalVertexCount: UInt32? = nil
    
    public lazy var totalValidVoxelCount: MetalBuffer<UInt> = {
        MetalBuffer<UInt>(device: device,
                          array: [0],
                          index: kBufferIndexMarchingCubeTotalValidVoxelCount.rawValue,
                          label: "Marching Cube Total Vertex Number",
                          options: .storageModePrivate)
    }()
    public lazy var activeInfoOutput: MetalBuffer<MarchingCubeActiveInfo> = {
        MetalBuffer<MarchingCubeActiveInfo>(device: device,
                                            count: Int(MARCHING_CUBE_BUFFER_MAX_COUNT),
                                            index: kBufferIndexMarchingCubeMarchingCubeActiveInfo.rawValue,
                                            label: "Marching Cube Active Info",
                                            options: .storageModeShared)
    }()
    public lazy var globalVertexBuffer: MetalBuffer<simd_float3> = {
        MetalBuffer<simd_float3>(device: device,
                                 array: Array<simd_float3>(repeating: simd_float3(0, 0, 0),
                                                           count: Int(MARCHING_CUBE_BUFFER_MAX_COUNT)),
                                 index: kBufferIndexMarchingCubeGlobalVertex.rawValue,
                                 label: "Marching Cube Global Vertex Buffer",
                                 options: .storageModePrivate)
    }()
    public lazy var globalNormalBuffer: MetalBuffer<simd_float3> = {
        MetalBuffer<simd_float3>(device: device,
                                 array: Array<simd_float3>(repeating: simd_float3(0, 0, 0),
                                                           count: Int(MARCHING_CUBE_BUFFER_MAX_COUNT)),
                                 index: kBufferIndexMarchingCubeGlobalNormal.rawValue,
                                 label: "Marching Cube Global Normal Buffer",
                                 options: .storageModePrivate)
    }()
    
    // Renderers
    private var cameraImageRenderer: CameraImageRenderer!
    private var depthToVertexRenderer: DepthToVertexRenderer!
    private var tsdfFusionRenderer: TSDFFusionRenderer!
    private var marchingCubeRenderer: MarchingCubeRenderer!
    private var outputTextureRenderer: OutputTextureRenderer!
    
    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: RenderDestinationProvider, textureOutputDestination: RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination
        self.textureOutputDestination = textureOutputDestination
        self.library = device.makeDefaultLibrary()!
        self.commandQueue = device.makeCommandQueue()!
                
        self.renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
        self.textureOutputDestination.depthStencilPixelFormat = .depth32Float_stencil8
        
        for _ in 0..<kMaxBuffersInFlight {
            cameraParameterUniformsBuffer.append(.init(device: device, count: MemoryLayout<CameraParameterUniforms>.size, index: kBufferIndexCameraParameterUniforms.rawValue, label: "CameraParameterUniformsBuffer", options: .storageModeShared))
        }
        
        self.cameraImageRenderer = CameraImageRenderer(renderer: self)
        self.depthToVertexRenderer = DepthToVertexRenderer(renderer: self)
        self.tsdfFusionRenderer = TSDFFusionRenderer(renderer: self)
        self.marchingCubeRenderer = MarchingCubeRenderer(renderer: self)
        self.outputTextureRenderer = OutputTextureRenderer(renderer: self)
    }
    
    func drawRectResized(size: CGSize) {
        viewportSize = size
    }
    
    fileprivate func updateCameraParameters(_ currentFrame: ARFrame) {
        let camera = currentFrame.camera
        let cameraIntrinsics = camera.intrinsics
        let cameraIntrinsicsInversed = camera.intrinsics.inverse
        /// World space to camera space.
        let viewMatrix = camera.viewMatrix(for: orientation)
        /// Camera space to world space.
        let viewMatrixInversed = viewMatrix.inverse
        // Camera space to NDC space(used via Metal)
        let projectionMatrix = camera.projectionMatrix(for: orientation, viewportSize: viewportSize, zNear: 0.001, zFar: 0)
        
        cameraParameterUniforms.rotatePinholeToARCamera = rotateToARCamera
        cameraParameterUniforms.cameraIntrinsics = cameraIntrinsics
        cameraParameterUniforms.cameraIntrinsicsInversed = cameraIntrinsicsInversed
        cameraParameterUniforms.cameraToWorld = viewMatrixInversed
        cameraParameterUniforms.worldToCamera = viewMatrix
        cameraParameterUniforms.viewProjectionMatrix = projectionMatrix * viewMatrix
        cameraParameterUniforms.cameraResolution = Float2(Float(currentFrame.camera.imageResolution.width), Float(currentFrame.camera.imageResolution.height))
        cameraParameterUniformsBuffer[currentBufferIndex][0] = cameraParameterUniforms
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
                 updateCameraParameters(currentFrame)
            }
            
            cameraImageRenderer.encodeCommands(into: commandBuffer)
            outputTextureRenderer.encodeCommands(into: commandBuffer)
            
            if readyToProcessMarchingCube, computeState == .normal, frameCount >= 420, frameCount % 120 == 60 {
                readyToProcessMarchingCube = false
                computeState = .marchingCubeTraverse
            }
            
//            print(computeState)
            if computeState == .normal {
                if frameCount % 2 == 1,
                   let currentFrame = session.currentFrame {
                    if updateDepthTextures(frame: currentFrame) {
                        // Unproject Points
                        depthToVertexRenderer.encodeCommands(into: commandBuffer)
                    }
                    tsdfFusionRenderer.encodeCommands(into: commandBuffer)
                }
            } else if computeState == .marchingCubeTraverse {
                totalVertexCount = nil
                totalValidVoxelCount = MetalBuffer<UInt>(device: device,
                                                         array: [0],
                                                         index: kBufferIndexMarchingCubeTotalValidVoxelCount.rawValue,
                                                         label: "Marching Cube Total Vertex Number",
                                                         options: .storageModePrivate)
                marchingCubeRenderer.encodeTraverseCommands(into: commandBuffer)
                commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
                    if let strongSelf = self {
                        strongSelf.computeState = .marchingCubeAccumulate
                    }
                }
                
                computeState = .waiting
            } else if computeState == .marchingCubeAccumulate {
                computeState = .waiting
                if totalValidVoxelCount[0] > 0 {
                    DispatchQueue.main.async {
                        for i in 1..<Int(self.totalValidVoxelCount[0]) {
                            self.activeInfoOutput[i].voxelNumber += self.activeInfoOutput[i - 1].voxelNumber;
                        }
                        self.computeState = .marchingCubeExtract
                        self.totalVertexCount = self.activeInfoOutput[Int(self.totalValidVoxelCount[0]) - 1].voxelNumber
                    }
                } else {
                    self.computeState = .normal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.readyToProcessMarchingCube = true
                    }
                }
            } else if computeState == .marchingCubeExtract {
                computeState = .waiting

                marchingCubeRenderer.encodeExtractCommands(into: commandBuffer)
                commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
                    if let strongSelf = self {
                        strongSelf.computeState = .normal
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            strongSelf.readyToProcessMarchingCube = true
                        }
//                        print(strongSelf.totalVertexCount)
//                        for z in 0..<Int(TSDF_SIZE) {
//                            for y in 0..<Int(TSDF_SIZE) {
//                                for x in 0..<Int(TSDF_SIZE) {
//                                    var voxel = strongSelf.tsdfBoxBuffer[x + y * Int(TSDF_SIZE) + z * Int(TSDF_SIZE) * Int(TSDF_SIZE)]
////                                    if voxel.value > 1.0 || voxel.value < -1.0 {
//                                        print(voxel)
////                                    }
//                                }
//                            }
//                        }
                        
//                        if let depthTexture = CVMetalTextureGetTexture(strongSelf.depthTexture!),
//                           let confidenceTexture = CVMetalTextureGetTexture(strongSelf.confidenceTexture!) {
//
//                            let confidenceTexturePixels: UnsafeMutablePointer<Float32> = confidenceTexture.getPixels()
//                            let depthTexturePixels: UnsafeMutablePointer<Float32> = depthTexture.getPixels()
//                            defer {
//                                confidenceTexturePixels.deallocate()
//                                depthTexturePixels.deallocate()
//                            }
//
//                            for z in 0..<Int(TSDF_SIZE) {
//                                for y in 0..<Int(TSDF_SIZE) {
//                                    for x in 0..<Int(TSDF_SIZE) {
//                                        let gid = simd_float3(Float(x), Float(y), Float(z))
//                                        let voxelPositionOffset = gid * strongSelf.tsdfParameterUniformsBuffer[0].sizePerVoxel
//                                        let worldSpaceVoxelPosition = strongSelf.tsdfParameterUniformsBuffer[0].origin + voxelPositionOffset
//                                        var cameraSpaceVoxelPosition = strongSelf.cameraParameterUniforms.worldToCamera * simd_float4(worldSpaceVoxelPosition, 1)
//                                        cameraSpaceVoxelPosition /= cameraSpaceVoxelPosition.w
//                                        let cameraSpaceVoxelPositionInPinholeModel = strongSelf.cameraParameterUniforms.rotatePinholeToARCamera * cameraSpaceVoxelPosition
//                                        var cameraPixelPosition = strongSelf.cameraParameterUniforms.cameraIntrinsics * simd_float3(cameraSpaceVoxelPositionInPinholeModel.x, cameraSpaceVoxelPositionInPinholeModel.y, cameraSpaceVoxelPositionInPinholeModel.z) / cameraSpaceVoxelPositionInPinholeModel.z;
//                                        cameraPixelPosition /= cameraPixelPosition.z;
//
//                                        if (cameraPixelPosition.x >= 0 && cameraPixelPosition.x < strongSelf.cameraParameterUniforms.cameraResolution.x &&
//                                            cameraPixelPosition.y >= 0 && cameraPixelPosition.y < strongSelf.cameraParameterUniforms.cameraResolution.y) {
//                                            let uv = simd_float2(cameraPixelPosition.x + 0.5, cameraPixelPosition.y + 0.5) / strongSelf.cameraParameterUniforms.cameraResolution;
//                                            let point = simd_uint2(uv * simd_float2(Float(depthTexture.width), Float(depthTexture.height)));
//                                            let textureIndex = Int(point.x + point.y * UInt32(depthTexture.width))
//                                            if (confidenceTexturePixels[textureIndex] >= Float(CONFIDENCE_THRESHOLD)) {
//                                                let depth = -depthTexturePixels[textureIndex];
//                                                var tsdf = cameraSpaceVoxelPosition.z - depth
//                                                if tsdf <= -strongSelf.tsdfParameterUniformsBuffer[0].truncateThreshold {
//                                                    tsdf = -strongSelf.tsdfParameterUniformsBuffer[0].truncateThreshold
//                                                } else if tsdf >= strongSelf.tsdfParameterUniformsBuffer[0].truncateThreshold {
//                                                    tsdf = strongSelf.tsdfParameterUniformsBuffer[0].truncateThreshold
//                                                }
//                                                let normalizedTSDF = tsdf / strongSelf.tsdfParameterUniformsBuffer[0].truncateThreshold
//
//                                                let index = z * Int(TSDF_SIZE) * Int(TSDF_SIZE) + y * Int(TSDF_SIZE) + x;
//                                                let weight = min(strongSelf.tsdfParameterUniformsBuffer[0].maxWeight, strongSelf.tsdfBoxBuffer[index].weight + 1);
//                                                var value = Float(strongSelf.tsdfBoxBuffer[index].value * Float(strongSelf.tsdfBoxBuffer[index].weight) + normalizedTSDF * Float(weight)) / Float(strongSelf.tsdfBoxBuffer[index].weight + weight)
////                                                tsdfBox[index].weight = weight;
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                        }
                        
                    }
                }
            }
            
            if let currentDrawable = renderDestination.currentDrawable { commandBuffer.present(currentDrawable) }
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
        
        frameCount += 1
    }
}

extension Renderer {
    
    /// Relaxed means no compare.
    private func makeRelaxedStencilState() -> MTLDepthStencilState {
        let relaxedStateDescriptor = MTLDepthStencilDescriptor()
        return device.makeDepthStencilState(descriptor: relaxedStateDescriptor)!
    }
    
    private func makeDepthStencilState() -> MTLDepthStencilState {
        // setup depth test for point cloud
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStateDescriptor)!
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
    static private func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> Float4x4 {
        // flip to ARKit Camera's coordinate
        let flipYZ = Float4x4(
            [  1,  0,  0,  0],
            [  0, -1,  0,  0],
            [  0,  0, -1,  0],
            [  0,  0,  0,  1]
        )

        let rotationAngle = Float(cameraToDisplayRotation(orientation: orientation)) * .degreesToRadian
        return flipYZ * Float4x4(simd_quaternion(rotationAngle, Float3(0, 0, 1)))
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


enum ComputeState {
    case normal
    case marchingCubeTraverse
    case marchingCubeAccumulate
    case marchingCubeExtract
    case waiting
}
