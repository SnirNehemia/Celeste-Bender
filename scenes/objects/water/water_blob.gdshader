shader_type canvas_item;
// The metaball threshold (Water_bending.md §6.3), used by WaterRenderer. TEXTURE is
// the picture of summed soft dots, one per particle: its red channel = how much
// water is near this pixel, its green channel = how much of that water is foam
// (each dot carries its own foam in green, see WaterRenderer._draw_dots). Below
// `threshold` it's air (discarded); above, water, in the same colors and see-through
// tint as the pools (look B+C's light end), so a ball landing in a pool reads as one
// water; a lighter rim marks the edge, and foaming water turns white.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float threshold = 0.45;
// How thick the light rim is, in field units above the threshold.
uniform float rim_width = 0.2;
uniform vec4 water_color : source_color = vec4(0.30, 0.60, 0.88, 1.0);
uniform vec4 rim_color : source_color = vec4(0.749, 0.894, 1.0, 1.0);    // #BFE4FF
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.0, 1.0);     // white water
// How much the water covers what's behind it (0 = invisible, 1 = opaque).
uniform float cover = 0.72;
// How white full foam is (WaterTuning.particle_foam_strength).
uniform float foam_strength = 0.8;

void fragment() {
	vec4 field_sample = texture(TEXTURE, UV);
	float field = field_sample.r;
	if (field < threshold) {
		discard;
	}
	vec3 behind = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 color = mix(behind, water_color.rgb, cover);
	float rim = 1.0 - step(threshold + rim_width, field);
	color = mix(color, rim_color.rgb, rim * 0.8);
	// The foam share of the water here: green / red, both summed over the same dots.
	// Rounded to 3 steps so it reads as pixel-art patches, not a smooth gradient.
	float foam = clamp(field_sample.g / max(field, 0.001), 0.0, 1.0);
	foam = floor(foam * 3.0 + 0.5) / 3.0;
	COLOR = vec4(mix(color, foam_color.rgb, foam * foam_strength), 1.0);
}
