#include "ReShade.fxh"
#include "Orix.fxh"

#ifndef PATH_TO_NORMAL_MAP
#define PATH_TO_NORMAL_MAP "blank-paint-canvas_normal-ogl.png"
#endif
uniform float lightAngle <ui_type = "slider";ui_min = 0.0f;ui_max = pi / 2;> = 0.0f;
uniform float bumpStrength <ui_type = "slider";ui_min = 0.0f;ui_max = 10.0f;> = 1.0f;
uniform float ambient <ui_type = "slider";ui_min = 0.0f;ui_max = 0.3f;> = 0.15f;
uniform float lightExposure <ui_type = "slider";ui_min = 0.0f; ui_max = 4.0f;> = 1.0f;

texture2D canvasNormalTexture <source = PATH_TO_NORMAL_MAP;>
{
    Height = 2048;
    Width = 2048;
};
sampler2D canvasNormal
{
    Texture = canvasNormalTexture;
};

float4 PS_OverlayCanvas(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
    float3 direction = normalize(float3(0.0f, sin(lightAngle), cos(lightAngle)));

    float3 normal = tex2D(canvasNormal, uv).xyz * 2.0f - 1.0f;
    normal = normalize(normal * float3(bumpStrength, bumpStrength, 1.0f));
	
    float light = ambient + lightExposure * saturate(dot(direction, normal));

    float3 color = tex2D(ReShade::BackBuffer, uv).rgb * saturate(light);

    return float4(color, 1.0f);
}

technique Orix_Overlay_Canvas
{
    pass OverlayCanvas
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_OverlayCanvas;
    }
}