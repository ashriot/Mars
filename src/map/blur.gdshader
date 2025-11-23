shader_type canvas_item;
uniform float blur_amount : hint_range(0, 10) = 0.0;

void fragment() {
	if (blur_amount <= 0.0) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec4 col = vec4(0.0);
		vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;

		// Sample center and surrounding 8 points for a smooth average
		col += texture(TEXTURE, UV);
		col += texture(TEXTURE, UV + vec2(0.0, -1.0) * ps);
		col += texture(TEXTURE, UV + vec2(0.0, 1.0) * ps);
		col += texture(TEXTURE, UV + vec2(-1.0, 0.0) * ps);
		col += texture(TEXTURE, UV + vec2(1.0, 0.0) * ps);
		col += texture(TEXTURE, UV + vec2(-0.7, -0.7) * ps);
		col += texture(TEXTURE, UV + vec2(0.7, -0.7) * ps);
		col += texture(TEXTURE, UV + vec2(-0.7, 0.7) * ps);
		col += texture(TEXTURE, UV + vec2(0.7, 0.7) * ps);

		COLOR = col / 9.0;
	}
}