
//  MarchingCubeRendererShaders.metal
//  LiDARBasedKinectFusion
//
//  Created by 陈俊杰 on 2021/2/9.
//

#include <metal_stdlib>
using namespace metal;

// Include header shared between this Metal shader code and C code executing Metal API commands
#import "ShaderTypes.h"

constant uint MarchingCubeNumberTable[256] =
{
    0,
    3,
    3,
    6,
    3,
    6,
    6,
    9,
    3,
    6,
    6,
    9,
    6,
    9,
    9,
    6,
    3,
    6,
    6,
    9,
    6,
    9,
    9,
    12,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    9,
    3,
    6,
    6,
    9,
    6,
    9,
    9,
    12,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    9,
    6,
    9,
    9,
    6,
    9,
    12,
    12,
    9,
    9,
    12,
    12,
    9,
    12,
    15,
    15,
    6,
    3,
    6,
    6,
    9,
    6,
    9,
    9,
    12,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    9,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    15,
    9,
    12,
    12,
    15,
    12,
    15,
    15,
    12,
    6,
    9,
    9,
    12,
    9,
    12,
    6,
    9,
    9,
    12,
    12,
    15,
    12,
    15,
    9,
    6,
    9,
    12,
    12,
    9,
    12,
    15,
    9,
    6,
    12,
    15,
    15,
    12,
    15,
    6,
    12,
    3,
    3,
    6,
    6,
    9,
    6,
    9,
    9,
    12,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    9,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    15,
    9,
    6,
    12,
    9,
    12,
    9,
    15,
    6,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    15,
    9,
    12,
    12,
    15,
    12,
    15,
    15,
    12,
    9,
    12,
    12,
    9,
    12,
    15,
    15,
    12,
    12,
    9,
    15,
    6,
    15,
    12,
    6,
    3,
    6,
    9,
    9,
    12,
    9,
    12,
    12,
    15,
    9,
    12,
    12,
    15,
    6,
    9,
    9,
    6,
    9,
    12,
    12,
    15,
    12,
    15,
    15,
    6,
    12,
    9,
    15,
    12,
    9,
    6,
    12,
    3,
    9,
    12,
    12,
    15,
    12,
    15,
    9,
    12,
    12,
    15,
    15,
    6,
    9,
    12,
    6,
    3,
    6,
    9,
    9,
    6,
    9,
    12,
    6,
    3,
    9,
    6,
    12,
    3,
    6,
    3,
    3,
    0,
};

constant int MarchingCubeTable[256][16] =
{
    { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  1,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  8,  3,  9,  8,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3,  1,  2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  2, 10,  0,  2,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  8,  3,  2, 10,  8, 10,  9,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  3, 11,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0, 11,  2,  8, 11,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  9,  0,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1, 11,  2,  1,  9, 11,  9,  8, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  3, 10,  1, 11, 10,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0, 10,  1,  0,  8, 10,  8, 11, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  9,  0,  3, 11,  9, 11, 10,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  8, 10, 10,  8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  7,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  3,  0,  7,  3,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  1,  9,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  1,  9,  4,  7,  1,  7,  3,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  4,  7,  3,  0,  4,  1,  2, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  2, 10,  9,  0,  2,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  2, 10,  9,  2,  9,  7,  2,  7,  3,  7,  9,  4, -1, -1, -1, -1 },
    {  8,  4,  7,  3, 11,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  4,  7, 11,  2,  4,  2,  0,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  0,  1,  8,  4,  7,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  7, 11,  9,  4, 11,  9, 11,  2,  9,  2,  1, -1, -1, -1, -1 },
    {  3, 10,  1,  3, 11, 10,  7,  8,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  1, 11, 10,  1,  4, 11,  1,  0,  4,  7, 11,  4, -1, -1, -1, -1 },
    {  4,  7,  8,  9,  0, 11,  9, 11, 10, 11,  0,  3, -1, -1, -1, -1 },
    {  4,  7, 11,  4, 11,  9,  9, 11, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  5,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  5,  4,  0,  8,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  5,  4,  1,  5,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  5,  4,  8,  3,  5,  3,  1,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10,  9,  5,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  0,  8,  1,  2, 10,  4,  9,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  5,  2, 10,  5,  4,  2,  4,  0,  2, -1, -1, -1, -1, -1, -1, -1 },
    {  2, 10,  5,  3,  2,  5,  3,  5,  4,  3,  4,  8, -1, -1, -1, -1 },
    {  9,  5,  4,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0, 11,  2,  0,  8, 11,  4,  9,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  5,  4,  0,  1,  5,  2,  3, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  1,  5,  2,  5,  8,  2,  8, 11,  4,  8,  5, -1, -1, -1, -1 },
    { 10,  3, 11, 10,  1,  3,  9,  5,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  9,  5,  0,  8,  1,  8, 10,  1,  8, 11, 10, -1, -1, -1, -1 },
    {  5,  4,  0,  5,  0, 11,  5, 11, 10, 11,  0,  3, -1, -1, -1, -1 },
    {  5,  4,  8,  5,  8, 10, 10,  8, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  7,  8,  5,  7,  9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  3,  0,  9,  5,  3,  5,  7,  3, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  7,  8,  0,  1,  7,  1,  5,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  5,  3,  3,  5,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  7,  8,  9,  5,  7, 10,  1,  2, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  1,  2,  9,  5,  0,  5,  3,  0,  5,  7,  3, -1, -1, -1, -1 },
    {  8,  0,  2,  8,  2,  5,  8,  5,  7, 10,  5,  2, -1, -1, -1, -1 },
    {  2, 10,  5,  2,  5,  3,  3,  5,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  7,  9,  5,  7,  8,  9,  3, 11,  2, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  5,  7,  9,  7,  2,  9,  2,  0,  2,  7, 11, -1, -1, -1, -1 },
    {  2,  3, 11,  0,  1,  8,  1,  7,  8,  1,  5,  7, -1, -1, -1, -1 },
    { 11,  2,  1, 11,  1,  7,  7,  1,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  5,  8,  8,  5,  7, 10,  1,  3, 10,  3, 11, -1, -1, -1, -1 },
    {  5,  7,  0,  5,  0,  9,  7, 11,  0,  1,  0, 10, 11, 10,  0, -1 },
    { 11, 10,  0, 11,  0,  3, 10,  5,  0,  8,  0,  7,  5,  7,  0, -1 },
    { 11, 10,  5,  7, 11,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  6,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  0,  1,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  8,  3,  1,  9,  8,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  6,  5,  2,  6,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  6,  5,  1,  2,  6,  3,  0,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  6,  5,  9,  0,  6,  0,  2,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  5,  9,  8,  5,  8,  2,  5,  2,  6,  3,  2,  8, -1, -1, -1, -1 },
    {  2,  3, 11, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  0,  8, 11,  2,  0, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  1,  9,  2,  3, 11,  5, 10,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  5, 10,  6,  1,  9,  2,  9, 11,  2,  9,  8, 11, -1, -1, -1, -1 },
    {  6,  3, 11,  6,  5,  3,  5,  1,  3, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8, 11,  0, 11,  5,  0,  5,  1,  5, 11,  6, -1, -1, -1, -1 },
    {  3, 11,  6,  0,  3,  6,  0,  6,  5,  0,  5,  9, -1, -1, -1, -1 },
    {  6,  5,  9,  6,  9, 11, 11,  9,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  5, 10,  6,  4,  7,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  3,  0,  4,  7,  3,  6,  5, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  9,  0,  5, 10,  6,  8,  4,  7, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  6,  5,  1,  9,  7,  1,  7,  3,  7,  9,  4, -1, -1, -1, -1 },
    {  6,  1,  2,  6,  5,  1,  4,  7,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2,  5,  5,  2,  6,  3,  0,  4,  3,  4,  7, -1, -1, -1, -1 },
    {  8,  4,  7,  9,  0,  5,  0,  6,  5,  0,  2,  6, -1, -1, -1, -1 },
    {  7,  3,  9,  7,  9,  4,  3,  2,  9,  5,  9,  6,  2,  6,  9, -1 },
    {  3, 11,  2,  7,  8,  4, 10,  6,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  5, 10,  6,  4,  7,  2,  4,  2,  0,  2,  7, 11, -1, -1, -1, -1 },
    {  0,  1,  9,  4,  7,  8,  2,  3, 11,  5, 10,  6, -1, -1, -1, -1 },
    {  9,  2,  1,  9, 11,  2,  9,  4, 11,  7, 11,  4,  5, 10,  6, -1 },
    {  8,  4,  7,  3, 11,  5,  3,  5,  1,  5, 11,  6, -1, -1, -1, -1 },
    {  5,  1, 11,  5, 11,  6,  1,  0, 11,  7, 11,  4,  0,  4, 11, -1 },
    {  0,  5,  9,  0,  6,  5,  0,  3,  6, 11,  6,  3,  8,  4,  7, -1 },
    {  6,  5,  9,  6,  9, 11,  4,  7,  9,  7, 11,  9, -1, -1, -1, -1 },
    { 10,  4,  9,  6,  4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4, 10,  6,  4,  9, 10,  0,  8,  3, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  0,  1, 10,  6,  0,  6,  4,  0, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  3,  1,  8,  1,  6,  8,  6,  4,  6,  1, 10, -1, -1, -1, -1 },
    {  1,  4,  9,  1,  2,  4,  2,  6,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  0,  8,  1,  2,  9,  2,  4,  9,  2,  6,  4, -1, -1, -1, -1 },
    {  0,  2,  4,  4,  2,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  3,  2,  8,  2,  4,  4,  2,  6, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  4,  9, 10,  6,  4, 11,  2,  3, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  2,  2,  8, 11,  4,  9, 10,  4, 10,  6, -1, -1, -1, -1 },
    {  3, 11,  2,  0,  1,  6,  0,  6,  4,  6,  1, 10, -1, -1, -1, -1 },
    {  6,  4,  1,  6,  1, 10,  4,  8,  1,  2,  1, 11,  8, 11,  1, -1 },
    {  9,  6,  4,  9,  3,  6,  9,  1,  3, 11,  6,  3, -1, -1, -1, -1 },
    {  8, 11,  1,  8,  1,  0, 11,  6,  1,  9,  1,  4,  6,  4,  1, -1 },
    {  3, 11,  6,  3,  6,  0,  0,  6,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  6,  4,  8, 11,  6,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  7, 10,  6,  7,  8, 10,  8,  9, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  7,  3,  0, 10,  7,  0,  9, 10,  6,  7, 10, -1, -1, -1, -1 },
    { 10,  6,  7,  1, 10,  7,  1,  7,  8,  1,  8,  0, -1, -1, -1, -1 },
    { 10,  6,  7, 10,  7,  1,  1,  7,  3, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2,  6,  1,  6,  8,  1,  8,  9,  8,  6,  7, -1, -1, -1, -1 },
    {  2,  6,  9,  2,  9,  1,  6,  7,  9,  0,  9,  3,  7,  3,  9, -1 },
    {  7,  8,  0,  7,  0,  6,  6,  0,  2, -1, -1, -1, -1, -1, -1, -1 },
    {  7,  3,  2,  6,  7,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  3, 11, 10,  6,  8, 10,  8,  9,  8,  6,  7, -1, -1, -1, -1 },
    {  2,  0,  7,  2,  7, 11,  0,  9,  7,  6,  7, 10,  9, 10,  7, -1 },
    {  1,  8,  0,  1,  7,  8,  1, 10,  7,  6,  7, 10,  2,  3, 11, -1 },
    { 11,  2,  1, 11,  1,  7, 10,  6,  1,  6,  7,  1, -1, -1, -1, -1 },
    {  8,  9,  6,  8,  6,  7,  9,  1,  6, 11,  6,  3,  1,  3,  6, -1 },
    {  0,  9,  1, 11,  6,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  7,  8,  0,  7,  0,  6,  3, 11,  0, 11,  6,  0, -1, -1, -1, -1 },
    {  7, 11,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  7,  6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  0,  8, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  1,  9, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  1,  9,  8,  3,  1, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  1,  2,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10,  3,  0,  8,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  9,  0,  2, 10,  9,  6, 11,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  6, 11,  7,  2, 10,  3, 10,  8,  3, 10,  9,  8, -1, -1, -1, -1 },
    {  7,  2,  3,  6,  2,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  7,  0,  8,  7,  6,  0,  6,  2,  0, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  7,  6,  2,  3,  7,  0,  1,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  6,  2,  1,  8,  6,  1,  9,  8,  8,  7,  6, -1, -1, -1, -1 },
    { 10,  7,  6, 10,  1,  7,  1,  3,  7, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  7,  6,  1,  7, 10,  1,  8,  7,  1,  0,  8, -1, -1, -1, -1 },
    {  0,  3,  7,  0,  7, 10,  0, 10,  9,  6, 10,  7, -1, -1, -1, -1 },
    {  7,  6, 10,  7, 10,  8,  8, 10,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  6,  8,  4, 11,  8,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  6, 11,  3,  0,  6,  0,  4,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  6, 11,  8,  4,  6,  9,  0,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  4,  6,  9,  6,  3,  9,  3,  1, 11,  3,  6, -1, -1, -1, -1 },
    {  6,  8,  4,  6, 11,  8,  2, 10,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10,  3,  0, 11,  0,  6, 11,  0,  4,  6, -1, -1, -1, -1 },
    {  4, 11,  8,  4,  6, 11,  0,  2,  9,  2, 10,  9, -1, -1, -1, -1 },
    { 10,  9,  3, 10,  3,  2,  9,  4,  3, 11,  3,  6,  4,  6,  3, -1 },
    {  8,  2,  3,  8,  4,  2,  4,  6,  2, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  4,  2,  4,  6,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  9,  0,  2,  3,  4,  2,  4,  6,  4,  3,  8, -1, -1, -1, -1 },
    {  1,  9,  4,  1,  4,  2,  2,  4,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  1,  3,  8,  6,  1,  8,  4,  6,  6, 10,  1, -1, -1, -1, -1 },
    { 10,  1,  0, 10,  0,  6,  6,  0,  4, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  6,  3,  4,  3,  8,  6, 10,  3,  0,  3,  9, 10,  9,  3, -1 },
    { 10,  9,  4,  6, 10,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  9,  5,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3,  4,  9,  5, 11,  7,  6, -1, -1, -1, -1, -1, -1, -1 },
    {  5,  0,  1,  5,  4,  0,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  7,  6,  8,  3,  4,  3,  5,  4,  3,  1,  5, -1, -1, -1, -1 },
    {  9,  5,  4, 10,  1,  2,  7,  6, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  6, 11,  7,  1,  2, 10,  0,  8,  3,  4,  9,  5, -1, -1, -1, -1 },
    {  7,  6, 11,  5,  4, 10,  4,  2, 10,  4,  0,  2, -1, -1, -1, -1 },
    {  3,  4,  8,  3,  5,  4,  3,  2,  5, 10,  5,  2, 11,  7,  6, -1 },
    {  7,  2,  3,  7,  6,  2,  5,  4,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  5,  4,  0,  8,  6,  0,  6,  2,  6,  8,  7, -1, -1, -1, -1 },
    {  3,  6,  2,  3,  7,  6,  1,  5,  0,  5,  4,  0, -1, -1, -1, -1 },
    {  6,  2,  8,  6,  8,  7,  2,  1,  8,  4,  8,  5,  1,  5,  8, -1 },
    {  9,  5,  4, 10,  1,  6,  1,  7,  6,  1,  3,  7, -1, -1, -1, -1 },
    {  1,  6, 10,  1,  7,  6,  1,  0,  7,  8,  7,  0,  9,  5,  4, -1 },
    {  4,  0, 10,  4, 10,  5,  0,  3, 10,  6, 10,  7,  3,  7, 10, -1 },
    {  7,  6, 10,  7, 10,  8,  5,  4, 10,  4,  8, 10, -1, -1, -1, -1 },
    {  6,  9,  5,  6, 11,  9, 11,  8,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  6, 11,  0,  6,  3,  0,  5,  6,  0,  9,  5, -1, -1, -1, -1 },
    {  0, 11,  8,  0,  5, 11,  0,  1,  5,  5,  6, 11, -1, -1, -1, -1 },
    {  6, 11,  3,  6,  3,  5,  5,  3,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 10,  9,  5, 11,  9, 11,  8, 11,  5,  6, -1, -1, -1, -1 },
    {  0, 11,  3,  0,  6, 11,  0,  9,  6,  5,  6,  9,  1,  2, 10, -1 },
    { 11,  8,  5, 11,  5,  6,  8,  0,  5, 10,  5,  2,  0,  2,  5, -1 },
    {  6, 11,  3,  6,  3,  5,  2, 10,  3, 10,  5,  3, -1, -1, -1, -1 },
    {  5,  8,  9,  5,  2,  8,  5,  6,  2,  3,  8,  2, -1, -1, -1, -1 },
    {  9,  5,  6,  9,  6,  0,  0,  6,  2, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  5,  8,  1,  8,  0,  5,  6,  8,  3,  8,  2,  6,  2,  8, -1 },
    {  1,  5,  6,  2,  1,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  3,  6,  1,  6, 10,  3,  8,  6,  5,  6,  9,  8,  9,  6, -1 },
    { 10,  1,  0, 10,  0,  6,  9,  5,  0,  5,  6,  0, -1, -1, -1, -1 },
    {  0,  3,  8,  5,  6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  5,  6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  5, 10,  7,  5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  5, 10, 11,  7,  5,  8,  3,  0, -1, -1, -1, -1, -1, -1, -1 },
    {  5, 11,  7,  5, 10, 11,  1,  9,  0, -1, -1, -1, -1, -1, -1, -1 },
    { 10,  7,  5, 10, 11,  7,  9,  8,  1,  8,  3,  1, -1, -1, -1, -1 },
    { 11,  1,  2, 11,  7,  1,  7,  5,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3,  1,  2,  7,  1,  7,  5,  7,  2, 11, -1, -1, -1, -1 },
    {  9,  7,  5,  9,  2,  7,  9,  0,  2,  2, 11,  7, -1, -1, -1, -1 },
    {  7,  5,  2,  7,  2, 11,  5,  9,  2,  3,  2,  8,  9,  8,  2, -1 },
    {  2,  5, 10,  2,  3,  5,  3,  7,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  2,  0,  8,  5,  2,  8,  7,  5, 10,  2,  5, -1, -1, -1, -1 },
    {  9,  0,  1,  5, 10,  3,  5,  3,  7,  3, 10,  2, -1, -1, -1, -1 },
    {  9,  8,  2,  9,  2,  1,  8,  7,  2, 10,  2,  5,  7,  5,  2, -1 },
    {  1,  3,  5,  3,  7,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  7,  0,  7,  1,  1,  7,  5, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  0,  3,  9,  3,  5,  5,  3,  7, -1, -1, -1, -1, -1, -1, -1 },
    {  9,  8,  7,  5,  9,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  5,  8,  4,  5, 10,  8, 10, 11,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  5,  0,  4,  5, 11,  0,  5, 10, 11, 11,  3,  0, -1, -1, -1, -1 },
    {  0,  1,  9,  8,  4, 10,  8, 10, 11, 10,  4,  5, -1, -1, -1, -1 },
    { 10, 11,  4, 10,  4,  5, 11,  3,  4,  9,  4,  1,  3,  1,  4, -1 },
    {  2,  5,  1,  2,  8,  5,  2, 11,  8,  4,  5,  8, -1, -1, -1, -1 },
    {  0,  4, 11,  0, 11,  3,  4,  5, 11,  2, 11,  1,  5,  1, 11, -1 },
    {  0,  2,  5,  0,  5,  9,  2, 11,  5,  4,  5,  8, 11,  8,  5, -1 },
    {  9,  4,  5,  2, 11,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  5, 10,  3,  5,  2,  3,  4,  5,  3,  8,  4, -1, -1, -1, -1 },
    {  5, 10,  2,  5,  2,  4,  4,  2,  0, -1, -1, -1, -1, -1, -1, -1 },
    {  3, 10,  2,  3,  5, 10,  3,  8,  5,  4,  5,  8,  0,  1,  9, -1 },
    {  5, 10,  2,  5,  2,  4,  1,  9,  2,  9,  4,  2, -1, -1, -1, -1 },
    {  8,  4,  5,  8,  5,  3,  3,  5,  1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  4,  5,  1,  0,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  8,  4,  5,  8,  5,  3,  9,  0,  5,  0,  3,  5, -1, -1, -1, -1 },
    {  9,  4,  5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4, 11,  7,  4,  9, 11,  9, 10, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  8,  3,  4,  9,  7,  9, 11,  7,  9, 10, 11, -1, -1, -1, -1 },
    {  1, 10, 11,  1, 11,  4,  1,  4,  0,  7,  4, 11, -1, -1, -1, -1 },
    {  3,  1,  4,  3,  4,  8,  1, 10,  4,  7,  4, 11, 10, 11,  4, -1 },
    {  4, 11,  7,  9, 11,  4,  9,  2, 11,  9,  1,  2, -1, -1, -1, -1 },
    {  9,  7,  4,  9, 11,  7,  9,  1, 11,  2, 11,  1,  0,  8,  3, -1 },
    { 11,  7,  4, 11,  4,  2,  2,  4,  0, -1, -1, -1, -1, -1, -1, -1 },
    { 11,  7,  4, 11,  4,  2,  8,  3,  4,  3,  2,  4, -1, -1, -1, -1 },
    {  2,  9, 10,  2,  7,  9,  2,  3,  7,  7,  4,  9, -1, -1, -1, -1 },
    {  9, 10,  7,  9,  7,  4, 10,  2,  7,  8,  7,  0,  2,  0,  7, -1 },
    {  3,  7, 10,  3, 10,  2,  7,  4, 10,  1, 10,  0,  4,  0, 10, -1 },
    {  1, 10,  2,  8,  7,  4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  9,  1,  4,  1,  7,  7,  1,  3, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  9,  1,  4,  1,  7,  0,  8,  1,  8,  7,  1, -1, -1, -1, -1 },
    {  4,  0,  3,  7,  4,  3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  4,  8,  7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  9, 10,  8, 10, 11,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  0,  9,  3,  9, 11, 11,  9, 10, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  1, 10,  0, 10,  8,  8, 10, 11, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  1, 10, 11,  3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  2, 11,  1, 11,  9,  9, 11,  8, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  0,  9,  3,  9, 11,  1,  2,  9,  2, 11,  9, -1, -1, -1, -1 },
    {  0,  2, 11,  8,  0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  3,  2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  3,  8,  2,  8, 10, 10,  8,  9, -1, -1, -1, -1, -1, -1, -1 },
    {  9, 10,  2,  0,  9,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  2,  3,  8,  2,  8, 10,  0,  1,  8,  1, 10,  8, -1, -1, -1, -1 },
    {  1, 10,  2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  1,  3,  8,  9,  1,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  9,  1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    {  0,  3,  8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 },
    { -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }
};

kernel void
marchingCubeTraverse(device TSDFVoxel                      *tsdfBox               [[buffer(kBufferIndexTSDFBox)]],
                     device MarchingCubeActiveInfo         *activeInfoOutput      [[buffer(kBufferIndexMarchingCubeMarchingCubeActiveInfo)]],
                     device atomic_uint                    &totalValidVoxelCount [[buffer(kBufferIndexMarchingCubeTotalValidVoxelCount)]],
                     uint3                                 gid                    [[thread_position_in_grid]],
                     uint3                                 lid                    [[thread_position_in_threadgroup]],
                     uint3                                 lsize                  [[threads_per_threadgroup]])
{
    threadgroup uint threadgroupVertexNumberOutput[1024];
    threadgroup uint threadgroupVertexIndexOutput[1024];
    
    uint threadIndexInThreadgroup = lid.z * lsize.x * lsize.y + lid.y * lsize.x + lid.x;
    threadgroupVertexNumberOutput[threadIndexInThreadgroup] = 0;
    
    uint planeSize = TSDF_SIZE * TSDF_SIZE, lineSize = TSDF_SIZE;

    bool overflow = false;
    simd_uint3 tsdfBoxPoint = gid;
    if (gid.x >= TSDF_SIZE - 1 || gid.y >= TSDF_SIZE - 1 || gid.z >= TSDF_SIZE - 1) { overflow = true; }
    
    if (!overflow) {
        uint index = tsdfBoxPoint.z * planeSize + tsdfBoxPoint.y * lineSize + tsdfBoxPoint.x;
        // Marching Cube 八个角落的索引
        uint eightCornerIndex[8];
        eightCornerIndex[0] = index + planeSize;
        eightCornerIndex[1] = eightCornerIndex[0] + 1;
        eightCornerIndex[2] = eightCornerIndex[1] + lineSize;
        eightCornerIndex[3] = eightCornerIndex[0] + lineSize;
        eightCornerIndex[4] = eightCornerIndex[0] - planeSize;
        eightCornerIndex[5] = eightCornerIndex[1] - planeSize;
        eightCornerIndex[6] = eightCornerIndex[2] - planeSize;
        eightCornerIndex[7] = eightCornerIndex[3] - planeSize;

        // 检查八个角落的体素是否有效
        bool valid = true;
        int tableIndex = 0;
        for (uint i = 0; i < 8; ++i) {
            if (eightCornerIndex[i] >= TSDF_SIZE * TSDF_SIZE * TSDF_SIZE) { valid = false; break; } // Make sure not exceeding the bounds

            TSDFVoxel voxel = tsdfBox[eightCornerIndex[i]];
            if (voxel.weight < MARCHING_CUBE_MIN_WEIGHT) { valid = false; break; }
            if (voxel.value < MARCHING_CUBE_ISO_VALUE) {
                tableIndex |= (1 << i);
            }
        }

        // 若八个角落的体素均有效
        if (valid) {
            thread uint localVertexNumber = MarchingCubeNumberTable[tableIndex];
            
            if (localVertexNumber != 0) {
                threadgroupVertexNumberOutput[threadIndexInThreadgroup] = localVertexNumber;
                threadgroupVertexIndexOutput[threadIndexInThreadgroup] = eightCornerIndex[4];
            }
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (threadIndexInThreadgroup == 0) {
        uint threadgroupLocalValidVoxelCount = 0;
        for (uint i = 0; i < lsize.x * lsize.y * lsize.z; ++i) {
            if (threadgroupVertexNumberOutput[i] != 0) {
                threadgroupLocalValidVoxelCount += 1;
            }
        }
        
        if (threadgroupLocalValidVoxelCount > 0) {
            uint previousValue = atomic_fetch_add_explicit(&totalValidVoxelCount, threadgroupLocalValidVoxelCount, memory_order_relaxed);
            uint index = previousValue;
            for (uint i = 0; i < lsize.x * lsize.y * lsize.z; ++i) {
                if (threadgroupVertexNumberOutput[i] != 0 && index < previousValue + threadgroupLocalValidVoxelCount && index < MARCHING_CUBE_BUFFER_MAX_COUNT) {
                    activeInfoOutput[index] = MarchingCubeActiveInfo{threadgroupVertexIndexOutput[i], threadgroupVertexNumberOutput[i]};
                    index++;
                }
            }
        }
    }
}

kernel void
marchingCubeAccumulate(device MarchingCubeActiveInfo         *activeInfoOutput      [[buffer(kBufferIndexMarchingCubeMarchingCubeActiveInfo)]],
                       device atomic_uint                    &totalValidVoxelCount  [[buffer(kBufferIndexMarchingCubeTotalValidVoxelCount)]])
{
    uint count = atomic_load_explicit(&totalValidVoxelCount, memory_order_relaxed);
    if (count > 0) {
        for (uint i = 1; i < count; ++i) {
            activeInfoOutput[i].voxelNumber += activeInfoOutput[i-1].voxelNumber;
        }
    }
}

kernel void
marchingCubeExtract(device TSDFVoxel                      *tsdfBox               [[buffer(kBufferIndexTSDFBox)]],
                    constant TSDFParameterUniforms        &tsdfParameterUniforms [[buffer(kBufferIndexTSDFParameterUniforms)]],
                    device MarchingCubeActiveInfo         *activeInfoInput       [[buffer(kBufferIndexMarchingCubeMarchingCubeActiveInfo)]],
                    device simd_float3                    *globalVertexBuffer    [[buffer(kBufferIndexMarchingCubeGlobalVertex)]],
                    device simd_float3                    *globalNormalBuffer    [[buffer(kBufferIndexMarchingCubeGlobalNormal)]],
                    uint                                  gid                    [[thread_position_in_grid]])
{
    MarchingCubeActiveInfo activeVoxel = activeInfoInput[gid];
    uint voxelIndex = activeVoxel.voxelIndex;
    
    uint planeSize = TSDF_SIZE * TSDF_SIZE, lineSize = TSDF_SIZE;

    // Marching Cube 八个角落的索引
    uint eightCornerIndex[8];
    eightCornerIndex[0] = voxelIndex + planeSize;
    eightCornerIndex[1] = eightCornerIndex[0] + 1;
    eightCornerIndex[2] = eightCornerIndex[1] + lineSize;
    eightCornerIndex[3] = eightCornerIndex[0] + lineSize;
    eightCornerIndex[4] = eightCornerIndex[0] - planeSize;
    eightCornerIndex[5] = eightCornerIndex[1] - planeSize;
    eightCornerIndex[6] = eightCornerIndex[2] - planeSize;
    eightCornerIndex[7] = eightCornerIndex[3] - planeSize;

    // Marching Cube 八个角落的 Voxel
    TSDFVoxel eightCornerVoxel[8];

    int tableIndex = 0;
    for (uint i = 0; i < 8; ++i) {
        TSDFVoxel voxel = tsdfBox[eightCornerIndex[i]];
        eightCornerVoxel[i] = voxel;
        if (voxel.value < MARCHING_CUBE_ISO_VALUE) {
            tableIndex |= (1 << i);
        }
    }
    
    simd_uint3 positionOffsetInGrid = simd_uint3(voxelIndex % TSDF_SIZE,
                                                 (voxelIndex / TSDF_SIZE) % TSDF_SIZE,
                                                 voxelIndex / TSDF_SIZE / TSDF_SIZE);
    simd_float3 referenceVoxelPosition = tsdfParameterUniforms.origin + simd_float3(positionOffsetInGrid) * tsdfParameterUniforms.sizePerVoxel;

    // Marching Cube 八个角落的坐标
    simd_float3 eightCornerVoxelCoordinate[8];
    eightCornerVoxelCoordinate[0] = referenceVoxelPosition + simd_float3(0,  0, tsdfParameterUniforms.sizePerVoxel);
    eightCornerVoxelCoordinate[1] = eightCornerVoxelCoordinate[0] + simd_float3(tsdfParameterUniforms.sizePerVoxel, 0, 0);
    eightCornerVoxelCoordinate[2] = eightCornerVoxelCoordinate[1] + simd_float3(0, tsdfParameterUniforms.sizePerVoxel, 0);
    eightCornerVoxelCoordinate[3] = eightCornerVoxelCoordinate[0] + simd_float3(0, tsdfParameterUniforms.sizePerVoxel, 0);
    eightCornerVoxelCoordinate[4] = eightCornerVoxelCoordinate[0] - simd_float3(0,  0, tsdfParameterUniforms.sizePerVoxel);
    eightCornerVoxelCoordinate[5] = eightCornerVoxelCoordinate[1] - simd_float3(0,  0, tsdfParameterUniforms.sizePerVoxel);
    eightCornerVoxelCoordinate[6] = eightCornerVoxelCoordinate[2] - simd_float3(0,  0, tsdfParameterUniforms.sizePerVoxel);
    eightCornerVoxelCoordinate[7] = eightCornerVoxelCoordinate[3] - simd_float3(0,  0, tsdfParameterUniforms.sizePerVoxel);

    // 十二条边的插值系数
    float interpolationRatio[12];
    interpolationRatio[0]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[0].value) / (eightCornerVoxel[1].value - eightCornerVoxel[0].value);
    interpolationRatio[1]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[1].value) / (eightCornerVoxel[2].value - eightCornerVoxel[1].value);
    interpolationRatio[2]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[2].value) / (eightCornerVoxel[3].value - eightCornerVoxel[2].value);
    interpolationRatio[3]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[3].value) / (eightCornerVoxel[0].value - eightCornerVoxel[3].value);
    interpolationRatio[4]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[4].value) / (eightCornerVoxel[5].value - eightCornerVoxel[4].value);
    interpolationRatio[5]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[5].value) / (eightCornerVoxel[6].value - eightCornerVoxel[5].value);
    interpolationRatio[6]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[6].value) / (eightCornerVoxel[7].value - eightCornerVoxel[6].value);
    interpolationRatio[7]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[7].value) / (eightCornerVoxel[4].value - eightCornerVoxel[7].value);
    interpolationRatio[8]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[0].value) / (eightCornerVoxel[4].value - eightCornerVoxel[0].value);
    interpolationRatio[9]  = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[1].value) / (eightCornerVoxel[5].value - eightCornerVoxel[1].value);
    interpolationRatio[10] = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[2].value) / (eightCornerVoxel[6].value - eightCornerVoxel[2].value);
    interpolationRatio[11] = (MARCHING_CUBE_ISO_VALUE - eightCornerVoxel[3].value) / (eightCornerVoxel[7].value - eightCornerVoxel[3].value);

    // 十二条边上插值得到的点坐标
    simd_float3 interpolationVertex[12];
    interpolationVertex[0]  = (1 - interpolationRatio[0])  * eightCornerVoxelCoordinate[0]  + interpolationRatio[0]  * eightCornerVoxelCoordinate[1];
    interpolationVertex[1]  = (1 - interpolationRatio[1])  * eightCornerVoxelCoordinate[1]  + interpolationRatio[1]  * eightCornerVoxelCoordinate[2];
    interpolationVertex[2]  = (1 - interpolationRatio[2])  * eightCornerVoxelCoordinate[2]  + interpolationRatio[2]  * eightCornerVoxelCoordinate[3];
    interpolationVertex[3]  = (1 - interpolationRatio[3])  * eightCornerVoxelCoordinate[3]  + interpolationRatio[3]  * eightCornerVoxelCoordinate[0];
    interpolationVertex[4]  = (1 - interpolationRatio[4])  * eightCornerVoxelCoordinate[4]  + interpolationRatio[4]  * eightCornerVoxelCoordinate[5];
    interpolationVertex[5]  = (1 - interpolationRatio[5])  * eightCornerVoxelCoordinate[5]  + interpolationRatio[5]  * eightCornerVoxelCoordinate[6];
    interpolationVertex[6]  = (1 - interpolationRatio[6])  * eightCornerVoxelCoordinate[6]  + interpolationRatio[6]  * eightCornerVoxelCoordinate[7];
    interpolationVertex[7]  = (1 - interpolationRatio[7])  * eightCornerVoxelCoordinate[7]  + interpolationRatio[7]  * eightCornerVoxelCoordinate[4];
    interpolationVertex[8]  = (1 - interpolationRatio[8])  * eightCornerVoxelCoordinate[0]  + interpolationRatio[8]  * eightCornerVoxelCoordinate[4];
    interpolationVertex[9]  = (1 - interpolationRatio[9])  * eightCornerVoxelCoordinate[1]  + interpolationRatio[9]  * eightCornerVoxelCoordinate[5];
    interpolationVertex[10] = (1 - interpolationRatio[10]) * eightCornerVoxelCoordinate[2]  + interpolationRatio[10] * eightCornerVoxelCoordinate[6];
    interpolationVertex[11] = (1 - interpolationRatio[11]) * eightCornerVoxelCoordinate[3]  + interpolationRatio[11] * eightCornerVoxelCoordinate[7];

    // 查表得到边的信息，再连接这些边上的插值点，得到三角形面片
    constant int *tableLine = MarchingCubeTable[tableIndex];
    uint start = 0, end = activeVoxel.voxelNumber;
    if (gid > 0) { start = activeInfoInput[gid - 1].voxelNumber; }
    for (uint i = start; i < end; ++i) {
        uint offset = i - start;
        globalVertexBuffer[i] = interpolationVertex[tableLine[offset]];
        
        if (offset % 3 == 2) {
            simd_float3 edgeOne = interpolationVertex[tableLine[offset - 1]] - interpolationVertex[tableLine[offset - 2]];
            simd_float3 edgeTwo = interpolationVertex[tableLine[offset]] - interpolationVertex[tableLine[offset - 2]];
            simd_float3 normal = normalize(cross(edgeOne, edgeTwo));
            globalNormalBuffer[i] = globalNormalBuffer[i - 1] = globalNormalBuffer[i - 2] = normal;
        }
    }
}
