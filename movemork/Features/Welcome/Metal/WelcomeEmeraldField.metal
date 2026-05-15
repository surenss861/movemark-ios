#include <metal_stdlib>
using namespace metal;

struct EmeraldVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex EmeraldVertexOut emerald_vertex(uint vid [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1, -1), float2( 1, -1), float2(-1,  1),
        float2( 1, -1), float2( 1,  1), float2(-1,  1)
    };
    const float2 uvs[6] = {
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(1, 1), float2(1, 0), float2(0, 0)
    };

    EmeraldVertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.uv = uvs[vid];
    return out;
}

fragment float4 emerald_fragment(
    EmeraldVertexOut in [[stage_in]],
    constant float &time [[buffer(0)]],
    constant float &intensity [[buffer(1)]]
) {
    float2 uv = in.uv;

    float3 base = float3(0.024, 0.071, 0.051);
    float3 glow = float3(0.086, 0.639, 0.290);

    float2 center = float2(0.5, 0.32);
    float radial = smoothstep(0.95, 0.15, distance(uv, center));

    float grain = fract(sin(dot(uv * 180.0 + time * 0.04, float2(12.9898, 78.233))) * 43758.5453);
    grain = (grain - 0.5) * 0.035;

    float drift = sin(uv.x * 2.8 + time * 0.12) * 0.012 + sin(uv.y * 2.2 - time * 0.09) * 0.01;

    float bottomBloom = smoothstep(1.0, 0.55, uv.y) * 0.08;

    float3 color = base;
    color += glow * radial * 0.14 * intensity;
    color += glow * bottomBloom * intensity;
    color += grain * intensity;
    color += drift * intensity;

    float vignette = smoothstep(1.15, 0.4, distance(uv, float2(0.5, 0.48)));
    color *= vignette;

    return float4(color, 1.0);
}
