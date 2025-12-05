#include "ReShade.fxh"

uniform float threshholdSharpness < ui_type = "slider";ui_min = 0.0; ui_max = 5.0; > = 1.0;
uniform float threshhold < ui_type = "slider";ui_min = 0.0; ui_max = 1.0; > = 0.6;
uniform float brightness < ui_type = "slider";ui_min = 0.0; ui_max = 5.0; > = 0.8;
uniform int kernalRadius < ui_type = "slider";ui_min = 1; ui_max = 6; > = 3;

float LogisticSigmoid(float x, float a, float b)
{
    return 1 / (1 + exp((-x + b) * exp(a)));
}

float2 FlipY(float2 uv)
{
    return float2(uv.x, 1 - uv.y);
}

float4 PS_BlurPixels(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float4 sum = 0.0;
    
    for (int y = -kernalRadius; y <= kernalRadius; y++)
    {
        for (int x = -kernalRadius; x <= kernalRadius; x++)
        {
            float2 offsetUV = uv + float2(x, y) * ReShade::PixelSize;
            float4 offsetPixel = tex2D(ReShade::BackBuffer, offsetUV);
            
            sum += offsetPixel * LogisticSigmoid(
            (0.2126 * offsetPixel.r + 0.7152 * offsetPixel.g + 0.0722 * offsetPixel.b), threshholdSharpness, threshhold);
        }
    }
    
    return sum * brightness / pow(kernalRadius * 2 + 1 ,2) + tex2D(ReShade::BackBuffer, uv);
}

technique Orix_Bloom
{
    pass BlurPixels
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BlurPixels;
    }
}