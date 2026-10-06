// 地上燒著的燈油（oil_fire.gd 的油面）：一片會流動的火，切成三階硬邊顏色（跟全場平面著色的畫風一致）。
// 網格是從中心往外的扇形，頂點顏色 r = 0（中心）到 1（油潑到的邊緣），火往外越燒越稀、邊緣被侵蝕成鋸齒。
// burn：0..1 燒的強度（熄滅時往 0）。火的紋路用兩層雜訊往上（-z 方向）捲動，看起來像在流
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float burn = 1.0;
uniform vec3 c_dark : source_color = vec3(0.55, 0.12, 0.04);
uniform vec3 c_mid : source_color = vec3(1.0, 0.42, 0.06);
uniform vec3 c_hot : source_color = vec3(1.0, 0.82, 0.32);
uniform float scale = 2.6;   // 紋路多密（每公尺幾格）

varying vec3 wpos;
varying float edge;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = COLOR.r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = wpos.xz * scale;
	float t = TIME;
	// 兩層往不同方向捲動的雜訊：火在地上流、一直變
	float n = noise(p + vec2(t * 0.4, -t * 1.3)) * 0.6 + noise(p * 2.1 + vec2(-t * 0.9, -t * 2.2)) * 0.4;
	// 中心燒得旺、往外越稀；邊緣用雜訊侵蝕成不規則的鋸齒
	float heat = n + (1.0 - edge) * 0.55 - 0.25 + (burn - 1.0) * 0.8;
	if (heat < 0.32 || edge > 0.92 + n * 0.08) {
		discard;
	}
	vec3 c = c_dark;
	if (heat > 0.48) { c = c_mid; }
	if (heat > 0.68) { c = c_hot; }
	ALBEDO = c;
}
