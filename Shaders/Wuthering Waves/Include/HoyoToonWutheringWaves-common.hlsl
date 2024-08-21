// UTILITY FIRST
float3 sRGBToLinear(float3 rgb)
{
    return lerp(pow((rgb + 0.055) * (1.0 / 1.055), (float3)2.4),rgb * (1.0/12.92),rgb <= ((float3)0.04045));
}

float channel_picker(float4 input, float channel)
{
    float output = input.x;
    output = (channel == 1) ? input.y : output;
    output = (channel == 2) ? input.z : output;
    output = (channel == 3) ? input.w : output;
    return output;
}

float3 color_fix(float3 color)
{
    return saturate(sqrt(color.xyz));
}

float4 color_fix(float4 color)
{
    return saturate(sqrt(color.xyzw));
}

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

//--------------------------------------------------------------------------------------
// MATERIAL ID SYSTEM
float3 skin_type(float vc, float id)
{
    float type = (_UseSkinMask) ? id : vc;
    float3 skin_id;

    float4 gequal = (type.xxxx >= float4(0.0500000007,0.300000012,0.5,0.899999976));
    float4 lequal = (float4(0.0500000007,0.300000012,0.5,0.899999976) >= type.xxxx);

    lequal.yzw = (lequal.yzw) ? (float3)1.0f : (float3)0.0f;
    gequal.yz = lequal.zw * gequal.yz;
    skin_id.x = (-gequal.x * lequal.y + 1) ? 1 : (-gequal.x * lequal.y + 1);
    skin_id.x = -gequal.y * skin_id.x + 1;
    skin_id.y = gequal.z * skin_id.x;
    skin_id.x = -gequal.z * skin_id.x + 1;
    skin_id.x = gequal.w * skin_id.x;
    skin_id.z = 1.0 - max(skin_id.x, skin_id.y);
    if(!_UseSkinMask) skin_id.x = 0.f;
    
    return skin_id;
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

//--------------------------------------------------------------------------------------
// DISPLACEMENT
// based on implementation from the 2006 ati example in the 2010 DirectX SDK 
void pom(in float3 normal, in float3 tangent, in float3 bitangent, in float3 view, in float2 uv, inout float2 height_uv)
{
    // transform view vector to tangent space 
    float3x3 World2Tangent = {tangent, bitangent, normal}; // this is the same matrix we use for normal maps
    float3 viewTS = mul(World2Tangent, view); // transform the vector
    
    // initial displacement direction 
    float2 pDir = normalize(viewTS.xy);

    // the length of this vectr determines the furthest amount of displacment
    float vLength = length(viewTS);
    float pLength = sqrt( vLength * vLength - viewTS.z * viewTS.z ) / viewTS.z;

    float2 parallaxOffset = (pDir * pLength) * _ParallaxHeight;

    float2 uvSize = uv * _EM_TexelSize.zw;

    // never knew you could write lines like this, shits cool af
    float2 dxSize, dySize;
    float2 dx, dy;

    float4(dxSize, dx) = ddx(float4(uvSize, uv));
    float4(dySize, dy) = ddx(float4(uvSize, uv));

    float  mLevel;      
    float  mLevelInt;    // mip level integer portion
    float  mLevelFrac;   // mip level fractional amount for blending in between levels

    float  minUVDelta;
    float2 dUV;

    // min changes in uv across quad
    dUV = dxSize * dxSize + dySize * dySize;

    // mipmapping max 
    minUVDelta = max(dUV.x, dUV.y);
    
    // compute current mip level
    mLevel = max(0.5f * log2(minUVDelta), 0.f);

    height_uv = uv;

    if ( mLevel <= (float) 10 )
    {
        
        int nNumSteps = _ParallaxSteps;

        float cHeight = 0.0;
        float stepSize   = 1.0 / (float) nNumSteps;
        float pHeight = 1.0;
        float nHeight = 0.0;

        int    stepIndex = 0;
        bool   bCondition = true;

        float2 offsetPerStep = stepSize * parallaxOffset;
        float2 cOffset = uv;
        float  cBound     = 1.0;
        float  pAmount   = 0.0;

        float2 pt1 = 0;
        float2 pt2 = 0;
        
        float2 texOffset2 = 0;

        while ( stepIndex < nNumSteps ) 
        {
            cOffset -= offsetPerStep;

            // Sample height map which in this case is stored in the alpha channel of the normal map:
            // cHeight = tex2Dgrad( tNormalHeightMap, cOffset, dx, dy ).a;
            cHeight = _EM.SampleGrad(sampler_linear_repeat, cOffset, dx, dy).y;

            cBound -= stepSize;

            if ( cHeight > cBound ) 
            {   
                pt1 = float2( cBound, cHeight );
                pt2 = float2( cBound + stepSize, pHeight );

                texOffset2 = cOffset - offsetPerStep;

                stepIndex = nNumSteps + 1;
                pHeight = cHeight;
            }
            else
            {
                stepIndex++;
                pHeight = cHeight;
            }
        }   

        float delta2 = pt2.x - pt2.y;
        float delta1 = pt1.x - pt1.y;
        
        float denom = delta2 - delta1;
        
        if ( denom == 0.0f ) // prevent division by 0
        {
            pAmount = 0.0f;
        }
        else
        {
            pAmount = (pt1.x * delta2 - pt2.x * delta1 ) / denom;
        }
        
        float2 vParallaxOffset = parallaxOffset * (1 - pAmount );

        float2 texSampleBase = uv - vParallaxOffset;
        height_uv = texSampleBase;


        if ( mLevel > (float)(10 - 1) )
        {
            mLevelFrac = modf( mLevel, mLevelInt );
            height_uv = lerp( texSampleBase, uv, mLevelFrac );
        } 
    }  
}

//--------------------------------------------------------------------------------------
// ALPHA HANDLING 
// dither : 
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

//--------------------------------------------------------------------------------------
// NORMAL MAPPING
float3 normal_offline(float3 normal, float3 tangent, float3 bitangent, float3 bumpmap, float scale)
{
    float3x3 tbn = {tangent.xyz, bitangent, normal};

    bumpmap.xyz = bumpmap.xyz * 2.0f - 1.0f;
    bumpmap.xy = bumpmap.xy * (float2)scale;
    bumpmap.xyz = normalize(bumpmap);

    normal = mul(bumpmap.xyz, tbn);
    normal = normalize(normal);
    return normal;   
}

void normal_online(float3 bumpmap, float3 ws_pos, float2 uv, inout float3 normal, in float scale)
{
    // reencode normal map to the proper ranges and scale it by _BumpScale
    bumpmap.xyz = bumpmap.xyz * 2.0f - 1.0f;
    bumpmap.xy = bumpmap.xy * (float2)scale;
    bumpmap.x = -bumpmap.x;
    bumpmap.xyz = normalize(bumpmap);

    // world space position derivative
    float3 p_dx = ddx(ws_pos);
    float3 p_dy = ddy(ws_pos);

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

    float3 bitangent = cross(corrected_normal, tangent); // finally could replace the reversed code with the proper function lol 
    bitangent = bitangent * -uv_det;

    float3x3 tbn = {tangent, bitangent, corrected_normal};

    float3 mapped_normals = mul(bumpmap.xyz, tbn);
    mapped_normals = normalize(mapped_normals); // for some reason, this normalize messes things up in mmd

    normal = mapped_normals;
}

//--------------------------------------------------------------------------------------
// SHADOW
float face_shadow(float2 uv, float3 light)
{   
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
    float facing = step(-0.5f, fdotl);

   
  
    float facemap = _MaskTex.Sample(sampler_linear_repeat, faceuv).w;
    // interpolate between sharp and smooth face shading
    shadow_step = smoothstep(shadow_step - (_SDFSmoothness+0.05f), shadow_step + (_SDFSmoothness+0.05f), facemap);

    shadow_step = 1.0 - (shadow_step * facing);
    return shadow_step;
}

float base_shadow(float ndotl, float ao_map)
{
    float solid = ao_map > .05f;
    float area = ndotl;// * .5f + .5f;
    area = area + _FrontShadowProcessOffset;
    area = smoothstep(_ShadowProcess, _ShadowProcess + saturate(_ShadowWidth + 0.25f), area);
    area = min(area, 1.f);
    area = saturate(((area * ao_map))) * 2 + 0.5f;
    return area;
}

float hair_shadow(float ndotl, float4 mask)
{
    float shadow_area = pow(smoothstep(_SolidShadowProcess, 1.0, mask.y) * _SolidShadowStrength, _ShadowOffsetPower) * _MaskShadowOffsetStrength;
    float shadow_check = 0.000001 >= shadow_area;
    shadow_area = shadow_check ? 0.f : shadow_area;


    shadow_area = ndotl * 0.5 + shadow_area;
    shadow_area = 0.5 +  shadow_area;

    shadow_area = (mask.y > 0.1) * shadow_area;
    
    return shadow_area;
}
//--------------------------------------------------------------------------------------
// RAMP SAMPLING
float ramp_shadow_base(float ndotl, float ao_map)
{
    float solid = ao_map > .05f;
    float area = ndotl * .5f + .5f;
    area = area;
    area = smoothstep(_RampProcess, _RampProcess + _RampWidth, area);
    area = min(area, 1.f);
    area = saturate(((area + 0.4))) ;
    return area;
}

float ramp_shadow_hair(float shadow_area, float4 mask)
{
    float frontshadow = max(0, shadow_area);
    frontshadow = min(_FrontShadowProcessOffset, frontshadow);
    float backshadow = min(_SolidShadowProcess, mask.y);
    backshadow = backshadow/_RampProcess;
    float ramp_area = lerp(frontshadow, shadow_area, backshadow);
    ramp_area = 0.5f +  ramp_area;
    ramp_area = saturate(-_ShadowProcess + ramp_area);
    return ramp_area;
}
//--------------------------------------------------------------------------------------
// SHADOW COLOR
float4 shadow_color_base(float3 normal, float3 light, float2 uv, float shadow_mask, float skin_id, float ramp_mask, in float shadow_area)
{
    // first shadow terms : 
    float shadow = (_UseSDFShadow || (_MaterialType == 1)) ? ((1.0 -  face_shadow(uv, light)) + 0.5f):  base_shadow(dot(normal, light), shadow_mask);
    float2 ramp_uv = (_UseSDFShadow || (_MaterialType == 1)) ? 1.0 - face_shadow(uv, light) : ramp_shadow_base(dot(normal, light), 1.0);
    shadow = saturate(shadow);
    ramp_uv = saturate(ramp_uv);

    float4 subsurface = lerp(_SubsurfaceColor, _SkinSubsurfaceColor, saturate(skin_id.x + (_MaterialType == 1)));

    // calculate ramp y position 
    ramp_uv.y = (1.0f - lerp(_RampPosition, 0.1f, saturate(skin_id.x + (_MaterialType == 1))));

    // sample ramp 
    float3 ramp = _Ramp.Sample(sampler_linear_clamp, ramp_uv); 

    // determine if the ramp mask is used
    ramp_mask = (_UseRampMask) ? ramp_mask : 0;

    // blend between the ramp and subsurface colors
    float3 shadow_color = lerp(subsurface, ramp, ramp_mask * _RampInt);

    // return the shadow color 
    return float4(lerp(shadow_color, 1.0, shadow), shadow); 
}

float4 shadow_color_hair(float3 normal, float3 light, float4 mask, float skin_id, in float shadow_area)
{
    // first shadow terms : 
    float shadow = hair_shadow(dot(normal, light), mask);
    float2 ramp_uv = ramp_shadow_hair(shadow, mask);
    shadow = (shadow);
    ramp_uv = (ramp_uv);
    
    // calculate ramp y position 
    ramp_uv.y = (1.0f - lerp(_RampPosition, 0.1f, skin_id.x));
    #ifdef _is_shadow
    ramp_uv.x = 0.1f;
    ramp_uv.y = 1.0 - 0.1;
    #endif
    // sample ramp 
    float3 ramp = _Ramp.Sample(sampler_linear_clamp, ramp_uv); 
    
    float4 subsurface = lerp(saturate(_SubsurfaceColor + 0.5f), _SkinSubsurfaceColor, skin_id.x);
    #ifdef _is_shadow
    subsurface = _HairShadowColor;
    #endif
    subsurface = saturate(sqrt(subsurface));
    // blend between the ramp and subsurface colors
    float ramp_color = _UseRampColor;
    float3 shadow_color = lerp(subsurface, ramp, ramp_color * _RampInt);
    
    // shadow = smoothstep(_ShadowProcess - _ShadowWidth, _ShadowProcess + _ShadowWidth, shadow);
    shadow = smoothstep(_ShadowProcess - _ShadowWidth, _ShadowProcess + _ShadowWidth, (shadow + 0.1));
    
    float shadow_dark = (mask.y > 0.1);
    shadow_dark = max(0.89f, shadow_dark);
    shadow_dark = min(1.00f, shadow_dark);
    shadow_dark = -0.899999976 + shadow_dark;
    shadow = shadow_dark * shadow;
    shadow = shadow * 4.99999905 + 0.5;
    shadow = shadow * (mask.y > 0.1);
    
    shadow_area = shadow;
    
    // shadow_color = saturate(sqrt(shadow_color));
    // return the shadow color 
    return float4(lerp(shadow_color, 1.0, shadow), shadow); 
    // return shadow; 
}

//--------------------------------------------------------------------------------------
// RIM LIGHTING
float3 rim_lighting(float3 normal, float3 light, float3 ss_pos, float3 ws_pos)
{
    float3 vs_normal = (mul((float3x3)UNITY_MATRIX_V, normal));

    float depth = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, ss_pos.xy), ss_pos);

    float camera_dist = saturate(1.0f / distance(_WorldSpaceCameraPos.xyz, ws_pos));
    float fov = extract_fov();
    fov = clamp(fov, 0, 150);
    float range = fov_range(0, 180, fov);
    float width_depth = camera_dist / range;

    float3 rim_width = _RimWidth * 0.0025f;
    rim_width = lerp(rim_width * 0.5f, rim_width * 0.45f, range) * width_depth;

    float2 offset_pos = ss_pos.xy;
    // offset_pos = lerp(offset_pos.x, -offset_pos.x, side);
    offset_pos = offset_pos + (rim_width * vs_normal);

    float offset = GetLinearZFromZDepth_WorksWithMirrors(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offset_pos.xy), ss_pos); 


    float3 rim = offset-depth;

    rim = smoothstep(0.0f, _RimHardness * 0.25, rim);

    rim = saturate(rim) * _RimColor;

    float ndotl = saturate(dot(normal, light));
    ndotl = smoothstep(0.0f, 0.5f, ndotl);
    
    rim = lerp(0.0f, rim, ndotl);

    return rim;

}

//--------------------------------------------------------------------------------------
// EMISSION
void emission_coloring(inout float3 color, in float emission_mask, inout float emissive)
{


    float emission_area = emission_mask >= _EmissionBreathThreshold;
        
    emissive = saturate(emission_area * _UseBreathLight);

    float3 emission = color_fix(_EmissionColor.xyz) * _EmissionStrength;
    color.xyz = lerp(color.xyz, color * emission + saturate(color * 0.75f), emissive);
}

//--------------------------------------------------------------------------------------
// SPECULAR
float3 specular_base(float3 normal, float3 half_vector, float shadow_mask, float power, float spec, float skin_id)
{
    float ndoth = dot(normal, half_vector);
    float spec_term = pow(ndoth, power);
    float toon_term = spec_term * (spec_term >= 0.1f) * (shadow_mask >= 0.1f);
    spec_term = spec_term * toon_term;
    spec_term = max(spec_term, 0.001);

    return saturate(spec_term * (spec.x >= 0.5));
}

float3 specular_base_second(float3 normal, float3 half_vector, float shadow_mask, float power, float spec, float skin_id)
{
    float ndoth = dot(normal, half_vector);
    float spec_term = pow(ndoth, power);
    float toon_term = spec_term * (spec_term >= 0.1f) * (shadow_mask >= 0.1f);
    spec_term = spec_term * toon_term;
    spec_term = max(spec_term, 0.001);

    float specular =  saturate(spec_term * (spec.x <= 0.85) * skin_id);
    return specular;
}

float3 specular_hair(float3 normal, float3 half_vector, float specular_mask, float ndotl)
{
    float3 specular = saturate(dot(normal, half_vector));
    float specular_area = specular * _SpecStrength;
    specular = 1 + -specular;
    
    float mask = max(specular_mask, specular.x); // hm red
    mask = min(1, mask); //
    mask = mask + -specular.x; //

    specular.x = 1 + -specular.x; //
    specular.x = max(9.99999975e-005, specular.x); //
    specular.x = mask / specular.x;

    specular = specular.xxx * specular_area.xxx;    
    return specular;
}

float3 specular_tight(float3 normal, float3 tangent, float3 bitangent, float3 half_vector, float ndotv, float3 pos, float2 uv, float2 bump)
{
    float aniso;
    if(_Outline == 1)
    // assuming the tangents have been generated over by the outline normals 
    // calculat the tangents online, not piggy backing off the tangents that
    // were output by the normal function since those ones would leave a lot
    // of weird artifacts and shit on them, this version of the tangents are
    // a lot more useable, there still may be some artifacting but that cant
    // be completely avoided. Best I can do for now, may expand this in the
    // future to incorporate a few more aniso calculation types...
    {
        float3 pos_dx = ddx(pos.xyz);
        float3 pos_dy = ddx(pos.xyz);
        float2 uv_x = ddx(uv);
        float2 uv_y = ddy(uv);
        tangent = (uv_y.y * pos_dx) - (uv_x.y * pos_dy);
        tangent = normalize( tangent - normal * dot( tangent, normal ));
    }

    aniso = dot(tangent, half_vector);
    aniso = -aniso * aniso + 1;
    aniso = pow(aniso, _AnistropyInt);
    aniso = saturate(aniso);

    bump = bump * 2.0f - 1.0f; // reencode the normals to the -1 1 range

    bump.x = saturate(-bump.x * _AnistropyNormalInt + aniso);


    float3 shift = smoothstep(_StockingRangeMin, _StockingRangeMax, ndotv);

    return float3(bump.x,shift.x, 1);
}

//--------------------------------------------------------------------------------------
float4 matcap_specular(float3 normal, float shadow, float spec_check, float3 spec, float3 diffuse, float skin_id)
{
    float2 sphere_uv = mul(normal, (float3x3)UNITY_MATRIX_I_V ).xy;
    sphere_uv = sphere_uv * 0.5f + 0.5f;  
    float4 matcap = _MatCapTex.Sample(sampler_linear_repeat, sphere_uv);
    spec.x = saturate(spec.x);
    float3 matcap_specular = lerp(matcap.x, matcap.y, spec.x);
    float3 spec_something = saturate(spec.yzx * float3(3,3,0.5) + float3(-1,-2,0.5));
    matcap_specular = lerp(matcap_specular, matcap.z, spec_something.x);
    matcap_specular = lerp(matcap_specular, matcap.w, spec_something.y);
    float2 matcap_int = lerp((float2)_MatCapInt, float2(_MetalMatCapBack, _MetalMatCapInt), spec_check);
    float shadow_check = shadow <= 0.65;

    float2 metal_shadow_int = matcap_int.x * shadow_check;
    metal_shadow_int.y = -matcap_int.x * shadow_check + matcap_int.y;
    metal_shadow_int.y = (1.0 - shadow_check) * metal_shadow_int.y + metal_shadow_int.x;
    matcap_specular = matcap_specular * metal_shadow_int.y;

    float3 something = diffuse.xyz * lerp(1.0f, _SkinColor, skin_id.x) + -(0.08f * spec_something.z);
    float3 metal_color = spec.x * something + (0.08f * spec_something.z);
    float4 metal_something = spec.zzzz *  float4(-1.f,-0.0275f,-0.572f,0.022f) + float4(1,0.0425f,1.04f,-0.04f);
    matcap_specular = saturate(matcap_specular);
    return float4(metal_color, matcap_specular.x);
}

float3 matcap_coloring(float3 diffuse, float4 matcap, float spec)
{
   return lerp(diffuse.xyz, diffuse.xyz * matcap.xyz, matcap.w * (spec.x >= 0.5));
}
//--------------------------------------------------------------------------------------
// material funtions 
void material_basic(inout float3 color, inout float4 shadow, inout float3 specular, in float3 normal, in float3 light, in float3 half_vector, in float3 spec, in float2 uv, in float shadow_mask, in float3 skin_id, in float2 typemask, inout float shadow_area, inout float4 matcap)
{


    float metal_check = (0.00000003 >= spec.z); 
    metal_check = (metal_check) ? 0 : pow(spec.z, 0.1f);
    metal_check = ((1 + -metal_check) * 19.899f + 0.1f) * -999 + 1000;

    float spec_check = (spec.x >= 0.85) ? 1.0f : 0.0f;

    // specular
    float power = lerp(_MetalSpecularPower, _SpecularPower, saturate(metal_check));
    specular = specular_base(normal, half_vector, shadow_mask, power, spec, skin_id.z);
    float specular2 = specular_base_second(normal, half_vector, shadow_mask, power, spec, skin_id.z);
    specular2 = specular2 >= _ToonMaxSpecular;
    specular = specular + (specular2 * 0.25f);
    specular = saturate(specular) * pow(color, lerp(0.5f, 2.0f, spec.x));

    // get shadow color
    float4 container = shadow_color_base(normal, light, uv, shadow_mask, skin_id.x, typemask.y, shadow_area);
    shadow = container.xyzw;
    shadow_area = container.w;

    
    matcap = matcap_specular(normal, shadow.w, spec_check, spec, color, skin_id.x);
    color.xyz = matcap_coloring(color.xyz, matcap, spec);
    
}

void material_tight(inout float3 color, inout float4 shadow, inout float3 specular, in float3 half_vector, in float3 light, in float3 normal, in float3 tangent, in float3 bitangent, in float3 ws_pos, in float2 uv, float2 bump, in float3 view, in float shadow_mask, in float2 skin_id, in float2 typemask, inout float shadow_area, inout float3 shift, inout float4 matcap, in float3 spec)
{
    float3 aniso = specular_tight(normal, tangent, bitangent, half_vector, dot(normal, view), ws_pos.xyz, uv, bump);
    
    float3 aniso_specular = aniso.x * ((_AnistropyColor) + 0.0025f);
    shift = saturate(sqrt(lerp((_StockingEdgeColor), (_StockingColor), min(aniso.y, 1.0f))));
    shift = color * shift + -color;
    shift = _StockingIntensity * shift + color;
    float3 stocking_light = saturate(dot(normal, half_vector));

    float spec_check = (spec.x >= 0.85) ? 1.0f : 0.0f;

    stocking_light = smoothstep(_StockingLightRangeMin, _StockingLightRangeMax, stocking_light.x);
    stocking_light = stocking_light.x * (_StockingLightColor);

    float3 stocking = stocking_light.x + shift;

    float4 container = shadow_color_base(normal, light, uv, shadow_mask, skin_id.x, typemask.y, shadow_area);
    shadow = container.xyzw;
    shadow_area = container.w;
    
    specular = aniso_specular;
    color = stocking;

    matcap = matcap_specular(normal, shadow.w, spec_check, spec, color, skin_id.x);
    color.xyz = matcap_coloring(color.xyz, matcap, spec);
}

void material_face(inout float3 shadow, in float3 normal, in float3 light, in float2 uv, in float shadow_mask, in float skin_id, in float typemask, inout float shadow_area)
{
    
    float4 container = shadow_color_base(normal, light, uv, shadow_mask, skin_id, typemask, shadow_area);
    shadow = container.xyz;
    shadow_area = container.w;
}

void material_hair(inout float3 shadow, inout float3 specular, in float3 normal, in float3 light, in float3 half_vector, in float4 hair_mask, in float skin_id, inout float shadow_area)
{   
    float4 container = shadow_color_hair(normal, light, hair_mask, skin_id, shadow_area);
    shadow = container.xyz;
    shadow_area = container.w;
    specular = specular_hair(normal, half_vector, hair_mask.x, dot(normal, light));
}

void material_eye(inout float3 color, inout float stencilmask, inout float3 shine, in float3 normal, in float3 tangent, in float3 bitangent, in float2 uv, in float3 view, in float4 vertexcolor)
{
    // intialize uv for eye parallax
    float2 eye_uv = uv;

    // parallax occlusion mapping
    // originally was going to use segas implementation of parallax and relief mapping for people to choose from but that was never going to work LOL
    pom(normal, tangent, bitangent, view, uv, eye_uv);

    // mask the eye so that the garbage artifacts dont appear in the whites
    float mask = saturate(_EM.Sample(sampler_linear_repeat, uv).w);
    float3 eye = _MainTex.Sample(sampler_linear_repeat, eye_uv);
    float3 eye_base = _MainTex.Sample(sampler_linear_repeat, uv);
    float stencil_mask_a = _Mask.Sample(sampler_linear_repeat, eye_uv).x;
    float stencil_mask_b = _Mask.Sample(sampler_linear_repeat, uv).x;
    eye = lerp(eye, eye_base, smoothstep(0.99, 1.0, mask));
    #if defined(is_stencil)
        color = eye;
    #endif
    stencilmask = lerp(stencil_mask_a, stencil_mask_b, smoothstep(0.99, 1.0, mask));

    // highlight 1 
    float shake = _LightShakeScale * sin(6.28318548 * (_LightShakeSpeed * _Time.y));

    float2 slight_pos = lerp(float2(_SecondLight_PositionX, _SecondLight_PositionY), float2(_SecondLight_PositionX, _SecondLight_PositionY), vertexcolor.yy);

    slight_pos.x = ((_LightShakPositionX * shake + slight_pos.x) + _LightPositionX);
    slight_pos.y = ((_LightShakPositionY * shake + slight_pos.y));

    float2 light_pos; 
    light_pos.x = slight_pos.x + 0.05f;
    light_pos.y = slight_pos.y + _LightPositionY;

    float2 idk = ((float2)1.f / float2(0.24f, 0.135f));

    light_pos.xy = light_pos.xy * idk;

    float2 rotation;
    sincos(_RotateAngle, rotation.x, rotation.y);
    float4 r6;
    r6.x = rotation.y;
    float4 r1;
    float4 r4;
    r4.xy = light_pos.xy;
    r4.zw = idk;
    float4 r5;
    r5.x = rotation.x;
    float4 r7;
    float4 r8;

    r7.z = -r5.x * r4.w;
    r1.w = -r6.x * r4.x + (r5.x * r4.y);
    r7.w = 0.5 + r1.w;
    r8.x = r5.x * r4.z;
    r7.xy = r6.xx * r4.zw;

    r1.w = -r5.x * r4.x + -(r6.x * r4.y);
    r8.z = 0.5 + r1.w;
    r4.xy = uv.xy;
    r4.z = 1;
    r5.x = dot(r7.xzw, r4.xyz);
    r8.y = r7.y;
    r5.y = dot(r8.xyz, r4.xyz);

    float3 highlight = _HeightLightMap.Sample(sampler_linear_clamp, r5.xy).xyz;
    r5.xyz = highlight;

    r1.w = _EyeScale * r5.z;
    r1.w = _HeightRatioInput * -r1.w + r1.w;
    r6.xy = float2(1,1) / float2(_HeightLight_WidthX, _HeightLight_WidthY);
    r6.zw = -float2(0.5, 0.5) * r6.xy + float2(0.5,0.5);
    r7.x = dot(r6.xz, r4.xz);
    r7.y = dot(r6.yw, r4.yz);

    float shine2 = _EM.Sample(sampler_linear_clamp, r7.xy).x;
    shine2 = lerp(shine2, 0, mask) * _HeightRatioInput;
    
    eye = eye + r1.w + shine2;
    shine = r1.w;
    
    
    
    #if !defined(is_stencil)
        color = eye;
    #endif
}

void material_glass(inout float4 color, in float3 normal, in float3 ss_pos, in float3 view, in float2 uv)
{
    float highlight = _HeightLightTex.Sample(sampler_linear_repeat, uv).x;
    color.xyz = highlight;
    color.w = 0.1f;
}


void material_tacet(inout float3 color, in float2 uv)
{
    float4 sdf = _D.Sample(sampler_linear_repeat, uv).xyzw;

    float2 noise2_uv = _Time.yy * (float2)_SoundWaveSpeed02 + (uv * (float2)_SoundWaveTiling02);
    float2 noise1_uv = _Time.yy * (float2)_SoundWaveSpeed01 + (uv * (float2)_SoundWaveTiling01);
    float noise1 = _Noise.Sample(sampler_linear_repeat, noise1_uv).xy;
    float noise2 = _Noise02.Sample(sampler_linear_repeat, noise2_uv).xy;

    float mark = (noise1.x * noise2.x - sdf.z )  >=  _SDFStart;
    clip((1-mark) - 0.01f);

    color.xyz = lerp(_SDFColor, color.xyz, mark);
}