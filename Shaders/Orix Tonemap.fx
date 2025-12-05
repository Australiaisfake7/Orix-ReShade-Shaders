#include "ReShade.fxh"
#include "Orix.fxh"

uniform float exposure < ui_type = "slider";ui_min = -2.0; ui_max = 1.0;ui_category = "Luminosity";> = 0.0;
uniform float contrast < ui_type = "slider";ui_min = 0.75; ui_max = 1.5;ui_category = "Luminosity";> = 1.0;

uniform float temperature <ui_type = "slider";ui_min = -1.0;ui_max = 1.0;ui_category = "White Balance";> = 0.0;
uniform float tint <ui_type = "slider";ui_min = -1.0;ui_max = 1.0;ui_category = "White Balance";> = 0.0;

uniform float lift < ui_type = "slider";ui_min = -0.2;ui_max = 0.3;ui_category = "LGG"; > = 0.0;
uniform float gamma < ui_type = "slider";ui_min = 0.5;ui_max = 1.5;ui_category = "LGG"; > = 1.0;
uniform float gain < ui_type = "slider";ui_min = 0.5;ui_max = 1.5;ui_category = "LGG"; > = 1.0;

uniform float3 shadowColor <ui_type = "slider";ui_min = 0.0; ui_max = 1.0;ui_category = "Split Toning";>;
uniform float3 highlightColor <ui_type = "slider";ui_min = 0.0; ui_max = 1.0;ui_category = "Split Toning";>;
uniform float splitToneShadowStrength < ui_type = "slider";ui_min = 0.0;ui_max = 1.0;ui_category = "Split Toning"; > = 0.0;
uniform float splitToneHighlightStrength < ui_type = "slider";ui_min = 0.0;ui_max = 1.0;ui_category = "Split Toning"; > = 0.0;

uniform float vibrance <ui_type = "slider";ui_min = 0.0; ui_max = 1.0;ui_category = "Chroma";> = 0.0;
uniform float saturation <ui_type = "slider";ui_min = 0.0; ui_max = 2.0;ui_category = "Chroma";> = 1.0;

uniform float FrameTime < source = "frametime"; >;

texture2D autoExposureLevelTexture
{
    Width = 1;
    Height = 1;
    Format = R16F;
};

sampler2D autoExposureLevel
{
    Texture = autoExposureLevelTexture;
};

float3 WhiteBalance(float3 color, float temp, float tint)
{
    float t = temp * 0.1;
    float ti = tint * 0.1;

    float3 balance;
    balance.r = 1.0 + t - ti;
    balance.g = 1.0 + ti;
    balance.b = 1.0 - t - ti;

    return color * balance;
}

float3 FilmicContrast(float3 color, float contrast)
{
    const float midpoint = 0.18;
    return pow(color / midpoint, contrast) * midpoint;
}

float3 SplitTone(float3 color, float3 shadowColor, float3 highlightColor, float shadowStrength, float highlightStrength)
{
    float l = Luminance(color);

    float shadowMask = smoothstep(0.25, 0.0, l);
    float highlightMask = smoothstep(0.85, 1.0, l);

    float3 shadow = lerp(color, color * shadowColor, shadowMask * shadowStrength);
    float3 highlight = lerp(color, color * highlightColor, highlightMask * highlightStrength);
    
return color + (shadow - color) + (highlight - color);
}

float3 Saturate(float3 color, float saturation)
{
    float l = Luminance(color);
    return lerp(l, color, saturation);
}

float3 ApplyVibrance(float3 color, float vibrance)
{
    float l = Luminance(color);
    float sat = length(color - l);
    float strength = (1.0 - sat) * vibrance;
    
    return color + (color - l) * strength;
}

float4 PS_Tonemap(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 pixelColor = tex2D(ReShade::BackBuffer, uv).rgb;
    
    // Gamma To Linear
    pixelColor = pow(pixelColor, 2.2);
    
    // Add Exposure
    pixelColor *= exp2(exposure);

    // White Balance Color
    pixelColor = WhiteBalance(pixelColor, temperature, tint);
        
    // Apply LGG
    pixelColor = saturate(pixelColor + lift);
    
    pixelColor = pow(pixelColor, 1.0 / gamma);
    
    pixelColor *= gain;
    
    // Add Contrast
    pixelColor = FilmicContrast(pixelColor, contrast);
    
    // Color Correct Shadows And Highlights
    pixelColor = SplitTone(pixelColor, shadowColor, highlightColor, splitToneShadowStrength, splitToneHighlightStrength);
    
    // Apply Vibrance
    pixelColor = ApplyVibrance(pixelColor, vibrance);
    
    // Saturate
    pixelColor = Saturate(pixelColor, saturation);
    
    // Tonemap To sRGB
    pixelColor = ACES(pixelColor);

    // Linear To Gamma
    pixelColor = pow(pixelColor, 1.0 / 2.2);
        
    return float4(pixelColor, 1.0);
}

technique Orix_Tonemap
{
    pass Tonemap
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Tonemap;
    }
}