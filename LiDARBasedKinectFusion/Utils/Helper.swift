//
//  Helper.swift
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/1/15.
//
import ARKit

typealias Float2 = SIMD2<Float>
typealias Float3 = SIMD3<Float>
typealias Float3x3 = simd_float3x3
typealias Float4x4 = simd_float4x4

extension Float {
    static let degreesToRadian = Float.pi / 180
}

extension matrix_float3x3 {
    mutating func copy(from affine: CGAffineTransform) {
        columns.0 = Float3(Float(affine.a), Float(affine.c), Float(affine.tx))
        columns.1 = Float3(Float(affine.b), Float(affine.d), Float(affine.ty))
        columns.2 = Float3(0, 0, 1)
    }
}

extension MTLTexture {
  func getPixels<T> (_ region: MTLRegion? = nil, mipmapLevel: Int = 0) -> UnsafeMutablePointer<T> {
    let fromRegion  = region ?? MTLRegionMake2D(0, 0, self.width, self.height)
    let width       = fromRegion.size.width
    let height      = fromRegion.size.height
    let bytesPerRow = MemoryLayout<T>.stride * width
    let data        = UnsafeMutablePointer<T>.allocate(capacity: bytesPerRow * height)

    self.getBytes(data, bytesPerRow: bytesPerRow, from: fromRegion, mipmapLevel: mipmapLevel)
    return data
  }
}
