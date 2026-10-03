shader_type spatial;
// 共用材質（規格 docs/Western_Faceted_FPS_Shader_美術改善規格.docx 的「Western_Faceted_Master」）：
// 模型匯進來的標準材質，在 main.gd 的 _flatten_models 一律換成這個，參數照抄（顏色、紋理、粗糙度記號、自發光）。
// 跟標準材質只差打光：照到多少光（受光角度 × 影子）不連續漸變，而是分成幾段固定亮度（規格第 4 節），
// 低面數模型每一面朝的方向不同，就會落在不同段，一面一面看得出來。
render_mode cull_disabled, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform bool use_triplanar = false;   // 紋理用物件自己的座標三面投影（main.gd 的 _add_grain）
uniform bool use_vcol = false;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float roughness = 1.0;        // 描線認東西的記號（outline.gdshader），不是真的粗糙度
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 1.0;
// 打光分段
uniform float ramp_steps = 4.0;       // 幾段（規格 3～5）；0 = 不分段，跟標準材質一樣連續
uniform float ramp_soft = 0.06;       // 段和段之間的過渡寬度（一段的幾成）：0 會在大面上看到鋸齒

// 背光那一面也要看得出一面一面：夕陽多半在鏡頭前方，看到的都是背光面，只有環境光照著，
// 環境光（main.tscn，七成是單一顏色）不分方向，每一面一樣亮，面就糊成一片。
// 這裡補一道「天空光」：朝天（和朝太陽那一邊）的面亮一點、朝地的暗一點，也分段。整塊顏色乘上去，受光面也跟著有一點差
uniform float facet_fill = 0.38;      // 最暗和最亮的面差多少（0 = 關）。0.22 幾乎看不出來，0.5 屋頂和兩面牆分得很開
uniform vec3 fill_dir = vec3(-0.45, 1.0, -0.21);   // 天空光從哪來：朝上、略偏太陽（main.tscn 的 Sun）的方位
uniform float fill_steps = 3.0;

// 材質分色（規格第 14 節）：木頭、石頭、植物、金屬各有自己的暗部和受光色調（乘在顏色上，接近 1 的小偏移）。
// main.gd 的 FACET_TYPES 照材質名字設。暗部 = 環境光照的部分，受光 = 太陽照的部分
uniform vec3 shade_tint = vec3(1.0);
uniform vec3 lit_tint = vec3(1.0);
uniform float value = 1.0;            // 整體明度：屋頂比牆暗一段（規格第 10 節）
// 夕陽很橘，直接乘上去每樣東西都變成同一種橘。太陽光的顏色先抽掉一些，材質自己的色相才留得住（規格第 5 節）
uniform float sun_neutral = 0.3;

varying vec3 tri_pos;
varying vec3 tri_w;

// 照到多少光 x（0～1）壓成 ramp_steps 段：四捨五入到最近的一段，平均亮度跟連續的差不多
float ramp_n(float x, float n) {
	if (n <= 0.0) {
		return x;
	}
	float s = x * n;
	float f = floor(s);
	return (f + smoothstep(0.5 - ramp_soft, 0.5 + ramp_soft, s - f)) / n;
}

float ramp(float x) {
	return ramp_n(x, ramp_steps);
}

void vertex() {
	if (use_triplanar) {
		// 跟標準材質的三面投影一樣算（Godot 的 BaseMaterial3D，混合銳利度 1）
		tri_w = abs(NORMAL);
		tri_w /= dot(tri_w, vec3(1.0));
		tri_pos = (VERTEX * uv_scale + uv_offset) * vec3(1.0, -1.0, 1.0);
	}
}

void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		if (use_triplanar) {
			c *= texture(albedo_tex, tri_pos.xy) * tri_w.z
				+ texture(albedo_tex, tri_pos.zy) * tri_w.x
				+ texture(albedo_tex, tri_pos.xz * vec2(1.0, -1.0)) * tri_w.y;
		} else {
			c *= texture(albedo_tex, UV * uv_scale.xy + uv_offset.xy);
		}
	}
	if (use_vcol) {
		c *= COLOR;
	}
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float fill = ramp_n(0.5 + 0.5 * dot(wn, normalize(fill_dir)), fill_steps);
	ALBEDO = c.rgb * (1.0 + facet_fill * (fill - 0.6)) * shade_tint * value;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	EMISSION = emission * emission_energy;
}

void light() {
	float x = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	vec3 sun = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.2126, 0.7152, 0.0722))), sun_neutral);
	DIFFUSE_LIGHT += ramp(x) * sun / PI * lit_tint / shade_tint;   // ALBEDO 已經乘了 shade_tint，受光的部分換成 lit_tint
}
