#include "ReShade.fxh"
#include "Orix.fxh"

uniform float threshold <ui_type = "slider";ui_min = 0.0; ui_max = 1.0;> = 0.2;
uniform int mode <ui_type = "radio";ui_items = "Sobel\0Laplacian\0Sobel And Laplacian\0Canny\0";> = 0;
uniform bool useDepth <ui_type = "input";> = false;

static int laplacian[] = { 1, 1, 1, 1, -8, 1, 1, 1, 1 };

texture2D tempBlurredBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D tempBlurredBuffer
{
    Texture = tempBlurredBufferTexture;
};

texture2D blurredBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};

sampler2D blurredBuffer
{
    Texture = blurredBufferTexture;
};

texture2D gradientBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D gradientBuffer
{
    Texture = gradientBufferTexture;
};

texture2D thinnedGradientBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};

sampler2D thinnedGradientBuffer
{
    Texture = thinnedGradientBufferTexture;
};

texture2D outlineBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R16F;
};

sampler2D outlineBuffer
{
    Texture = outlineBufferTexture;
};

texture2D thinnedOutlineBufferTexture
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R16F;
};

sampler2D thinnedOutlineBuffer
{
    Texture = thinnedOutlineBufferTexture;
};

float4 PS_GaussianBlurVertical(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 1 || mode == 2 || mode == 3)
    {
        float3 sum = 0.0;
        float weightSum = 0.0;
    
        for (int y = -3; y <= 3; y++)
        {
            float3 color = tex2D(ReShade::BackBuffer, uv + float2(0, y) * ReShade::PixelSize).rgb;
            float weight = exp(-y * 0.5);
            sum += color * weight;
            weightSum += weight;
        }
    
        return float4(sum / weightSum, 1.0);
    }
    return tex2D(ReShade::BackBuffer, uv);
}

float4 PS_GaussianBlurHorizontal(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 1 || mode == 2 || mode == 3)
    {
        float3 sum = 0.0;
        float weightSum = 0.0;
    
        for (int x = -3; x <= 3; x++)
        {
            float3 color = tex2D(ReShade::BackBuffer, uv + float2(x, 0) * ReShade::PixelSize).rgb;
            float weight = exp(-x * 0.5);
            sum += color * weight;
            weightSum += weight;
        }
    
        return float4(sum / weightSum, 1.0);
    }
    return tex2D(ReShade::BackBuffer, uv);
}

float4 PS_GetGradients(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 3)
    {
        float x = Luminance(Convolve(uv, sobelX, blurredBuffer));
        float y = Luminance(Convolve(uv, sobelY, blurredBuffer));
        return float4(x, y, length(float2(x, y)), 1.0);
    }
    return float4(0.0, 0.0, 0.0,0.0);
}

float4 PS_NonMaximumSuppression(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 3)
    {
        float3 gradient = tex2D(gradientBuffer, uv).rgb;
        float angle = atan2(gradient.y, gradient.x) / 0.78539816339;
        
        float2 minOffset = float2(cos(floor(angle) * 0.78539816339), sin(floor(angle) * 0.78539816339));
        float2 maxOffset = float2(cos(ceil(angle) * 0.78539816339), sin(ceil(angle) * 0.78539816339));

        float r = angle - floor(angle);
        
        float forward = lerp(tex2D(gradientBuffer, uv + minOffset * ReShade::PixelSize).b, tex2D(gradientBuffer, uv + maxOffset * ReShade::PixelSize).b, r);
        float backward = lerp(tex2D(gradientBuffer, uv - minOffset * ReShade::PixelSize).b, tex2D(gradientBuffer, uv - maxOffset * ReShade::PixelSize).b, r);

        if (gradient.z > forward && gradient.z > backward)
            return float4(gradient, gradient.z);
        return float4(gradient, 0.0);
                
    }   
    return float4(0.0, 0.0, 0.0, 0.0);
}

float PS_DoubleThreshold(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 3)
    {
        float m = tex2D(thinnedGradientBuffer, uv).a;
    
        if (m < threshold)
            return 0.0;
        else if (m < 2.0 * threshold)
            return 1.0;
        else
            return 2.0;
    }
    return 0.0;
}

float PS_EdgeConnect(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    if (mode == 3)
    {
        float m = tex2D(outlineBuffer, uv).r;
        if (m == 2.0)
            return 1.0;
        else if (m == 0.0)
            return 0.0;
        else
        {
            float sum = 0.0;
            for (int y = -8; y <= 8; y++)
            {
                for (int x = -8; x <= 8; x++)
                {
                    int ix = clamp(x + 8, 0, 16);
                    int iy = clamp(y + 8, 0, 16);

                    sum += tex2D(outlineBuffer, uv + float2(ix, iy) * ReShade::PixelSize).r;
                }
            }
            if (sum >= 3.0)
                return 1.0;
            else
                return 0.0;
        }
    }
    return 0.0;
}


float4 PS_OverlayEdges(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_TARGET
{
    float sobel = 0.0;
    float lap = 0.0;
    float depth = 0.0;
    float canny = 0.0;
    
    if (mode == 0 || mode == 2)
    {
        float x = Luminance(Convolve(uv, sobelX, ReShade::BackBuffer));
        float y = Luminance(Convolve(uv, sobelY, ReShade::BackBuffer));
        sobel = sqrt(dot(float2(x, y), float2(x, y)));
    }
    if (mode == 1 || mode == 2)
    {
        lap = Luminance(Convolve(uv, laplacian, blurredBuffer));
    }
    if (mode == 3)
    {
        canny = tex2D(thinnedOutlineBuffer, uv).r;
    }
    if (useDepth)
    {
        float x = ConvolveDepth(uv, sobelX);
        float y = ConvolveDepth(uv, sobelY);
        
        depth = dot(float2(x, y), float2(x, y));
    }
    
    float v = sobel * 0.6 + lap * 1.2 + depth * 0.5 + canny;
    return v > threshold ? float4(0.0, 0.0, 0.0, 1.0) : tex2D(ReShade::BackBuffer, uv);
}

technique Orix_Edge_Detection
{
    pass BlurVertical
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GaussianBlurVertical;
        RenderTarget = tempBlurredBufferTexture;
    }
    pass BlurHorizontal
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GaussianBlurHorizontal;
        RenderTarget = blurredBufferTexture;
    }
    pass GetGradients
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_GetGradients;
        RenderTarget = gradientBufferTexture;
    }
    pass NonMaximumSuppression
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_NonMaximumSuppression;
        RenderTarget = thinnedGradientBufferTexture;
    }
    pass DoubleThreshold
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_DoubleThreshold;
        RenderTarget = outlineBufferTexture;
    }
    pass EdgeConnect
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_EdgeConnect;
        RenderTarget = thinnedOutlineBufferTexture;
    }
    pass OverlayEdges
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_OverlayEdges;
    }
}
    