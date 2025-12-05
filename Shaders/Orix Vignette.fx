#include "ReShade.fxh"

uniform float innerRadius < ui_type = "slider";ui_min = 0.0; ui_max = 5.0; > = 0.0;
uniform float outerRadius < ui_type = "slider";ui_min = 0.0; ui_max = 5.0; > = 1.0;

float4 PS_Vignette(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 p = (uv - float2(0.5,0.5)) * 2;
    p.x *= ReShade::AspectRatio;
    float distance = sqrt(p.x * p.x + p.y * p.y);
    return tex2D(ReShade::BackBuffer, uv) * (1 - smoothstep(innerRadius, outerRadius, distance));
}

technique Orix_Vignette
{
    pass VignetteEffect
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Vignette;
    }
}