//
//  TSDFFusionRendererShaders.metal
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/2/2.
//

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

kernel void
tsdfFusionKernel(device TSDFVoxel                      *tsdfBox               [[buffer(kBufferIndexTSDFBox)]],
                 constant TSDFParameterUniforms        &tsdfParameterUniforms [[buffer(kBufferIndexTSDFParameterUniforms)]],
                 constant CameraParameterUniforms      &cameraUniforms        [[buffer(kBufferIndexCameraParameterUniforms)]],
                 texture2d<float, access::read>        depthTexture           [[texture(kTextureIndexDepthMap)]],
                 texture2d<unsigned int, access::read> confidenceTexture      [[texture(kTextureIndexConfidenceMap)]],
                 texture2d<float, access::read>        vertexTexture          [[texture(kTextureIndexVertexMap)]],
                 uint3                                 gid                    [[thread_position_in_grid]],
                 uint3                                 gridSize               [[threads_per_grid]])
{
    simd_float3 voxelPositionOffset = simd_float3(gid.x, gid.y, gid.z) * tsdfParameterUniforms.sizePerVoxel;
    simd_float3 worldSpaceVoxelPosition = tsdfParameterUniforms.origin + voxelPositionOffset;
    simd_float4 cameraSpaceVoxelPosition = cameraUniforms.worldToCamera * simd_float4(worldSpaceVoxelPosition, 1);
    cameraSpaceVoxelPosition /= cameraSpaceVoxelPosition.w;
    simd_float4 cameraSpaceVoxelPositionInPinholeModel = cameraUniforms.rotatePinholeToARCamera * cameraSpaceVoxelPosition;

    // Compare to camera resolution
    simd_float3 cameraPixelPosition = cameraUniforms.cameraIntrinsics * cameraSpaceVoxelPositionInPinholeModel.xyz / cameraSpaceVoxelPositionInPinholeModel.z;
    if (cameraPixelPosition.z < 0) return;
    cameraPixelPosition /= cameraPixelPosition.z;
    if (cameraPixelPosition.x >= 0 && cameraPixelPosition.x < cameraUniforms.cameraResolution.x &&
        cameraPixelPosition.y >= 0 && cameraPixelPosition.y < cameraUniforms.cameraResolution.y) {
        simd_float2 uv = (cameraPixelPosition.xy + 0.5) / cameraUniforms.cameraResolution;
        simd_uint2 point = simd_uint2(uv * simd_float2(depthTexture.get_width(), depthTexture.get_height()));
        if (confidenceTexture.read(point).x >= CONFIDENCE_THRESHOLD) {
            float depth = -depthTexture.read(point).x;
            float normalizedTSDF = clamp((cameraSpaceVoxelPosition.z - depth) / tsdfParameterUniforms.truncateThreshold, -1.0, 1.0);
//            if (normalizedTSDF <= -0.95 || normalizedTSDF >= 0.95) { return; }
            uint index = gid.z * gridSize.x * gridSize.y + gid.y * gridSize.x + gid.x;
            float weight = min(tsdfParameterUniforms.maxWeight, tsdfBox[index].weight + 1);
            tsdfBox[index].value = (tsdfBox[index].value * tsdfBox[index].weight + normalizedTSDF * weight) / (tsdfBox[index].weight + weight);
            tsdfBox[index].weight = weight;
        }
    }
}
