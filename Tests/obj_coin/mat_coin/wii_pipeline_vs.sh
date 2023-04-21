//------------------------------------------------------------------------------
/** @file   wii_pipleline_vs.sh
 *  @brief  wiiのパイプラインエミュレータ（頂点）
 *  @author Takuhiro Dohta
 */
//------------------------------------------------------------------------------
#version 150

//------------------------------------------------------------------------------
// ハード仕様
//------------------------------------------------------------------------------
#define CHANNEL_MAX     	( 2 )
#define LIGHT_OBJ_MAX       ( 8 )
#define FOG_MAX             ( 8 )

//@@ group="priority" label="描画優先度" order="110"
//@@ renderinfo="priority" group="priority" label="描画優先度" type="int" default="0"

//------------------------------------------------------------------------------
// マクロ定義
//------------------------------------------------------------------------------
#define chan_ctrl_rgb( n )	chan_ctrl##n##_color.rgb
#define	chan_ctrl_a( n )	chan_ctrl##n##_alpha.a
#define reg_color0 			mat_color0
#define reg_color1 			mat_color1
#define vtx_color0			aColor0
#define vtx_color1			aColor1

#define calc_channel( n )                                                                                                                    \
{                                                                                                                                            \
    vec3 enable_light_rgb = vec3( chan_ctrl##n##_color_light_enable, chan_ctrl##n##_color_light_enable, chan_ctrl##n##_color_light_enable ); \
    vec3 light_color_rgb = clamp( diffuse_light.rgb + amb_color##n.rgb * cAmbColor[##n].rgb, 0.0, 1.0 );                                     \
    float light_color_a  = clamp( diffuse_light.a   + amb_color##n.a,                        0.0, 1.0 );                                     \
    color##n##a##n.rgb = chan_ctrl##n##_color.rgb * max( enable_light_rgb, light_color_rgb );                                                \
    color##n##a##n.a   = chan_ctrl##n##_alpha.a   * max( 1.0 - chan_ctrl##0##_alpha_light_enable, light_color_a );                           \
}                                                                                                                                          \

//------------------------------------------------------------------------------
#define src_tex0 	vec4 tex_coord = vec4( aTexCoord0, 1.0, 1.0 )
#define src_tex1 	vec4 tex_coord = vec4( aTexCoord1, 1.0, 1.0 )
#define src_tex2 	vec4 tex_coord = vec4( aTexCoord2, 1.0, 1.0 )
#define src_tex3 	vec4 tex_coord = vec4( aTexCoord3, 1.0, 1.0 )
#define src_tex4 	vec4 tex_coord = vec4( aTexCoord4, 1.0, 1.0 )
#define src_tex5 	vec4 tex_coord = vec4( aTexCoord5, 1.0, 1.0 )
#define src_tex6 	vec4 tex_coord = vec4( aTexCoord6, 1.0, 1.0 )
#define src_tex7 	vec4 tex_coord = vec4( aTexCoord7, 1.0, 1.0 )
#define src_pos  	vec4 tex_coord = vec4( posv.x, posv.y, posv.z, 1.0 )
#define src_nrm  	vec4 tex_coord = vec4( nrmv.x * 0.5 + 0.5, nrmv.y * -0.5 + 0.5, 1.0, 1.0 ) // NW4R makes z to 1.0

#define expand_tex_func( n )	tex_coord##n##_src_param
#define expand_tex_mtx( n )   	tex_coord##n##_mtx

#define calc_tex_coord( n )                                        \
{                                                                  \
    expand_tex_func( n );                                          \
    tex_coord##n##.x = dot( expand_tex_mtx( n )[ 0 ], tex_coord ); \
    tex_coord##n##.y = dot( expand_tex_mtx( n )[ 1 ], tex_coord ); \
    float tw         = dot( expand_tex_mtx( n )[ 2 ], tex_coord ); \
}                                                                  

//------------------------------------------------------------------------------
// 静的バリエーション用マクロ
//------------------------------------------------------------------------------
// tag  : "chan_ctrl_array"
// attr : "size"
// "2"  : "1"
// "4"  : "2"
#define channel_num 1

// tag  : "chan_ctrl"
// attr : channel
// "reg" : mat_color
// "vtx" : vtx_color
#define chan_ctrl0_color reg_color0
#define chan_ctrl0_color_light_enable light_off

#define chan_ctrl0_alpha reg_color0
#define chan_ctrl0_alpha_light_enable light_off

#define chan_ctrl1_color 		       	chan_ctrl0_color
#define chan_ctrl1_alpha        		chan_ctrl0_ctrl_alpha
#define chan_ctrl1_color_light_enable	chan_ctrl0_color_light_enable
#define chan_ctrl1_alpha_light_enable	chan_ctrl0_alpha_light_enable

//------------------------------------------------------------------------------
// tag  : "material"

// attr : "fog_index"
// "-1"-"128" : "-1"-"128"
#define fog_index 0

//------------------------------------------------------------------------------
// tag  : "tex_coord_array"

// attr : "size"
// "0"-"15" : "0" - "15"
#define tex_coord_num 3

// tag  : "tex_coord"

// attr : "func"
// "mtx24" : "tex_mtx24"
// "mtx34" : "tex_mtx34"
#define tex_coord0_func tex_mtx34

// attr : "src_param"
// "tex0" - "tex7" : "tex0" - "tex7"
// "nrm" : "nrm"
// "pos" : "pos"
#define tex_coord0_src_param src_nrm

// attr : "mtx"
// "texmtx0" - "texmtx7" : "texmtx0" - "texmtx7"
#define tex_coord0_mtx texmtx0

#define tex_coord1_func tex_mtx34
#define tex_coord1_src_param src_nrm
#define tex_coord1_mtx texmtx1

#define tex_coord2_func tex_mtx34
#define tex_coord2_src_param src_nrm
#define tex_coord2_mtx texmtx2

#define tex_coord3_func			tex_mtx24
#define tex_coord3_src_param	src_tex0
#define tex_coord3_mtx			texmtx0

#define tex_coord4_func			tex_mtx24
#define tex_coord4_src_param	src_tex0
#define tex_coord4_mtx			texmtx0

#define tex_coord5_func			tex_mtx24
#define tex_coord5_src_param	src_tex0
#define tex_coord5_mtx			texmtx0

#define tex_coord6_func			tex_mtx24
#define tex_coord6_src_param	src_tex0
#define tex_coord6_mtx			texmtx0

#define tex_coord7_func			tex_mtx24
#define tex_coord7_src_param	src_tex0
#define tex_coord7_mtx			texmtx0

//------------------------------------------------------------------------------
// 環境と視点を合わせたデータ
//------------------------------------------------------------------------------
layout(std140) uniform MdlEnvView
{
    vec4        cView[ 3 ];
    vec4        cViewProj[ 4 ];
    vec3        cLightDiffDir[ LIGHT_OBJ_MAX ];
    vec4        cLightDiffColor[ LIGHT_OBJ_MAX ];
    vec4        cAmbColor[ CHANNEL_MAX ];
    vec3        cFogColor[ FOG_MAX ];
    float       cFogStart[ FOG_MAX ];
    float       cFogStartEndInv[ FOG_MAX ];
};

//------------------------------------------------------------------------------
// Skeletonごとのuniform
//------------------------------------------------------------------------------
layout(std140) uniform MdlMtx
{
    vec4        cMtxPalette[ 64 * 3 ];
};

//------------------------------------------------------------------------------
// Shapeごとのuniform
//------------------------------------------------------------------------------
#if 0

layout(std140) uniform Shp
{
    int         cWeightNum;
};

#else

layout(std140) uniform Shp
{
    vec4        cShpMtx[ 3 ];
    int         cWeightNum;
};

#endif

//------------------------------------------------------------------------------
// マテリアル
//------------------------------------------------------------------------------
layout(std140) uniform Mat
{
    vec4        mat_color0;       // @@ id="mat_color0"    item="color"     default="1 1 1 1"
    vec4        mat_color1;       // @@ id="mat_color1"    item="color"     default="1 1 1 1"
    vec4        amb_color0;       // @@ id="amb_color0"    item="color"     default="1 1 1 1"
    vec4        amb_color1;       // @@ id="amb_color1"    item="color"     default="1 1 1 1"
    vec4        tev_color0;       // @@ id="tev_color0"    item="color"     default="1 1 1 1"
    vec4        tev_color1;       // @@ id="tev_color1"    item="color"     default="1 1 1 1"
    vec4        tev_color2;       // @@ id="tev_color2"    item="color"     default="1 1 1 1"
    vec4        konst0;           // @@ id="konst0"        item="color"     default="1 1 1 1"
    vec4        konst1;           // @@ id="konst1"        item="color"     default="1 1 1 1"
    vec4        konst2;           // @@ id="konst2"        item="color"     default="1 1 1 1"
    vec4        konst3;           // @@ id="konst3"        item="color"     default="1 1 1 1"
    vec4		ind_texmtx0[ 2 ]; // @@ id="ind_texmtx0"   type="srt2d"     default="1 1 0 0 0"
    vec4		ind_texmtx1[ 2 ]; // @@ id="ind_texmtx1"   type="srt2d"     default="1 1 0 0 0"
    vec4		ind_texmtx2[ 2 ]; // @@ id="ind_texmtx2"   type="srt2d"     default="1 1 0 0 0"
    vec4		texmtx0[ 3 ];     // @@ id="texmtx0"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo0"
    vec4		texmtx1[ 3 ];     // @@ id="texmtx1"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo1"
    vec4		texmtx2[ 3 ];     // @@ id="texmtx2"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo2"
    vec4		texmtx3[ 3 ];     // @@ id="texmtx3"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo3"
    vec4		texmtx4[ 3 ];     // @@ id="texmtx4"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo4"
    vec4		texmtx5[ 3 ];     // @@ id="texmtx5"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo5"
    vec4		texmtx6[ 3 ];     // @@ id="texmtx6"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo6"
    vec4		texmtx7[ 3 ];     // @@ id="texmtx7"       type="texsrt_ex" default="0 1 1 0 0 0" hint="albedo7"
};

//------------------------------------------------------------------------------
in      vec3   aPosition;    // @@ id="_p0" hint="position0"
in      vec3   aNormal;      // @@ id="_n0" hint="normal0"
in      vec4   aBlendWeight; // @@ id="_w0" hint="blendweight0"
in      ivec4  aBlendIndex;  // @@ id="_i0" hint="blendindex0"
in      vec2   aTexCoord0;   // @@ id="_u0" hint="uv0"
in      vec2   aTexCoord1;   // @@ id="_u1" hint="uv1"
in      vec2   aTexCoord2;   // @@ id="_u2" hint="uv2"
in      vec2   aTexCoord3;   // @@ id="_u3" hint="uv3"
in      vec2   aTexCoord4;   // @@ id="_u4" hint="uv4"
in      vec2   aTexCoord5;   // @@ id="_u5" hint="uv5"
in      vec2   aTexCoord6;   // @@ id="_u6" hint="uv6"
in      vec2   aTexCoord7;   // @@ id="_u7" hint="uv7"
in      vec4   aColor0;      // @@ id="_c0" hint="color0"
in      vec4   aColor1;      // @@ id="_c1" hint="color1"

out     vec2   tex_coord0;
out     vec2   tex_coord1;
out     vec2   tex_coord2;
out     vec2   tex_coord3;
out     vec2   tex_coord4;
out     vec2   tex_coord5;
out     vec2   tex_coord6;
out     vec2   tex_coord7;
out     vec4   color0a0;
out     vec4   color1a1;
out     vec4   fog_color;
// red-pro2
out     vec3   normal;

const float light_on  = 0.0;
const float light_off = 1.0;

#define calc_weight_skining( weight_index )                  \
{                                                            \
    int index    = aBlendIndex[ weight_index ] * 3;          \
    float weight = aBlendWeight[ weight_index ];             \
    posw.x += weight * dot( cMtxPalette[ index + 0 ], pos ); \
    posw.y += weight * dot( cMtxPalette[ index + 1 ], pos ); \
    posw.z += weight * dot( cMtxPalette[ index + 2 ], pos ); \
    nrmw.x += weight * dot( cMtxPalette[ index + 0 ], nrm ); \
    nrmw.y += weight * dot( cMtxPalette[ index + 1 ], nrm ); \
    nrmw.z += weight * dot( cMtxPalette[ index + 2 ], nrm ); \
}

void main()
{
    vec4 pos = vec4( aPosition, 1 );
    vec4 nrm = vec4( aNormal,   0 );

    vec4 posw = vec4( 0.0, 0.0, 0.0, 1.0 );
    vec4 nrmw = vec4( 0.0 );

    // GLSLの最適化による変な挙動を防ぐために4つまではベタ書きしておく
    switch ( cWeightNum )
    {
    case 0:
        {
            posw.x = dot( cShpMtx[ 0 ], pos );
            posw.y = dot( cShpMtx[ 1 ], pos );
            posw.z = dot( cShpMtx[ 2 ], pos );

            nrmw.x = dot( cShpMtx[ 0 ], nrm );
            nrmw.y = dot( cShpMtx[ 1 ], nrm );
            nrmw.z = dot( cShpMtx[ 2 ], nrm );
            break;
        }
    case 1:
        {
            int index = aBlendIndex[ 0 ] * 3;

            posw.x = dot( cMtxPalette[ index + 0 ], pos );
            posw.y = dot( cMtxPalette[ index + 1 ], pos );
            posw.z = dot( cMtxPalette[ index + 2 ], pos );

            nrmw.x = dot( cMtxPalette[ index + 0 ], nrm );
            nrmw.y = dot( cMtxPalette[ index + 1 ], nrm );
            nrmw.z = dot( cMtxPalette[ index + 2 ], nrm );
            break;
        }
    case 2:
        {
            calc_weight_skining( 0 );
            calc_weight_skining( 1 );
            break;
        }
    case 3:
        {
            calc_weight_skining( 0 );
            calc_weight_skining( 1 );
            calc_weight_skining( 2 );
            break;
        }
    case 4:
        {
            calc_weight_skining( 0 );
            calc_weight_skining( 1 );
            calc_weight_skining( 2 );
            calc_weight_skining( 3 );
            break;
        }
    default:
        {
            // 一応残しておくが、ここに来るのは非推奨
            for ( int i = 0; i < cWeightNum; ++i )
            {
                calc_weight_skining( i );
            }
            break;
        }
    }

    nrmw = normalize( nrmw );

    vec3 nrmv = vec3( dot( cView[ 0 ], nrmw ), dot( cView[ 1 ], nrmw ), dot( cView[ 2 ], nrmw ) );
    vec3 posv = vec3( dot( cView[ 0 ], posw ), dot( cView[ 1 ], posw ), dot( cView[ 2 ], posw ) );

    vec4 diffuse_light = vec4( 0.0 );
    for ( int i = 0; i < LIGHT_OBJ_MAX; ++i )
    {
        diffuse_light += clamp( -dot( nrmv, cLightDiffDir[ i ] ), 0.0, 1.0 ) * cLightDiffColor[ i ];
    }
    diffuse_light = clamp( diffuse_light, 0.0, 1.0 );

#if ( 0 < channel_num )
    calc_channel( 0 );
#endif

#if ( 1 < channel_num )
    calc_channel( 1 );
#endif

#if ( 0 < tex_coord_num )
    calc_tex_coord( 0 );
#endif

#if ( 1 < tex_coord_num )
    calc_tex_coord( 1 );
#endif

#if ( 2 < tex_coord_num )
    calc_tex_coord( 2 );
#endif

#if ( 3 < tex_coord_num )
    calc_tex_coord( 3 );
#endif

#if ( 4 < tex_coord_num )
    calc_tex_coord( 4 );
#endif

#if ( 5 < tex_coord_num )
    calc_tex_coord( 5 );
#endif

#if ( 6 < tex_coord_num )
    calc_tex_coord( 6 );
#endif

#if ( 7 < tex_coord_num )
    calc_tex_coord( 7 );
#endif

#if ( 0 <= fog_index )

    // if vertex color
    fog_color.rgb = cFogColor[ fog_index ].rgb;
    fog_color.a   = clamp( ( -posv.z - cFogStart[ fog_index ] ) * cFogStartEndInv[ fog_index ], 0.0, 1.0 );

#else

    fog_color.rgb = vec3( 1.0 );
    fog_color.a   = 0.0;

#endif

    gl_Position.x = dot( cViewProj[ 0 ], posw );
    gl_Position.y = dot( cViewProj[ 1 ], posw );
    gl_Position.z = dot( cViewProj[ 2 ], posw );
    gl_Position.w = dot( cViewProj[ 3 ], posw );
    
    normal.xyz = nrmw.xyz;
}


 