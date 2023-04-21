//------------------------------------------------------------------------------
/** @file   wii_pipleline_fs.sh
 *  @brief  wiiのパイプラインエミュレータ（フラグメント）
 *  @author Takuhiro Dohta
 */
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// ハード仕様
//------------------------------------------------------------------------------
#define TEV_STAGE_MAX   	( 8 )
#define IND_STAGE_MAX   	( 4 )

//------------------------------------------------------------------------------
// マクロ定義
//------------------------------------------------------------------------------
#define konst_color8( x )		vec4( x / 8.0 )
#define expand_swap_table( n )	swap_table##n
#define swap_table( c, n )		c.expand_swap_table( n )
#define tev_tex_coord( n )		stage_ind##n##_offset( stage##n##_tex_coord_order, textureSize( stage##n##_tex_map_order, 0 ) )
#define tev_tex_fetch( n )      texture( stage##n##_tex_map_order, tev_tex_coord( n ) )
#define ind_tex_fetch( n )		texture( ind_stage##n##_tex_map_order, ind_stage##n##_tex_coord_order )

#define ind_offset0( tex_coord, tex_size )       ( ( tex_coord ) + ( ind_offset0_ ) / ( tex_size ) )
#define ind_offset1( tex_coord, tex_size )       ( ( tex_coord ) + ( ind_offset1_ ) / ( tex_size ) )
#define ind_offset2( tex_coord, tex_size )       ( ( tex_coord ) + ( ind_offset2_ ) / ( tex_size ) )
#define ind_offset3( tex_coord, tex_size )       ( ( tex_coord ) + ( ind_offset3_ ) / ( tex_size ) )
#define ind_offset_null( tex_coord, tex_size )   ( ( tex_coord ) )
#define divide_2( stage )                        ( ( stage ) * 0.5 )
#define scale_1( stage )                         ( ( stage ) )
#define scale_2( stage )                         ( ( stage ) * 2.0 )
#define scale_4( stage )                         ( ( stage ) * 4.0 )
#define op_add( a, b )                           ( ( a ) + ( b ) )
#define op_sub( a, b )                           ( ( a ) - ( b ) )
#define bias_zero_rgb( stage )                   ( ( stage ) )
#define bias_add_half_rgb( stage )               ( ( stage ) + vec3( 0.5 ) )
#define bias_sub_half_rgb( stage )               ( ( stage ) - vec3( 0.5 ) )
#define bias_zero_a( stage )                     ( ( stage ) )
#define bias_add_half_a( stage )                 ( ( stage ) + 0.5 )
#define bias_sub_half_a( stage )                 ( ( stage ) - 0.5 )

#define calc_tev_rgb( ca, cb, cc, cd, op, bias, scale ) \
  clamp( scale( bias( op( ( cd ), ( ( one.rgb - ( cc ) ) * ( ca ) + ( cc ) * ( cb ) ) ) ) ), 0.0, 1.0 )

#define calc_tev_alpha( aa, ab, ac, ad, op, bias, scale ) \
  clamp( scale( bias( op( ( ad ), ( ( one.a   - ( ac ) ) * ( aa ) + ( ac ) * ( ab ) ) ) ) ), 0.0, 1.0 )

#define calc_tev_stage( n )                                              \
{                                                                        \
    vec4 ras = swap_table( stage##n##_ras_order, stage##n##_ras_swap );  \
    vec4 tex = tev_tex_fetch( n );                                       \
    tex = swap_table( tex, stage##n##_tex_map_swap );                    \
                                                                         \
    vec3 konst_color  = stage_color##n##_konst;                          \
    float konst_alpha = stage_alpha##n##_konst;                          \
                                                                         \
    stage_color##n##_out_reg.rgb = calc_tev_rgb( stage_color##n##_a,     \
                                                 stage_color##n##_b,     \
                                                 stage_color##n##_c,     \
                                                 stage_color##n##_d,     \
                                                 stage_color##n##_op,    \
                                                 stage_color##n##_bias,  \
                                                 stage_color##n##_scale  \
                                                 );                      \
                                                                         \
    stage_alpha##n##_out_reg.a = calc_tev_alpha( stage_alpha##n##_a,     \
                                                 stage_alpha##n##_b,     \
                                                 stage_alpha##n##_c,     \
                                                 stage_alpha##n##_d,     \
                                                 stage_alpha##n##_op,    \
                                                 stage_alpha##n##_bias,  \
                                                 stage_alpha##n##_scale  \
                                                 );                      \
}

#define calc_ind_stage( n )                                                                                           \
{                                                                                                                     \
    vec4 tex = ind_tex_fetch( n ) - vec4( 0.5 );                                                                      \
    ind_offset##n##_ = ind_texmtx##n[ 0 ].xy * tex.a + ind_texmtx##n[ 0 ].zw * tex.r + ind_texmtx##n[ 1 ].xy * tex.r; \
    ind_offset##n##_ = ( ind_offset##n##_ ) * 255.0;                                                                  \
}                                                                                                    

//------------------------------------------------------------------------------
// tag  : "indirect_stage_array"

// attr : "size"

// "0"-"15" : "0" - "15"
#define ind_stage_num			   0

// attr : "tex_map_order"

// "-1", "0" - "7"  : "ind_tex_map0", "ind_tex_map0" - "ind_tex_map7" 
#define ind_stage0_tex_map_order   tex_map0

// attr : "tex_coord_order"

// "-1", "0" - "7"  : "ind_tex_coord0", "ind_tex_coord0" - "ind_tex_coord7"
#define ind_stage0_tex_coord_order tex_coord0

#define ind_stage1_tex_map_order   tex_map1
#define ind_stage1_tex_coord_order tex_coord1
#define ind_stage2_tex_map_order   tex_map2
#define ind_stage2_tex_coord_order tex_coord2
#define ind_stage3_tex_map_order   tex_map3
#define ind_stage3_tex_coord_order tex_coord3

//------------------------------------------------------------------------------
// tag  : "add_indirect_combination_array"

// attr : "size"

// "0"-"15" : "0" - "15"
#define ind_combination_num     0

//------------------------------------------------------------------------------
// tag  : "tev_stage_array"

// attr : "size"

// "0"-"15" : "0" - "15"
#define tev_stage_num 3

// attr : "swap_table0" - "swap_table3"

// ex."r g b a" : "rgba"
// ex."r r r b" : "rrrb"
#define swap_table0 rgba
#define swap_table1 rrra
#define swap_table2 ggga
#define swap_table3 bbba

//------------------------------------------------------------------------------
// tag  : "tev_stage"

// attr : "ras_order"

// "color0a0"   : "color0a0"
// "color1a1"   : "color1a1"
// "color_null" : "color_null"
#define stage0_ras_order color_null

// attr : "tex_map_order"

// "-1", "0" - "7"  : "tex_map0", "tex_map0" - "tex_map7"
#define stage0_tex_map_order tex_map0

// attr : "tex_coord_order"

// "-1", "0" - "7"  : "tex_coord0", "tex_coord0" - "tex_coord7"
#define stage0_tex_coord_order tex_coord0

// attr : "ras_swap"

// "0" - "3" : "0" - "3"
#define stage0_ras_swap 0

// attr : "tex_map_swap"

// "0" - "3" : "0"-"3"
#define stage0_tex_map_swap 0

//------------------------------------------------------------------------------
// tag  : "tev_stage_color"

// attr : "a", "b", "c", "d"

// "rasc"   : "ras.rgb"
// "rasa"   : "ras.a"
// "texc"   : "tex.rgb"
// "texa"   : "tex.a"
// "c0"     : "reg0.rgb"
// "a0"     : "reg0.aaa"
// "c1"     : "reg1.rgb"
// "a1"     : "reg1.aaa"
// "c2"     : "reg2.rgb"
// "a2"     : "reg2.aaa"
// "cprev"  : "prev.rgb"
// "aprev"  : "prev.aaa"
// "konst"  : "konst_color.rgb"
// "zero"   : "zero.rgb"
// "half"   : "half_rgb"
// "one"    : "one.rgb"
#define stage_color0_a zero.rgb
#define stage_color0_b tex.rgb
#define stage_color0_c reg0.rgb
#define stage_color0_d zero.rgb

// attr   : "constant"

// "k0"   : "konst0.rgb"
// "k0_r" : "konst0.rrr"
// "k0_g" : "konst0.ggg"
// "k0_b" : "konst0.bbb"
// "k0_a" : "konst0.aaa"
// "k1"   : "konst1.rgb"
// "k1_r" : "konst1.rrr"
// "k1_g" : "konst1.ggg"
// "k1_b" : "konst1.bbb"
// "k1_a" : "konst1.aaa"
// "k2"   : "konst2.rgb"
// "k2_r" : "konst2.rrr"
// "k2_g" : "konst2.ggg"
// "k2_b" : "konst2.bbb"
// "k2_a" : "konst2.aaa"
// "k3"   : "konst3.rgb"
// "k3_r" : "konst3.rrr"
// "k3_g" : "konst3.ggg"
// "k3_b" : "konst3.bbb"
// "k3_a" : "konst3.aaa"
// "8_8"  : "konst_8_8.rgb"
// "7_8"  : "konst_7_8.rgb"
// "6_8"  : "konst_6_8.rgb"
// "5_8"  : "konst_5_8.rgb"
// "4_8"  : "konst_4_8.rgb"
// "3_8"  : "konst_3_8.rgb"
// "2_8"  : "konst_2_8.rgb"
// "1_8"  : "konst_1_8.rgb"
#define stage_color0_konst konst0.rgb

// attr : "op"

// "add" : "op_add"
// "sub" : "op_sub"
#define stage_color0_op op_add

// attr : "bias"

// "zero"     : "bias_zero_rgb"
// "sub_half" : "bias_sub_half_rgb"
// "add_half" : "bias_add_half_rgb"
#define stage_color0_bias bias_zero_rgb

// attr : "scale"

// "divide_2" : "divide_2
// "scale_1"  : "scale_1
// "scale_2"  : "scale_2
// "scale_4"  : "scale_4
#define stage_color0_scale scale_1

// attr : "out_reg"

// "reg0" : "reg0"
// "reg1" : "reg1"
// "reg2" : "reg2"
// "prev" : "prev"
#define stage_color0_out_reg reg2

//------------------------------------------------------------------------------
// tag  : "tev_stage_alpha"

// attr : "a", "b", "c", "d"

// "rasa"   : "ras.a"
// "texa"   : "tex.a"
// "a0"     : "reg0.a"
// "a1"     : "reg1.a"
// "a2"     : "reg2.a"
// "aprev"  : "prev.a"
// "konst"  : "konst_alpha"
// "zero"   : "zero.a"
#define stage_alpha0_a zero.a
#define stage_alpha0_b tex.a
#define stage_alpha0_c reg0.a
#define stage_alpha0_d zero.a
#define stage_alpha0_op op_add

// attr   : "constant"

// "k0_r" : "konst0.r"
// "k0_g" : "konst0.g"
// "k0_b" : "konst0.b"
// "k0_a" : "konst0.a"
// "k1_r" : "konst1.r"
// "k1_g" : "konst1.g"
// "k1_b" : "konst1.b"
// "k1_a" : "konst1.a"
// "k2_r" : "konst2.r"
// "k2_g" : "konst2.g"
// "k2_b" : "konst2.b"
// "k2_a" : "konst2.a"
// "k3_r" : "konst3.r"
// "k3_g" : "konst3.g"
// "k3_b" : "konst3.b"
// "k3_a" : "konst3.a"
// "8_8"  : "konst_8_8.a"
// "7_8"  : "konst_7_8.a"
// "6_8"  : "konst_6_8.a"
// "5_8"  : "konst_5_8.a"
// "4_8"  : "konst_4_8.a"
// "3_8"  : "konst_3_8.a"
// "2_8"  : "konst_2_8.a"
// "1_8"  : "konst_1_8.a"
#define stage_alpha0_konst konst_8_8.a

#define stage_alpha0_bias bias_zero_a
#define stage_alpha0_scale scale_1
#define stage_alpha0_out_reg reg2

//------------------------------------------------------------------------------
#define stage_ind0_offset ind_offset_null

//------------------------------------------------------------------------------
#define stage1_tex_map_order tex_map2
#define stage1_tex_coord_order tex_coord2
#define stage1_ras_order color_null
#define stage1_ras_swap 0
#define stage1_tex_map_swap 0
#define stage_color1_a zero.rgb
#define stage_color1_b tex.rgb
#define stage_color1_c reg2.aaa
#define stage_color1_d konst_color.rgb
#define stage_color1_konst konst3.rgb
#define stage_color1_op op_add
#define stage_color1_bias bias_zero_rgb
#define stage_color1_scale scale_1
#define stage_color1_out_reg prev
#define stage_alpha1_a zero.a
#define stage_alpha1_b zero.a
#define stage_alpha1_c zero.a
#define stage_alpha1_d zero.a
#define stage_alpha1_konst konst0.a
#define stage_alpha1_op op_add
#define stage_alpha1_bias bias_zero_a
#define stage_alpha1_scale scale_1
#define stage_alpha1_out_reg prev
#define stage_ind1_offset ind_offset_null

//------------------------------------------------------------------------------
#define stage2_tex_map_order tex_map1
#define stage2_tex_coord_order tex_coord1
#define stage2_ras_order color_null
#define stage2_ras_swap 0
#define stage2_tex_map_swap 0
#define stage_color2_a zero.rgb
#define stage_color2_b tex.rgb
#define stage_color2_c reg2.rgb
#define stage_color2_d prev.rgb
#define stage_color2_konst konst_8_8.rgb
#define stage_color2_op op_add
#define stage_color2_bias bias_zero_rgb
#define stage_color2_scale scale_1
#define stage_color2_out_reg prev
#define stage_alpha2_a zero.a
#define stage_alpha2_b zero.a
#define stage_alpha2_c zero.a
#define stage_alpha2_d zero.a
#define stage_alpha2_konst konst_8_8.a
#define stage_alpha2_op op_add
#define stage_alpha2_bias bias_zero_a
#define stage_alpha2_scale scale_1
#define stage_alpha2_out_reg prev
#define stage_ind2_offset ind_offset_null

//------------------------------------------------------------------------------
#define stage3_tex_map_order tex_map1
#define stage3_tex_coord_order tex_coord1
#define stage3_ras_order color_null
#define stage3_ras_swap 0
#define stage3_tex_map_swap 0
#define stage_color3_a zero.rgb
#define stage_color3_b tex.rgb
#define stage_color3_c reg2.rgb
#define stage_color3_d prev.rgb
#define stage_color3_konst konst_8_8.rgb
#define stage_color3_op op_add
#define stage_color3_bias bias_zero_rgb
#define stage_color3_scale scale_1
#define stage_color3_out_reg prev
#define stage_alpha3_a zero.a
#define stage_alpha3_b zero.a
#define stage_alpha3_c zero.a
#define stage_alpha3_d reg2.a
#define stage_alpha3_konst konst_8_8.a
#define stage_alpha3_op op_add
#define stage_alpha3_bias bias_zero_a
#define stage_alpha3_scale scale_1
#define stage_alpha3_out_reg prev
#define stage_ind3_offset ind_offset_null

//------------------------------------------------------------------------------
#define stage4_tex_map_order	stage0_tex_map_order
#define stage4_tex_coord_order	stage0_tex_coord_order
#define stage4_ras_order		stage0_ras_order
#define stage4_ras_swap			stage0_ras_swap
#define stage4_tex_map_swap		stage0_tex_map_swap
#define stage_color4_a          stage_color0_a
#define stage_color4_b          stage_color0_b
#define stage_color4_c          stage_color0_c
#define stage_color4_d          stage_color0_d
#define stage_color4_konst		stage_color0_konst
#define stage_color4_op         stage_color0_op
#define stage_color4_bias       stage_color0_bias
#define stage_color4_scale      stage_color0_scale
#define stage_color4_out_reg    stage_color0_out_reg
#define stage_alpha4_a          stage_alpha0_a
#define stage_alpha4_b          stage_alpha0_b
#define stage_alpha4_c          stage_alpha0_c
#define stage_alpha4_d          stage_alpha0_d
#define stage_alpha4_konst		stage_alpha0_konst
#define stage_alpha4_op         stage_alpha0_op
#define stage_alpha4_bias       stage_alpha0_bias
#define stage_alpha4_scale      stage_alpha0_scale
#define stage_alpha4_out_reg    stage_alpha0_out_reg
#define stage_ind4_offset       ind_offset_null

//------------------------------------------------------------------------------
#define stage5_tex_map_order	stage0_tex_map_order
#define stage5_tex_coord_order	stage0_tex_coord_order
#define stage5_ras_order		stage0_ras_order
#define stage5_ras_swap			stage0_ras_swap
#define stage5_tex_map_swap		stage0_tex_map_swap
#define stage_color5_a          stage_color0_a
#define stage_color5_b          stage_color0_b
#define stage_color5_c          stage_color0_c
#define stage_color5_d          stage_color0_d
#define stage_color5_konst		stage_color0_konst
#define stage_color5_op         stage_color0_op
#define stage_color5_bias       stage_color0_bias
#define stage_color5_scale      stage_color0_scale
#define stage_color5_out_reg    stage_color0_out_reg
#define stage_alpha5_a          stage_alpha0_a
#define stage_alpha5_b          stage_alpha0_b
#define stage_alpha5_c          stage_alpha0_c
#define stage_alpha5_d          stage_alpha0_d
#define stage_alpha5_konst		stage_alpha0_konst
#define stage_alpha5_op         stage_alpha0_op
#define stage_alpha5_bias       stage_alpha0_bias
#define stage_alpha5_scale      stage_alpha0_scale
#define stage_alpha5_out_reg    stage_alpha0_out_reg
#define stage_ind5_offset       ind_offset_null

//------------------------------------------------------------------------------
#define stage6_tex_map_order	stage0_tex_map_order
#define stage6_tex_coord_order	stage0_tex_coord_order
#define stage6_ras_order		stage0_ras_order
#define stage6_ras_swap			stage0_ras_swap
#define stage6_tex_map_swap		stage0_tex_map_swap
#define stage_color6_a          stage_color0_a
#define stage_color6_b          stage_color0_b
#define stage_color6_c          stage_color0_c
#define stage_color6_d          stage_color0_d
#define stage_color6_konst		stage_color0_konst
#define stage_color6_op         stage_color0_op
#define stage_color6_bias       stage_color0_bias
#define stage_color6_scale      stage_color0_scale
#define stage_color6_out_reg    stage_color0_out_reg
#define stage_alpha6_a          stage_alpha0_a
#define stage_alpha6_b          stage_alpha0_b
#define stage_alpha6_c          stage_alpha0_c
#define stage_alpha6_d          stage_alpha0_d
#define stage_alpha6_konst		stage_alpha0_konst
#define stage_alpha6_op         stage_alpha0_op
#define stage_alpha6_bias       stage_alpha0_bias
#define stage_alpha6_scale      stage_alpha0_scale
#define stage_alpha6_out_reg    stage_alpha0_out_reg
#define stage_ind6_offset       ind_offset_null

//------------------------------------------------------------------------------
#define stage7_tex_map_order	stage0_tex_map_order
#define stage7_tex_coord_order	stage0_tex_coord_order
#define stage7_ras_order		stage0_ras_order
#define stage7_ras_swap			stage0_ras_swap
#define stage7_tex_map_swap		stage0_tex_map_swap
#define stage_color7_a          stage_color0_a
#define stage_color7_b          stage_color0_b
#define stage_color7_c          stage_color0_c
#define stage_color7_d          stage_color0_d
#define stage_color7_konst		stage_color0_konst
#define stage_color7_op         stage_color0_op
#define stage_color7_bias       stage_color0_bias
#define stage_color7_scale      stage_color0_scale
#define stage_color7_out_reg    stage_color0_out_reg
#define stage_alpha7_a          stage_alpha0_a
#define stage_alpha7_b          stage_alpha0_b
#define stage_alpha7_c          stage_alpha0_c
#define stage_alpha7_d          stage_alpha0_d
#define stage_alpha7_konst		stage_alpha0_konst
#define stage_alpha7_op         stage_alpha0_op
#define stage_alpha7_bias       stage_alpha0_bias
#define stage_alpha7_scale      stage_alpha0_scale
#define stage_alpha7_out_reg    stage_alpha0_out_reg
#define stage_ind7_offset       ind_offset_null

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
// テクスチャ
//------------------------------------------------------------------------------
uniform sampler2D tex_map0; // @@ id="_a0" hint="albedo0"
uniform sampler2D tex_map1; // @@ id="_a1" hint="albedo1"
uniform sampler2D tex_map2; // @@ id="_a2" hint="albedo2"
uniform sampler2D tex_map3; // @@ id="_a3" hint="albedo3"
uniform sampler2D tex_map4; // @@ id="_a4" hint="albedo4"
uniform sampler2D tex_map5; // @@ id="_a5" hint="albedo5"
uniform sampler2D tex_map6; // @@ id="_a6" hint="albedo6"
uniform sampler2D tex_map7; // @@ id="_a7" hint="albedo7"

in      vec2   tex_coord0;
in      vec2   tex_coord1;
in      vec2   tex_coord2;
in      vec2   tex_coord3;
in      vec2   tex_coord4;
in      vec2   tex_coord5;
in      vec2   tex_coord6;
in      vec2   tex_coord7;
in      vec4   color0a0;
in      vec4   color1a1;
in      vec4   fog_color;
// red-pro2
in      vec3   normal;

#define one    const_one
#define zero   const_zero
#define half   const_half

// for swizzle accsess
const vec4 const_zero = vec4( 0.0 );
const vec4 const_half = vec4( 0.5 );
const vec4 const_one  = vec4( 1.0 );
const vec4 konst_8_8  = konst_color8( 8.0 );
const vec4 konst_7_8  = konst_color8( 7.0 );
const vec4 konst_6_8  = konst_color8( 6.0 );
const vec4 konst_5_8  = konst_color8( 5.0 );
const vec4 konst_4_8  = konst_color8( 4.0 );
const vec4 konst_3_8  = konst_color8( 3.0 );
const vec4 konst_2_8  = konst_color8( 2.0 );
const vec4 konst_1_8  = konst_color8( 1.0 );
const vec4 color_null = const_one;

void main( void )
{
#if ( tev_stage_num < 0 || TEV_STAGE_MAX < tev_stage_num )
#   error
#endif

#if ( ind_stage_num < 0 || IND_STAGE_MAX < ind_stage_num )
#   error
#endif

    vec2 ind_offset0_ = vec2( 0.0 );
    vec2 ind_offset1_ = vec2( 0.0 );
    vec2 ind_offset2_ = vec2( 0.0 );
    vec2 ind_offset3_ = vec2( 0.0 );

    // indirect
#if ( 0 < ind_stage_num )
    calc_ind_stage( 0 );
#endif

#if ( 1 < ind_stage_num )
    calc_ind_stage( 1 );
#endif

#if ( 2 < ind_stage_num )
    calc_ind_stage( 2 );
#endif

#if ( 3 < ind_stage_num )
    calc_ind_stage( 3 );
#endif

    // tev stage
    vec4 reg0 = tev_color0;
    vec4 reg1 = tev_color1;
    vec4 reg2 = tev_color2;
    vec4 prev = one;

#if ( 0 < tev_stage_num )
    calc_tev_stage( 0 );
#endif

#if ( 1 < tev_stage_num )
    calc_tev_stage( 1 );
#endif

#if ( 2 < tev_stage_num )
    calc_tev_stage( 2 );
#endif

#if ( 3 < tev_stage_num )
    calc_tev_stage( 3 );
#endif

#if ( 4 < tev_stage_num )
    calc_tev_stage( 4 );
#endif

#if ( 5 < tev_stage_num )
    calc_tev_stage( 5 );
#endif

#if ( 6 < tev_stage_num )
    calc_tev_stage( 6 );
#endif

#if ( 7 < tev_stage_num )
    calc_tev_stage( 7 );
#endif

    gl_FragData[ 0 ].rgb = mix( prev.rgb, fog_color.rgb, fog_color.a );
    gl_FragData[ 0 ].a   = prev.a;
    
    gl_FragData[ 1 ].rgb = normalize( normal ) * 0.5 + 0.5;
    gl_FragData[ 1 ].a   = 1.0;   
}


 