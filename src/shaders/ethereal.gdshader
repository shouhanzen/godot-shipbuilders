shader_type canvas_item;

// ----------------------------------
// Classic 2D Perlin Noise (cnoise)
// Courtesy of various implementations of Perlin noise in GLSL
// ----------------------------------
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

vec2 fade2(vec2 t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float permute(float x) {
    return mod(((34.0 * x) + 1.0) * x, 289.0);
}

vec4 permute4(vec4 x) {
    return mod(((34.0 * x) + 1.0) * x, 289.0);
}

float cnoise(vec2 P) {
    vec2 Pi = floor(P);
    vec2 Pf = fract(P);
    vec4 ix = vec4(Pi.x, Pi.x + 1.0, Pi.x, Pi.x + 1.0);
    vec4 iy = vec4(Pi.y, Pi.y, Pi.y + 1.0, Pi.y + 1.0);
    ix = mod(ix, 289.0);
    iy = mod(iy, 289.0);
    vec4 i = permute4(permute4(ix) + iy);
    vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0;
    vec4 gy = abs(gx) - 0.5;
    vec4 tx = floor(gx + 0.5);
    gx = gx - tx;
    vec2 f = fade2(Pf);
    vec4 g_dot = gx * vec4(Pf.x, Pf.x - 1.0, Pf.x, Pf.x - 1.0) +
                 gy * vec4(Pf.y, Pf.y, Pf.y - 1.0, Pf.y - 1.0);
    vec2 blend = vec2(
        mix(g_dot.x, g_dot.y, f.x),
        mix(g_dot.z, g_dot.w, f.x)
    );
    return mix(blend.x, blend.y, f.y);
}

float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    const int OCTAVES = 6; // Increased octaves for finer detail

    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * cnoise(st * frequency);
        frequency *= 2.0; // Doubling frequency at each octave
        amplitude *= 0.5; // Halving amplitude for smoothness
    }
    return value;
}

void fragment() {
    vec2 uv = SCREEN_UV * 15.0; // Increased scale for denser patterns
    float t = TIME * 0.2;

    float n = fbm(uv + vec2(t));
    float n2 = fbm(uv * 1.5 - vec2(t * 0.3));

    vec3 color1 = vec3(0.5, 0.6, 0.8); // Balanced blue
    vec3 color2 = vec3(0.8, 0.5, 0.7); // Softer purple
    vec3 color3 = vec3(0.3, 0.7, 0.6); // Calmer turquoise

    vec3 mixedColor = mix(color1, color2, smoothstep(0.2, 0.8, n));
    vec3 final_color = mix(mixedColor, color3, smoothstep(0.2, 0.8, n2 * n2));

    final_color *= 0.9; // Slight brightness reduction to maintain balance

    float pulse = 0.5 + 0.3 * sin(t * 2.0);
    final_color *= (1.0 + 0.1 * pulse);

    float sparkle = fbm(uv * 20.0 + t * 5.0); // Higher frequency for finer sparkle
    sparkle = pow(max(0.0, sparkle), 8.0) * 0.2; // Softer sparkle
    final_color += vec3(sparkle);

    COLOR = vec4(final_color, 1.0);
}
