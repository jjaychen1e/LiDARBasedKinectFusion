//
//  DepthToVertexRenderer.swift
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/1/8.
//

import Foundation
import Metal
import MetalKit

class DepthToVertexRenderer {
    
    private var renderer: Renderer!
    
    // MARK: - Properties from Renderer
    
    private var device: MTLDevice { renderer.device }
    private var library: MTLLibrary { renderer.library }
    private var currentParameterUniformBuffer: MetalBuffer<CameraParameterUniforms> { renderer.currentCameraParameterUniformBuffer }
    private var depthTexture: CVMetalTexture? { renderer.depthTexture }
    private var confidenceTexture: CVMetalTexture? { renderer.confidenceTexture }
    private var vertexTexture: Texture? { renderer.vertexTexture }
    
    // MARK: - Self owned properties
    
    private lazy var unprojectComputePipelineState = makeUnprojectComputePipelineState()
    
    // MARK: - Main Methods
    
    init(renderer: Renderer) {
        self.renderer = renderer
    }
    
    private func resetVertexTexture() {
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type2D
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.width = CVMetalTextureGetTexture(depthTexture!)!.width
        textureDescriptor.height = CVMetalTextureGetTexture(depthTexture!)!.height
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        renderer.vertexTexture = Texture(texture: device.makeTexture(descriptor: textureDescriptor)!, index: kTextureIndexVertexMap.rawValue)
    }
    
    private func compute(depth depthTexture: CVMetalTexture, andConfidenceTexture confidenceTexture: CVMetalTexture, intoVertext vertexTexture: Texture, with encoder: MTLComputeCommandEncoder) {
        if let depthTexture = CVMetalTextureGetTexture(depthTexture),
           let confidenceTexture = CVMetalTextureGetTexture(confidenceTexture) {
            encoder.setBuffer(currentParameterUniformBuffer)
            encoder.setTexture(texture: Texture(texture: depthTexture, index: kTextureIndexDepthMap.rawValue))
            encoder.setTexture(texture: Texture(texture: confidenceTexture, index: kTextureIndexConfidenceMap.rawValue))
            encoder.setTexture(texture: vertexTexture)
            encoder.setComputePipelineState(unprojectComputePipelineState)

            let w = unprojectComputePipelineState.threadExecutionWidth
            let h = unprojectComputePipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadsPerGrid = MTLSize(width: depthTexture.width, height: depthTexture.height, depth: 1)
            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            encoder.endEncoding()
        }
    }
    
    func encodeCommands(into commandBuffer: MTLCommandBuffer) {
        if vertexTexture == nil { resetVertexTexture() }
        
        if let depthTexture = depthTexture,
           let confidenceTexture = confidenceTexture,
           let vertexTexture = vertexTexture,
           let unprojectComputeEncoder = commandBuffer.makeComputeCommandEncoder() {
            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
            //   we use from the CVMetalTextures are not valid unless their parent CVMetalTextures
            //   are retained. Since we may release our CVMetalTexture ivars during the rendering
            //   cycle, we must retain them separately here.
            var textures = [depthTexture, confidenceTexture]
            commandBuffer.addCompletedHandler{ _ in
                textures.removeAll()
            }
            
            compute(depth: depthTexture, andConfidenceTexture: confidenceTexture ,intoVertext: vertexTexture, with: unprojectComputeEncoder)
        }
    }
}


// MARK: - Metal Setup

extension DepthToVertexRenderer {
    private func makeUnprojectComputePipelineState() -> MTLComputePipelineState {
        let unprojectFunction = library.makeFunction(name: "unprojectKernel")!
        let unprojectComputePipelineDescriptor = MTLComputePipelineDescriptor()
        unprojectComputePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        unprojectComputePipelineDescriptor.computeFunction = unprojectFunction
        let unprojectComputePipelineState = try! device.makeComputePipelineState(descriptor: unprojectComputePipelineDescriptor, options: [], reflection: nil)
        
        return unprojectComputePipelineState
    }
}
