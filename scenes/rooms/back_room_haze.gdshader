// back_room_haze.gdshader: the look of a room seen from another depth (BackRoomView
// in play, EditorDepthView in the editor). It's pulled toward the haze color
// (BackRoomView sets it to the backdrop's main color, Backdrop.get_main_color, so
// deeper rooms sink into the background around them), but its solid things stay
// SOLID (their alpha is kept): the backdrop shows only through the room's open air,
// never through its platforms and objects. The node's modulate alpha still fades
// the whole picture in and out.
//
// More cues that it's further back (BackRoomView.apply_look sets them per layer):
//   - contrast and saturation: its light-dark range is squashed toward the haze
//     color's brightness and its colors drained, so nothing behind is as crisp or
//     as colorful as the front;
//   - blur_radius: a soft blur (depth of field), alpha too, so far edges are soft.
shader_type canvas_item;

// The air the room sits in, and how far its colors are pulled into it (0-1).
uniform vec4 haze_color : source_color = vec4(0.42, 0.47, 0.6, 1.0);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.45;
// 1 = as painted; lower = flatter and grayer.
uniform float contrast : hint_range(0.0, 1.0) = 1.0;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
// The blur's reach, in pixels of the picture (0 = sharp).
uniform float blur_radius = 0.0;

void fragment() {
	// The picture, softened by the same 3x3 tent blur, alpha-weighted so
	// see-through pixels don't darken the colors. Inline: Godot doesn't take the
	// built-in TEXTURE as a function argument everywhere.
	vec4 picture = texture(TEXTURE, UV);
	if (blur_radius > 0.0) {
		vec4 sum = vec4(0.0);
		vec2 reach = TEXTURE_PIXEL_SIZE * blur_radius;
		for (int x = -1; x <= 1; x++) {
			for (int y = -1; y <= 1; y++) {
				float weight = (2.0 - abs(float(x))) * (2.0 - abs(float(y)));
				vec4 tap = texture(TEXTURE, UV + vec2(float(x), float(y)) * reach);
				sum += vec4(tap.rgb * tap.a, tap.a) * weight;
			}
		}
		sum /= 16.0;  // the tent weights (1-2-1 by 1-2-1) add up to 16
		picture = vec4(sum.rgb / max(sum.a, 0.0001), sum.a);
	}
	vec3 color = picture.rgb;
	vec3 luma_weights = vec3(0.299, 0.587, 0.114);
	color = mix(vec3(dot(color, luma_weights)), color, saturation);
	float haze_brightness = dot(haze_color.rgb, luma_weights);
	color = haze_brightness + (color - haze_brightness) * contrast;
	color = mix(color, haze_color.rgb, haze_amount);
	// COLOR starts as the vertex color times modulate: keep only its alpha (the fade).
	COLOR = vec4(color, picture.a * COLOR.a);
}
