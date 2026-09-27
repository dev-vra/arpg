// Peça do boneco: textura original tingida pela cor do set/raridade,
// brilho de refino (+9/+12/+15) com borda (rim) pulsante.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tint_mix = 0.0;
uniform float metal = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_strength = 0.0;
uniform float hit_flash = 0.0;

void fragment() {
	vec3 base = texture(tex, UV).rgb;
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base, tint.rgb * (0.3 + lum * 0.85), tint_mix);
	METALLIC = metal;
	ROUGHNESS = mix(0.8, 0.55, metal);
	SPECULAR = 0.35;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	EMISSION = glow_color.rgb * glow_strength * pulse * (0.06 + rim * 1.2) + vec3(hit_flash);
}
