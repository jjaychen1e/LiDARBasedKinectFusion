//
//  MarchingCubeRenderer.swift
//  LiDARBasedKinectFusion
//
//  Created by jjaychen on 2021/2/12.
//

import Foundation
import Metal
import MetalKit

class MarchingCubeRenderer {
    private var renderer: Renderer
    
    // MARK: - Properties from Renderer
    
    private var device: MTLDevice { renderer.device }
    private var library: MTLLibrary { renderer.library }
    private var tsdfBoxBuffer: MetalBuffer<TSDFVoxel> { renderer.tsdfBoxBuffer }
    private var tsdfParameterUniformsBuffer: MetalBuffer<TSDFParameterUniforms> { renderer.tsdfParameterUniformsBuffer }
    private var totalValidVoxelCount: MetalBuffer<UInt> { renderer.totalValidVoxelCount }
    private var activeInfoOutput: MetalBuffer<MarchingCubeActiveInfo> { renderer.activeInfoOutput }
    private var globalVertexBuffer: MetalBuffer<simd_float3> { renderer.globalVertexBuffer }
    private var globalNormalBuffer: MetalBuffer<simd_float3> { renderer.globalNormalBuffer }
    
    // MARK: - Self owned properties
    
    private lazy var marchingCubeTraverseComputePipelineState = makeMarchingCubeTraverseComputePipelineState()
    private lazy var marchingCubeAccumulateComputePipelineState = makeMarchingCubeAccumulateComputePipelineState()
    private lazy var marchingCubeExtractComputePipelineState = makeMarchingCubeExtractComputePipelineState()
    
    // MARK: - Main Methods
    init(renderer: Renderer) {
        self.renderer = renderer
    }
    
    func encodeTraverseCommands(into commandBuffer: MTLCommandBuffer) {
        if let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(marchingCubeTraverseComputePipelineState)
            commandEncoder.setBuffer(tsdfBoxBuffer)
            commandEncoder.setBuffer(totalValidVoxelCount)
            commandEncoder.setBuffer(activeInfoOutput)
            
            let w = marchingCubeTraverseComputePipelineState.threadExecutionWidth
            let h = marchingCubeTraverseComputePipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadsPerGrid = MTLSize(width: Int(TSDF_SIZE), height: Int(TSDF_SIZE), depth: Int(TSDF_SIZE))
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
        }
    }
    
    func encodeAccumulateCommands(into commandBuffer: MTLCommandBuffer) {
        if let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(marchingCubeAccumulateComputePipelineState)
            commandEncoder.setBuffer(activeInfoOutput)
            commandEncoder.setBuffer(totalValidVoxelCount)
            let threadsPerThreadgroup = MTLSizeMake(1, 1, 1)
            let threadsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
        }
    }
    
    func encodeExtractCommands(into commandBuffer: MTLCommandBuffer) {
        if let commandEncoder = commandBuffer.makeComputeCommandEncoder() {
            commandEncoder.setComputePipelineState(marchingCubeExtractComputePipelineState)
            commandEncoder.setBuffer(tsdfBoxBuffer)
            commandEncoder.setBuffer(tsdfParameterUniformsBuffer)
            commandEncoder.setBuffer(activeInfoOutput)
            commandEncoder.setBuffer(globalVertexBuffer)
            commandEncoder.setBuffer(globalNormalBuffer)
            
            let w = marchingCubeExtractComputePipelineState.threadExecutionWidth
            let h = marchingCubeExtractComputePipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadgroup = MTLSizeMake(w * h, 1, 1)
            let threadsPerGrid = MTLSize(width: Int(totalValidVoxelCount[0]), height: 1, depth: 1)
            commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
        }
    }
}

// MARK: - Metal Setup

extension MarchingCubeRenderer {
    private func makeMarchingCubeExtractComputePipelineState() -> MTLComputePipelineState {
        let marchingCubeExtractFunction = library.makeFunction(name: "marchingCubeExtract")!
        let marchingCubeExtractComputePipelineDescriptor = MTLComputePipelineDescriptor()
        marchingCubeExtractComputePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        marchingCubeExtractComputePipelineDescriptor.computeFunction = marchingCubeExtractFunction
        let marchingCubeExtractComputerPipelineState = try! device.makeComputePipelineState(descriptor: marchingCubeExtractComputePipelineDescriptor, options: [], reflection: nil)
        
        return marchingCubeExtractComputerPipelineState
    }
    
    private func makeMarchingCubeAccumulateComputePipelineState() -> MTLComputePipelineState {
        let marchingCubeAccumulateFunction = library.makeFunction(name: "marchingCubeAccumulate")!
        let marchingCubeAccumulateComputePipelineDescriptor = MTLComputePipelineDescriptor()
        marchingCubeAccumulateComputePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        marchingCubeAccumulateComputePipelineDescriptor.computeFunction = marchingCubeAccumulateFunction
        let marchingCubeAccumulateComputerPipelineState = try! device.makeComputePipelineState(descriptor: marchingCubeAccumulateComputePipelineDescriptor, options: [], reflection: nil)
        
        return marchingCubeAccumulateComputerPipelineState
    }
    
    private func makeMarchingCubeTraverseComputePipelineState() -> MTLComputePipelineState {
        let marchingCubeTraverseFunction = library.makeFunction(name: "marchingCubeTraverse")!
        let marchingCubeTraverseComputePipelineDescriptor = MTLComputePipelineDescriptor()
        marchingCubeTraverseComputePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        marchingCubeTraverseComputePipelineDescriptor.computeFunction = marchingCubeTraverseFunction
        let marchingCubeTraverseComputerPipelineState = try! device.makeComputePipelineState(descriptor: marchingCubeTraverseComputePipelineDescriptor, options: [], reflection: nil)
        
        return marchingCubeTraverseComputerPipelineState
    }
}
