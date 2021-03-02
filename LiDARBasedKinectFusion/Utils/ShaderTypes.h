//
//  ShaderTypes.h
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/1/6.
//

//
//  Header containing types and enum constants shared between Metal shaders and C/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#define CONFIDENCE_THRESHOLD 1

#define TSDF_SIZE 570
#define TSDF_PER_LENGTH 0.00390625
#define TSDF_MAX_WEIGHT 512


#define MARCHING_CUBE_MIN_ISO_VALUE -1.0
#define MARCHING_CUBE_ISO_VALUE 0
#define MARCHING_CUBE_MIN_WEIGHT 100
#define MARCHING_CUBE_BUFFER_MAX_COUNT 50000000


// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum BufferIndices {
    kBufferIndexCameraParameterUniforms            = 0,
    kBufferIndexTSDFBox                            = 1,
    kBufferIndexTSDFParameterUniforms              = 2,
    kBufferIndexMarchingCubeTotalValidVoxelCount   = 3,
    kBufferIndexMarchingCubeGlobalVertex           = 4,
    kBufferIndexMarchingCubeGlobalNormal           = 5,
    kBufferIndexMarchingCubeMarchingCubeActiveInfo = 6,
} BufferIndices;

// Texture index values shared between shader and C code to ensure Metal shader texture indices
//   match indices of Metal API texture set calls
typedef enum TextureIndices {
    kTextureIndexY                          = 0,
    kTextureIndexCbCr                       = 1,
    kTextureIndexDepthMap                   = 2,
    kTextureIndexConfidenceMap              = 3,
    kTextureIndexVertexMap                  = 4,
    kTextureIndexNormalMap                  = 5,
    kTextureOutputTexture                   = 6,
} TextureIndices;

struct CameraParameterUniforms {
    // This is a transpose of a normal tranlation matrix because it's converted from CGAffineTransform
    matrix_float3x3 viewToCamera;
    matrix_float3x3 cameraIntrinsics;
    matrix_float3x3 cameraIntrinsicsInversed;
    matrix_float4x4 rotatePinholeToARCamera;
    matrix_float4x4 cameraToWorld;
    matrix_float4x4 worldToCamera;
    matrix_float4x4 viewProjectionMatrix;
    simd_float2     cameraResolution;
};

struct TSDFParameterUniforms {
    /// The origin of the TSDF box. It locates in one corner of the box(whose coornidate components' value is smallest) instead of  the center of the box.
    /// It's designed for the convienience of calculating positions of all voxels.
    simd_float3 origin;
    /// The size of each voxel(a cube).
    float sizePerVoxel;
    /// The threshold used to truncate the DSF.
    float truncateThreshold;
    /// The size of the whole TSDF box. Usually, it is a cube.
    simd_uint3 size;
    int maxWeight;
};

// ((1024*1024*1024*8)/(32*2))^(1/3) = 512
// ((1426*1024*1024*8)/(64))^(1/3) = 571 (iPad Pro 2020 11')
struct TSDFVoxel {
    float value;
    int weight;
};

struct MarchingCubeActiveInfo {
    uint voxelIndex;
    uint voxelNumber; // total voxel number
//    uint tableIndex;
};

#endif /* ShaderTypes_h */
