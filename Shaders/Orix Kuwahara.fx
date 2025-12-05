#include "ReShade.fxh"
#include "Orix.fxh"

uniform int mode <ui_type = "radio";ui_items = "Simple\0Simple Gaussian\0Generalized\0Anisotropic\0";> = 0;
uniform int radius <ui_type = "slider";ui_min = 1; ui_max = 9;> = 5;
uniform float sigma <ui_type = "slider";ui_min = 0.1f;ui_max = 5.0f;ui_label = "Strength (Gaussian / Generalized / Anisotropic)";> = 1.5f;
uniform float sectorOverlap <ui_type = "slider";ui_min = 0.45f; ui_max = 3.0f;ui_label = "Sector Overlap (Generalized / Anisotropic)";> = 1.0f;
uniform float alpha <ui_type = "slider";ui_min = 0.1f; ui_max = 2.0f; ui_label = "Stretch Strength (Anisotropic)";> = 1.0f;

float4 SimpleKuwahara(float2 uv, bool gaussian)
{
    float3 sums[4];
    float deviations[4];
    float ws[4];
    
    for (int i = 0; i < 4; i++)
    {
        sums[i] = 0.0f;
        deviations[i] = 0.0f;
        ws[i] = 0.0f;
    }
    {
        for (int y = -radius; y <= radius; y++)
        {
            for (int x = -radius; x <= radius; x++)
            {
                float2 p = float2(x, y);
                float3 c = tex2D(ReShade::BackBuffer, uv + p * ReShade::PixelSize).rgb;
                bool4 s;
                bool up = y >= 0;
                bool down = y <= 0;
                bool left = x <= 0;
                bool right = x >= 0;
            
                float w = 1.0f;
                
                if (gaussian)
                    w = exp(-dot(p, p) / (2.0f * sigma * sigma));
                if (up)
                {
                    sums[0] += c * w;
                    ws[0] += w;
                }
                if (down)
                {
                    sums[1] += c * w;
                    ws[1] += w;
                }
                if (left)
                {
                    sums[2] += c * w;
                    ws[2] += w;
                }
                if (right)
                {
                    sums[3] += c * w;
                    ws[3] += w;
                }
            }
        }
    }
    
    for (int j = 0; j < 4; j++)
    {
        sums[j] /= ws[j];
    }
    
    {
        for (int y = -radius; y <= radius; y++)
        {
            for (int x = -radius; x <= radius; x++)
            {
                float3 c = tex2D(ReShade::BackBuffer, uv + float2(x, y) * ReShade::PixelSize).rgb;
                bool up = y >= 0;
                bool down = y <= 0;
                bool left = x <= 0;
                bool right = x >= 0;
            
                float w = 1.0f;
                
                if (up)
                {
                    deviations[0] += Luminance(pow(c - sums[0], 2));
                }
                if (down)
                {
                    deviations[1] += Luminance(pow(c - sums[1], 2));
                }
                if (left)
                {
                    deviations[2] += Luminance(pow(c - sums[2], 2));
                }
                if (right)
                {
                    deviations[3] += Luminance(pow(c - sums[3], 2));
                }
            }
        }
    }
    float ld = 1e38;
    float3 c;
    for (int k = 0; k < 4; k++)
    {
        if (deviations[k] < ld)
        {
            c = sums[k];
            ld = deviations[k];
        }
    }
    return float4(c, 1.0f);
}

float4 GeneralizedKuwahara(float2 uv, bool anisotropic)
{  
    float phi = 0.0f;
    float cosPhi = 1.0f;
    float sinPhi = 0.0f;
    float a = radius * 1.5f;
    float b = radius * 0.8f;
    
    if (anisotropic)
    {
        float sX = max(Luminance(Convolve(uv, sobelX, ReShade::BackBuffer)), epsilon);
        float sY = max(Luminance(Convolve(uv, sobelY, ReShade::BackBuffer)), epsilon);
        
        float l1 = 0.0f;
        float l2 = 0.0f;
        float2 v1 = 0.0f;
        float2 v2 = 0.0f;
        
        if (length(float2(sX, sY)) > epsilon)
        {
            float a = sX * sX;
            float b = sX * sY;
            float c = sY * sY;
            float trace = a + c;
            float determinant = sqrt((a - c) * (a - c) + 4 * b * b);
            l1 = (trace + determinant) / 2.0f;
            l2 = (trace - determinant) / 2.0f;
            
            // Get Eigenvectors as a ratio of b to l - a
            v1 = float2(b, (l1 - a));
            v2 = float2(b, (l2 - a));
            
            if (length(v1) > 0.0f) 
                v1 = normalize(v1);
            if (length(v2) > 0.0f) 
                v2 = normalize(v2);
        }
        else
        {
            v1 = float2(1.0f, 0.0f);
            v2 = float2(0.0f, 1.0f);
        }
        
        float A = (l1 - l2) / (l1 + l2);
        
        a = (alpha + A) / alpha * radius;
        b = alpha / (alpha + A) * radius;
        
        phi = atan2(v1.y, v1.x);
        cosPhi = cos(phi);
        sinPhi = sin(phi);
    }
    
    float2x2 scale = float2x2(1.0f / a, 0.0f, 0.0f, 1.0f / b);
    float2x2 rotate = float2x2(cosPhi, -sinPhi, sinPhi, cosPhi);
    float2x2 transform = mul(scale, rotate);
    
    float4 m[8];
    float3 s[8];
    
    {
        for (int i = 0; i < 8; i++)
        {
            m[i] = 0.0f;
            s[i] = 0.0f;
        }
    }
    
    float zeta = 2.0f / radius;
    float eta = (zeta + cos(sectorOverlap)) / (sin(sectorOverlap) * sin(sectorOverlap));
    
    int bx = int(ceil(abs(a * cosPhi) + abs(b * sinPhi)));
    int by = int(ceil(abs(a * sinPhi) + abs(b * cosPhi)));
    
    for (int y = -by; y <= by; y++)
    {
        for (int x = -bx; x <= bx; x++)
        {
            float2 p = float2(x, y);
            float2 v = mul(transform, p);
            if (length(v) > 1.0f)
                continue;
            
            float3 c = tex2Dlod(ReShade::BackBuffer, float4(uv + p * ReShade::PixelSize, 0.0f, 0.0f)).rgb;
            float sum = 0;
            float w[8];
            float z, vxx, vyy;
            vxx = zeta - eta * v.x * v.x;
            vyy = zeta - eta * v.y * v.y;
            z = max(0, v.y + vxx);
            sum += w[0] = z * z;
            z = max(0, -v.x + vyy);
            sum += w[2] = z * z;
            z = max(0, -v.y + vxx);
            sum += w[4] = z * z;
            z = max(0, v.x + vyy);
            sum += w[6] = z * z;
            
            v = sqrt(2) / 2 * float2(v.x - v.y, v.x + v.y);
            
            vxx = zeta - eta * v.x * v.x;
            vyy = zeta - eta * v.y * v.y;
            z = max(0, v.y + vxx);
            sum += w[1] = z * z;
            z = max(0, -v.x + vyy);
            sum += w[3] = z * z;
            z = max(0, -v.y + vxx);
            sum += w[5] = z * z;
            z = max(0, v.x + vyy);
            sum += w[7] = z * z;
            
            float g = exp(-3.125f * dot(v, v)) / sum;
            
            for (int k = 0; k < 8; ++k)
            {
                float wk = w[k] * g;
                m[k] += float4(c * wk, wk);
                s[k] += c * c * wk;
            }
        }
    }
    float4 output = 0.0f;
    {
        for (int i = 0; i < 8; i++)
        {
            m[i].rgb /= m[i].w;
            s[i] = abs(s[i] / m[i].w - m[i].rgb * m[i].rgb);
            
            float sd = Luminance(s[i]);
            float w = 1.0f / (1.0f + pow(abs(1000.0f * sd), sigma));
            output += float4(m[i].rgb * w, w);
        }
    }
    
    return float4(output.rgb / output.w, 1.0f);
}

float4 PS_Kuwahara(float4 pos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    if (mode == 0)
        return SimpleKuwahara(uv, false);
    else if (mode == 1)
        return SimpleKuwahara(uv, true);
    else if (mode == 2)
        return GeneralizedKuwahara(uv, false);
    else 
        return GeneralizedKuwahara(uv, true);
}

technique Orix_Kuwahara
{
    pass Kuwahara
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Kuwahara;
    }
}