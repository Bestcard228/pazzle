Shader "PuzzleGame/PixelFilter"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PixelSize ("Pixel Size", Range(1,8)) = 2
        _DesignResolution ("Design Resolution", Vector) = (540,960,0,0)
        _ColorLevels ("Color Levels", Range(0,64)) = 32
        _Sharpness ("Sharpness", Range(0,1)) = 0.35
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float _PixelSize;
            float4 _DesignResolution;
            int _ColorLevels;
            float _Sharpness;

            float3 ToLinear(float3 c) { return pow(max(c, 0), 2.2); }
            float3 ToSRGB(float3 c) { return pow(max(c, 0), 1.0/2.2); }

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float2 blocks = max(float2(1,1), floor(_DesignResolution.xy / _PixelSize));
                float2 blockSize = 1.0 / blocks;
                float2 blockOrigin = floor(IN.uv * blocks) * blockSize;
                float3 sum = 0;
                for(int x=0;x<2;x++) for(int y=0;y<2;y++)
                {
                    float2 offset = (float2(x,y)+0.5)*0.5;
                    sum += ToLinear(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, blockOrigin + offset*blockSize).rgb);
                }
                float3 averaged = sum*0.25;
                float3 centre = ToLinear(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, blockOrigin + blockSize*0.5).rgb);
                float3 c = ToSRGB(lerp(averaged, centre, _Sharpness));
                if(_ColorLevels>0)
                {
                    float levels = (float)_ColorLevels;
                    c = floor(c*levels+0.5)/levels;
                }
                return half4(c,1);
            }
            ENDHLSL
        }
    }
}
