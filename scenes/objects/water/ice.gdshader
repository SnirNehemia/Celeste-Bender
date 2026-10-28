shader_type canvas_item;
// The glint on ice (Water_bending.md §7.3, look A from the first W5 play-test): a
// thin diagonal band of white light that slides across every piece of ice as the
// player moves (IceLook.update_glint sets glint_offset from the player's x), so ice
// catches the light like glass. Everything else about the look is drawn by IceLook
// as plain colored polygons; this only brightens the pixels the band crosses.

uniform float glint_offset = 0.0;
// Bands repeat every glint_period px, glint_width px wide, at this slant (px of x
// per px of y).
uniform float glint_period = 56.0;
uniform float glint_width = 2.0;
uniform float glint_slant = 0.8;
uniform float glint_strength = 0.6;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float along = mod(floor(world_position.x) + floor(world_position.y) * glint_slant - glint_offset, glint_period);
	float band = step(along, glint_width);
	// Only on the ice's body, not on its faint see-through parts.
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), band * glint_strength * step(0.5, COLOR.a));
}
