// Personagem (corpo e peças): textura tingida por set/raridade, normal map opcional,
// brilho de refino com borda pulsante, clarão de dano e luz de contorno fria.
// No corpo, hide_bone[] esconde a pele coberta por peças: fragmentos cujo peso
// cai em ossos cobertos são descartados (o corpo "esconde a parte coberta").
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform bool use_normal = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
uniform float metal = 0.0;
uniform float rough = 0.7;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_strength = 0.0;
uniform float hit_flash = 0.0;
uniform vec4 rim_color : source_color = vec4(0.45, 0.6, 1.0, 1.0);
uniform float rim_strength = 0.18;
uniform float hide_bone[65];
uniform bool use_mask = false;
varying float v_hide;

void vertex() {
	v_hide = 0.0;
	if (use_mask) {
		vec4 h = vec4(hide_bone[BONE_INDICES.x], hide_bone[BONE_INDICES.y], hide_bone[BONE_INDICES.z], hide_bone[BONE_INDICES.w]);
		v_hide = dot(h, BONE_WEIGHTS);
	}
}

void fragment() {
	if (v_hide > 0.5) {
		discard;
	}
	vec3 base = texture(albedo_tex, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, tint.rgb * (0.35 + lum * 0.9), tint_mix);
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	EMISSION = rim_color.rgb * rim * rim_strength
		+ glow_color.rgb * glow_strength * pulse * (0.08 + rim * 1.4)
		+ vec3(hit_flash);
}
