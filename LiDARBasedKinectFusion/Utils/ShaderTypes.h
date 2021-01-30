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


// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs match
//   Metal API buffer set calls
typedef enum BufferIndices {
    kBufferIndexCameraParameterUniforms = 0,
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
} TextureIndices;

struct CameraParameterUniforms {
    // This is a transpose of a normal tranlation matrix because it's converted from CGAffineTransform
    matrix_float3x3 viewToCamera;
    matrix_float3x3 cameraIntrinsicsInversed;
    matrix_float4x4 cameraToWorld;
    matrix_float4x4 viewProjectionMatrix;
    simd_float2     cameraResolution;
};

#endif /* ShaderTypes_h */
