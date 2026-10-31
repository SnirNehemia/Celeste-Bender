// backdrop_wipe.gdshader: the soft seam of a SOFT change between two backdrop
// looks (Backdrop, scenes/backdrop/backdrop.gd). It sits on the CanvasGroup that
// holds the NEW look: a CanvasGroup first draws all its children into one
// picture, then draws that picture with this shader, so the whole look can be
// shown or hidden pixel by pixel.
//
// During the change both looks scroll by one screen, the new one coming in from
// one side. Its LEADING EDGE (the side facing the old look) is not a hard line:
// over `feather` px the new look thins out in a 4x4 ordered dither, and the old
// look (which reaches that far past its own edge) shows through the gaps. Where
// both looks share a tall layer (BackdropTheme.add_tall_layer) the two pictures
// match, so only the nearer layers blend.

shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
// Which side the new look comes in from: (0, -1) the top, (1, 0) the right...
uniform vec2 enter_from = vec2(0.0, -1.0);
// Where the new look's leading edge is now, in screen pixels along the way it moves
// (a row for up / down, a column for left / right).
uniform float leading_edge = 0.0;
// How many pixels the blend reaches back from the leading edge.
uniform float feather = 36.0;
// The screen in game pixels, so the dither squares are one game pixel big.
uniform vec2 screen_pixels = vec2(320.0, 180.0);

// The classic 4x4 Bayer matrix: thresholds spread so that any share of pixels
// lit forms an even pattern.
float bayer_threshold(ivec2 pixel) {
	int index = (pixel.x & 3) + (pixel.y & 3) * 4;
	const float matrix[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (matrix[index] + 0.5) / 16.0;
}

void fragment() {
	vec4 picture = textureLod(screen_texture, SCREEN_UV, 0.0);
	// The group's picture is stored premultiplied by alpha: undo that.
	if (picture.a > 0.0001) {
		picture.rgb /= picture.a;
	}
	vec2 pixel_position = SCREEN_UV * screen_pixels;
	// How far inside the new look this pixel is, counted back from its leading edge.
	float inside = 0.0;
	if (enter_from.y < 0.0) {
		inside = leading_edge - pixel_position.y;
	} else if (enter_from.y > 0.0) {
		inside = pixel_position.y - leading_edge;
	} else if (enter_from.x < 0.0) {
		inside = leading_edge - pixel_position.x;
	} else {
		inside = pixel_position.x - leading_edge;
	}
	float shown = clamp(inside / feather, 0.0, 1.0);
	picture.a *= shown > bayer_threshold(ivec2(floor(pixel_position))) ? 1.0 : 0.0;
	COLOR *= picture;
}
