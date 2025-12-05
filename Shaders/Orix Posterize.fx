#include "ReShade.fxh"

uniform int channelColors <ui_type = "slider";ui_min = 1;ui_max = 256;> = 256;
uniform float ditherStrength <ui_type = "slider";ui_min = 0.0;ui_max = 10.0;> = 1.0;

static int bayerMatrix[64] =
{
 0, 32,  8, 40,  2, 34, 10, 42,
 48, 16, 56, 24, 50, 18, 58, 26,
 12, 44,  4, 36, 14, 46,  6, 38,
 60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43,  1, 33,  9, 41,
 51, 19, 59, 27, 49, 17, 57, 25,
 15, 47,  7, 39, 13, 45,  5, 37,
 63, 31, 55, 23, 61, 29, 53, 21
};

float4 PS_Posterize(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    int2 matrixCoordinates = floor(uv / ReShade::PixelSize) % 8;
    
    float ditherValue = bayerMatrix[matrixCoordinates.x + matrixCoordinates.y * 8] / 64.0 / 255.0 * ditherStrength;
    
    return floor((tex2D(ReShade::BackBuffer, uv) + ditherValue) * channelColors) / channelColors;
}

technique Orix_Posterize
{
    pass Posterize
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Posterize;
    }
}