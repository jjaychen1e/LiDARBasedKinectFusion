//
//  TSDFFusionRenderer.swift
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/2/3.
//

import Foundation
import Metal
import MetalKit

class TSDFFusionRenderer {
    
    private var renderer: Renderer!
    
    // MARK: - Properties from Renderer
    
    private var device: MTLDevice { renderer.device }
    private var library: MTLLibrary { renderer.library }
    private var tsdfBoxBuffer: MetalBuffer<TSDFVoxel> { renderer.tsdfBoxBuffer }
    private var tsdfParameterUniformsBuffer: MetalBuffer<TSDFParameterUniforms> { renderer.tsdfParameterUniformsBuffer }
    private var currentCameraParameterUniformBuffer: MetalBuffer<CameraParameterUniforms> { renderer.currentCameraParameterUniformBuffer }
    private var depthTexture: CVMetalTexture? { renderer.depthTexture }
    private var confidenceTexture: CVMetalTexture? { renderer.confidenceTexture }
    private var vertexTexture: Texture? { renderer.vertexTexture }
    
    // MARK: - Self owned properties
    
    private lazy var tsdfFusionComputePipelineState = makeTSDFFusionComputePipelineState()
    
    // MARK: - Main Methods
    
    init(renderer: Renderer) {
        self.renderer = renderer
    }
    
    func encodeCommands(into commandBuffer: MTLCommandBuffer) {
        var textures = [depthTexture, confidenceTexture]
        commandBuffer.addCompletedHandler{ _ in
            textures.removeAll()
        }
        
        if let _depthTexture = depthTexture,
           let depthTexture = CVMetalTextureGetTexture(_depthTexture),
           let _confidenceTexture = confidenceTexture,
           let confidenceTexture = CVMetalTextureGetTexture(_confidenceTexture),
           let vertexTexture = vertexTexture,
           let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(tsdfFusionComputePipelineState)
            commandEncoder.setBuffer(tsdfBoxBuffer)
            commandEncoder.setBuffer(tsdfParameterUniformsBuffer)
            commandEncoder.setBuffer(currentCameraParameterUniformBuffer)
            commandEncoder.setTexture(texture: Texture(texture: depthTexture, index: kTextureIndexDepthMap.rawValue))
            commandEncoder.setTexture(texture: Texture(texture: confidenceTexture, index: kTextureIndexConfidenceMap.rawValue))
            commandEncoder.setTexture(texture: vertexTexture)
            
            let w = tsdfFusionComputePipelineState.threadExecutionWidth
            let h = tsdfFusionComputePipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadsPerGrid = MTLSize(width: Int(TSDF_SIZE), height: Int(TSDF_SIZE), depth: Int(TSDF_SIZE))
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
        }
    }
}

// MARK: - Metal Setup

extension TSDFFusionRenderer {
    private func makeTSDFFusionComputePipelineState() -> MTLComputePipelineState {
        let tsdfFusionFunction = library.makeFunction(name: "tsdfFusionKernel")!
        let tsdfFusionComputePipelineDescriptor = MTLComputePipelineDescriptor()
        tsdfFusionComputePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        tsdfFusionComputePipelineDescriptor.computeFunction = tsdfFusionFunction
        let tsdfFusionComputePipelineState = try! device.makeComputePipelineState(descriptor: tsdfFusionComputePipelineDescriptor, options: [], reflection: nil)
        
        return tsdfFusionComputePipelineState
    }
}
