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
                 uint3                                 gid                    [[thread_position_in_grid]])
{
    simd_float3 voxelPositionOffset = simd_float3(gid.x, gid.y, gid.z) * tsdfParameterUniforms.sizePerVoxel;
    simd_float3 worldSpaceVoxelPosition = tsdfParameterUniforms.origin + voxelPositionOffset;
    simd_float4 cameraSpaceVoxelPosition = cameraUniforms.worldToCamera * simd_float4(worldSpaceVoxelPosition, 1);
    cameraSpaceVoxelPosition /= cameraSpaceVoxelPosition.w;
    
    // Compare to camera resolution
    simd_float3 cameraPixelPosition = cameraUniforms.cameraIntrinsics * cameraSpaceVoxelPosition.xyz / cameraSpaceVoxelPosition.z;
    cameraPixelPosition /= cameraPixelPosition.z;
    if (cameraPixelPosition.x >= 0 && cameraPixelPosition.x <= cameraUniforms.cameraResolution.x &&
        cameraPixelPosition.y >= 0 && cameraPixelPosition.y <= cameraUniforms.cameraResolution.y) {
        simd_uint2 uv = simd_uint2(cameraPixelPosition.xy / cameraUniforms.cameraResolution);
        if (confidenceTexture.read(uv).x >= CONFIDENCE_THRESHOLD) {
            float depth = -depthTexture.read(uv).x;
            float tsdf = clamp(cameraSpaceVoxelPosition.z - depth, -tsdfParameterUniforms.truncateThreshold, tsdfParameterUniforms.truncateThreshold);
            float normalizedTSDF = tsdf / tsdfParameterUniforms.truncateThreshold;
            uint index = gid.z * tsdfParameterUniforms.size.x * tsdfParameterUniforms.size.y + gid.y * tsdfParameterUniforms.size.x + gid.x;
            float weight = min(tsdfParameterUniforms.maxWight, tsdfBox[index].weight + 1);
            tsdfBox[index].value = (tsdfBox[index].value * tsdfBox[index].weight + normalizedTSDF * weight) / (tsdfBox[index].weight + weight);
            tsdfBox[index].weight = weight;
        }
    }
}
