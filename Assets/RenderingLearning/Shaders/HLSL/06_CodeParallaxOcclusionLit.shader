Shader "Learning/Code Parallax Occlusion Lit"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _HeightMap ("Height Map (White = High)", 2D) = "gray" {}
        _ParallaxScale ("Parallax Scale", Range(0, 0.1)) = 0.035
        _MinSteps ("Minimum Steps", Range(4, 32)) = 8
        _MaxSteps ("Maximum Steps", Range(8, 64)) = 32
        _NormalStrength ("Height Normal Strength", Range(0, 16)) = 6
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.35
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForwardOnly" }
            Blend One Zero
            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_HeightMap);
            SAMPLER(sampler_HeightMap);
            float4 _HeightMap_TexelSize;

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _HeightMap_ST;
                half4 _BaseColor;
                half _ParallaxScale;
                half _NormalStrength;
                half _Metallic;
                half _Smoothness;
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
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half3 tangentWS : TEXCOORD2;
                half3 bitangentWS : TEXCOORD3;
                float2 uv : TEXCOORD4;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.positionCS = positionInputs.positionCS;
                output.positionWS = positionInputs.positionWS;
                output.normalWS = normalInputs.normalWS;
                output.tangentWS = normalInputs.tangentWS;
                output.bitangentWS = normalInputs.bitangentWS;
                output.uv = input.uv;
                return output;
            }

            half2 ApplyParallaxOcclusion(half2 uv, half3 viewDirTS, out half hitDepth)
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
                half previousRayDepth = currentRayDepth;
                half previousDifference = currentDifference;

                [loop]
                for (int i = 0; i < 64; i++)
                {
                    if (i >= stepCount || currentDifference >= 0.0h)
                        break;
                    previousUV = currentUV;
                    previousRayDepth = currentRayDepth;
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
                hitDepth = lerp(previousRayDepth, currentRayDepth, weight);
                return lerp(previousUV, currentUV, weight);
            }

            half3 EstimateHeightNormalTS(half2 uv)
            {
                half2 heightUV = TRANSFORM_TEX(uv, _HeightMap);
                half2 texel = _HeightMap_TexelSize.xy;
                half hL = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV - half2(texel.x, 0)).r;
                half hR = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV + half2(texel.x, 0)).r;
                half hD = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV - half2(0, texel.y)).r;
                half hU = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, heightUV + half2(0, texel.y)).r;
                return SafeNormalize(half3((hL - hR) * _NormalStrength,
                                           (hD - hU) * _NormalStrength, 1.0h));
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half3 normalWS = SafeNormalize(input.normalWS);
                half3 tangentWS = SafeNormalize(input.tangentWS);
                half3 bitangentWS = SafeNormalize(input.bitangentWS);
                half3x3 tangentToWorld = half3x3(tangentWS, bitangentWS, normalWS);
                half3 viewDirWS = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));
                half3 viewDirTS = TransformWorldToTangentDir(viewDirWS, tangentToWorld, true);
                half hitDepth;
                half2 parallaxUV = ApplyParallaxOcclusion(input.uv, viewDirTS, hitDepth);
                half2 baseUV = TRANSFORM_TEX(parallaxUV, _BaseMap);
                half4 baseSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV) * _BaseColor;
                half3 normalTS = EstimateHeightNormalTS(parallaxUV);
                normalWS = TransformTangentToWorld(normalTS, tangentToWorld, true);

                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = input.positionWS;
                lightingInput.positionCS = input.positionCS;
                lightingInput.normalWS = normalWS;
                lightingInput.viewDirectionWS = viewDirWS;
                lightingInput.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                lightingInput.bakedGI = SampleSH(normalWS);
                lightingInput.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                lightingInput.shadowMask = half4(1, 1, 1, 1);
                lightingInput.vertexLighting = VertexLighting(input.positionWS, normalWS);

                SurfaceData surface = (SurfaceData)0;
                surface.albedo = baseSample.rgb;
                surface.metallic = saturate(_Metallic);
                surface.specular = half3(0, 0, 0);
                surface.smoothness = saturate(_Smoothness);
                surface.normalTS = half3(0, 0, 1);
                surface.occlusion = 1;
                surface.emission = half3(0, 0, 0);
                surface.alpha = 1.0h;
                surface.clearCoatMask = 0;
                surface.clearCoatSmoothness = 1;
                return UniversalFragmentPBR(lightingInput, surface);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
              #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
              #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
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
            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
            struct Varyings { float4 positionCS : SV_POSITION; half3 normalWS : TEXCOORD0; };
            Varyings DepthNormalsVert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = NormalizeNormalPerVertex(TransformObjectToWorldNormal(input.normalOS));
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