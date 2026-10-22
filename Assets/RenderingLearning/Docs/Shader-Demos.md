# Shader demos (URP 13.1.9)

The project uses Unity 2022.1.25f1 and URP 13.1.9. The examples are arranged by authoring type and paired with materials under `Assets/RenderingLearning/Materials/`.

## Assets and data flow

| Example | Input | Work | Output |
| --- | --- | --- | --- |
| `Shaders/Graph/Graph_Unlit_Texture.shadergraph` + `M_01_UnlitGraph` | Mesh UV, Base Map | Sample the texture in Shader Graph | Direct Unlit color; no automatic scene lighting |
| `Shaders/HLSL/02_CodeLitTexture.shader` + `M_02_CodeLit` | Position, normal, UV, Base Map, Base Color, Metallic, Smoothness, URP lighting inputs | HLSL prepares `SurfaceData` and `InputData`, then calls `UniversalFragmentPBR` | URP Lit/PBR shaded color |
| `Shaders/HLSL/03_CodeUnlitTexture.shader` + `M_03_CodeUnlit` | UV, Base Map, Base Color | Sample texture and output the result | Direct color, unaffected by standard scene lights |
| `Shaders/HLSL/04_CodeParallaxUnlit.shader` + `M_04_CodeParallax` | Tangent basis, view direction, UV, Height and Albedo maps, Parallax Scale | Sample height, offset UV in tangent space, sample Albedo | Unlit color with a view-dependent texture shift |
| `Shaders/Graph/Graph_Lit_TextureSample.shadergraph` + `M_LitGraph_TextureSample` | UV, Checker map and Lit surface properties | Sample texture and provide surface description | URP Lit shading |
| `Shaders/Graph/Graph_Practice_Template.shadergraph` | Default graph blocks; no connected edges | Empty starting point for node experiments | Defaults until the learner connects graph nodes |

## Scene and pipeline setup

`Assets/Scenes/SampleScene.unity` contains the camera, directional light, Global Volume and a cube. `Assets/Settings/` contains three URP Pipeline Assets and their Renderer Data. The HighFidelity Renderer Data contains the SSAO Renderer Feature; SSAO is separate from the Volume Profile. `SampleSceneProfile.asset` contains post-processing Overrides such as Tonemapping and Panini Projection.

The graph Lit example provides material surface data; it does not replace the URP Lit model. The graph Unlit example directly returns color. The code Lit example calls URP's PBR helper, while the code Unlit example returns a color directly.

## Compare

1. Open `Assets/Scenes/SampleScene.unity`. Create or reuse four primitive meshes and assign the four numbered materials.
2. Rotate or disable the Directional Light. Lit responds to the light; Unlit remains close to the same texture color.
3. Adjust Metallic and Smoothness on `M_02_CodeLit` under a bright light or Reflection Probe.
4. Assign `M_04_CodeParallax` to a mesh with UV0 and valid tangents. Start with Parallax Scale around `0.02`; set it to zero to compare ordinary texture sampling.
5. Switch the Quality level to compare the Performant, Balanced and HighFidelity pipeline budgets.
6. Inspect `URP-HighFidelity-Renderer.asset` for SSAO and `SampleSceneProfile.asset` for Volume effects; these are different configuration layers.

## Parallax mapping

The vertex stage transforms the view direction into tangent space. The fragment stage samples the height map, computes a small UV offset based on the tangent-space view direction, then samples the Albedo map with the shifted UV. This is a basic single-sample technique: it changes texture lookup, not mesh vertices, silhouette, depth, or parallax-shaped shadows. The height texture is linear data (white is higher, black is lower).

Regenerate the paired textures with `python Assets/RenderingLearning/Tools/GenerateParallaxTextures.py Assets/RenderingLearning/Textures`.

## Limits of the code examples

The HLSL shaders are teaching examples. They include the depth and depth-normal passes needed for the current learning scene, but they do not implement every URP feature. In particular, they do not include custom `ShadowCaster` or `Meta` passes; check the shader's pass list before using one as a production shader.
