// Minimapa estilo ARPG: máscara suave da área explorada vira preenchimento
// translúcido com contorno claro (sem blocos, sem moldura).
shader_type canvas_item;

uniform vec4 fill : source_color = vec4(0.70, 0.78, 0.90, 0.38);
uniform vec4 edge : source_color = vec4(0.93, 0.96, 1.0, 0.95);

void fragment() {
	float m = texture(TEXTURE, UV).r;
	float inside = smoothstep(0.28, 0.42, m);
	float rim = inside * (1.0 - smoothstep(0.42, 0.58, m));
	vec4 c = vec4(fill.rgb, fill.a * inside);
	COLOR = mix(c, edge, rim);
}
