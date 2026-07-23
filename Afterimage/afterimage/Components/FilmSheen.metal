#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// MARK: - Film sheen shader
//
// Backs `ScrollSheen.swift`. Generates an organic, per-card-randomized specular
// sheen for the film-strip negative — the texture/irregularity the old single
// linear-gradient band lacked.
//
// Everything here is a pure function of (position, progress, seed): no clock,
// no per-frame randomness. The host view feeds `progress` from scroll offset,
// so the sheen only moves while the feed moves — keeping the DESIGN.md rule
// "no continuous infinite animations on the feed."

namespace afterimage {

// Cheap hash → value noise → fbm. Used for the wavy light front and the
// mottled grain along the streak.
inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

inline float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

inline float fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p *= 2.02;
        amp *= 0.5;
    }
    return v;
}

} // namespace afterimage

// `size`      — strip pixel size, for uv normalization.
// `progress`  — 0…1 scroll travel of this strip through the viewport.
// `seed`      — per-card random seed (tilt, phases, widths derive from it).
// `intensity` — peak brightness scalar.
[[ stitchable ]]
half4 filmSheen(float2 pos, half4 color,
                float2 size, float progress, float seed, float intensity) {
    using namespace afterimage;

    float2 uv = pos / max(size, float2(1.0, 1.0));

    // Vertical glare front (no tilt): the streak runs straight down the strip
    // so the light is uniform top-to-bottom — the strip never reads as
    // permanently brighter at the top. It still sweeps horizontally with
    // scroll, so the glare animation is preserved.
    float diag = uv.x;

    // Wavy light front: bend the straight edge with low-frequency fbm so the
    // boundary of the light reads as scattered, not ruler-straight. Kept small
    // and symmetric about the centre line (uv.y - 0.5) so it adds no net
    // top-vs-bottom brightness bias.
    float wob = fbm(float2(uv.y * 3.5 + seed * 4.0, seed)) - 0.5;
    diag += wob * 0.06;

    half3 acc = half3(0.0);
    float alpha = 0.0;

    // Several sub-streaks at seeded phase / width / speed → interference and
    // overlap instead of one uniform band.
    const int N = 3;
    for (int k = 0; k < N; k++) {
        float fk = float(k);
        float ph     = hash21(float2(seed + fk * 3.1, 2.3));
        float sweeps = mix(0.7, 1.5, hash21(float2(seed + fk, 5.1)));
        float w      = mix(0.045, 0.12, hash21(float2(seed + fk, 9.4)));
        float center = fract(progress * sweeps + ph);

        float d = diag - center;
        d -= round(d);                                   // wrap to [-0.5, 0.5]
        float band = exp(-(d * d) / (2.0 * w * w));

        // Mottled grain along the streak — brightness is blotchy, not flat.
        float tex = 0.4 + 1.0 * fbm(uv * float2(9.0, 16.0) + seed * 3.0 + fk * 2.0);
        band *= tex;

        // Subtle iridescence (the rainbow a real negative throws under light),
        // biased warm so it stays on the app's gold/cream palette.
        float hue = d * 3.5 + seed * 0.7 + fk * 0.27;
        half3 irid = half3(0.5 + 0.5 * cos(6.2831 * (hue + 0.00)),
                           0.5 + 0.5 * cos(6.2831 * (hue + 0.33)),
                           0.5 + 0.5 * cos(6.2831 * (hue + 0.66)));
        half3 warm = half3(1.0, 0.92, 0.78);
        half3 col = mix(warm, irid, half(0.4));

        acc += col * half(band);
        alpha += band;
    }

    // Strongest as the card crosses mid-screen — the glint "passes by."
    float focus = clamp(1.0 - abs(progress - 0.5) * 2.0, 0.0, 1.0);
    float env = intensity * (0.3 + 0.7 * focus);

    acc *= half(env);
    alpha = clamp(alpha * env, 0.0, 1.0);

    return half4(acc, half(alpha));
}
