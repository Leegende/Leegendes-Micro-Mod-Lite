Includes = {
    "constants.fxh"
    "standardfuncsgfx.fxh"
    "pdxmap.fxh"
    "shadow.fxh"
    "tiled_pointlights.fxh"
    "fow.fxh"
}

## 1. MANDATORY STRUCTS (Keeps the game from crashing)
VertexStruct VS_INPUT_WATER
{
    int2 position : POSITION;
};

VertexStruct VS_OUTPUT_WATER
{
    float4 position         : PDX_POSITION;
    float3 pos              : TEXCOORD0; 
    float2 uv               : TEXCOORD1;
    float4 screen_pos       : TEXCOORD2; 
    float3 cubeRotation     : TEXCOORD3;
    float4 vShadowProj      : TEXCOORD4;    
    float4 vScreenCoord     : TEXCOORD5;
    float2 uv_ice           : TEXCOORD6;    
};

ConstantBuffer( 3, 48 )
{
    float3 vTime_HalfPixelOffset;
};

## 2. SAMPLERS (The 'OG' list)
PixelShader =
{
    Samplers =
    {
        HeightTexture = { Index = 0 }
        LeanTexture1 = { Index = 1 }
        LeanTexture2 = { Index = 2 }
        ProvinceSecondaryColorMap = { Index = 3 }
        SpecularMap = { Index = 4 }
        WaterRefraction = { Index = 5 }
        IceDiffuse = { Index = 6 }
        IceNoise = { Index = 7 }
        ReflectionCubeMap = { Index = 8 Type = "Cube" }
        SnowMudTexture = { Index = 9 }
        LightIndexMap = { Index = 10 }
        LightDataMap = { Index = 11 }
        GradientBorderChannel1 = { Index = 12 }
        GradientBorderChannel2 = { Index = 13 }       
        GradientBorderChannel3 = { Index = 14 }
        ShadowMap = { Index = 15 Type = "Shadow" }
    }
}

VertexShader =
{
    MainCode VertexShader
    [[
        VS_OUTPUT_WATER main( const VS_INPUT_WATER VertexIn )
        {
            VS_OUTPUT_WATER VertexOut;
            VertexOut.pos = float3( VertexIn.position.x, WATER_HEIGHT, VertexIn.position.y );
            VertexOut.position = mul( ViewProjectionMatrix, float4( VertexOut.pos.x, VertexOut.pos.y, VertexOut.pos.z, 1.0f ) );
            VertexOut.screen_pos = VertexOut.position;
            VertexOut.screen_pos.y = FIX_FLIPPED_UV( VertexOut.screen_pos.y );
            VertexOut.uv = float2( ( VertexIn.position.x + 0.5f ) / MAP_SIZE_X,  ( VertexIn.position.y + 0.5f - MAP_SIZE_Y ) / -MAP_SIZE_Y );
            VertexOut.uv *= float2( MAP_POW2_X, MAP_POW2_Y );
            VertexOut.uv_ice = VertexOut.uv * float2( MAP_SIZE_X, MAP_SIZE_Y ) * 0.1f;
            VertexOut.uv_ice *= float2( FOW_POW2_X, FOW_POW2_Y );
        
            float vAnimTime = vTime_HalfPixelOffset.x * 0.01f;
            VertexOut.cubeRotation = normalize( float3( sin( vAnimTime ) * 0.5f, sin( vAnimTime ), cos( vAnimTime ) * 0.3f ) );
            VertexOut.vShadowProj = mul( ShadowMapTextureMatrix, float4( VertexOut.pos, 1.0f ) );   
            
            VertexOut.vScreenCoord.x = ( VertexOut.position.x * 0.5 + VertexOut.position.w * 0.5 );
            VertexOut.vScreenCoord.y = ( VertexOut.position.w * 0.5 - VertexOut.position.y * 0.5 );
            VertexOut.vScreenCoord.z = VertexOut.position.w;
            VertexOut.vScreenCoord.w = VertexOut.position.w;    
            
            return VertexOut;
        }
    ]]
}

PixelShader =
{
    MainCode PixelShader
    [[
        // FORCED HIGH QUALITY CODE - REMOVED ALL IFDEFS
        float3 ApplyIce( float3 vColor, float2 vPos, inout float3 vNormal, float4 vMudSnowColor, float2 vIceUV, out float vIceFade )
        {
            float4 vIceDiffuse = tex2D( IceDiffuse, vIceUV );
            float vIceNoise = tex2D( IceNoise, ( vPos + 0.5f ) * ICE_NOISE_TILING ).r;
            float vSnow = saturate( GetSnow( vMudSnowColor ) - 0.0f );
            vIceFade = saturate( ( (vSnow*8.0f * vIceNoise * (1 - cam_distance( ICE_CAM_MIN, ICE_CAM_MAX ))) - 0.3f ) * 10.0f );
            vNormal = normalize( lerp( vNormal, normalize( vIceDiffuse.rbg - 0.5f ), vIceFade ) );
            return lerp( vColor, ICE_COLOR * vIceDiffuse.a, vIceFade );
        }

        float MultiSampleTexX( in sampler2D TexCh, in float2 vUV )
        {
            float vOffsetX = -0.5f / MAP_SIZE_X;
            float vOffsetY = -0.5f / MAP_SIZE_Y;
            float vResult = tex2D( TexCh, vUV ).x;
            vResult += tex2D( TexCh, vUV + float2( -vOffsetX, 0 ) ).x;
            vResult += tex2D( TexCh, vUV + float2( 0, -vOffsetY ) ).x;
            vResult += tex2D( TexCh, vUV + float2( vOffsetX, 0 ) ).x;
            vResult += tex2D( TexCh, vUV + float2( 0, vOffsetY ) ).x;
            vResult /= 5;
            return vResult;
        }
        
        float4 main( VS_OUTPUT_WATER Input ) : PDX_COLOR
        {
            float waterHeight = MultiSampleTexX( HeightTexture, Input.uv ) / ( 95.7f / 255.0f );
            float waterShore = saturate( ( waterHeight - 0.954f ) * 25.0f );
        
            float2 B; float3 M; float3 normal;
            SampleWater( Input.uv, vTime_HalfPixelOffset.x, B, M, normal, LeanTexture1, LeanTexture2 );
        
            float vSpecMap = tex2D( SpecularMap, Input.uv ).a;
            normal.y += ( 1.0f - vSpecMap );
            normal.xz *= vSpecMap;
            normal = normalize( normal );
            
            float3 SunDirWater = CalculateSunDirectionWater( Input.pos );
            float3 H = normalize( normalize(vCamPos - Input.pos).xzy + -SunDirWater.xzy );
            float2 HWave = H.xy/H.z - B;
        
            float3 sigma = M - float3( B*B, B.x*B.y);
            float det = sigma.x*sigma.y - sigma.z*sigma.z;
            float e = HWave.x*HWave.x*sigma.y + HWave.y*HWave.y*sigma.x - 2*HWave.x*HWave.y*sigma.z;
            float spec = (det <= 0) ? 0.0f : exp( -0.5f*e/det ) / sqrt(det);
            
            float2 refractiveUV = ( Input.screen_pos.xy / Input.screen_pos.w ) * 0.5f + 0.5f;
            refractiveUV.y = 1.0f - refractiveUV.y;
            float2 vRefractionDistortion = normal.xz * saturate( 5.0f - ( Input.screen_pos.z / Input.screen_pos.w ) * 5.0f ) * 1.80f;
        
            float3 vEyeDir = normalize( Input.pos - vCamPos.xyz );
            float3 reflectiveColor = texCUBE( ReflectionCubeMap, reflect( vEyeDir, normal ) ).rgb;
            float3 refractiveColor = tex2D( WaterRefraction, (refractiveUV.xy + vTime_HalfPixelOffset.gb) - vRefractionDistortion ).rgb;

            float fresnel = saturate( 0.5f + ( 0.5f ) * pow( 1.0f - saturate( dot( -vEyeDir, normal ) ) * 0.5f, 10.0) );
            refractiveColor = refractiveColor * ( 1.0f - fresnel ) + reflectiveColor * fresnel;
            
            float vIceFade = 0.0f;
            float4 vMudSnowColor = GetMudSnowColor( Input.pos, SnowMudTexture );
            refractiveColor = ApplyIce( refractiveColor, Input.pos.xz, normal, vMudSnowColor, Input.uv_ice, vIceFade );

            float vBloomAlpha = 0.0f;
            gradient_border_apply( refractiveColor, normal, Input.uv + vRefractionDistortion * 0.0075f, GradientBorderChannel1, GradientBorderChannel2, 0.0f, vGBCamDistOverride_GBOutlineCutoff.zw * GB_OUTLINE_CUTOFF_SEA, vGBCamDistOverride_GBOutlineCutoff.xy, vBloomAlpha );
            refractiveColor = lerp(refractiveColor, float3(0,0,0), 0.2f);
            secondary_color_mask( refractiveColor, normal, Input.uv - vRefractionDistortion * 0.001, ProvinceSecondaryColorMap, vBloomAlpha );

            LightingProperties lightingProperties;
            lightingProperties._WorldSpacePos = Input.pos;
            lightingProperties._ToCameraDir = normalize(vCamPos - Input.pos);
            lightingProperties._Normal = normal;
            lightingProperties._Diffuse = refractiveColor;
            lightingProperties._Glossiness = (spec/9.0f) * (1-vSpecMap) + vIceFade * 20.0f;
            lightingProperties._SpecularColor = vec3(0.010f + vIceFade * 0.07f);
            lightingProperties._NonLinearGlossiness = GetNonLinearGlossiness(lightingProperties._Glossiness);
            
            float3 diffuseLight = vec3(0.0); float3 specularLight = vec3(0.0);
            float fShadowTerm = GetShadowScaled( SHADOW_WEIGHT_WATER, Input.vScreenCoord, ShadowMap );
        
            CalculateSunLight( lightingProperties, fShadowTerm, SunDirWater, diffuseLight, specularLight );
            CalculatePointLights( lightingProperties, LightDataMap, LightIndexMap, diffuseLight, specularLight);

            float3 vOut = ComposeLight(lightingProperties, diffuseLight, specularLight);
            vOut = ApplyFOW( vOut, ShadowMap, Input.vScreenCoord );
            vOut = ApplyDistanceFog( vOut, Input.pos );
            vOut = DayNightWithBlend( vOut, CalcGlobeNormal( Input.pos.xz ), lerp(BORDER_NIGHT_DESATURATION_MAX, 1.0f, vBloomAlpha) );
            
            return float4( vOut, 1.0f - waterShore );
        }
    ]]
}

## 3. FINAL EFFECTS (All pointing to the same high-quality code)
BlendState BlendState { BlendEnable = yes AlphaTest = no SourceBlend = "src_alpha" DestBlend = "inv_src_alpha" WriteMask = "RED|GREEN|BLUE" }

Effect water_low_gfx { VertexShader = "VertexShader" PixelShader = "PixelShader" Defines = { "NO_REFRACTIONS" } }
Effect water_no_refractions { VertexShader = "VertexShader" PixelShader = "PixelShader" }
Effect water { VertexShader = "VertexShader" PixelShader = "PixelShader" }