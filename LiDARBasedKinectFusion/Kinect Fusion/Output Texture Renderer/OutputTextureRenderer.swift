//
//  OutputTextureRenderer.swift
//  LiDARBasedKinectFusion
//
//  Created by jjaychen on 2021/2/17.
//

import Foundation
import Metal
import MetalKit
import ARKit

class OutputTextureRenderer {
    private var renderer: Renderer
    
    // MARK: - Properties from Renderer
    private var device: MTLDevice { renderer.device }
    private var renderDestination: RenderDestinationProvider { renderer.renderDestination }
    private var textureOutputDestination: RenderDestinationProvider { renderer.textureOutputDestination }
    private var library: MTLLibrary { renderer.library }
    private var depthStencilState: MTLDepthStencilState { renderer.depthStencilState }
    private var currentCameraParameterUniformBuffer: MetalBuffer<CameraParameterUniforms> { renderer.currentCameraParameterUniformBuffer }
    private var totalVertexCount: UInt32? { renderer.totalVertexCount }
    private var activeInfoOutput: MetalBuffer<MarchingCubeActiveInfo> { renderer.activeInfoOutput }
    private var globalVertexBuffer: MetalBuffer<simd_float3> { renderer.globalVertexBuffer }
    private var globalNormalBuffer: MetalBuffer<simd_float3> { renderer.globalNormalBuffer }
    
    // MARK: - Self owned properties
    private lazy var outputTextureRenderPipelineState: MTLRenderPipelineState =  makeOutputTextureRenderPipelineState()!
    
    init(renderer: Renderer) {
        self.renderer = renderer
    }
    
    func encodeCommands(into commandBuffer: MTLCommandBuffer) {
        if let totalVertexCount = totalVertexCount,
           let renderPassDescriptor = renderDestination.currentRenderPassDescriptor {
            renderPassDescriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
            renderPassDescriptor.colorAttachments[0].storeAction = .store
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor){
              renderEncoder.label = "OutputTextureRenderEncoder"
              renderEncoder.setRenderPipelineState(outputTextureRenderPipelineState)
              renderEncoder.setDepthStencilState(depthStencilState)
              renderEncoder.setFrontFacing(.counterClockwise)
              renderEncoder.setCullMode(.back)
              renderEncoder.setVertexResource(globalVertexBuffer)
              renderEncoder.setVertexResource(globalNormalBuffer)
              renderEncoder.setVertexResource(currentCameraParameterUniformBuffer)
              renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Int(totalVertexCount))
              renderEncoder.endEncoding()
          }
        }
    }
}

// MARK: - Metal Setup

extension OutputTextureRenderer {
    
    private func makeOutputTextureRenderPipelineState() -> MTLRenderPipelineState? {
        let outputTextureRendererVertexFunction = library.makeFunction(name: "outputTextureRendererVertexFuncion")!
        let outputTextureRendererFragmentFunction = library.makeFunction(name: "outputTextureRendererFragmentFunction")!
        
        let outputTexturePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        outputTexturePipelineStateDescriptor.vertexFunction = outputTextureRendererVertexFunction
        outputTexturePipelineStateDescriptor.fragmentFunction = outputTextureRendererFragmentFunction
        outputTexturePipelineStateDescriptor.label = "Output Texture Render Pipeline"
        outputTexturePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        outputTexturePipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        outputTexturePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        outputTexturePipelineStateDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        
        return try? device.makeRenderPipelineState(descriptor: outputTexturePipelineStateDescriptor)
    }
    
}
