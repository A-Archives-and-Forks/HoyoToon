Shader "Hidden/Locked/HoyoToon/Wuthering Waves/Character/446ec9a033fe21941969a6c6c6e7fea3"
{
    Properties 
  { 
      [HideInInspector] shader_is_using_HoyoToon_editor("", Float)=0
        [HideInInspector] ShaderBG ("UI/background", Float) = 0
        [HideInInspector] ShaderLogo ("UI/wuwalogo", Float) = 0
        [HideInInspector] shader_is_using_hoyeditor ("", Float) = 0
        [HideInInspector] footer_github ("{texture:{name:hoyogithub},action:{type:URL,data:https://github.com/HoyoToon/HoyoToon},hover:Github}", Float) = 0
        [HideInInspector] footer_discord ("{texture:{name:hoyodiscord},action:{type:URL,data:https://discord.gg/hoyotoon},hover:Discord}", Float) = 0
        [HoyoToonShaderOptimizerLockButton] _ShaderOptimizerEnabled ("Lock Material", Float) = 1
        [Enum(Base, 0, Face, 1, Eye, 2, Bangs, 3, Hair, 4, Glass, 5, Tacet Mark, 6)] _MaterialType ("Material Type--{on_value_actions:[
            {value:0,actions:[{type:SET_PROPERTY,data:_StencilPassA=2}, {type:SET_PROPERTY,data:_StencilPassB=0}, {type:SET_PROPERTY,data:_StencilCompA=0}]},
            {value:0,actions:[{type:SET_PROPERTY,data:_StencilCompB=0}, {type:SET_PROPERTY,data:_StencilRef=0}, {type:SET_PROPERTY,data:render_queue=2040}, {type:SET_PROPERTY,data:render_type=Opaque}]},
            {value:1,actions:[{type:SET_PROPERTY,data:_StencilPassA=0}, {type:SET_PROPERTY,data:_StencilPassB=2}, {type:SET_PROPERTY,data:_StencilCompA=5}]},
            {value:1,actions:[{type:SET_PROPERTY,data:_StencilCompB=5}, {type:SET_PROPERTY,data:_StencilRef=100}, {type:SET_PROPERTY,data:render_queue=2010}, {type:SET_PROPERTY,data:render_type=Opaque}]},
            {value:2,actions:[{type:SET_PROPERTY,data:_StencilPassA=0}, {type:SET_PROPERTY,data:_StencilPassB=2}, {type:SET_PROPERTY,data:_StencilCompA=5}]},
            {value:2,actions:[{type:SET_PROPERTY,data:_StencilCompB=5}, {type:SET_PROPERTY,data:_StencilRef=100}, {type:SET_PROPERTY,data:render_queue=2011}, {type:SET_PROPERTY,data:render_type=Opaque}]},
            {value:3,actions:[{type:SET_PROPERTY,data:_StencilPassA=0}, {type:SET_PROPERTY,data:_StencilPassB=0}, {type:SET_PROPERTY,data:_StencilCompA=5}]},
            {value:3,actions:[{type:SET_PROPERTY,data:_StencilCompB=8}, {type:SET_PROPERTY,data:_StencilRef=100}, {type:SET_PROPERTY,data:render_queue=2020}, {type:SET_PROPERTY,data:render_type=Opaque}]},
            {value:4,actions:[{type:SET_PROPERTY,data:_StencilPassA=2}, {type:SET_PROPERTY,data:_StencilPassB=0}, {type:SET_PROPERTY,data:_StencilCompA=0}]},
            {value:4,actions:[{type:SET_PROPERTY,data:_StencilCompB=0}, {type:SET_PROPERTY,data:_StencilRef=0}, {type:SET_PROPERTY,data:render_queue=2040}, {type:SET_PROPERTY,data:render_type=Opaque}]},
            {value:5,actions:[{type:SET_PROPERTY,data:_StencilPassA=2}, {type:SET_PROPERTY,data:_StencilPassB=0}, {type:SET_PROPERTY,data:_StencilCompA=0}]},
            {value:5,actions:[{type:SET_PROPERTY,data:_StencilCompB=0}, {type:SET_PROPERTY,data:_StencilRef=0}, {type:SET_PROPERTY,data:render_queue=2060}, {type:SET_PROPERTY,data:render_type=Opaque}]}, 
            {value:6,actions:[{type:SET_PROPERTY,data:_StencilPassA=2}, {type:SET_PROPERTY,data:_StencilPassB=0}, {type:SET_PROPERTY,data:_StencilCompA=0}]},
            {value:6,actions:[{type:SET_PROPERTY,data:_StencilCompB=0}, {type:SET_PROPERTY,data:_StencilRef=0}, {type:SET_PROPERTY,data:render_queue=2060}, {type:SET_PROPERTY,data:render_type=Opaque}]}]}", Float) = 0
        [HideInInspector] start_main ("Main", Float) = 0
            [Toggle] _MultiLight ("Enable Multi Light Source Mode", float) = 1
            [Toggle] _FilterLight ("Limit Spot/Point Light Intensity", Float) = 1
            [HideInInspector] start_coretex ("Main Textures", Float) = 0
            [HideInInspector] start_diff ("Diffuse Texture", Float) = 0
                _MainTex ("Diffuse Texture", 2D) = "white" {}
                [Toggle] _UseMainTexA ("Alpha is Toon Mask", Float) = 0
            [HideInInspector]  end_diff ("", Float) = 0
            [HideInInspector] start_mask ("Type Mask", Float) = 0
                _MaskTex ("Mask", 2D) = "grey" {}
                [Toggle] _UseSDFShadow ("Use SDF Shadow", Float) = 0
            [HideInInspector] end_mask ("", Float) = 0
            [HideInInspector] start_type ("ID Mask", Float) = 0
                _TypeMask ("Type Mask (ID)", 2D) = "grey" {}
                [Toggle] _UseSkinMask ("Skin Mask Enable", Float) = 0
                [Toggle] _UseRampMask ("Ramp Mask Enable", Float) = 0
            [HideInInspector] end_type ("", Float) = 0
            [HideInInspector] start_nrm("Normal|Roughness|Metal", Float) = 0
                _Normal_Roughness_Metallic ("Normal Map(RG)|Roughness(B)|Metallic(G)", 2D) = "bump" {}
            [HideInInspector] end_nrm("", Float) = 0
            [HideInInspector] end_coretex ("", Float) = 0
            [HideInInspector] start_coloring ("Colors", Float) = 0
                _BaseColor ("Base Color", Color) = (1,1,1,1)
                _SkinColor ("Skin Color", Color) = (1,1,1,1)
                _SubsurfaceColor ("Subsurface Color", Color) = (0.5,0.5,0.5,1)
                _SkinSubsurfaceColor ("Skin Subsurface Color", Color) = (0.9387,0.6038,0.4072,1.0)
            [HideInInspector] end_coloring ("", Float) = 0
            [HideInInspector] start_facingdirection ("Facing Direction", Float) = 0
                _headUpVector ("Up Vector | XYZ", Vector) = (0, 1, 0, 0)
                _headForwardVector ("Forward Vector | XYZ", Vector) = (0, 0, 1, 0)
                _headRightVector ("Right Vector | XYZ ", Vector) = (-1, 0, 0, 0)
            [HideInInspector] end_facingdirection ("", Float) = 0
        [HideInInspector] end_main ("", Float) = 0
        [HideInInspector] start_bump("Normal|Roughness|Metal", Float) = 0
            [Toggle] _UseNormalMap ("Enable Bump Mapping", Float) = 0
            [Toggle] _NormalFlip ("Enable Bump Mapping", Float) = 0
            _NormalStrength ("Bump Strength", Float) = 1
        [HideInInspector] end_bump("", Float) = 0
        [HideInInspector] start_spec("Specular", Float) = 0
            _ToonMaxSpecular ("Specular Sharpness", Float) = 0.1
            _SpecularPower ("Specular Power", Float) = 1
            _SpecStrength ("Specular Strength", Float) = 0.2 
            [HideInInspector] start_matcap ("Metal MatCap", Float) = 0
                _MetalSpecularPower ("Metal Specular Power", Float) = 1
                _MatCapTex ("MatCap Texture", 2D) = "black" {}
                _MetalMatCapBack ("Metal MatCap Back Intensity", Float) = 1
                _MatCapInt ("MatCap Intensity", Float) = 1
                _MetalMatCapInt ("Metal MatCap Intensity", Float) = 1
            [HideInInspector] end_matcap ("", Float) = 0
        [HideInInspector] end_spec("", Float) = 0
        [HideInInspector] start_rim ("Rim Light", Float) = 0
            [Toggle] _EnableRimLight ("Use Rim Lighting", Float) = 1
            _RimWidth ("Rim Width", Float) = 1
            _RimHardness ("Rim Hardness", Float) = 1
            _RimColor ("Rim Color", Color) = (0.5,0.5,0.5,1)
        [HideInInspector] end_rim ("", Float) = 0
        [HideInInspector] start_stock ("Stocking", Float) = 0
            [Toggle] _UseStocking ("Enable Stocking", Float) = 0
            _StockingIntensity ("Stocking Intensity", Float) = 1.0
            [HideInInspector] start_anistropy ("Anisotropic", Float) = 0
                _AnistropyColor ("Anisotropic Highlight Color", Color) = (0.0139, 0.0139, 0.0139, 1.0)
                _AnistropyInt ("Anisotropic Intensity", Float) = 1
                _AnistropyNormalInt ("Anisotropic Normal Intensity", Float) = 1
            [HideInInspector] end_anistropy ("", Float) = 0
            [HideInInspector] start_scolor ("Colors", Float) = 0
                _StockingLightColor ("Stocking Light Color", Color) = (0.0139, 0.0139, 0.0139, 1.0)
                _StockingEdgeColor ("Stocking Edge Color", Color) = (0.609,0.542,0.596,1.0)
                _StockingColor ("Stocking Color", Color) = (0.731,0.689,0.739,1.0)
            [HideInInspector] end_scolor ("", Float) = 0
            [HideInInspector] start_knee ("Knee Settings", Float) = 0 
                _Stocking_KneeSkinIntensityOffset ("Knee Skin Intensity Offset", Float) = 0.1
                _Stocking_KneeSkinRangeOffset ("Knee Skin Range Offset", Float) = 2
            [HideInInspector] end_knee ("", Float) = 0
            [HideInInspector] start_ranges ("Ranges", float) = 0
                _StockingLightRangeMax ("Stocking Light Range Max", Float) = 1
                _StockingLightRangeMin ("Stocking Light Range Min", Float) = 0.4
                _StockingRangeMax ("Stocking Range Max", Float) = 1.0
                _StockingRangeMiddle ("Stocking Range Middle", Float) = 0.48
                _StockingRangeMin ("Stocking Range Min", Float) = 0.4
                _StockingSkinRange ("Stocking Skin Range", Float) = 6
            [HideInInspector] end_ranges ("", float) = 0
        [HideInInspector] end_stock ("Stocking", Float) = 0
        [HideInInspector] start_eye ("Eye", Float) = 0
            [Toggle] _UseHeightLightShape ("Use Highlight Shape", Float) = 0
            [Toggle] _UseEyeSDF ("Use Eye SDF", Float) = 0
            _RotateAngle ("Rotation Angle", Float) = 0.11
            _EyeScale ("Eye Scale", Float) = 0.8
            _HeightRatioInput ("Highlight Ratio", Float) = 0.4
            [HideInInspector] start_eyetex ("Eye", Float) = 0
                _HeightLightMap ("Highlight Map", 2D) = "black" {}
                _EM ("Highlight EM Map", 2D) = "black" {}
            [HideInInspector] end_eyetex ("", Float) = 0
            [HideInInspector] start_hlight ("Highlight", Float) = 0
                [HideInInspector] start_eyeshake ("Eye Shake", Float) = 0
                    _LightShakeScale ("Light Shake Scale", Float) = 0.01
                    _LightShakeSpeed ("Light Shake Speed", Float) = 10
                    _LightShakPositionX ("Light Shake X", Float) = 0.5
                    _LightShakPositionY ("Light Shake Y", Float) = 0.5
                [HideInInspector] end_eyeshake ("", Float) = 0
                [HideInInspector] start_lightpos ("Light Positions", Float) = 0
                    _SecondLight_PositionX ("Secont Light Position X", Float) = 0.5
                    _SecondLight_PositionY ("Secont Light Position Y", Float) = 0.5
                    _LightPositionX ("Light Position X", Float) = 0.5
                    _LightPositionY ("Light Position Y", Float) = 0.5
                [HideInInspector] end_lightpos ("", Float) = 0
                [HideInInspector] start_heightlight ("Height Light", Float) = 0
                    _HeightLight_PositionX ("Highlight Pos X", Float) = 0.54
                    _HeightLight_PositionY ("Highlight Pos Y", Float) = 0.58 
                    _HeightLight_WidthX ("Highlight Width X", Float) = 1.71
                    _HeightLight_WidthY ("HighLight Width Y", Float) = 1.03
                [HideInInspector] end_heightlight ("", Float) = 0
            [HideInInspector] end_hlight ("", Float) = 0
            [HideInInspector] start_parallax ("Parallax", Float) = 0
                _ParallaxSteps ("Step Count", Int) = 25 
                _ParallaxHeight ("Parallax Height", Float) = 0.2
            [HideInInspector] end_parallax ("", Float) = 0
        [HideInInspector] end_eye ("", Float) = 0
        [HideInInspector] start_shadow ("Shadow", Float) = 0
            _ShadowProcess ("Shadow Process", Float) = 0.55
            _BackShadowProcessOffset ("Back Shadow Offset", Float) = -0.1
            _FrontShadowProcessOffset ("Front Shadow Offset", Float) = 0.4
            _ShadowWidth ("Shadow Width", Float) = 0.01
            _ShadowOffsetPower ("Shadow Offset Power", Float) = 0.56
            _MaskShadowOffsetStrength ("Mask Shadow Offset Strength", Float) = .42
            [HideInInspector] start_solidshadow("Solid Shadow Settings", Float) = 0
                _SolidShadowWidth ("Solid Shadow Width", Float) = 0.9
                _SolidShadowStrength ("Solid Shadow Strength", Float) = 1
                _SolidShadowProcess ("Solid Shadow Process", Float) = 0.1
            [HideInInspector] end_solidshadow("", Float) = 0
            [HideInInspector] start_ramp ("Shadow Ramp", Float) = 0
                [Toggle] _UseRampColor ("Use Shadow Ramp", Float) = 0
                _Ramp ("Shadow Ramp", 2D) = "white" {}
                _RampPosition ("Ramp Position", Float) = 0.5
                _RampProcess ("Ramp Process", Float) = 0.5 
                _RampWidth ("Ramp Width", Float) = 0.1
                _RampInt ("Ramp Intensity", Float) = 0.3
            [HideInInspector] end_ramp ("", Float) = 0
            [HideInInspector] start_hair ("Hair Shadow", Float) = 0
                [Toggle] _EnableHairShadow ("Enable Hair Shadow", Float) = 0
                _HairShadowColor("Hair Subsurface Color", Color) = (0.938686,0.603828,0.40724,1.0)
                [IntRange] _StencilRefShadow ("Stencil Reference Value", Range(0, 255)) = 0
                [Enum(UnityEngine.Rendering.StencilOp)] _StencilPassShadow ("Stencil Pass Op Shadow", Float) = 0
                [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompShadow ("Stencil Compare Function Shadow", Float) = 8
            [HideInInspector] end_hair ("", Float) = 0
        [HideInInspector] end_shadow ("", Float) = 0
        [HideInInspector] start_outline ("Outline", Float) = 0
            _OutlineTexture ("Outline Texture", 2D) = "white" {}
            [Enum(Off, 0, Tangent, 1, Normal, 2)] _Outline ("Outline Type", Float) = 1
            [Toggle] _UseMainTex ("Use Outline Texture", Float) = 1
            _OutlineWidth ("Outline Width", Float) = 0.11
            [Toggle] _UseVertexGreen_OutlineWidth ("Use Vertex Green as Width", Float) = 0
            [Toggle] _UseVertexColorB_InnerOutline ("Vertex B is Inner Range", Float) = 0
            _OutlineColor ("Outline Color", Color) = (0.765, 0.765, 0.765, 1.0)
        [HideInInspector] end_outline ("", Float) = 0
        [HideInInspector] start_special ("Special Effects", Float) = 0
            [HideInInspector] start_emission ("Emission", Float) = 0
                [Toggle] _UseBreathLight ("Use Emission", Float) = 0
                _EmissionBreathThreshold ("Emission Texture Threshold", float) = 0.9
                _EmissionColor ("Emission Color", Color) = (1,1,1,1)
                _EmissionStrength ("Emission Strength", Float) = 1
            [HideInInspector] end_emission ("", Float) = 0
            [HideInInspector] start_stencil ("Stencil", Float) = 0
                [Toggle] _EnabelStencil ("Enable Stencil", Float) = 1 
                [Toggle] _AlphaStencil ("Use Transparency in Stencil", Float) = 1
                _Mask ("Stencil Mask", 2D) = "white" {}
                [Enum(UnityEngine.Rendering.StencilOp)] _StencilPassA ("Stencil Pass Op A", Float) = 0
                [Enum(UnityEngine.Rendering.StencilOp)] _StencilPassB ("Stencil Pass Op B", Float) = 0
                [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompA ("Stencil Compare Function A", Float) = 8
                [Enum(UnityEngine.Rendering.CompareFunction)] _StencilCompB ("Stencil Compare Function B", Float) = 8
                [IntRange] _StencilRef ("Stencil Reference Value", Range(0, 255)) = 0
            [HideInInspector] end_stencil ("", Float) = 0
            [HideInInspector] start_tacet ("Tacet Mark", Float) = 0
                _D ("Tacet Mark", 2D) = "white" {}
                _Noise ("Tacet Mark Noise", 2D) = "white" {}
                _Noise02 ("Tacet Mark Noise 02", 2D) = "white" {}
                _SDFStart ("Tacet Mark SDF Start", Range(-1, -0.01)) = -0.2
                _SDFColor ("Tacet Mark SDF Color", Color) = (0.0, 0.0, 0.0,1)
                [HideInInspector] start_soundwave ("Sound Wave", Float) = 0
                    _SoundWaveSpeed01 ("Sound Wave Speed 01", Float) = -0.2
                    _SoundWaveTiling01 ("Sound Wave Tiling 01", Float) = 3.8
                    _SoundWaveSpeed02 ("Sound Wave Speed 02", Float) = -0.57
                    _SoundWaveTiling02 ("Sound Wave Tiling 02", Float) = 7.8
                [HideInInspector] end_soundwave ("", Float) = 0
            [HideInInspector] end_tacet ("", Float) = 0
        [HideInInspector] end_special ("", Float) = 0
        [HideInInspector] start_renderingOptions("Rendering Options", Float) = 0
            [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 0
            [Enum(Off, 0, On, 1)] _ZWrite("ZWrite", Int) = 1
            [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
            [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source Blend", Int) = 1
            [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination Blend", Int) = 0
        [HideInInspector] end_renderingOptions("", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        HLSLINCLUDE
            #define use_rim
            #define is_tacet
        #include "UnityCG.cginc"
        #include "UnityLightingCommon.cginc"
        #include "UnityShaderVariables.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"
        #include "UnityInstancing.cginc"
        #include "/HoyoToonWutheringWaves-declaration.hlsl"
        #include "/HoyoToonWutheringWaves-common.hlsl"
        #include "/HoyoToonWutheringWaves-input.hlsl"
        ENDHLSL
        Pass
        {
            Name "Character"
            Tags{ "LightMode" = "ForwardBase" }
            Cull [_Cull]
            Blend [_SrcBlend] [_DstBlend]
            Stencil
            {
                Ref [_StencilRef]      
                Comp [_StencilCompA]
				Pass [_StencilPassA]
            }
            HLSLPROGRAM
            #pragma multi_compile_fwdbase
            #pragma multi_compile _IS_PASS_BASE
            #pragma vertex vs_model
            #pragma fragment ps_model
            #include "/HoyoToonWutheringWaves-program.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "Stencil"
            Tags{ "LightMode" = "ForwardBase" }
            Blend SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
            Stencil
            {
                ref [_StencilRef]              
				Comp [_StencilCompB]
				Pass [_StencilPassB]
			}
            HLSLPROGRAM
            #define is_stencil
            #pragma multi_compile_fwdbase
            #pragma multi_compile _IS_PASS_BASE
            #pragma vertex vs_model
            #pragma fragment ps_model
            #include "/HoyoToonWutheringWaves-program.hlsl"
            ENDHLSL
        }
        Pass // Character Light Pass
        {
            Name "Character Light Pass"
            Tags{ "LightMode" = "ForwardAdd" }
            Cull [_Cull]
            ZWrite Off
            Blend One One     
            HLSLPROGRAM
            #pragma multi_compile_fwdadd
            #pragma multi_compile _IS_PASS_LIGHT
            #pragma vertex vs_model
            #pragma fragment ps_model 
            #include "/HoyoToonWutheringWaves-program.hlsl"
            ENDHLSL
        }    
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
    CustomEditor "HoyoToon.ShaderEditor"
}
