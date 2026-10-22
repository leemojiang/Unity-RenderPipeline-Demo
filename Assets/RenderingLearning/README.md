# SRP Example — URP rendering learning template

**Project version:** Unity 2022.1.25f1  
**URP package:** 13.1.9

This is a small project for learning Unity's render pipeline through paired Shader Graph and HLSL examples. Start with `Assets/Scenes/SampleScene.unity`, then browse `Assets/RenderingLearning/`.

## Folders

- `Assets/RenderingLearning/Shaders/Graph/`: Lit texture sample, a blank Graph practice template, and the Unlit texture graph.
- `Assets/RenderingLearning/Shaders/HLSL/`: Code Lit, Code Unlit, and basic parallax mapping shaders.
- `Assets/RenderingLearning/Materials/`: Materials paired with the examples, plus reusable URP Lit materials.
- `Assets/RenderingLearning/Textures/`: Checker texture and paired parallax Albedo/Height maps.
- `Assets/RenderingLearning/Docs/`: step-by-step shader walkthrough.
- `Assets/RenderingLearning/Tools/`: standard-library Python script to regenerate the parallax textures.
- `Assets/Settings/`: URP assets, Renderer Data, and the SampleScene Volume Profile.
- `Assets/Scenes/`: sample scene.

## Learning sequence

1. Compare `Graph_Unlit_Texture` and `03_CodeUnlitTexture` to follow UV → texture sample → color output.
2. Compare `Graph_Lit_TextureSample` and `02_CodeLitTexture` to distinguish surface inputs from the URP Lit lighting calculation.
3. Read `04_CodeParallaxUnlit` to see how height data offsets fragment UVs in tangent space.
4. Inspect the HighFidelity Renderer Data and its SSAO Feature, then inspect `SampleSceneProfile.asset` separately to learn how screen-space effects and Volume post-processing are configured.

See `Assets/RenderingLearning/Docs/Shader-Demos.md` for input/output tables and practice steps. Keep each asset's `.meta` file alongside it when moving or renaming assets; Unity references assets by GUID.
