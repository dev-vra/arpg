// Chão procedural em espaço de mundo: três cores misturadas por ruído em duas escalas.
shader_type spatial;

uniform vec4 color_a : source_color = vec4(0.2, 0.25, 0.15, 1.0);
uniform vec4 color_b : source_color = vec4(0.3, 0.25, 0.18, 1.0);
uniform vec4 color_c : source_color = vec4(0.12, 0.16, 0.1, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float scale = 0.05;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n1 = texture(noise, wpos.xz * scale).r;
	float n2 = texture(noise, wpos.xz * scale * 4.3 + vec2(0.37, 0.71)).r;
	float n3 = texture(noise, wpos.xz * scale * 17.0).r;
	vec3 col = mix(color_a.rgb, color_b.rgb, smoothstep(0.35, 0.65, n1));
	col = mix(col, color_c.rgb, smoothstep(0.55, 0.8, n2) * 0.7);
	col *= 0.85 + n3 * 0.3;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
