#include "ReShade.fxh"
#include "Orix.fxh"

uniform float strength < ui_type = "slider";ui_min = 0.0; ui_max = 2.0;> = 0.5;
uniform int mode <ui_type = "radio";ui_items = "Luminance\0Contrast Adaptive\0";>;
uniform bool showOverlay <ui_type = "input";> = false;

float4 PS_SharpenPixels(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (mode == 0)
    {
        float sum = 0.0;
        float3 pixelColor = tex2D(ReShade::BackBuffer, uv).rgb;
        float pixelBrightness = Luminance(pixelColor);
        for (int y = -1; y <= 1; y++)
        {
            for (int x = -1; x <= 1; x++)
            {
                float2 offsetUV = uv + float2(x, y) * ReShade::PixelSize;
                float3 color = tex2D(ReShade::BackBuffer, offsetUV).rgb;
                sum += Luminance(color);
            }
        }
    
        float detail = pixelBrightness - sum / 9;
    
        if (showOverlay)
            return float4(float3(detail * strength, detail * strength, detail * strength), 1.0);
        else
            return float4(pixelColor + detail * strength, 1.0);
    }
    else
    {
        float3 up = tex2D(ReShade::BackBuffer, uv + float2(0, 1) * ReShade::PixelSize).rgb;
        float3 left = tex2D(ReShade::BackBuffer, uv + float2(-1, 0) * ReShade::PixelSize).rgb;
        float3 center = tex2D(ReShade::BackBuffer, uv).rgb;
        float3 right = tex2D(ReShade::BackBuffer, uv + float2(1, 0) * ReShade::PixelSize).rgb;
        float3 down = tex2D(ReShade::BackBuffer, uv + float2(0, -1) * ReShade::PixelSize).rgb;
        
        float3 minColor = min(min(up, left), min(right, down));
        float3 maxColor = max(max(up, left), max(right, down));

        float s = saturate(1.0 - (Luminance(maxColor) - Luminance(minColor)));
        s *= strength;
        
        return float4(clamp((up + left + right + down) * -s + center * (1.0 + 4.0 * s), minColor, maxColor), 1.0);
    }
}

technique Orix_Sharpen
{
    pass Sharpen
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SharpenPixels;
    }
}