Shader "Learning/Code Parallax Occlusion Unlit"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _HeightMap ("Height Map (White = High)", 2D) = "gray" {}
        _ParallaxScale ("Parallax Scale", Range(0, 0.1)) = 0.035
        _MinSteps ("Minimum Steps", Range(4, 32)) = 8
        _MaxSteps ("Maximum Steps", Range(8, 64)) = 32
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend One Zero
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_HeightMap);
            SAMPLER(sampler_HeightMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _HeightMap_ST;
                half4 _BaseColor;
                half _ParallaxScale;
                float _MinSteps;
                float _MaxSteps;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                half3 viewDirTS : TEXCOORD1;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = positionInputs.positionCS;
                output.uv = input.uv;

                half3 viewDirWS = GetWorldSpaceViewDir(positionInputs.positionWS);
                half3x3 tangentToWorld = half3x3(
                    normalInputs.tangentWS,
                    normalInputs.bitangentWS,
                    normalInputs.normalWS);
                output.viewDirTS = TransformWorldToTangentDir(viewDirWS, tangentToWorld, true);
                return output;
            }

            half2 ApplyParallaxOcclusion(half2 uv, half3 viewDirTS)
            {
                half viewZ = max(viewDirTS.z, 0.08h);
                half2 totalOffset = viewDirTS.xy / viewZ * _ParallaxScale;

                int minSteps = (int)min(_MinSteps, _MaxSteps);
                int maxSteps = (int)max(_MinSteps, _MaxSteps);
                int stepCount = (int)round(lerp((float)minSteps, (float)maxSteps, 1.0h - saturate(viewDirTS.z)));
                stepCount = max(stepCount, 1);

                half stepDepth = 1.0h / stepCount;
                half2 stepUV = totalOffset / stepCount;
                half2 currentUV = uv;
                half currentRayDepth = 0.0h;
                half currentSurfaceDepth = 1.0h - SAMPLE_TEXTURE2D(
                    _HeightMap, sampler_HeightMap, TRANSFORM_TEX(currentUV, _HeightMap)).r;
                half currentDifference = currentRayDepth - currentSurfaceDepth;

                half2 previousUV = currentUV;
                half previousDifference = currentDifference;
                half2 hitUV = currentUV;

                [loop]
                for (int i = 0; i < 64; i++)
                {
                    if (i >= stepCount || currentDifference >= 0.0h)
                        break;

                    previousUV = currentUV;
                    previousDifference = currentDifference;
                    currentUV -= stepUV;
                    currentRayDepth += stepDepth;

                    currentSurfaceDepth = 1.0h - SAMPLE_TEXTURE2D(
                        _HeightMap, sampler_HeightMap, TRANSFORM_TEX(currentUV, _HeightMap)).r;
                    currentDifference = currentRayDepth - currentSurfaceDepth;
                }

                half denominator = previousDifference - currentDifference;
                half weight = abs(denominator) > 0.0001h
                    ? saturate(previousDifference / denominator)
                    : 0.0h;
                hitUV = lerp(previousUV, currentUV, weight);
                return hitUV;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half2 parallaxUV = ApplyParallaxOcclusion(input.uv, normalize(input.viewDirTS));
                half2 baseUV = TRANSFORM_TEX(parallaxUV, _BaseMap);
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV) * _BaseColor;
                return half4(color.rgb, 1.0h);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionCS : SV_POSITION; };

            Varyings DepthVert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 DepthFrag(Varyings input) : SV_Target { return 0; }
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode"="DepthNormals" }
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepthNormalsVert
            #pragma fragment DepthNormalsFrag
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                half3 normalWS : TEXCOORD0;
            };

            Varyings DepthNormalsVert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = NormalizeNormalPerVertex(normalInputs.normalWS);
                return output;
            }

            half4 DepthNormalsFrag(Varyings input) : SV_Target
            {
                #if defined(_GBUFFER_NORMALS_OCT)
                    float3 normalWS = normalize(input.normalWS);
                    float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
                    float2 remappedNormalWS = saturate(octNormalWS * 0.5 + 0.5);
                    half3 packedNormalWS = PackFloat2To888(remappedNormalWS);
                    return half4(packedNormalWS, 0.0);
                #else
                    return half4(NormalizeNormalPerPixel(input.normalWS), 0.0);
                #endif
            }
            ENDHLSL
        }
    }
}
