// MIT License — Lain project.
// Four-pass Anime4K-style DoG ×2 upscale, the same chain the web player
// runs under its `anime4k-dog-x2` preset (luminance → Gaussian X →
// Gaussian Y → bounded correction at 2× output).

//!DESC Lain DoG luminance
//!HOOK MAIN
//!BIND MAIN
//!SAVE LINELUMA

vec4 hook() {
    return vec4(dot(MAIN_tex(MAIN_pos), vec4(0.299, 0.587, 0.114, 0.0)), 0.0, 0.0, 1.0);
}

//!DESC Lain DoG Gaussian X
//!HOOK LINELUMA
//!BIND LINELUMA
//!SAVE MMKERNEL

vec4 hook() {
    vec2 d = vec2(LINELUMA_pt.x, 0.0);
    float c = LINELUMA_tex(LINELUMA_pos).r;
    float l = LINELUMA_tex(LINELUMA_pos - d).r;
    float r = LINELUMA_tex(LINELUMA_pos + d).r;
    float g = (LINELUMA_tex(LINELUMA_pos - d * 2.0).r + LINELUMA_tex(LINELUMA_pos + d * 2.0).r) * 0.06136;
    g += (l + r) * 0.24477 + c * 0.38774;
    return vec4(g, min(min(l, c), r), max(max(l, c), r), 1.0);
}

//!DESC Lain DoG Gaussian Y
//!HOOK MMKERNEL
//!BIND MMKERNEL
//!SAVE LINEKERNEL

vec4 hook() {
    vec2 d = vec2(0.0, MMKERNEL_pt.y);
    vec3 c = MMKERNEL_tex(MMKERNEL_pos).rgb;
    vec3 a = MMKERNEL_tex(MMKERNEL_pos - d).rgb;
    vec3 b = MMKERNEL_tex(MMKERNEL_pos + d).rgb;
    float g = (MMKERNEL_tex(MMKERNEL_pos - d * 2.0).r + MMKERNEL_tex(MMKERNEL_pos + d * 2.0).r) * 0.06136;
    g += (a.r + b.r) * 0.24477 + c.r * 0.38774;
    return vec4(g, min(min(a.g, c.g), b.g), max(max(a.b, c.b), b.b), 1.0);
}

//!DESC Lain DoG apply x2
//!HOOK MAIN
//!BIND MAIN
//!BIND LINELUMA
//!BIND LINEKERNEL
//!WIDTH NATIVE.w 2 *
//!HEIGHT NATIVE.h 2 *
//!SAVE MAIN

vec4 hook() {
    float lum = LINELUMA_tex(LINELUMA_pos).r;
    vec3 gauss = LINEKERNEL_tex(LINEKERNEL_pos).rgb;
    float correction = clamp((lum - gauss.r) * 0.8 + lum, gauss.g, gauss.b) - lum;
    return MAIN_tex(MAIN_pos) + vec4(correction, correction, correction, 0.0);
}
