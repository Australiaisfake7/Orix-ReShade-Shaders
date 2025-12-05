#include "ReShade.fxh"

uniform float strength <ui_type = "slider";ui_min = 0.0;ui_max = 0.1;> = 0.0;

float4 PS_ChromaticAbboration(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 cUV = uv - 0.5;
    float distance = sqrt(cUV.x * cUV.x + cUV.y * cUV.y);
    float3 color;
    
    color.r = tex2D(ReShade::BackBuffer, uv + distance * strength).r;
    color.g = tex2D(ReShade::BackBuffer, uv).g;
    color.b = tex2D(ReShade::BackBuffer, uv - distance * strength).b;
    
    return float4(color, 1.0);
}

technique Orix_Chromatic_Abboration
{
    pass ChromaticAbboration
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_ChromaticAbboration;
    }
}