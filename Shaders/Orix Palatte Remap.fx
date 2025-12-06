#include "ReShade.fxh"
#include "Orix.fxh"

uniform uint numColors <ui_type = "slider"; ui_min = 1;ui_max = 256;> = 16;
uniform float ditherStrength <ui_type = "slider";ui_min = 0.0f;ui_max = 20.0f;> = 1.0f;
uniform float2 baseLightnessBounds <ui_type = "slider";ui_min = 0.0f;ui_max = 1.0f;> = float2(0.0f, 0.1f);
uniform float2 lightnessIncrementBounds <ui_type = "slider";ui_min = 0.0f;ui_max = 1.0f;> = float2(0.0f, 0.1f);
uniform float2 baseChromaBounds <ui_type = "slider";ui_min = 0.0f;ui_max = 1.0f;> = float2(0.0f, 0.1f);
uniform float2 chromaIncrementBounds <ui_type = "slider";ui_min = 0.0f;ui_max = 1.0f;> = float2(0.0f, 0.1f);
uniform float2 hueIncrementBounds <ui_type = "slider";ui_min = 0.0f;ui_max = 6.28f;> = float2(0.0f, 0.1f);
uniform uint seed <ui_type = "slider";ui_min = 0; ui_max = 1e9;>;

texture2D palatteTexture
{
    Width = 256;
    Height = 1;
    Format = RGBA16F;
};

sampler2D palette
{
    Texture = palatteTexture;
    MagFilter = POINT;
    MinFilter = POINT;
};


float hash(uint n)
{
    // integer hash copied from Hugo Elias
    n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
    return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
}

float4 PS_WriteColors(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float ls = lerp(baseLightnessBounds.x, baseLightnessBounds.y, hash(seed + 38));
    float li = lerp(lightnessIncrementBounds.x, lightnessIncrementBounds.y, hash(seed + 57));
    float cs = lerp(baseChromaBounds.x, baseChromaBounds.y, hash(seed + 7));
    float ci = lerp(chromaIncrementBounds.x, chromaIncrementBounds.y, hash(seed + 30));
    float hs = hash(seed + 96) * 2.0f * pi;
    float hi = lerp(hueIncrementBounds.x, hueIncrementBounds.y, hash(seed + 32));
    
    return float4(ls + li * uv.x, cs + ci * uv.x, hs + hi * uv.x, 1.0f);
}

float4 PS_Remap(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 c = tex2D(ReShade::BackBuffer, uv).rgb;
    int2 p = uv / ReShade::PixelSize;
    p %= 8;
    
    float l = Luminance(c) + bayer8x8[p.x + p.y * 8] / 64.0f / 256.0f * ditherStrength;
    l = floor(l * (numColors - 1) + 0.5f) / (numColors - 1);

    c = saturate(OklabToSRGB(OkLChToOklab(tex2D(palette, float2(l, 0.5f)).rgb)));
    return float4(c, 1.0f);
}

technique Orix_Palatte_Remap
{
    pass WriteColors
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_WriteColors;
        RenderTarget = palatteTexture;
    }
    pass Remap
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Remap;
    }
}