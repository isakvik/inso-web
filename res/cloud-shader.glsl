/*
Adapted from "2D clouds" by drift: https://www.shadertoy.com/view/4tdSWr
*/

#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec2 iResolution;
uniform float iTime;

const float cloudscale = 1.1;
const float speed = 0.005;
const float cloudcover = 0.2;
const float cloudalpha = 8.0;
const mat2 m = mat2(1.6, 1.2, -1.2, 1.6);

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(in vec2 p) {
    const float k1 = 0.366025404;
    const float k2 = 0.211324865;
    vec2 i = floor(p + (p.x + p.y) * k1);
    vec2 a = p - i + (i.x + i.y) * k2;
    vec2 o = a.x > a.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec2 b = a - o + k2;
    vec2 c = a - 1.0 + 2.0 * k2;
    vec3 h = max(0.5 - vec3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    vec3 n = h * h * h * h * vec3(dot(a, hash(i)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

float fbm(vec2 n) {
    float total = 0.0;
    float amplitude = 0.1;

    for (int i = 0; i < 7; i++) {
        total += noise(n) * amplitude;
        n = m * n;
        amplitude *= 0.4;
    }

    return total;
}

void main() {
    vec2 p = gl_FragCoord.xy / iResolution.xy;
    vec2 uv = p * vec2(iResolution.x / iResolution.y, 1.0);
    float time = iTime * speed;
    float q = fbm(uv * cloudscale * 0.5);

    float ridge = 0.0;
    uv *= cloudscale;
    uv -= q - time;
    float weight = 0.8;

    for (int i = 0; i < 8; i++) {
        ridge += abs(weight * noise(uv));
        uv = m * uv + time;
        weight *= 0.7;
    }

    float shape = 0.0;
    uv = p * vec2(iResolution.x / iResolution.y, 1.0);
    uv *= cloudscale;
    uv -= q - time;
    weight = 0.7;

    for (int i = 0; i < 8; i++) {
        shape += weight * noise(uv);
        uv = m * uv + time;
        weight *= 0.6;
    }

    shape *= ridge + shape;

    float detail = 0.0;
    time = iTime * speed * 2.0;
    uv = p * vec2(iResolution.x / iResolution.y, 1.0);
    uv *= cloudscale * 2.0;
    uv -= q - time;
    weight = 0.4;

    for (int i = 0; i < 7; i++) {
        detail += weight * noise(uv);
        uv = m * uv + time;
        weight *= 0.6;
    }

    float ridgeDetail = 0.0;
    time = iTime * speed * 3.0;
    uv = p * vec2(iResolution.x / iResolution.y, 1.0);
    uv *= cloudscale * 3.0;
    uv -= q - time;
    weight = 0.4;

    for (int i = 0; i < 7; i++) {
        ridgeDetail += abs(weight * noise(uv));
        uv = m * uv + time;
        weight *= 0.6;
    }

    detail += ridgeDetail;

    float coverage = cloudcover + cloudalpha * shape * ridge;
    float cloudAmount = clamp(coverage + detail, 0.0, 1.0);
    float sideWeight = smoothstep(0.0, 0.88, abs(p.x * 2.0 - 1.0));
    float density = smoothstep(0.18, 0.78, cloudAmount) * sideWeight;
    float light = clamp(0.35 + detail * 1.8, 0.0, 1.0);
    vec3 cloudColor = mix(vec3(0.36, 0.26, 0.44), vec3(0.0), light);

    gl_FragColor = vec4(cloudColor, density * 0.4);
}
