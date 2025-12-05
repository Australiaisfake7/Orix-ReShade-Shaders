#include "ReShade.fxh"

uniform int kernalRadius <ui_type = "slider";ui_min = 1; ui_max = 6;> = 2;
uniform float sigmaS <ui_type = "slider";ui_min = 0.1; ui_max = 10.0; ui_label = "Distance Weight";> = 0.5;
uniform float sigmaR <ui_type = "slider";ui_min = 0.001; ui_max = 1.0; ui_label = "Range Threshold";> = 0.3;

float4 PS_BilateralBlur(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 sum = 0.0;
    float weightSum = 0.0;
    float3 pixelColor = tex2D(ReShade::BackBuffer, uv).rgb;
    
    for (int y = -kernalRadius; y <= kernalRadius; y++)
    {
        for (int x = -kernalRadius; x <= kernalRadius; x++)
        {
            float2 cUV = float2(x, y);
            float2 offsetUV = uv + cUV * ReShade::PixelSize;
            
            float3 offsetColor = tex2D(ReShade::BackBuffer, offsetUV).rgb;
            
            float distanceSquared = dot(cUV,cUV);
            
            float distanceWeight = exp(-distanceSquared / (2.0 * sigmaS * sigmaS));
            
            float colorDifference = length(pixelColor - offsetColor);
            
            float rangeWeight = exp(-colorDifference * colorDifference / (2.0 * sigmaR * sigmaR));
            
            sum += offsetColor * distanceWeight * rangeWeight;
            
            weightSum += distanceWeight * rangeWeight;

        }
    }
    
    return float4(sum / max(weightSum, 1e-9), 1.0);
}

technique Orix_Blur
{
    pass Blur
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_BilateralBlur;
    }
}