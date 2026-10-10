#version 440

// Recolour Clawd: every pixel that is a multiple of the body orange
// (body, side shade, the walk's darker shades) becomes the same multiple of
// `target`. Hats, headphones, tools, eyes and outlines are not multiples of
// the body colour and stay as drawn. Build: tools/build-shaders.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 target;
};

layout(binding = 1) uniform sampler2D source;

const vec3 BODY = vec3(201.0, 113.0, 89.0) / 255.0;

void main() {
    vec4 p = texture(source, qt_TexCoord0);
    if (p.a > 0.0) {
        vec3 c = p.rgb / p.a;
        float k = dot(c, BODY) / dot(BODY, BODY);
        if (k > 0.15 && length(c - k * BODY) < 0.02)
            c = clamp(k * target.rgb, 0.0, 1.0);
        p = vec4(c * p.a, p.a);
    }
    fragColor = p * qt_Opacity;
}
