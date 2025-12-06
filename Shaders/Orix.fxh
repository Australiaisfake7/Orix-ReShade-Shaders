const static int sobelX[] = { -1, 0, 1, -2, 0, 2, -1, 0, 1 };
const static int sobelY[] = { 1, 2, 1, 0, 0, 0, -1, -2, -1 };

static int bayer8x8[64] =
{
    0, 32, 8, 40, 2, 34, 10, 42,
 48, 16, 56, 24, 50, 18, 58, 26,
 12, 44, 4, 36, 14, 46, 6, 38,
 60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41,
 51, 19, 59, 27, 49, 17, 57, 25,
 15, 47, 7, 39, 13, 45, 5, 37,
 63, 31, 55, 23, 61, 29, 53, 21
};

const static float pi = 3.14159265359;
const static float epsilon = 1e-9;

float3 Convolve(float2 uv, int kernel[9], sampler2D buffer)
{
    float3 sum = 0.0;
    for (int y = 0; y < 3; y++)
    {
        for (int x = 0; x < 3; x++)
        {
            float3 color = tex2D(buffer, uv + (float2(x, y) - 1.0) * ReShade::PixelSize).rgb;
            sum += color * kernel[x + y * 3];
        }
    }
    return sum;
}

float ConvolveDepth(float2 uv, int kernel[9])
{
    float sum = 0.0;
    for (int y = 0; y < 3; y++)
    {
        for (int x = 0; x < 3; x++)
        {
            float color = ReShade::GetLinearizedDepth(uv + (float2(x, y) - 1.0) * ReShade::PixelSize);
            sum += color * kernel[x + y * 3];
        }
    }
    return sum;
}

float3 SRGBToLinear(float3 color)
{
    float3 l = 0.0;
    
    if (color.r <= 0.04045)
        l.r = color.r / 12.92;
    else
        l.r = pow(((color.r + 0.055) / 1.055), 2.4);
    if (color.g <= 0.04045)
        l.g = color.g / 12.92;
    else
        l.g = pow(((color.g + 0.055) / 1.055), 2.4);
    if (color.b <= 0.04045)
        l.b = color.b / 12.92;
    else
        l.b = pow(((color.b + 0.055) / 1.055), 2.4);

    return l;
}

float3 LinearToSRGB(float3 color)
{
    float3 l = 0.0;
    
    if (color.r <= 0.0031308)
        l.r = color.r * 12.92;
    else
        l.r = pow(color.r, 1.0 / 2.4) * 1.055 - 0.055;
    if (color.g <= 0.0031308)
        l.g = color.g * 12.92;
    else
        l.g = pow(color.g, 1.0 / 2.4) * 1.055 - 0.055;
    if (color.b <= 0.0031308)
        l.b = color.b * 12.92;
    else
        l.b = pow(color.b, 1.0 / 2.4) * 1.055 - 0.055;

    return l;
}

float Luminance(float3 color)
{
    return dot(SRGBToLinear(color), float3(0.2126, 0.7152, 0.0722));
}

float3 LinearToOklab(float3 color)
{
    float l = 0.4122214708f * color.r + 0.5363325363f * color.g + 0.0514459929f * color.b;
    float m = 0.2119034982f * color.r + 0.6806995451f * color.g + 0.1073969566f * color.b;
    float s = 0.0883024619f * color.r + 0.2817188376f * color.g + 0.6299787005f * color.b;

    float l_ = pow(l,1.0 / 3.0);
    float m_ = pow(m, 1.0 / 3.0);
    float s_ = pow(s, 1.0 / 3.0);

    return float3(
        0.2104542553f * l_ + 0.7936177850f * m_ - 0.0040720468f * s_,
        1.9779984951f * l_ - 2.4285922050f * m_ + 0.4505937099f * s_,
        0.0259040371f * l_ + 0.7827717662f * m_ - 0.8086757660f * s_
    );
}

float3 OklabToLinear(float3 color)
{
        float l_ = color.r + 0.3963377774f * color.g + 0.2158037573f * color.b;
        float m_ = color.r - 0.1055613458f * color.g - 0.0638541728f * color.b;
        float s_ = color.r - 0.0894841775f * color.g - 1.2914855480f * color.b;

        float l = l_ * l_ * l_;
        float m = m_ * m_ * m_;
        float s = s_ * s_ * s_;

        return float3(
            +4.0767416621f * l - 3.3077115913f * m + 0.2309699292f * s,
		-1.2684380046f * l + 2.6097574011f * m - 0.3413193965f * s,
		-0.0041960863f * l - 0.7034186147f * m + 1.7076147010f * s
    );
}

float3 SRGBToOklab(float3 color)
{
    return LinearToOklab(SRGBToLinear(color));
}

float3 OklabToSRGB(float3 color)
{
    return LinearToSRGB(OklabToLinear(color));
}

float3 OkLabToOkLCh(float3 color)
{
    float3 c = 0.0;
    
    c.r = color.r;
    c.g = sqrt(color.g * color.g + color.b * color.b);
    c.b = atan2(color.b, color.g);
    
    return c;
}

float3 OkLChToOklab(float3 color)
{
    float3 c = 0.0;
    
    c.r = color.r;
    c.g = color.g * cos(color.b);
    c.b = color.g * sin(color.b);
    
    return c;
}


float3 ACES(float3 x)
{
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}