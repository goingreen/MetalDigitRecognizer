//
//  AdaptiveThreshold.metal
//  DigitRecognizer
//
//  Created by Артур Антонов on 07.05.17.
//  Copyright © 2017 Artur Antonov. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


kernel void adaptive_threshold (texture2d<float, access::sample> inTexture [[texture(0)]],
                                texture2d<float, access::write> outTexture [[texture(1)]],
                                texture2d<float, access::read> weights [[texture(2)]],
                                constant float &C [[buffer(0)]],
                                uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height())
        return;
    int size = weights.get_width();
    int radius = size / 2;
    
    constexpr sampler s(coord::pixel, address::clamp_to_edge);
    
    float4 accumColor(0, 0, 0, 0);
    for (int j = 0; j < size; ++j)
    {
        for (int i = 0; i < size; ++i)
        {
            uint2 kernelIndex(i, j);
            float2 textureIndex(gid.x + (i - radius), gid.y + (j - radius));
            float4 color = inTexture.sample(s, textureIndex).bgra;
            float4 weight = weights.read(kernelIndex).rrrr;
            accumColor += weight * color;
        }
    }
    float3 lum(0.312, 0.608, 0.08);
    
    float threshold = dot(accumColor.bgr, lum) - C;
    float grayColor = dot(inTexture.read(gid).bgr, lum);
    
    if (grayColor > 0.1 && grayColor > threshold)
        outTexture.write(float4(float3(0), 1), gid);
    else
        outTexture.write(float4(1), gid);
}
