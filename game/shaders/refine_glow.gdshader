// Brilho por nível de refino: emissão crescente em +9, +12 e +15.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_strength = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.6;
	METALLIC = 0.4;
	float pulse = 0.8 + 0.2 * sin(TIME * 3.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	EMISSION = glow_color.rgb * glow_strength * pulse * (0.35 + rim);
}
