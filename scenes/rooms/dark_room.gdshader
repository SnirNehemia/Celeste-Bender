// The darkness of dark rooms (DarkRoomOverlay, dark_room_overlay.gd). Drawn as one
// rectangle over the camera's view, in WORLD coordinates. A pixel is dark when it lies
// inside a dark room's rectangle, and every light cuts a soft hole into the dark.
//
// The look stays pixel art: the light is worked out once per WORLD pixel (floor), cut
// into a few steps (light_steps) and the edges between the steps are dithered with a
// 4x4 ordered pattern fixed to the world, so it never crawls when the camera moves.
shader_type canvas_item;

// Up to 64 lights: (world x, world y, radius px, strength 0..1).
uniform vec4 lights[64];
uniform int light_count = 0;
// Up to 16 dark rooms on screen: (x, y, width, height) in world px.
uniform vec4 dark_rects[16];
uniform int dark_rect_count = 0;
// How black the dark is (1 = pitch black) and how many light steps.
uniform float darkness = 1.0;
uniform float light_steps = 5.0;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// The classic 4x4 Bayer matrix, as thresholds 0..1.
float bayer4(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = x + y * 4;
	int pattern[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(pattern[index]) + 0.5) / 16.0;
}

void fragment() {
	vec2 pixel = floor(world_position);
	bool is_dark = false;
	for (int rect_index = 0; rect_index < dark_rect_count; rect_index++) {
		vec4 rect = dark_rects[rect_index];
		if (pixel.x >= rect.x && pixel.y >= rect.y && pixel.x < rect.x + rect.z && pixel.y < rect.y + rect.w) {
			is_dark = true;
			break;
		}
	}
	if (!is_dark) {
		discard;
	}
	vec2 center = pixel + vec2(0.5);
	float light = 0.0;
	for (int light_index = 0; light_index < light_count; light_index++) {
		vec4 source = lights[light_index];
		float distance_share = length(center - source.xy) / max(source.z, 1.0);
		// Full inside the first third, then fading to nothing at the radius.
		float falloff = 1.0 - smoothstep(0.3, 1.0, distance_share);
		light = max(light, falloff * source.w);
	}
	// Steps, with dithered edges between them.
	float stepped = floor(light * light_steps + bayer4(pixel)) / light_steps;
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - clamp(stepped, 0.0, 1.0)));
}
