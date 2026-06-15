#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Ported from the "Plasma Bloom" iridescent wallpaper shader (shaders.js).
// Living blobs of color drifting and merging, with a touch-driven glow and
// a single expanding ripple ring on tap. Used as the Journal Companion
// splash/onboarding background (design_notes.md "liquid glass" direction).

namespace {

float hash21(float2 p) {
    p = fract(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(float2 p) {
    float v = 0.0;
    float a = 0.5;
    float2x2 m = float2x2(float2(1.6, -1.2), float2(1.2, 1.6));
    for (int i = 0; i < 5; i++) {
        v += a * vnoise(p);
        p = m * p;
        a *= 0.5;
    }
    return v;
}

// Iridescent "Golden Hour" palette: amber -> coral -> peach -> rose -> warm cream.
float3 irid(float t) {
    float3 a = float3(0.95, 0.76, 0.62);
    float3 b = float3(0.05, 0.15, 0.22);
    float3 d = float3(0.00, 0.18, 0.50);
    return a + b * cos(6.28318 * (t + d));
}

// Tiny dither to kill banding on smooth gradients.
float dither(float2 fc, float time) {
    return (hash21(fc + fract(time)) - 0.5) / 255.0;
}

// A single expanding, decaying ripple ring (xy = origin, z = start time, w = strength).
float rippleField(float2 p, float aspect, float4 ripple, float time) {
    if (ripple.w < 0.5) {
        return 0.0;
    }
    float age = time - ripple.z;
    if (age < 0.0 || age > 4.0) {
        return 0.0;
    }
    float2 d = float2((p.x - ripple.x) * aspect, p.y - ripple.y);
    float dist = length(d);
    float radius = age * 0.55;
    float dr = (dist - radius) / 0.13;
    float ring = exp(-dr * dr);
    float decay = exp(-age * 1.2);
    return sin((dist - radius) * 38.0) * ring * decay * ripple.w;
}

}

/// SwiftUI `colorEffect` shader. `size` is the layer size in points, `touch` is
/// the normalized (0...1) touch position (origin top-left, matching SwiftUI's
/// coordinate space), `touchActive` is 1 while pressed, and `ripple` is the
/// most recent tap's origin/start-time/strength.
[[ stitchable ]]
half4 plasmaBloom(float2 position, half4 color, float2 size, float time,
                   float2 touch, float touchActive, float4 ripple) {
    float2 fc = position;
    float2 p = fc / size;
    float aspect = size.x / size.y;
    float2 uv = float2(p.x * aspect, p.y);
    float t = time * 0.12;

    float field = 0.0;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        float2 c = float2(aspect * (0.5 + 0.40 * sin(t * 0.6 + fi * 2.1)),
                                  0.5 + 0.40 * cos(t * 0.52 + fi * 1.7));
        float2 dd = uv - c;
        float r2 = dot(dd, dd);
        field += (0.020 + 0.004 * fi) / (r2 + 0.004);
    }

    float2 mc = float2(touch.x * aspect, touch.y);
    float2 dm = uv - mc;
    float rm = dot(dm, dm);
    field += (0.045 + 0.06 * touchActive) / (rm + 0.004);
    field += rippleField(p, aspect, ripple, time) * 0.6;

    float v = smoothstep(0.7, 2.4, field);
    float hue = field * 0.10 + t * 0.25 + 0.05;
    float3 col = irid(hue);
    col = mix(float3(1.0), col, clamp(v, 0.0, 1.0) * 0.9);

    float band = smoothstep(0.9, 1.1, field) - smoothstep(1.1, 1.4, field);
    col -= band * 0.06;          // soft membrane outline
    col += 0.10 * exp(-rm * 5.0); // touch core glow
    col += float3(dither(fc, time));

    return half4(half3(clamp(col, 0.0, 1.0)), 1.0);
}
