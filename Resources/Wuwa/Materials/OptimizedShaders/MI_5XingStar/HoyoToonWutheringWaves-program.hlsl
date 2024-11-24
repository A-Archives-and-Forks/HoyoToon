vertex_out vs_model (vertex_in v)
{
    vertex_out o = (vertex_out)0.0f;
    v.color = float4(sRGBToLinear(v.color.xyz), v.color.w);
    o.pos = UnityObjectToClipPos(v.vertex);
    #if defined(_IS_PASS_SHADOW)
        if((0.0 /*_EnableHairShadow*/))
        {
            float4 ws_pos = mul(unity_ObjectToWorld, v.vertex);
            float3 vl = mul(_WorldSpaceLightPos0.xyz, UNITY_MATRIX_V) * (1.f / ws_pos.w);
            float3 offset_pos = ((vl * .001f) * float3(4,0,0)) + v.vertex.xyz;
            v.vertex.xyz = offset_pos;
            o.pos = UnityObjectToClipPos(v.vertex);
        }
    #endif
    o.coord0.xy = v.uv0;
    o.coord0.zw = v.uv1;
    o.coord1.xy = v.uv2;
    o.coord1.zw = v.uv3;
    o.os_pos = v.vertex;
    o.ws_pos = mul(unity_ObjectToWorld, v.vertex);
    o.ss_pos = ComputeScreenPos(o.pos);
    o.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
    o.tangent.xyz = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
    o.tangent.w = v.tangent.w * unity_WorldTransformParams.w; 
    o.view = _WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, v.vertex).xyz;
    o.color = v.color;
    TRANSFER_SHADOW(o)
    return o;
}
vertex_out vs_edge (vertex_in v)
{
    vertex_out o;
    o.coord0.xy = v.uv0;
    o.coord0.zw = v.uv1;
    o.coord1.xy = v.uv2;
    o.coord1.zw = v.uv3;
    o.color = v.color;
    o.pos = UnityObjectToClipPos(v.vertex);
    float4 wv_pos = mul(UNITY_MATRIX_MV, v.vertex);
    o.normal = mul((float3x3)unity_ObjectToWorld, v.normal);
    o.tangent.xyz = mul((float3x3)unity_ObjectToWorld, v.tangent.xyz);
    o.tangent.w = v.tangent.w * unity_WorldTransformParams.w; 
    float3 bitangent = cross(o.normal, o.tangent.xyz) * o.tangent.w;
    float3 outline = 0;
    if((1.0 /*_Outline*/) > 0)
    {
        outline = ((1.0 /*_Outline*/) == 1) ? o.tangent : o.normal;
        float width = (0.11 /*_OutlineWidth*/) * 0.01;
        outline = mul((float3x3)UNITY_MATRIX_V, outline.xyz);
        if((0.0 /*_UseVertexGreen_OutlineWidth*/)) width *= v.color.y;
        if((0.0 /*_UseVertexColorB_InnerOutline*/) && ((6.0 /*_MaterialType*/) == 1)) width -= saturate(v.color.z - 0.9f);
        wv_pos.xyz = outline * max(width, 0.0f) + wv_pos;
        o.pos = mul(UNITY_MATRIX_P, wv_pos);
    }
    else // if no outline, then just set everything to 0 so it esentially doesnt display...
    {
        o = (vertex_out)0.0f; 
    }
    return o;
}
fixed4 ps_model (vertex_out i) : SV_Target
{
    float4 output = (float4)1.f;
    float2 uv = i.coord0.xy;
    UNITY_LIGHT_ATTENUATION(atten, i, i.ws_pos.xyz);
    float2 gradient = i.coord1.zw;
    float3 normal = normalize(i.normal);
    float4 tangent = i.tangent;
    float3 bitangent = normalize(cross(normal, tangent.xyz) * tangent.w);
    float3 view = normalize(i.view);
    float4 vertexcolor = i.color;
    float2 screen = (i.ss_pos.xy / i.ss_pos.w);
    float3 light = normalize(_WorldSpaceLightPos0.xyz);
    #ifdef _IS_PASS_LIGHT
        #if defined(POINT) || defined(SPOT) 
            light = normalize(_WorldSpaceLightPos0.xyz - i.ws_pos.xyz);
        #endif
    #endif
    float3 half_vector = normalize(light + view);
    float4 diffuse = _MainTex.Sample(sampler_MainTex, uv);
    float4 typemask = _TypeMask.Sample(sampler_linear_repeat, uv);
    float4 mask = _MaskTex.Sample(sampler_linear_repeat, uv);
    float4 normalmap = _Normal_Roughness_Metallic.Sample(sampler_linear_repeat, uv);
    float stencil_mask = _Mask.Sample(sampler_linear_repeat, uv).x;
    float shadow_mask = ((0.0 /*_UseMainTexA*/)) ? diffuse.w : mask.y;
    #if defined(use_normal)
    if((0.0 /*_UseNormalMap*/)) // only if normal mapping is enabled however
    {
        float3 map = ((0.0 /*_NormalFlip*/)) ? float3(1.f - normalmap.x, 1.f - normalmap.y, 1.f) : float3(normalmap.x, normalmap.y, 1.f);
        normal_online(map, i.ws_pos, uv, normal, (1.0 /*_NormalStrength*/));
    } 
    #endif
    float4 color = float4(1,1,1,1);
    color.xyz = diffuse.xyz * color;
    if((6.0 /*_MaterialType*/) == 3 || (6.0 /*_MaterialType*/) == 4) typemask.x = vertexcolor.x;
    float3 skin_id = skin_type(vertexcolor.x, typemask.x);
    float4 subsurface = lerp(float4(0.2140411,0.2140411,0.2140411,1), float4(0.8661774,0.3230001,0.1379704,1), skin_id.x);
    float3 spec = float3(1.0,1.0,1.0) * normalmap.zww;
    float4 shadow_color = (float4)1.0f;
    float shadow_area = 1.0f;
    float3 specular = (float3)0.0f;
    float3 emission = 0.0f;
    float4 matcap  = 0.0f;
    float3 rim_light = 0.0f;
    float3 shift = 0.0f;
    float3 ambient_color = max(half3(0.05f, 0.05f, 0.05f), max(ShadeSH9(half4(0.0, 0.0, 0.0, 1.0)),ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)).rgb));
    float3 light_color = max(ambient_color, _LightColor0.rgb);
    float3 GI_color = DecodeLightProbe(normal);
    GI_color = GI_color < float3(1,1,1) ? GI_color : float3(1,1,1);
    float GI_intensity = 0.299f * GI_color.r + 0.587f * GI_color.g + 0.114f * GI_color.b;
    GI_intensity = GI_intensity < 1 ? GI_intensity : 1.0f;
    if((6.0 /*_MaterialType*/) == 0) // base/body/cloth shading 
    {   
        stencil_mask = 0;
        #if defined(use_stocking)
            if((0.0 /*_UseStocking*/) && (skin_id.y > 0.5))
            {
                material_tight(color.xyz, shadow_color, specular, half_vector, light, normal, tangent, bitangent, i.ws_pos, uv, normalmap.xy, view, shadow_mask.x, skin_id.xy, typemask.xyz, shadow_area, shift, matcap, spec);
            }
            else 
            {
        #endif
            material_basic(color.xyz, shadow_color, specular, normal, light, half_vector, spec, uv, shadow_mask.x, skin_id.xyz, typemask.xyz, shadow_area, matcap);
            specular *= 1.0  - normalmap.w;
        #if defined(use_stocking)
            }
        #endif
    }
    #if defined(is_face)
    else if((6.0 /*_MaterialType*/) == 1) // face shading, there isnt
    {
        material_face(shadow_color.xyz, normal, light, uv, shadow_mask, skin_id, typemask.y, shadow_area);
    }
    #endif
    #if defined(is_eyes)
    else if((6.0 /*_MaterialType*/) == 2) // eyes shading
    {
        material_eye(color.xyz, stencil_mask, emission.xyz, normal, tangent, bitangent, uv, view, vertexcolor);
    }
    #endif
    #if defined(is_hair) || defined(is_bangs) 
    else if((6.0 /*_MaterialType*/) == 3 || (6.0 /*_MaterialType*/) == 4) // hair shading
    {
        stencil_mask = diffuse.w;
        material_hair(shadow_color.xyz, specular.xyz, normal, light, half_vector, mask, skin_id, shadow_area);
    }
    #endif
    #if defined(is_glass)
    else if((6.0 /*_MaterialType*/) == 5) // accessory shading
    {
        material_glass(color, normal, i.ss_pos.xyz / i.ss_pos.w, view, uv);
        clip(-1); // place holder for now until i can reverse engineer the logic for glass materials
    }
    #endif
    #if defined(is_tacet)
    else if((6.0 /*_MaterialType*/) == 6) // tacet shading
    {
        material_tacet(color.xyz, uv);
    }
    #endif
    #if defined(use_rim)
    if((1.0 /*_EnableRimLight*/))
    {
        rim_light = rim_lighting(normal, light, i.ss_pos.xyz / i.ss_pos.w, i.ws_pos);
    }
    #endif
    #if defined(_IS_PASS_BASE)
        output.xyz = color.xyz + rim_light;
        output.xyz = lerp(output.xyz * shadow_color, output.xyz, shadow_area);
        output.xyz = output.xyz + specular.xyz;
        output.xyz = output.xyz + emission;
        float emissive = 0.0f;
        #if defined(use_emission)
        emission_coloring(output.xyz, diffuse.w, emissive);
        #endif
        if(emissive <= 0.99f)
        {
            output.xyz =  output.xyz * light_color;
            output.xyz = output.xyz + (GI_color * GI_intensity * _GI_Intensity * smoothstep(1.0f ,0.0f, GI_intensity / 2.0f));
        }
        #if defined(can_debug)
            if((0.0 /*_DebugMode*/) == 1)
            {
                if((0.0 /*_DebugDiffuse*/) == 1) output.xyzw = float4(diffuse.xyz, 1.0f);
                if((0.0 /*_DebugDiffuse*/) == 2) output.xyzw = float4(diffuse.www, 1.0f);
                if((0.0 /*_DebugMaskTex*/) == 1) output.xyzw = float4(mask.xxx, 1.0f);
                if((0.0 /*_DebugMaskTex*/) == 2) output.xyzw = float4(mask.yyy, 1.0f);
                if((0.0 /*_DebugMaskTex*/) == 3) output.xyzw = float4(mask.zzz, 1.0f);
                if((0.0 /*_DebugMaskTex*/) == 4) output.xyzw = float4(mask.www, 1.0f);
                if((0.0 /*_DebugTypeMask*/) == 1) output.xyzw = float4(typemask.xxx, 1.0f);
                if((0.0 /*_DebugTypeMask*/) == 2) output.xyzw = float4(typemask.yyy, 1.0f);
                if((0.0 /*_DebugTypeMask*/) == 3) output.xyzw = float4(typemask.zzz, 1.0f);
                if((0.0 /*_DebugTypeMask*/) == 4) output.xyzw = float4(typemask.www, 1.0f);
                if((0.0 /*_DebugMask*/) == 1) output.xyzw = float4(stencil_mask.xxx, 1.0f);
                if((0.0 /*_DebugNormalMap*/) == 1) output.xyzw = float4(normalmap.xy, 1.0f, 1.0f);
                if((0.0 /*_DebugNormalMap*/) == 2) output.xyzw = float4(normalmap.zzz, 1.0f);
                if((0.0 /*_DebugNormalMap*/) == 3) output.xyzw = float4(normalmap.www, 1.0f);
                if((0.0 /*_DebugVertexColor*/) == 1) output.xyzw = float4(i.color.xxx, 1.0f);
                if((0.0 /*_DebugVertexColor*/) == 2) output.xyzw = float4(i.color.yyy, 1.0f);
                if((0.0 /*_DebugVertexColor*/) == 3) output.xyzw = float4(i.color.zzz, 1.0f);
                if((0.0 /*_DebugVertexColor*/) == 4) output.xyzw = float4(i.color.www, 1.0f);
                if((0.0 /*_DebugRimLight*/) == 1) output.xyzw = float4(rim_light.xyz, 1.0f);
                if((0.0 /*_DebugShadow*/) == 1) output.xyzw = float4(shadow_area.xxx, 1.0f);
                if((0.0 /*_DebugShadow*/) == 2) output.xyzw = float4(shadow_color.xyz, 1.0f);
                if((0.0 /*_DebugNormalVector*/) == 1) output.xyzw = float4(i.normal.xyz * 0.5f + 0.5f, 1.0f);
                if((0.0 /*_DebugNormalVector*/) == 2) output.xyzw = float4(i.normal.xyz, 1.0f);
                if((0.0 /*_DebugNormalVector*/) == 3) output.xyzw = float4(normal.xyz * 0.5f + 0.5f, 1.0f);
                if((0.0 /*_DebugNormalVector*/) == 4) output.xyzw = float4(normal.xyz, 1.0f);
                if((0.0 /*_DebugTangent*/) == 1) output.xyzw = float4(i.tangent.xyz, 1.0f);
                if((0.0 /*_DebugSpecular*/) == 1) output.xyzw = float4(specular.xyz, 1.0f);
                if((0.0 /*_DebugSpecular*/) == 1) output.xyzw = float4(matcap.xyz, 1.0f);
                if((0.0 /*_DebugSpecular*/) == 2) output.xyzw = float4(matcap.xyz, 1.0f);
                if((0.0 /*_DebugStocking*/) == 1) output.xyzw = float4(shift.xyz, 1.0f);
                if((0.0 /*_DebugMatcap*/) == 1)
                {
                    float2 sphere_uv = mul(normal, (float3x3)UNITY_MATRIX_I_V ).xy;
                    sphere_uv = sphere_uv * 0.5f + 0.5f;  
                    matcap = _MatCapTex.Sample(sampler_linear_repeat, sphere_uv);
                }
                if((0.0 /*_DebugMatcap*/) >= 1) output.xyzw = float4(matcap.xyz*matcap.w, 1.0f);
                if((0.0 /*_DebugFaceVector*/) == 1) output.xyzw = float4(normalize(UnityObjectToWorldDir(float4(0,0,1,0).xyz)).xyz, 1.0f);
                if((0.0 /*_DebugFaceVector*/) == 2) output.xyzw = float4(normalize(UnityObjectToWorldDir(float4(-1,0,0,0).xyz)).xyz, 1.0f);
                if((0.0 /*_DebugLights*/) == 1) return float4((float3)0.0f, 1.0f);
            }
        #endif
        #if defined(is_stencil)
            if((1.0 /*_EnabelStencil*/))
            {
                if((6.0 /*_MaterialType*/) == 2 || (6.0 /*_MaterialType*/) == 1)
                {
                    clip((stencil_mask) - 0.5f);
                    output.w = stencil_mask;
                }
                else if ((6.0 /*_MaterialType*/) == 3)
                {
                    if((1.0 /*_AlphaStencil*/))
                    {
                        output.w = stencil_mask;
                    }
                    else
                    {
                        clip((stencil_mask) - 0.8f);
                    }    
                }
                else 
                {
                    clip(-1);
                }
                return output;
            }
        #endif
        #if defined(_IS_PASS_SHADOW)
            if((6.0 /*_MaterialType*/) == 3)
            {
                float2 ramp_uv;
                ramp_uv.x = 0.1f;
                ramp_uv.y = 1.0 - 0.1;
                float3 ramp = _Ramp.Sample(sampler_linear_clamp, ramp_uv); 
                float3 hair_shadow = lerp(float4(0.8661482,0.3230331,0.137999,1), ramp, 0.4);
                hair_shadow = saturate(sqrt(hair_shadow + 0.25f));
                shadow_area =  dot(normal, normalize(_WorldSpaceLightPos0.xyz));
                hair_shadow = lerp(1.0f, hair_shadow, shadow_area);
                output.xyz = saturate(hair_shadow);
            }
            else if((6.0 /*_MaterialType*/) != 3)
            {
                clip(-1.f);
            }
        #endif
    #endif
    #if defined(_IS_PASS_LIGHT)
        shadow_area =  saturate(pow(shadow_area, 5.0f));
        if((6.0 /*_MaterialType*/) == 1) shadow_area = smoothstep(0.0, 0.5, saturate(dot(normal, light)));
        float light_intesnity = max(0.001f, (0.299f * _LightColor0.r + 0.587f * _LightColor0.g + 0.114f * _LightColor0.b));
        float3 light_pass_color = ((diffuse.xyz * 5.0f) * _LightColor0.xyz) * atten * saturate(shadow_area) * 0.5f;
        float3 light_pass_a_color = lerp(light_pass_color.xyz, lerp(0.0f, min(light_pass_color, light_pass_color / light_intesnity), _WorldSpaceLightPos0.w), (1.0 /*_FilterLight*/)); // prevents lights from becoming too intense
        if((6.0 /*_MaterialType*/) == 6) light_pass_a_color = float3(0.0f, 0.0f, 0.0f);
        #if defined(POINT) || defined(SPOT)
        output.xyz = (light_pass_a_color) * 0.5f;
        #elif defined(DIRECTIONAL)
        output.xyz = 0.0f; // dont let extra directional lights add onto the model, this will fuck a lot of shit up
        #endif
    #endif
    return output;
}
float4 ps_edge (vertex_out i) : SV_TARGET
{
    float3 GI_color = DecodeLightProbe(normalize(i.normal));
    GI_color = GI_color < float3(1,1,1) ? GI_color : float3(1,1,1);
    float GI_intensity = 0.299f * GI_color.r + 0.587f * GI_color.g + 0.114f * GI_color.b;
    GI_intensity = GI_intensity < 1 ? GI_intensity : 1.0f;  
    GI_color = (GI_color * GI_intensity * _GI_Intensity * smoothstep(1.0f ,0.0f, GI_intensity / 2.0f));
    float3 ambient_color = max(half3(0.05f, 0.05f, 0.05f), max(ShadeSH9(half4(0.0, 0.0, 0.0, 1.0)),ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)).rgb));
    float3 light_color = max(ambient_color, _LightColor0.rgb);
    float2 uv = i.coord0.xy;
    float4 diffuse = _OutlineTexture.Sample(sampler_linear_repeat, uv);
    float4 color = ((1.0 /*_UseMainTex*/)) ? diffuse * float4(0.5461946,0.5461946,0.5461946,1) :  float4(0.5461946,0.5461946,0.5461946,1);
    color.w = 1.f;
    color.xyz = color.xyz * light_color.xyz + GI_color;
    if((1.0 /*_Outline*/) == 0) clip(-1);
    if((6.0 /*_MaterialType*/) == 2 || (6.0 /*_MaterialType*/) >= 5 ) clip(-1); 
    return color;
}
