//
//  OutputTextureRendererShaders.metal
//  LiDARBasedKinectFusion
//
//  Created by jjaychen on 2021/2/16.
//

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

struct Vertex
{
    float4 position [[position]];
    float4 normal;
};

vertex Vertex outputTextureRendererVertexFuncion (uint                             vid       [[vertex_id]],
                                                  constant simd_float3             *vertices [[buffer(kBufferIndexMarchingCubeGlobalVertex)]],
                                                  constant simd_float3             *normals  [[buffer(kBufferIndexMarchingCubeGlobalNormal)]],
                                                  constant CameraParameterUniforms &uniforms [[buffer(kBufferIndexCameraParameterUniforms)]]) {
    Vertex vertexOutput;
    vertexOutput.position = uniforms.viewProjectionMatrix * simd_float4(vertices[vid], 1);
    vertexOutput.position /= vertexOutput.position.w;
    vertexOutput.normal = simd_float4(normals[vid], 1);
    return vertexOutput;
}

fragment float4 outputTextureRendererFragmentFunction (Vertex vertexIn [[stage_in]])
{
    return simd_float4(simd_float3(dot(vertexIn.normal, simd_float4(0.2126, 0.7152, 0.0722, 1))), 1) / 2;
}
