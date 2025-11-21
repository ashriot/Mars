shader_type canvas_item;

uniform vec4 color : source_color = vec4(0, 0, 0, 1);
uniform float width : hint_range(0, 20) = 1.0;
uniform int pattern : hint_range(0, 1) = 0; // 0 = Pixel Art (Crunchy), 1 = Smooth (Anti-Aliased)
uniform bool inside = false; // If true, outline draws inside the sprite (good for HUD)

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE;
	vec4 sprite_color = texture(TEXTURE, UV);
	float alpha = sprite_color.a;
	
	if (pattern == 0) {
		// --- PIXEL ART MODE (Neighbor check) ---
		// Good for low-res, chunky sprites
		float outline = 0.0;
		for (float y = -1.0; y <= 1.0; y++) {
			for (float x = -1.0; x <= 1.0; x++) {
				vec2 offset = vec2(x, y) * width * size;
				// Skip center
				if (x == 0.0 && y == 0.0) continue;
				// Diamond check (up/down/left/right only)
				if (abs(x) + abs(y) > 1.0) continue; 
				
				float a = texture(TEXTURE, UV + offset).a;
				outline += a;
			}
		}
		outline = clamp(outline, 0.0, 1.0);
		
		// Draw logic
		vec4 final_color = mix(sprite_color, color, clamp(outline - alpha, 0.0, 1.0));
		COLOR = final_color;
		
	} else {
		// --- SMOOTH MODE (Radial Sampling) ---
		// Good for high-res icons, bullets, circular shapes
		float max_a = 0.0;
		int samples = 16; // More samples = smoother circle
		
		for (int i = 0; i < samples; i++) {
			float angle = 6.283185 * float(i) / float(samples);
			vec2 offset = vec2(cos(angle), sin(angle)) * width * size;
			float a = texture(TEXTURE, UV + offset).a;
			max_a = max(max_a, a);
		}
		
		// Apply the outline color with the sampled alpha
		vec4 outline_c = color;
		outline_c.a = max_a;
		
		// Composite: Put the original sprite ON TOP of the outline
		// This preserves the "nice transparency" of your bullet
		COLOR = mix(outline_c, sprite_color, alpha);
	}
}