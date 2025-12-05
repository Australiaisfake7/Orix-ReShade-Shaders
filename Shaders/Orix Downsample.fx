#include "ReShade.fxh"

int halfIterations <ui_type = "slider";ui_min = 0; ui_max = 6;> = 2;

float4 PS_Downsample(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float2 snappedUV = (floor(uv / pow(2, halfIterations) / ReShade::PixelSize) + 0.5) * pow(2, halfIterations) * ReShade::PixelSize;
    return tex2D(ReShade::BackBuffer, snappedUV);
}

technique Orix_Downsample
{
    pass Downsample
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Downsample;
    }
}