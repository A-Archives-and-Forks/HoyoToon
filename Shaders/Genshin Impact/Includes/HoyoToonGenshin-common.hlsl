float materialID(float alpha)
{
    float region = alpha;

    float material = 1.0f;

    material = (_UseMaterial2 && (region >= 0.8f)) ? 2.0f : 1.0f;
    material = (_UseMaterial3 && (region >= 0.4f && region <= 0.6f)) ? 3.0f : material;
    material = (_UseMaterial4 && (region >= 0.2f && region <= 0.4f)) ? 4.0f : material;
    material = (_UseMaterial5 && (region >= 0.6f && region <= 0.8f)) ? 5.0f : material;

    return material;
}

float isDithered(float2 pos, float alpha) 
{
    pos *= _ScreenParams.xy;

    // Define a dither threshold matrix which can
    // be used to define how a 4x4 set of pixels
    // will be dithered
    float DITHER_THRESHOLDS[16] =
    {
        1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
        13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
        4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
        16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
    };

    int index = (int(pos.x) % 4) * 4 + int(pos.y) % 4;
    return alpha - DITHER_THRESHOLDS[index];
}

void ditherClip(float2 pos, float alpha)
{
    clip(isDithered(pos, alpha));
}


// from: https://github.com/cnlohr/shadertrixx/blob/main/README.md#best-practice-for-getting-depth-of-a-given-pixel-from-the-depth-texture
float GetLinearZFromZDepth_WorksWithMirrors(float zDepthFromMap, float2 screenUV)
{
	#if defined(UNITY_REVERSED_Z)
	zDepthFromMap = 1 - zDepthFromMap;
			
	// When using a mirror, the far plane is whack.  This just checks for it and aborts.
	if( zDepthFromMap >= 1.0 ) return _ProjectionParams.z;
	#endif

	float4 clipPos = float4(screenUV.xy, zDepthFromMap, 1.0);
	clipPos.xyz = 2.0f * clipPos.xyz - 1.0f;
	float4 camPos = mul(unity_CameraInvProjection, clipPos);
	return -camPos.z / camPos.w;
}

float3 DecodeLightProbe( float3 N )
{
    return ShadeSH9(float4(N,1));
}

float4 maintint(float4 diffuse)
{
    float4 screen = diffuse;
    float4 u_xlat16_4 = screen * _MainTexTintColor;
    float4 u_xlat16_5 = u_xlat16_4 + u_xlat16_4;
    float4 u_xlat16_6 = screen + _MainTexTintColor;
    u_xlat16_6.xyz = u_xlat16_6.xyz + u_xlat16_6.xyz;
    u_xlat16_4.xyz = u_xlat16_4.xyz * float3(-4.0, -4.0, -4.0) + u_xlat16_6.xyz;
    u_xlat16_6.x = (0.5f < screen.x) ? float(1.0) : float(0.0);
    u_xlat16_6.y = (0.5f < screen.y) ? float(1.0) : float(0.0);
    u_xlat16_6.z = (0.5f < screen.z) ? float(1.0) : float(0.0);
    u_xlat16_4.xyz = u_xlat16_4.xyz + float3(-1.0, -1.0, -1.0);
    u_xlat16_4.xyz = u_xlat16_6.xyz * u_xlat16_4.xyz + u_xlat16_5.xyz;
    return u_xlat16_4;
}

float get_index(float material_id)
{
    // prevents a returned negative index on certain GPUs
    return max(0, material_id - 1);
}

float4 coloring(float region)
{
    float4 colors[5] = 
    {
        _Color,
        _Color2,
        _Color3,
        _Color4,
        _Color5,
    };

    float4 color = _Color;
    color = colors[region - 1.0f];

    color = (!_DisableColors) ? color : (float4)1.0f;
    return color;
}

float4 material_mask_coloring(float4 mask)
{

    return 1;

}

float packed_channel_picker(SamplerState texture_sampler, Texture2D texture_2D, float2 uv, float channel)
{
    float4 packed = texture_2D.SampleLevel(texture_sampler, uv, 0);

    float choice;
    if(channel == 0) {choice = packed.x;}
    else if(channel == 1) {choice = packed.y;}
    else if(channel == 2) {choice = packed.z;}
    else if(channel == 3) {choice = packed.w;}

    return choice;
}


float3 hue_shift(float3 in_color, float material_id, float shift1, float shift2, float shift3, float shift4, float shift5, float shiftglobal, float autobool, float autospeed, float mask)
{   
    if(!_EnableHueShift) return in_color;
    float auto_shift = (_Time.y * autospeed) * autobool; 
    
    float shift[5] = 
    {
        shift1,
        shift2,
        shift3,
        shift4,
        shift5
    };
    
    float shift_all = 0.0f;
    if(shift[get_index(material_id)] > 0)
    {
        shift_all = shift[get_index(material_id)] + auto_shift;
    }
     
    
    auto_shift = (_Time.y * autospeed) * autobool; 
    if(shiftglobal > 0)
    {
        shiftglobal = shiftglobal + auto_shift;
    }
    

    float hue = shift_all + shiftglobal;
    hue = lerp(0.0f, 6.27f, hue);

    float3 k = (float3)0.57735f;
    float cosAngle = cos(hue);

    float3 adjusted_color = in_color * cosAngle + cross(k, in_color) * sin(hue) + k * dot(k, in_color) * (1.0f - cosAngle);

    return lerp(in_color, adjusted_color, mask);
}

float3 normal_mapping(float3 normalmap, float4 vertexws, float2 uv, float3 normal)
{
    float3 bumpmap = normalmap.xyz;
    bumpmap.xy = bumpmap.xy * 2.0f - 1.0f;

    bumpmap.z = max(-min(_BumpScale, 0.5f) + 1.0f, 0.001f);
    bumpmap.xyz = _DummyFixedForNormal ? bumpmap : normalize(bumpmap);   // why why why

    // world space position derivative
    float3 p_dx = ddx(vertexws);
    float3 p_dy = ddy(vertexws);  
    // texture coord derivative
    float3 uv_dx;
    uv_dx.xy = ddx(uv);
    float3 uv_dy;
    uv_dy.xy = ddy(uv); 
    uv_dy.z = -uv_dx.y;
    uv_dx.z = uv_dy.x;  
    // this functions the same way as the w component of a traditional set of tangents.
    // determinent of the uv the direction of the bitangent
    float3 uv_det = dot(uv_dx.xz, uv_dy.yz);
    uv_det = -sign(uv_det); 
    // normals are inverted in the case of a back-facing poly
    // useful for the two sided dresses and what not... 
    float3 corrected_normal = normal;   
    float2 tangent_direction = uv_det.xy * uv_dy.yz;
    float3 tangent = (tangent_direction.y * p_dy.xyz) + (p_dx * tangent_direction.x);
    tangent = normalize(tangent);
    float3 bitangent = cross(corrected_normal.xyz, tangent.xyz);
    bitangent = bitangent * -uv_det;    
    
    float3x3 tbn = {tangent, bitangent, corrected_normal};  
    float3 mapped_normals = mul(bumpmap.xyz, tbn);
    mapped_normals = normalize(mapped_normals); // for some reason, this normalize messes things up in mmd  
    mapped_normals = (0.99f >= bumpmap.z) ? mapped_normals : corrected_normal;  
    return mapped_normals; 
}

void detail_line(float2 sspos, float sdf, inout float3 diffuse)
{
    float3 line_color = (_TextureLineMultiplier.xyz * diffuse.xyz - diffuse.xyz) * _TextureLineMultiplier.www;
    float line_dist = LinearEyeDepth(sspos.x / sspos); // this may need to be replaced with the version that works for mirrors, will wait for feedback    
    float line_thick = _TextureLineDistanceControl.x * line_dist + _TextureLineThickness;
    line_thick = 1.0f - min(line_thick, min(_TextureLineDistanceControl.y, 0.99f)); 
    line_dist = (line_dist > _TextureLineDistanceControl.z) ? 1.0f : 0.0f;
    line_thick = 1.0f - line_thick;

    float line_smooth = -_TextureLineSmoothness * line_dist + line_thick;
    line_dist = _TextureLineSmoothness * line_dist + line_thick;
    line_dist = -line_smooth + line_dist;   
    float lines = sdf - line_smooth;
    line_dist = 1.0f / line_dist;
    lines = lines * line_dist;
    lines = saturate(lines);
    line_dist = lines * -2.0f + 3.0f;
    lines = lines * lines;
    lines = lines * line_dist;
    // these 6 lines above are a smoothstep
    diffuse.xyz = lines * line_color + diffuse.xyz;
}

float shadow_area_face(float2 uv, float3 light)
{   
    // float3 light = normalize(_WorldSpaceLightPos0.xyz);
    #if defined(faceishadow)
        float3 head_forward = normalize(UnityObjectToWorldDir(_headForwardVector.xyz));
        float3 head_right   = normalize(UnityObjectToWorldDir(_headRightVector.xyz));
        float rdotl = dot((head_right.xz),  (light.xz));
        float fdotl = dot((head_forward.xz), (light.xz));

        float2 faceuv = 1.0f;
        if(rdotl > 0.0f )
        {
            faceuv = uv;
        }  
        else
        {
            faceuv = uv * float2(-1.0f, 1.0f) + float2(1.0f, 0.0f);
        }

        float shadow_step = 1.0f - (fdotl * 0.5f + 0.5f);

        // apply rotation offset
        shadow_step = smoothstep(max(_FaceMapRotateOffset, 0.0), min(_FaceMapRotateOffset + 1.0f, 1.0f), shadow_step);
        
        // use only the alpha channel of the texture 
        float facemap = _FaceMapTex.Sample(sampler_linear_repeat, faceuv).w;
        // interpolate between sharp and smooth face shading
        shadow_step = smoothstep(shadow_step - (_FaceMapSoftness), shadow_step + (_FaceMapSoftness), facemap);
        
        if(_UseFaceBlueAsAO) shadow_step = shadow_step * _LightMapTex.Sample(sampler_linear_repeat, uv).b;
    #else 
        float shadow_step = 1.0f;
    #endif

    return shadow_step;
}

float3 shadow_area_ramp(float lightmapao, float vertexao, float vertexwidth, float ndotl, float material_id)
{
    float3 shadow = 1.0f;

    lightmapao = (_UseLightMapColorAO) ? lightmapao + -0.5f : 0.0f;
    float shadow_thresh = dot(lightmapao.xx, abs(lightmapao.xx)) + 0.5f;
    shadow_thresh = (_UseVertexColorAO) ? shadow_thresh * vertexao : shadow_thresh;

    float shadow_bright = 0.95f < shadow_thresh;
    float shadow_dark = shadow_thresh < 0.05f;

    float shadow_area = (shadow_bright) ? 1.0f : ((ndotl * 0.5f + 0.5f) + shadow_thresh) * 0.5f;
    shadow_area = (shadow_dark) ? 0.0f : shadow_area;

    float shadow_check = shadow_area < _LightArea;
    
    shadow_area = (-shadow_area + _LightArea) / _LightArea;

    float width = (_UseVertexRampWidth) ? max(0.01f, vertexwidth + vertexwidth) * _ShadowRampWidth : _ShadowRampWidth;

    shadow_area = shadow_area / width;

    shadow.x = 1.0f - min(shadow_area, 1.0f);
    shadow.x = shadow_check ? shadow.x : 1.0f;
    shadow.y = shadow_check ? 1.0f : 0.0f; 
    shadow.z = shadow_area;

    return shadow;
}

float shadow_area_transition(float lightmapao, float vertexao, float ndotl, float material_id)
{
    float shadow = 1.0f;

    lightmapao = (_UseLightMapColorAO) ? lightmapao - 0.5f: 0.5f;

    float shadow_thresh = dot(lightmapao.xx, abs(lightmapao.xx)) + 0.5f;
    shadow_thresh = (_UseVertexColorAO) ? shadow_thresh * vertexao : shadow_thresh;

    float shadow_bright = shadow_thresh > 0.95f; 
    float shadow_dark = shadow_thresh < 0.05f;

    shadow_thresh = (shadow_thresh + (ndotl * 0.5f + 0.5f)) * 0.5f;
    
    shadow = (shadow_bright) ? 1.0f : shadow_thresh;
    shadow = (shadow_dark) ? 0.0f : shadow;
    float transition; 
    float area = (shadow < _LightArea);
    
    #ifdef _IS_PASS_LIGHT
    float2 trans_value[5] =
    {
        float2(0.1f, 1.0f),
        float2(0.1f, 1.0f),
        float2(0.1f, 1.0f),
        float2(0.1f, 1.0f),
        float2(0.1f, 1.0f),
    };
    #else
    float2 trans_value[5] =
    {
        float2(_ShadowTransitionRange, _ShadowTransitionSoftness),
        float2(_ShadowTransitionRange2, _ShadowTransitionSoftness2),
        float2(_ShadowTransitionRange3, _ShadowTransitionSoftness3),
        float2(_ShadowTransitionRange4, _ShadowTransitionSoftness4),
        float2(_ShadowTransitionRange5, _ShadowTransitionSoftness5),
    };
    #endif
    

    shadow = -shadow + _LightArea;
    shadow = shadow / trans_value[get_index(material_id)].x;
    float check = shadow.x >= 1.0f;
    transition = min(pow(shadow + 0.009f, trans_value[get_index(material_id)].y), 1.0f);

    shadow = (check) ? 1.0f : transition;
    shadow = (_UseShadowTransition) ? shadow : 1.0f;
    shadow = (area) ? shadow : 0.0f;

    #ifdef _IS_PASS_LIGHT
    shadow.x = saturate(1.0f - shadow.x);
    #endif

    return shadow;
}

void shadow_color(in float lightmapao, in float vertexao, in float customao, in float vertexwidth, in float ndotl, in float material_id, in float2 uv, inout float3 shadow, inout float3 metalshadow, inout float3 color, float3 light)
{   
    #if defined(use_shadow)
        float ao = 1.0f;
        if(_CustomAOEnable) ao = customao;
        float3 outcolor = (float3)1.0f;
        float4 warm_shadow_array[5] = 
        {
            _FirstShadowMultColor,
            _FirstShadowMultColor2,
            _FirstShadowMultColor3,
            _FirstShadowMultColor4,
            _FirstShadowMultColor5,
        };
        float4 cool_shadow_array[5] =
        {
            _CoolShadowMultColor,
            _CoolShadowMultColor2,
            _CoolShadowMultColor3,
            _CoolShadowMultColor4,
            _CoolShadowMultColor5,
        };
        outcolor = lerp(warm_shadow_array[get_index(material_id)], cool_shadow_array[get_index(material_id)], _DayOrNight);
        
        float3 outshadow = (float3)1.0f;
        if(_UseShadowRamp) outshadow = shadow_area_ramp(lightmapao, vertexao, vertexwidth, ndotl, material_id);
        if(!_UseShadowRamp) outshadow = shadow_area_transition(lightmapao, vertexao, ndotl, material_id);  

        if(_UseFaceMapNew)
        {
            outshadow = shadow_area_face(uv, light).xxx;
            if(_CustomAOEnable) outshadow = outshadow * customao;        
        }
        shadow = outshadow;
        metalshadow = outshadow;

        

        if(_UseShadowRamp)
        {

            #if defined(has_sramp)
            float2 day_ramp_coords = -((get_index(material_id)) * 0.1f + 0.05f) + 1.0f;
            day_ramp_coords.x = shadow.x * ao;
            float2 night_ramp_coords = -((get_index(material_id)) * 0.1f + 0.55f) + 1.0f;
            night_ramp_coords.x = shadow.x * ao;
            float3 dayramp = _PackedShadowRampTex.SampleLevel(sampler_linear_clamp, day_ramp_coords, 0.0f).xyz;
            float3 nightramp = _PackedShadowRampTex.SampleLevel(sampler_linear_clamp, night_ramp_coords, 0.0f);
            float3 ramp = lerp(dayramp, nightramp, _DayOrNight);
            color = lerp(1.0f, ramp, saturate(shadow.y + (1.0f - ao)));
            #endif
        }
        else if(_UseFaceMapNew)
        {
            color = lerp(outcolor, 1.0f, shadow.x);
        }
        else
        {
            color = lerp(1.0f, outcolor, shadow.x);
        }
    #endif
}

void metalics(in float3 shadow, in float3 normal, float3 ndoth, float speculartex, float backfacing, inout float3 color)
{
    #if defined(use_metal)
        float shadow_transition = ((bool)shadow.y) ? shadow.z : 0.0f;
        shadow_transition = saturate(shadow_transition);

        // calculate centered sphere coords for spheremapping
        float2 sphere_uv = mul(normal, (float3x3)UNITY_MATRIX_I_V ).xy;
        sphere_uv.x = sphere_uv.x * _MTMapTileScale; 
        sphere_uv = sphere_uv * 0.5f + 0.5f;  

        // sample sphere map 
        float sphere = _MTMap.Sample(sampler_linear_repeat, sphere_uv).x;
        sphere = sphere * _MTMapBrightness;
        sphere = saturate(sphere);
        
        // float3 metal_color = sphere.xxx;
        float3 metal_color = lerp(_MTMapDarkColor, _MTMapLightColor, sphere.xxx);
        metal_color = color * metal_color;

        ndoth = max(0.001f, ndoth);
        ndoth = pow(ndoth, _MTShininess) * _MTSpecularScale;
        ndoth = saturate(ndoth);

        float specular_sharp = _MTSharpLayerOffset<ndoth;

        float3 metal_specular = (float3)ndoth;
        if(specular_sharp)
        {
            metal_specular = _MTSharpLayerColor;
        }
        else
        {
            if(_MTUseSpecularRamp)
            {
                metal_specular = _MTSpecularRamp.Sample(sampler_linear_clamp, float2(metal_specular.x, 0.5f)) * _MTSpecularColor;
                metal_specular = metal_specular * speculartex; 
            }
            else
            {  
                metal_specular = metal_specular * _MTSpecularColor;
                metal_specular = metal_specular * speculartex; 
            }    
        }

        float3 metal_shadow = lerp(1.0f, _MTShadowMultiColor, shadow_transition);
        metal_specular = lerp(metal_specular , metal_specular * _MTSpecularAttenInShadow, shadow_transition);
        float3 metal = metal_color + (metal_specular * (float3)0.5f);
        metal = metal * metal_shadow;  

        float metal_area = saturate((speculartex > 0.89f) - _UseCharacterLeather);

        if(_DebugMode && (_DebugMetal == 1))
        {
            metal = (metal_area) ? metal : (float3)0.0f;
            color.xyz = metal;
        }
        else
        {
            metal = (metal_area) ? metal : color;
            color.xyz = metal; 
        }
    #endif

}

void specular_color(in float ndoth, in float3 shadow, in float lightmapspec, in float lightmaparea, in float material_id, inout float3 specular)
{
    #if defined(use_specular)
        float2 spec_array[5] =
        {
            float2(_Shininess, _SpecMulti),
            float2(_Shininess2, _SpecMulti2),
            float2(_Shininess3, _SpecMulti3),
            float2(_Shininess4, _SpecMulti4),
            float2(_Shininess5, _SpecMulti5),        
        };

        float4 color_array[5] =
        {
            _SpecularColor, 
            _SpecularColor2, 
            _SpecularColor3, 
            _SpecularColor4, 
            _SpecularColor5, 
        };
        
        float term = ndoth;
        term = pow(max(ndoth, 0.001f), spec_array[get_index(material_id)].x);
        float check = term > (-lightmaparea + 1.015);
        specular = term * (color_array[get_index(material_id)] * spec_array[get_index(material_id)].y) * lightmapspec; 
        specular = lerp((float3)0.0f, specular * (float3)0.5f, check);
    #endif 
}

void leather_color(in float ndoth, in float3 normal, in float3 light, in float lightmapspec, inout float3 leather, inout float3 holographic, inout float3 color)
{
    #if defined(use_leather)
        float2 sphere_uv = mul(normal , (float3x3)UNITY_MATRIX_I_V).xy; 
        float xaxis = sphere_uv.x * 0.5f + 0.5f;
        float area =  pow( 4.0 * xaxis * (1.0 - xaxis), 1); // this is to fix any weird edge when offseting the sphere coords
        sphere_uv.y = lerp(sphere_uv.y, sphere_uv.y + _LeatherReflectOffset, area);
        sphere_uv.x = sphere_uv.x * _MTMapTileScale;
        sphere_uv = sphere_uv * 0.5f + 0.5f;  

        // sample the leather matcap first before calculating the specular shines, i just felt like it
        float3 matcap = _LeatherReflect.SampleLevel(sampler_linear_repeat, sphere_uv, _LeatherReflectBlur) * _LeatherReflectScale;
        // blur controls the miplevel of the matcap giving a quick way to blur/soften the shine

        // main shine
        float specular = min(pow(max(ndoth, 0.001f), _LeatherSpecularRange), 1.0f);
        specular = smoothstep(0.5, _LeatherSpecularSharpe, specular.x) * _LeatherSpecularScale;

        // detail shine
        float3 detail = min(pow(max(ndoth, 0.001f), _LeatherSpecularDetailRange), 1.0f);
        detail = smoothstep(0.5f, _LeatherSpecularDetailSharpe, detail.x) * _LeatherSpecularDetailScale;
        detail = detail.xxx * _LeatherSpecularDetailColor.xyz;

        // holographic
        float holo = saturate(dot(normal, light) * 0.5f + 0.5f) * _LeatherLaserTiling + _LeatherLaserOffset;
        float3 holo_ramp = _LeatherLaserRamp.Sample(sampler_MainTex, holo.xx).xyz * _LeatherLaserScale;

        // combined
        float3 combined = max(matcap, specular * _LeatherSpecularColor + detail);

        leather = 0 + combined;
        leather = saturate(holo_ramp * holo_ramp + leather);
        color = (lightmapspec * leather) + color;
    #endif
    
}

void glass_color(inout float4 color, in float4 uv, in float3 view, in float3 normal)
{   
    #if defined(parallax_glass)
        float2 specular_uv = (uv.zw * _GlassSpecularTex_ST.xy) * (float2)_GlassTiling + _GlassSpecularTex_ST.zw;
        specular_uv = (_GlassSpecularOffset + -1.0f) * view.xy + specular_uv;
        float2 detail_uv = (float2)_GlassSpecularDetailOffset * (float2)1.0f + specular_uv;

        float shine_a = _GlassSpecularTex.Sample(sampler_MainTex, specular_uv).x;
        float shine_b = _GlassSpecularTex.Sample(sampler_MainTex, detail_uv).y;

        float detail_length = (uv.w + (-_GlassSpecularDetailLength)) / max(_GlassSpecularDetailLengthRange, 0.0001f);
        detail_length = saturate(detail_length);
        float3 detail = (detail_length * shine_b) * _GlassSpecularDetailColor ;

        float specular_length = (uv.w + (-_GlasspecularLength)) / max(_GlasspecularLengthRange, 0.0001f);
        specular_length = saturate(specular_length);
        float3 specular = ((specular_length * shine_a) * _GlassSpecularColor) + detail;

        float ndotv = pow(1.0 - dot(normal, view), _GlassThickness) * _GlassThicknessScale;
        float3 thickness = saturate(ndotv * _GlassThickness) * _GlassThicknessColor;

        specular = specular + thickness;

        float4 main = _MainTex.Sample(sampler_MainTex, uv.xy);

        color.xyz = (main * _MainColor) * _MainColorScaler + specular;
        color.w = main.w;
    #endif
}

float pulsate(float rate, float max_value, float min_value, float time_offset)
{
    float pulse = sin(_Time.yy * rate + time_offset) * 0.5f + 0.5f;
    return pulse = smoothstep(min_value, max_value, pulse);
}

float4 emission_color(in float3 color, in float material_id)
{
    float3 e_color[5] =
    {
        float3((_EmissionColor1_MHY * max(_EmissionScaler1 / 2, 1.0f)).xyz),
        float3((_EmissionColor2_MHY * max(_EmissionScaler2 / 2, 1.0f)).xyz),
        float3((_EmissionColor3_MHY * max(_EmissionScaler3 / 2, 1.0f)).xyz),
        float3((_EmissionColor4_MHY * max(_EmissionScaler4 / 2, 1.0f)).xyz),
        float3((_EmissionColor5_MHY * max(_EmissionScaler5 / 2, 1.0f)).xyz),
    };

    float e_scaler[5] =
    {
        _EmissionScaler1,
        _EmissionScaler2,
        _EmissionScaler3,
        _EmissionScaler4,
        _EmissionScaler5,
    };
    float array_index = max(get_index(material_id), 0);

    float3 emission = e_color[get_index(material_id)].xyz * (_EmissionColor_MHY * max(_EmissionScaler / 2, 1.0f)) * color; 
    return max(float4(emission.xyz, e_scaler[get_index(material_id)] * _EmissionScaler), 0.0f);
}

float4 emission_color_eyes(in float3 color, in float material_id)
{
    return max(float4((_EmissionColorEye * max(_EmissionScaler, 1.0f)) * max(_EyeGlowStrength, 1.0f) * color, _EmissionScaler * _EyeGlowStrength), 0.0f);
}

float3 outline_emission(in float3 color, in float material_id)
{
    float4 e_color[5] = 
    {
        _OutlineGlowColor,
        _OutlineGlowColor2,
        _OutlineGlowColor3,
        _OutlineGlowColor4,
        _OutlineGlowColor5,
    };

    float3 emission = e_color[get_index(material_id)].xyz * _OutlineGlowInt * color;
    return emission;
}

float3 custom_ramp_color(float ramp)
{
    float3 color = _RampPoint0.xyz;
    if(ramp < 0.45f)
    {
        ramp = smoothstep(0.0f, 0.45f, ramp);
        color = lerp(_RampPoint0.xyz, _RampPoint1.xyz, ramp);
    }
    else
    {
        ramp = smoothstep(0.45f, 1.0f, ramp);
        color = lerp(_RampPoint1.xyz, _RampPoint2.xyz, ramp);
    }
    return color;
}

void nyx_state_marking(inout float3 color, in float2 uv0, in float2 uv1, in float2 uv2, in float2 uv3, in float3 normal, in float3 view, in float4 ws_pos)
{
    #if defined(nyx_body)

        float2 uv[4] = 
        {
            uv0,
            uv1,
            uv2,
            uv3
        };


        float nyx_mask = packed_channel_picker(sampler_linear_repeat, _TempNyxStatePaintMaskTex, uv[_NyxBodyUVCoord], _TempNyxStatePaintMaskChannel); 
        
        
        float4 screen_uv = (((ws_pos.xyxy / ws_pos.wwww) * _ScreenParams.xyxy) / _ScreenParams.xxxx);
        float4 noise_uv = _Time.yyyy * _NyxStateOutlineColorNoiseAnim.zwxy;
        noise_uv = frac(noise_uv);
        screen_uv = screen_uv * _NyxStateOutlineColorNoiseScale.xyxy + noise_uv;
        float noise_a = _NyxStateOutlineNoise.Sample(sampler_linear_repeat, screen_uv.xy).x;
        screen_uv.xy = noise_a.xx * (float2)_NyxStateOutlineColorNoiseTurbulence + screen_uv.zw;
        float2 ramp_uv;
        float2 time_uv;
        ramp_uv.x = _NyxStateOutlineNoise.Sample(sampler_linear_repeat, screen_uv.xy).x;
        ramp_uv.y = float(0.75);
        time_uv.y = float(0.25);
        float3 nyx_ramp = _NyxStateOutlineColorRamp.Sample(sampler_linear_repeat, ramp_uv.xy, 0.0).xyz;
        time_uv.x = (_DayOrNight) ? 0 : 1;
        float3 time_ramp = _NyxStateOutlineColorRamp.Sample(sampler_linear_repeat, time_uv.xy, 0.0).xyz;
        if(_NyxStateRampType == 1) 
        {
            nyx_ramp = custom_ramp_color(ramp_uv.x);
        }

        float nyx_brightness = max(nyx_ramp.z, nyx_ramp.y);
        nyx_brightness = max(nyx_ramp.x, nyx_brightness);
        float bright_check = 1.0f < nyx_brightness;
        nyx_ramp.xyz = bright_check ? (nyx_ramp * (1.0f / nyx_brightness)) : nyx_ramp;
        
        nyx_ramp = nyx_ramp * _NyxStateOutlineColorScale;

        color = lerp(color, (nyx_ramp * time_ramp) * _NyxStateOutlineColorOnBodyMultiplier.xyz, nyx_mask * _NyxStateOutlineColorOnBodyOpacity);
    #endif
}

void fresnel_hit(in float ndotv, inout float3 color)
{   
    #if defined(has_fresnel)
        ndotv = saturate(ndotv);
        ndotv = max(pow(1.0f - ndotv, _HitColorFresnelPower), 0.00001f);
        float3 rim_color = max(_ElementRimColor.xyz, _HitColor.xyz);
        color = (rim_color * ndotv) * (float3)_HitColorScaler + color;
    #endif
}

float extract_fov()
{
    return 2.0f * atan((1.0f / unity_CameraProjection[1][1]))* (180.0f / 3.14159265f);
}

float fov_range(float old_min, float old_max, float value)
{
    float new_value = (value - old_min) / (old_max - old_min);
    return new_value; 
}

float outlinelerp(float start_scale, float end_scale, float start_z, float end_z, float z)
{
    float t = (z - start_z) / max(end_z - start_z, 0.001f);
    t = saturate(t);
    return lerp(start_scale, end_scale, t);
}

bool isVR()
{
    // USING_STEREO_MATRICES
    #if UNITY_SINGLE_PASS_STEREO
        return true;
    #else
        return false;
    #endif
}

// genshin fov range = 30 to 90
float3 camera_position()
{
    #ifdef USING_STEREO_MATRICES
        return lerp(unity_StereoWorldSpaceCameraPos[0], unity_StereoWorldSpaceCameraPos[1], 0.5);
    #endif
    return _WorldSpaceCameraPos;
}

float3 rimlighting(float4 sspos, float3 normal, float4 wspos, float3 light, float material_id, float3 color, float3 view)
{
    float3 rim_light = (float3)0.0f;
    #if defined(use_rimlight)
        if(_RimLightType == 2) // new type rimlight, based on games implementation as of 4.0+
        {
            float2 screen_pos = sspos.xy / sspos.w;

            float fov = extract_fov();
            fov = clamp(fov, 0, 150);
            float range = fov_range(0, 180, fov);

            float4 camera_pos =  mul(unity_WorldToCamera, wspos);
            float camera_depth = saturate(1.0f - ((camera_pos.z / camera_pos.w) / 5.0f));

            float3 offset = (_UseFaceMapNew) ?  mul(unity_WorldToCamera, wspos).xyz :  mul((float3x3)unity_WorldToCamera, normal);
            offset.z = (_UseFaceMapNew) ? -0.01 : 0.01f;
            offset = normalize(offset);
            float depth_og = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screen_pos), screen_pos);

            float something = camera_depth / range;

            float rim_width = _ES_AvatarRimWidthScale * _ES_AvatarRimWidth;
            float2 offset_uv = screen_pos;
            offset_uv.x = offset_uv.x  + (offset.x * ((rim_width * 0.00044f) * something )).x;

            float depth_off = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offset_uv), offset_uv);

            float depth_diff = (-depth_og) + depth_off; 

            depth_diff = max(depth_diff, 0.000001f);
            depth_diff = pow(depth_diff, 0.05f);
            depth_diff = (depth_diff - 0.81f) * 12.5f;
            depth_diff = saturate(depth_diff);
            
            float rim_depth = depth_diff * -2.0f + 3.0f;
            depth_diff = depth_diff * depth_diff;
            depth_diff = depth_diff * rim_depth;
            // rim_depth = (-depth_og) + 2.0f;
            // rim_depth = rim_depth * 0.3f + depth_og;
            // rim_light = depth_diff;
            depth_diff = saturate(depth_diff);

            
            float3 rim_vector = normalize(view + -_WorldSpaceLightPos0.xyz);

            float3 front_rim = 1.0f -  dot(normal, rim_vector);
            float3 back_rim = dot(normal, rim_vector);
            back_rim = pow(back_rim, 7.5f);
            front_rim = pow(front_rim, 7.5f);
            front_rim = saturate(front_rim);
            back_rim = saturate(back_rim);
            
            back_rim = (back_rim * (_ES_AvatarBackRimIntensity * (_ES_AvatarBackRimColor)));
            front_rim = ((((_ES_AvatarFrontRimIntensity * (_ES_AvatarFrontRimColor)) * front_rim ) + back_rim));
                        
            float3 rim_color = color * 5.0f;
            rim_color = (rim_color) * saturate(_LightColor0.xyz + 0.1f);
            
            rim_light = front_rim * rim_color;
            rim_light = rim_light * depth_diff;
            rim_light = saturate(rim_light * camera_depth);
        }
        else // legacy rim light mode, based on implementation as of 1.5
        {
            // // instead of relying entirely on the camera depth texture, calculate a camera depth vector like this
            float4 camera_pos =  mul(unity_WorldToCamera, wspos);
            float camera_depth = saturate(1.0f - ((camera_pos.z / camera_pos.w) / 5.0f)); // tuned for vrchat

            float fov = extract_fov();
            fov = clamp(fov, 0, 150);
            float range = fov_range(0, 180, fov);
            float width_depth = camera_depth / range;
            float rim_width = lerp(_RimLightThickness * 0.5f, _RimLightThickness * 0.45f, range) * width_depth;

            if(isVR())
            {
                rim_width = rim_width * 0.66f;
            }
            // screen space uvs
            float2 screen_pos = sspos.xy / sspos.w;

            // camera space normals : 
            float3 vs_normal = mul((float3x3)unity_WorldToCamera, normal);
            vs_normal.z = 0.001f;
            vs_normal = normalize(vs_normal);

            // screen normals reconstructed using screen position
            float cs_ndotv = -dot(-view.xyz, vs_normal) + 1.0f;
            cs_ndotv = saturate(cs_ndotv);
            cs_ndotv = max(cs_ndotv, 0.0099f);
            float cs_ndotv_pow = pow(cs_ndotv, 5.0f);

            // sample original camera depth texture
            float4 depth_og = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screen_pos), screen_pos);

            float3 normal_cs = mul((float3x3)unity_WorldToCamera, normal);
            normal_cs.z = 0.001f;
            normal_cs.xy = normalize(normal_cs.xyz).xy;
            normal_cs.xyz = normal_cs.xyz * (rim_width);
            float2 pos_offset = normal_cs * 0.001f + screen_pos;
            // sample offset depth texture 
            float depth_off = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, pos_offset), pos_offset);

            float depth_diff = (-depth_og) + depth_off;

            depth_diff = max(depth_diff, 0.001f);
            depth_diff = pow(depth_diff, 0.04f);
            depth_diff = (depth_diff - 0.8f) * 10.0f;
            depth_diff = saturate(depth_diff);
            
            float rim_depth = depth_diff * -2.0f + 3.0f;
            depth_diff = depth_diff * depth_diff;
            depth_diff = depth_diff * rim_depth;
            rim_depth = (-depth_og) + 2.0f;
            rim_depth = rim_depth * 0.3f + depth_og;
            rim_depth = min(rim_depth, 1.0f);
            depth_diff = depth_diff * rim_depth;

            depth_diff = lerp(depth_diff, 0.0f, saturate(step(depth_diff, _RimThreshold)));

            float4 rim_colors[5] = 
            {
                _RimColor1, _RimColor2, _RimColor3, _RimColor4, _RimColor5
            };

            // get rim light color 
            float3 rim_color = rim_colors[get_index(material_id)] * _RimColor;
            rim_color = rim_color * cs_ndotv;

            depth_diff = depth_diff * _RimLightIntensity;
            depth_diff *= camera_depth;

            rim_light = depth_diff * cs_ndotv_pow;
            rim_light = saturate(rim_light);

            rim_light = saturate(rim_light * (color.xyz * (float3)5.0f));
        }
    #else
        rim_light = (float3)0.0f;
    #endif

    
    return rim_light;
}

float3 fakePointLight(float3 worldPos, float matIDTex, float3 out_color,
        float3 fake_ref, float fake_freq, float freq_min, float3 fake_pos, float3 fake_col,
        float fake_range, float skin_int, float fake_int, float skin_sat)
{
    out_color = out_color * fake_ref;
    float2 noise_uv = float2(frac(_Time.y * fake_freq), 0.0f);
    float noise_tex = _FakePointNoiseTex.Sample(sampler_linear_repeat, noise_uv).x;
    noise_tex = max(noise_tex, freq_min);

    float3 light_pos = worldPos.xyz - fake_pos.xyz;
    light_pos = sqrt(dot(light_pos, light_pos));
    light_pos = light_pos + -fake_range;
    light_pos = -light_pos * 3.33333325f + 1.0f;
    light_pos = saturate( light_pos);

    float skin_light = light_pos * skin_int;
    float light = light_pos * fake_int;

    light = (matIDTex >= 0.8f) ? skin_light : light;

    float3 light_color = dot(fake_col, float3(0.298999995f, 0.587000012f, 0.114f));
    light_color = lerp(fake_col, light_color, skin_sat);
    light_color = (matIDTex >= 0.8f) ? light_color : fake_col;
    light_color = light_color * light;

    light_color = light_color * noise_tex;
    light_color = (out_color * light_color + light_color);
    out_color = out_color + light_color;
    return out_color; 
}

void weapon_shit(inout float3 diffuse_color, float diffuse_alpha, float2 uv, float3 normal, float3 view, float3 wspos)
{
    #if defined(weapon_mode)
        float ndotv = pow(max(1.0f - dot(normal, view), 0.0001f), 2.0f);

        float2 uv_wp = uv * _WeaponPatternTex_ST.xy + _WeaponPatternTex_ST.zw;
        float2 weapon_uv = uv;
        if(_DissolveDirection_Toggle)
        {
            weapon_uv.y = weapon_uv.y - 1.0f;
        }
        weapon_uv.y = (_WeaponDissolveValue * 2.09f + weapon_uv.y) + -1.0f;
        
        float2 weapon_tex = _WeaponDissolveTex.Sample(sampler_linear_clamp, weapon_uv).xy;

        float2 pattern_uv = _Time.yy * (float2)_Pattern_Speed + uv_wp;

        float pattern_tex = _WeaponPatternTex.Sample(sampler_linear_repeat, pattern_uv).x;

        ndotv = ndotv * 1.1f + pattern_tex;

        float weapon_dissolve = sin((_WeaponDissolveValue + -0.25f) * 6.28f) + 1.0f;
        ndotv = ndotv * weapon_dissolve;
        ndotv = ndotv * 0.5f + (weapon_tex.y * 3.0f);

        float3 weapon_view = -wspos.xyz + _WorldSpaceCameraPos.xyz;
        weapon_view = normalize(weapon_view);

        float skill_ndotv = dot(normal, weapon_view);

        skill_ndotv = pow(max(1.0f - saturate(skill_ndotv), 0.001f), _SkillEmisssionPower);
        
        float3 skill_fresnel = skill_ndotv * _SkillEmisssionColor;

        float2 scan_uv = uv * _ScanPatternTex_ST.xy + _ScanPatternTex_ST.zw;
        if(_ScanDirection_Switch)
        {
            scan_uv.y = -scan_uv.y + 1.0f;
        }
        scan_uv.y = scan_uv.y * 0.5f + (_Time.y * _ScanSpeed);
        float scan_tex = _ScanPatternTex.Sample(sampler_linear_repeat, scan_uv).x;

        float3 weapon_color = ndotv * _WeaponPatternColor.xyz + diffuse_color;
        weapon_color = skill_fresnel * (float3)_SkillEmissionScaler + weapon_color; 
        weapon_color = (scan_tex * _ScanColorScaler) * _ScanColor.xyz + weapon_color;

        ndotv = diffuse_alpha + ndotv;
        ndotv = skill_fresnel * _SkillEmissionScaler + ndotv;
        ndotv =  (scan_tex * _ScanColorScaler) * _ScanColor.x + ndotv;
        ndotv = saturate(ndotv);

        float ndotv_check = (0.0099f < ndotv);

        weapon_color = weapon_color + (-diffuse_color);
        weapon_color = ndotv * weapon_color + diffuse_color;
        weapon_color = ndotv_check ? weapon_color : diffuse_color;

        
        float4 diffuse_diss;
        diffuse_diss.x = max(weapon_color.z, weapon_color.y);
        diffuse_diss.w = max(weapon_color.x, diffuse_diss.x);

        float3 color = weapon_color.xyz;

        diffuse_color = color;

        clip(weapon_tex.x - 0.001f);
    #endif
}

// star cloak shit
void star_cocks(inout float4 diffuse_color, float2 uv0, float2 uv1, float2 uv2, float4 sspos, float ndotv, float3 light, float3 parallax)
{
    #if defined(is_cock)
        // initialize different uvs
        float cockType = _StarCockType;
        float uvSource = _StarUVSource;

        float2 uv = uv0;
        if(uvSource == 1)
        {
            uv = uv1;
        }
        else if(uvSource == 2)
        {
            uv = uv2;
        }

        float fov = extract_fov();
        fov = clamp(fov, 0, 150);
        float range = fov_range(0, 180, fov);
        
        if(cockType == 0) // paimon/dainsleif 
        {
            #if defined(paimon_cock)
                parallax = normalize(parallax);

                float2 star_parallax = parallax * (_StarHeight + -1.0f);


                float star_speed = _Time.y * _Star01Speed;
                float2 star_1_uv = uv * _StarTex_ST.xy + _StarTex_ST.zw;
                star_1_uv.y = star_speed + star_1_uv.y;
                star_1_uv.xy = star_parallax * (float2)-0.1 + star_1_uv;

                float2 star_2_uv = uv * _Star02Tex_ST.xy + _Star02Tex_ST.zw;
                star_2_uv.y = star_speed * 0.5f + star_2_uv.y;
                star_parallax = parallax * (_Star02Height + -1.0f);
                star_2_uv.xy = star_parallax * (float2)-0.1f + star_2_uv.xy;

                float2 color_uv = uv.xy * _ColorPaletteTex_ST.xy + _ColorPaletteTex_ST.zw;
                color_uv.x = _Time.y * _ColorPalletteSpeed + color_uv.x;
                float3 color_palette = _ColorPaletteTex.Sample(sampler_linear_clamp, color_uv);

                float2 noise_1_uv = uv.xy * _NoiseTex01_ST.xy + _NoiseTex01_ST.zw;
                noise_1_uv = _Time.yy * (float2)_Noise01Speed + noise_1_uv;
                float2 noise_2_uv = uv.xy * _NoiseTex02_ST.xy + _NoiseTex02_ST.zw;
                noise_2_uv = _Time.yy * (float2)_Noise02Speed + noise_2_uv;

                float noise_1 = _NoiseTex01.Sample(sampler_linear_repeat, noise_1_uv).x;
                float noise_2 = _NoiseTex02.Sample(sampler_linear_repeat, noise_2_uv).x;

                float noise = noise_1 * noise_2;
                float star_1 = _StarTex.Sample(sampler_linear_repeat, star_1_uv).x;
                float star_2 = _Star02Tex.Sample(sampler_linear_repeat, star_2_uv).y;
                
                float3 stars = star_2 + star_1;
                stars = diffuse_color.w * stars;
                stars = color_palette * stars;

                stars = stars * (float3)_StarBrightness;

                float2 const_uv = uv.xy * _ConstellationTex_ST.xy + _ConstellationTex_ST.zw;
                star_parallax = parallax * (_ConstellationHeight + -1.0f);
                const_uv = star_parallax * (float2)-0.1f + const_uv;
                float3 constellation = _ConstellationTex.Sample(sampler_linear_repeat, const_uv).xyz;
                constellation = constellation * (float3)_ConstellationBrightness;

                float2 cloud_uv = uv.xy * _CloudTex_ST.xy + _CloudTex_ST.zw;
                star_parallax = parallax * (_CloudHeight + -1.0f);

                cloud_uv = noise * (float2)_Noise03Brightness + cloud_uv;
                cloud_uv = star_parallax * (float2)-0.1f + cloud_uv;
                float cloud = _CloudTex.Sample(sampler_linear_repeat, cloud_uv).x;

                cloud = cloud * diffuse_color.w;
                cloud = cloud * _CloudBrightness;


                float3 everything = stars * noise + constellation;

                float3 everything_2 = diffuse_color.xyz + everything;
                
                everything_2  = cloud * color_palette + everything_2;
                
                diffuse_color.xyz = everything_2;
            #endif
        }
        else if(cockType == 1) // skirk
        {
            #if defined(skirk_cock)
                float4 weird_view = float4(_WorldSpaceCameraPos.xyz, 0.0f) - unity_ObjectToWorld[3] * (_ScreenParams.x / _ScreenParams.y);
                weird_view.x = dot(weird_view, weird_view);
                weird_view.x = sqrt(weird_view.x);

                weird_view.x = lerp(1.0f, weird_view.x, range);

                float3 star_flicker;
                star_flicker.x = _Time.y * _StarFlickerParameters.x;
                star_flicker.y = ndotv * _StarFlickerParameters.y;
                star_flicker.y = star_flicker.y * weird_view.x + star_flicker.x;
                star_flicker.y = frac(star_flicker.y);
                star_flicker.y = (star_flicker.y >= _StarFlickerParameters.z) ? 1.0f : 0.0f;

                float2 star_uv;
                star_uv = uv * _StarTex_ST.xy + _StarTex_ST.zw;

                float2 screen_uv = sspos.xy / sspos.w;
                screen_uv = screen_uv * 2.0f - 1.0f;
                screen_uv.x = screen_uv.x * (_ScreenParams.x / _ScreenParams.y);

                screen_uv = screen_uv * weird_view.x;
                screen_uv = screen_uv * (float2)_StarTiling + (-star_uv);
                star_uv = (float2)_UseScreenUV * screen_uv + star_uv;
                star_uv = star_uv + frac(_Time.yy * _StarTexSpeed.xy);

                float3 star_tex = _StarTex.Sample(sampler_linear_repeat, star_uv);
                float star_grey =  dot(star_tex, float3(0.03968f, 0.4580f, 0.006f));
                float star_flick = star_grey >= _StarFlickRange;

                float2 star_mask = _StarMask.Sample(sampler_linear_repeat, uv).xy;
                float mask_red = -star_mask.x + 1.0f;

                float3 flicker_color = lerp(0.0f, star_flicker.y * _StarFlickColor.xyz, star_flick);

                float3 star_color = star_tex.xyz * _StarColor.xyz + flicker_color;

                float2 block_stuff = float2((-_BlockHighlightViewWeight.x + _CloakViewWeight.x), (-_BlockHighlightSoftness.x + _BlockHighlightRange.x));

                float block_masked = star_mask.y * block_stuff.x + _BlockHighlightViewWeight;

                float4 blockhighmask = _BlockHighlightMask.Sample(sampler_linear_repeat, uv.xy);



                float4 block_light = light.zzzz * block_masked.xxxx + float4(0.0f, 0.2f, 0.5f, 0.8f);
                block_light = frac(block_light);
                block_light = block_light * 2.0f - 1.0f;
                block_light = -abs(block_light) + 1.0f;
                block_light = block_stuff.y + block_light;
                block_light = block_light / (block_stuff.y + _BlockHighlightRange);
                block_light = saturate(block_light);
                
                float2 blocks = blockhighmask.xy * block_light.xy;

                float2 brightuv = uv.xy + frac(_Time.yy * _BrightLineMaskSpeed.xy);
                float brightmask = _BrightLineMask.Sample(sampler_linear_repeat, brightuv).x;
                brightmask = pow(brightmask, _BrightLineMaskContrast) * _BrightLineColor;

                float3 block_thing = blocks.y + blocks.x;
                block_thing = blockhighmask.z * block_light.z + block_thing;
                block_thing = blockhighmask.w * block_light.w + block_thing;
                block_thing = saturate(block_thing) * _BlockHighlightColor;

                float3 everything = star_color * mask_red + block_thing;

                everything.xyz = diffuse_color.w * brightmask + everything.xyz; 
                everything.xyz = _Color.xyz * diffuse_color.xyz + everything.xyz; 
                diffuse_color.xyz = everything;
            #endif
        }
        else if(cockType == 2)
        {
            #if defined(asmoday_cock)
                float2 noise_uv = uv * _NoiseMap_ST.xy + _NoiseMap_ST.zw;
                noise_uv = _Time.yy * _NoiseSpeed.xy + noise_uv;
                float noise = _NoiseMap.Sample(sampler_linear_repeat, noise_uv).x;

                float2 flow_1_uv = uv * _FlowMap_ST.xy + _FlowMap_ST.zw;
                flow_1_uv = noise.xx * (float2)_NoiseScale + flow_1_uv;
                flow_1_uv = _Time.yy * _FlowMaskSpeed.xy + flow_1_uv;

                float2 flow_2_uv = uv * _FlowMap02_ST.xy + _FlowMap02_ST.zw;
                flow_2_uv = _Time.yy * _FlowMask02Speed.xy + flow_2_uv;

                float2 mask_uv = uv * _FlowMask_ST.xy + _FlowMask_ST.zw;
                
                float grad_bottom_area = max(uv.y, 0.0001f);
                grad_bottom_area = pow(grad_bottom_area, _BottomPower) * _BottomScale;
                float3 bottom_grad = lerp(_BottomColor01, _BottomColor02, grad_bottom_area);

                float3 flow_color = _FlowColor.xyz * (float3)_FlowScale;
                float flow_map_1 = _FlowMap.Sample(sampler_linear_repeat, flow_1_uv).x;
                float flow_map_2 = _FlowMap02.Sample(sampler_linear_repeat, flow_2_uv).x;
                
                float3 flow = flow_map_1 + flow_map_2;
                flow = flow * flow_color;

                float grad_mask_area = max(uv.y, 0.0001f);
                grad_mask_area = pow(grad_mask_area, _FlowMaskPower) * _FlowMaskScale;
                grad_mask_area = saturate(grad_mask_area);

                flow = flow * grad_mask_area;

                float flow_mask = _FlowMask.Sample(sampler_linear_repeat, mask_uv).x;
                bottom_grad = flow * flow_mask + bottom_grad;

                diffuse_color.xyz = lerp(diffuse_color.xyz, bottom_grad, diffuse_color.w);
            #endif
        }

    #endif
}

void arm_effect(inout float4 diffuse, float2 uv0, float2 uv1, float2 uv2, float3 view, float3 normal, float ndotl)
{
    #if defined(asmogay_arm)
        float2 uv = uv2;

        float2 mask_uv = uv * _Mask_ST.xy + _Mask_ST.zw;
        mask_uv.xy = _Time.y * float2(_Mask_Speed_U, 0.0f) + mask_uv;
        float3 masktex = _Mask.Sample(sampler_linear_repeat, mask_uv.xy).xyz;

        float2 effuv1 = uv * _Tex01_UV.xy + _Tex01_UV.zw;
        effuv1.xy = _Time.yy * float2(_Tex01_Speed_U, _Tex01_Speed_V) + effuv1.xy;
        float3 eff1 = _MainTex.Sample(sampler_linear_repeat, effuv1.xy).xyw;
        float2 effuv2 = uv * _Tex02_UV.xy + _Tex02_UV.zw;
        effuv2.xy = _Time.yy * float2(_Tex02_Speed_U, _Tex02_Speed_V) + effuv2.xy;
        float3 eff2 = _MainTex.Sample(sampler_linear_repeat, effuv2.xy).xyw;
        float3 effmax = max(eff1.y, eff2.y);
        float2 effuv3 = uv * _Tex03_UV.xy + _Tex03_UV.zw;
        effuv3.xy = _Time.yy * float2(_Tex03_Speed_U, _Tex03_Speed_V) + effuv3.xy;
        float3 eff3 = _MainTex.Sample(sampler_linear_repeat, effuv3.xy).xyw;
        effmax = max(effmax, eff3.y);
        float2 effmul = masktex.xz * eff3.zx;
        effmax = max(masktex.y, effmax);
        effmul.xy = eff1.zx * eff2.zx + effmul.xy;
        effmax = (-effmul.y) + effmax;

        float downrange = uv.x>=_DownMaskRange;

        downrange = (downrange) ? 1.0 : 0.0;
        effmul.x = downrange * effmul.x;
        float2 effuv4 = uv * _Tex04_UV.xy + _Tex04_UV.zw;
        effuv4.xy = _Time.yy * float2(_Tex04_Speed_U, _Tex04_Speed_V) + effuv4.xy;
        float eff4 = _MainTex.Sample(sampler_MainTex, effuv4.xy).z;
        float2 effuv5 = uv * _Tex05_UV.xy + _Tex05_UV.zw;
        effuv5.xy = _Time.yy * float2(_Tex05_Speed_U, _Tex05_Speed_V) + effuv5.xy;
        float eff5 = _MainTex.Sample(sampler_MainTex, effuv5.xy).z;
        float eff9 = eff5 * eff4;

        float toprange = eff9.x>=_TopMaskRange;

        float linerange = eff9.x>=_TopLineRange;

        linerange = (linerange) ? -1.0 : -0.0;
        toprange = (toprange) ? 1.0 : 0.0;
        effmul.x = toprange * effmul.x;
        linerange = linerange + toprange;
        linerange = effmul.x * linerange;
        effmax = max(linerange, effmax);

        effmax = saturate(effmax);

        float3 efflight = lerp(_LineColor, _LightColor, effmax);
        float light_color = lerp(_ShadowColor, _LightColor, (1.0f - (ndotl.x * 0.5 + 0.5)) <= _ShadowWidth);
        effmax = lerp(light_color, _LineColor, effmax);
        efflight.xyz = (-effmax) + efflight.xyz;
        float effshadow = ndotl.x * 0.5 + 0.5;
        effshadow = 1.0;

        float shadowbool = _ShadowWidth>=effshadow;

        effshadow = (shadowbool) ? 1.0 : 0.0;
        effmax = effshadow.xxx * efflight.xyz + effmax;
        float efffrsn = dot(normal.xyz, view.xyz);
        efflight.x = (-efffrsn.x) + 1.0;
        efflight.x = max(efflight.x, 0.0001f);
        
        efflight.x = pow(efflight.x, _FresnelPower);
        efflight.x = efflight.x + _FresnelScale;
        efflight.x = saturate(efflight.x);
        float4 outeff;
        outeff.xyz = _FresnelColor.xyz * efflight.xxx + effmax; 
        // outeff.xyz = outeff;
        effmax.x = max(uv.x, 0.0001f);
        effmax.x = pow(effmax.x, _GradientPower);
        effmax.x = effmax.x * _GradientScale;
        outeff.w = saturate(effmax.x * effmul.x); 
        diffuse.xyz = outeff.xyz;

        float grad_alpha = max(uv.y, 9.99999975e-05);
        grad_alpha.x = log2(grad_alpha.x);
        grad_alpha.x = grad_alpha.x * _GradientPower;
        grad_alpha.x = exp2(grad_alpha.x);
        grad_alpha.x = grad_alpha.x * _GradientScale;
        diffuse.w = saturate(grad_alpha.x * effmul.x);

        // above is old code
        // below is new code
        
        // float3 mask_uv;
        // mask_uv.xy = uv.xy * _Mask_ST.xy + _Mask_ST.zw;
        // mask_uv.xy = mask_uv.xy + float2(0.0f, _Time.y * _Mask_Speed_U);
        // float3 mask_tex = _Mask.Sample(sampler_LightMapTex, mask_uv.xy);
        // float4 tex_uv;
        // tex_uv.xy = uv.xy * _Tex01_UV.xy + _Tex01_UV.zw;
        // tex_uv.xy = _Time.yy * float2(_Tex01_Speed_U, _Tex01_Speed_V) + tex_uv.xy;
        // float3 tex01 = _MainTex.Sample(sampler_MainTex, tex_uv).xyw;
        // float2 tex2_uv = uv.xy * _Tex02_UV.xy + _Tex02_UV.zw;
        // tex2_uv.xy = _Time.yy * float2(_Tex02_Speed_U, _Tex02_Speed_V) + tex2_uv.xy;
        // float3 tex02 = _MainTex.Sample(sampler_MainTex, tex2_uv.xy).xyw;
        // float4 maxy; 
        // maxy.x = max(tex01.y, tex02.y);
        // float2 tex3_uv = uv.xy * _Tex03_UV.xy + _Tex03_UV.zw;
        // tex3_uv = _Time.yy * float2(_Tex03_Speed_U, _Tex03_Speed_V) + tex3_uv;
        // float3 tex03 = _MainTex.Sample(sampler_MainTex, tex3_uv).xyw;
        // maxy.x = max(maxy.x, tex03.y);
        // float2 tex_masked = mask_tex.xz * tex03.zx;
        // maxy.x = max(mask_tex.y, maxy.x);
        // tex_masked.xy = tex01.zx * tex02.zx + tex_masked.xy;
        // maxy.x = (-tex_masked.y) + maxy.x;

        // bool bool_a = uv0.x>=_DownMaskRange;

        // float4 bool_a_check = (bool_a) ? 1.0 : 0.0;
        // tex_masked.x = bool_a_check * tex_masked.x;
        // mask_uv.xy = uv.xy * _Tex04_UV.xy + _Tex04_UV.zw;
        // mask_uv.xy = _Time.yy * float2(_Tex04_Speed_U, _Tex04_Speed_V) + mask_uv.xy;
        // mask_tex.x = _MainTex.Sample(sampler_MainTex, mask_uv.xy).z;
        // float2 tex5_uv = uv.xy * _Tex05_UV.xy + _Tex05_UV.zw;
        // tex5_uv.xy = _Time.yy * float2(_Tex05_Speed_U, _Tex05_Speed_V) + tex5_uv.xy;
        // float tex05 = _MainTex.Sample(sampler_MainTex, tex5_uv.xy).z;
        // mask_uv.x = tex05 * mask_tex.x;

        // bool bool_b = mask_uv.x>=_TopMaskRange;
        // bool_a = mask_uv.x>=_TopLineRange;

        // bool_a_check = (bool_a) ? -1.0 : -0.0;
        // float4 bool_b_check = (bool_b) ? 1.0 : 0.0;
        // tex_masked.x = bool_b_check * tex_masked.x;
        // bool_a_check = bool_a_check + bool_b_check;
        // bool_a_check = tex_masked.x * bool_a_check;
        // maxy.x = max(bool_a_check, maxy.x);

        // maxy.x = clamp(maxy.x, 0.0, 1.0);

        // float3 line_color = _LineColor.xyz + (-_LightColor.xyz);
        // line_color.xyz = maxy.xxx * line_color.xyz + _LightColor.xyz;
        // float3 line_comb = (-_ShadowColor.xyz) + _LineColor.xyz;
        // float4 line_shadow;
        // line_shadow.xzw = maxy.xxx * line_comb.xyz + _ShadowColor.xyz;
        // line_color.xyz = (-line_shadow.xzw) + line_color.xyz;
        // mask_uv.xyz = (-view.xyz) * _WorldSpaceLightPos0.www + _WorldSpaceLightPos0.xyz;
        // mask_uv.x = dot(mask_uv.xyz, normal.xyz);
        // float shadow_area = mask_uv.x * 0.5 + 0.5;
        // shadow_area = (-shadow_area) + 1.0;

        // bool_a = _ShadowWidth>=shadow_area;

        // shadow_area = (bool_a) ? 1.0 : 0.0;
        // line_shadow.xzw = (float3)shadow_area * line_color.xyz + line_shadow.xzw;
        // mask_uv.xyz = normalize(normal);
        // tex_uv.xyz = normalize(view);
        // mask_uv.x = dot(tex_uv.xyz, mask_uv.xyz);
        // float ndotv_b = (-mask_uv.x) + 1.0;
        // ndotv_b.x = max(ndotv_b.x, 9.99999975e-05);
        // ndotv_b.x = log2(ndotv_b.x);
        // ndotv_b.x = ndotv_b.x * _FresnelPower;
        // ndotv_b.x = exp2(ndotv_b.x);
        // ndotv_b.x = ndotv_b.x + _FresnelScale;

        // ndotv_b.x = clamp(ndotv_b.x, 0.0, 1.0);
        // diffuse.xyz = _FresnelColor.xyz * ndotv_b.xxx + line_shadow.xzw;
        // float grad_alpha = max(uv.y, 9.99999975e-05);
        // grad_alpha.x = log2(grad_alpha.x);
        // grad_alpha.x = grad_alpha.x * _GradientPower;
        // grad_alpha.x = exp2(grad_alpha.x);
        // grad_alpha.x = grad_alpha.x * _GradientScale;
        // diffuse.w = saturate(grad_alpha.x * tex_masked.x);

        clip(saturate(1.0f - (uv.y > 0.995f)) - 0.1f );
    #endif 
}

void mavuika_vat_vs(inout float4 position, inout float2 uv1, in float3 normal, in float4 color)
{   
    #if defined(use_vat)
    if(_EnableHairVat)
    {
        float2 uv = uv1 * _VertexTexST.xy + _VertexTexST.zw;
        uv = _Time.yy * float2(_VertexTexUS, _VertexTexVS) + uv.xy;
        float4 noise = _VertexTex.SampleLevel(sampler_linear_repeat, uv, 0).xyzw;
        float shift = 0.0f;
        shift.x = _VertexTexSwitch == 3 ? noise.w : shift;
        shift.x = _VertexTexSwitch == 2 ? noise.z : shift;
        shift.x = _VertexTexSwitch == 1 ? noise.y : shift;
        shift.x = _VertexTexSwitch == 0 ? noise.x : shift;
        shift = shift + _VertexAdd;
        shift = shift * _VertexPower;
        float3 offset = shift * normal.xyz;
        offset = offset * color.xxx;
        float mask = saturate(color.z + _VertexMask);
        offset = offset * mask;
        position.xyz = offset.xyz + position.xyz;
    }   
    #endif
}

void mavuika_vat_ps(inout float4 diffuse, in float4 uv, in float3 normal, in float3 view, in float3 vcol)
{
    #if defined(use_vat)
        if(_EnableHairVertexVat)
        {
            // set up uvs
            float2 noise_uv = _Time.yy * float2(_VertTexUS, _VertTexVS) + (uv.zw * _VertTexST.xy + _VertTexST.zw);
            float2 lerp_uv = uv.xy * _LerpTextureST.xy + _LerpTextureST.zw;
            // sample noise texture
            float4 noise = _VertTex.Sample(sampler_linear_repeat, noise_uv).xyzw;
            float shift = 0.0f;
            shift.x = _VertTexSwitch == 3 ? noise.w : shift;
            shift.x = _VertTexSwitch == 2 ? noise.z : shift;
            shift.x = _VertTexSwitch == 1 ? noise.y : shift;
            shift.x = _VertTexSwitch == 0 ? noise.x : shift;
            shift.x = (((shift + _VertAdd) * _VertPower)  * vcol.x) * saturate(vcol.z + _VertMask); 
            // offset uv for blending texture using noise texture
            lerp_uv = _NoisePowerForLerpTex.xx * shift.xx + lerp_uv.xy;
            // sample blend texture
            float3 blend_tex = _LerpTexture.Sample(sampler_linear_repeat, lerp_uv).xyz;
            float3 color = lerp(_DarkColor, _LightColor, blend_tex.yyy);
            float highlights = sin(_Time.y * _HighlightsSpeed) * _HighlightsBrightness + 1.0f;

            float ndotv = dot(normal, view);
            ndotv.x = -ndotv.x + 1.0f;
            ndotv = max(ndotv, 0.000001f);
            ndotv = pow(ndotv, 2.3199f);
            ndotv = ndotv * 1.399f + 0.3f;
            ndotv = blend_tex.z * ndotv;

            float4 u_xlat16_6;
            float4 u_xlat16_5;
            float4 u_xlat16_0;
            float4 u_xlat16_1;
            
            u_xlat16_6.xyz = _HighlightsColor.xyz * highlights + (-color.xyz);
            u_xlat16_5.xyz = ndotv * u_xlat16_6.xyz + color.xyz;
            u_xlat16_6.xyz = _AhomoColor.xyz * highlights + (-u_xlat16_5.xyz);
            u_xlat16_5.xyz = blend_tex.xxx * u_xlat16_6.xyz + u_xlat16_5.xyz;
            u_xlat16_5.xyz = u_xlat16_5.xyz * _AllColorBrightness.xyz;
            u_xlat16_0.xyz = u_xlat16_5.xyz * _DayColor.xyz;
            u_xlat16_5.x = max(u_xlat16_0.z, u_xlat16_0.y);
            u_xlat16_1.w = max(u_xlat16_0.x, u_xlat16_5.x);

            u_xlat16_1.xyz = u_xlat16_0.xyz / u_xlat16_1.www;
            u_xlat16_0.w = 1.0;
            u_xlat16_0 = (1.0<u_xlat16_1.w) ? u_xlat16_1 : u_xlat16_0;

            diffuse = u_xlat16_0;
        }
    #endif   
}

int bitFieldInsert(int base, int insert, int start, int num)
// the fact i had to write this function myself is stupid
{
    int mask = ~(0xffffffff < num) << start;
    return (base & ~mask) | (insert << start);
}

void stencil_mask(float4 pos, inout float4 color, float4 lightmap, float3 view)
{
    // #if defined (is_stencil) 
        float filterMask = 1.0f;
        if(_StencilFilter > 0)
        {
            if(_StencilFilter == 1) filterMask = saturate(step(0, pos.x));
            if(_StencilFilter == 2) filterMask = saturate(step(pos.x, 0));
        }

        filterMask = filterMask * _HairBlendSilhouette;
        filterMask = max(0, filterMask);

        if(_StencilType == 2) // hair
        {
            float3 up      = UnityObjectToWorldDir(_headUpVector.xyz);
            float3 forward = UnityObjectToWorldDir(_headForwardVector.xyz);
            float3 right   = UnityObjectToWorldDir(_headRightVector.xyz);

            float3 view_xz = normalize(view - dot(view, up) * up);
            float cosxz    = max(0.0f, dot(view_xz, forward));
            float alpha_a  = saturate((1.0f - cosxz) / 0.658f);

            float3 view_yz = normalize(view - dot(view, right) * right);
            float cosyz    = max(0.0f, dot(view_yz, forward));
            float alpha_b  = saturate((1.0f - cosyz) / 0.293f);
            float hair_alpha;
            hair_alpha = max(alpha_a, alpha_b);

            hair_alpha = (_HairBlendUse) ? max(hair_alpha, filterMask) : saturate(filterMask + saturate(step(pos.z - _HairZOffset, 0.0f)));

            // color.xyz = hair_alpha;
            color.w = hair_alpha;
        }
        else if(_StencilType == 1) // eye
        {
            color.w = filterMask;
            clip(color.w - 0.01f);
        }
        else if(_StencilType == 0) // face
        {     
            color.w = ( (lightmap.x - lightmap.w) <= 0) * saturate(step(0.0, pos.y - 0.01f)) * filterMask;
            clip(color.w - 0.01f);
        }
        else
        {
            discard;
        }
    // #endif
}

// even if i dont push this for the january update, id like to get the back end started
void character_stocking(in float3 normal, in float3 view, in float2 uv, in float materialRegion, in float check, inout float4 color)
// initial implementation based on how I know mihoyo likes to implement stockings 
// thanks to star rail and hi3p2
{
    // need to make sure the logic doesnt escape at all
    #if defined(use_stockings) 
    if(_UseCharacterStockings)
    {
        float2 patternUV = uv;
        // patternUV = patternUV * _StockingsDetailPattenScale + (_StockingsDetailPattenScale * -0.5f);
        // patternUV = patternUV * _StockingsDetailPattenTiling;
        float2 detailUV = uv;
        float2 decalUV = uv;

        // float pattern = _StockingsDetailTex.Sample(sampler_linear_repeat, patternUV).z;

        float4 lightmap = _LightMapTex.Sample(sampler_linear_clamp, uv);


        // color.xyz = pattern;

        float ndotv = dot(normal, view);
        float ndotl = dot(normal, _WorldSpaceLightPos0.xyz);

        float stocking_light = lerp(0.0f, _StockingsLightColor, lightmap.x);
        stocking_light = lerp(stocking_light * _StockingsLightScaleInShadow, stocking_light, saturate(ndotl));


        float3 stocking_color = lerp(_StockingsShadowColor, 1.0f, ndotl);

        float3 stocking_specular = (saturate(pow(ndotv, _StockingsSpecularSharpe)) * _StockingsSpecularScale) * _StockingsSpecularColor;
        stocking_specular = stocking_specular * lightmap.z;

        float stocking_light_range = 1.0f - _StockingsLightRange;

        color.xyz = lightmap.x * 0.5 + 0.5;
    }
    #endif
}