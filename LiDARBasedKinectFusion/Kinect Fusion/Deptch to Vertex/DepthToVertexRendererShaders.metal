//
//  DepthToVertexRendererShaders.metal
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/1/18.
//

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

/// Retrieves the world position of a specified camera point with depth
static float4 worldSpacePoint(simd_float2 pixelPoint, float depth, simd_float3x3 cameraIntrinsicsInversed, float4x4 cameraToWorld) {
    const auto cameraSpacePoint = cameraIntrinsicsInversed * simd_float3(pixelPoint, 1) * depth;
    const auto worldSpacePoint = cameraToWorld * simd_float4(cameraSpacePoint, 1);
    
    return worldSpacePoint / worldSpacePoint.w;
}

kernel void
unprojectKernel(constant CameraParameterUniforms      &uniforms         [[buffer(kBufferIndexCameraParameterUniforms)]],
                texture2d<float, access::read>        depthTexture      [[texture(kTextureIndexDepthMap)]],
                texture2d<unsigned int, access::read> confidenceTexture [[texture(kTextureIndexConfidenceMap)]],
                texture2d<float, access::write>       vertexTexture     [[texture(kTextureIndexVertexMap)]],
                uint2                                 gid               [[thread_position_in_grid]])
{
    unsigned int confidence  = confidenceTexture.read(gid).x;
    if (confidence >= CONFIDENCE_THRESHOLD) {
        float depth  = depthTexture.read(gid).x;
        simd_float2 normalSpacePosition = simd_float2((float)(gid.x) / (depthTexture.get_width() - 1),
                                                      (float)(gid.y) / (depthTexture.get_height() - 1));
        simd_float2 pixelPoint = normalSpacePosition * uniforms.cameraResolution;
        simd_float4 position = worldSpacePoint(pixelPoint,
                                               depth,
                                               uniforms.cameraIntrinsicsInversed,
                                               uniforms.cameraToWorld);
        vertexTexture.write(position, gid);
    }
}
