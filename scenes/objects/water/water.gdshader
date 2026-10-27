shader_type canvas_item;
// The look of all water (Water_bending.md §12.1, play-test 1). Used by WaterWorld,
// which draws every body, drop and spray speck of a room as one list of triangles
// and puts the facts this shader needs into each corner's COLOR:
//   COLOR.r  how far under the surface this corner is, px / 64 (0 at the surface).
//            Corners in between are interpolated, so every pixel knows its depth.
//   COLOR.g  foam, 0..1: how churned the water is here (fast flow, splashes).
//   COLOR.b  what is drawn: 0 = the body, 0.25 = a soaked tile's damp top (its
//            foam channel says how soaked), 0.5 = the 1 px surface line, 1 = a drop
//            (a drop with foam 1 is a white spray speck).
// It runs on the graphics card, once per pixel at 320x180, so it costs the CPU
// nothing: the 2 ms water budget (§6.5) only pays for the simulation.
//
// Three looks to compare in play (`look_style`, WaterTuning, key 7 cycles them).
// Foam and spray (option D) are in all three.
//   0 = B, SEE-THROUGH (the default): what's behind the water sways by a pixel and
//       shows through a tint that goes from light at the surface to murky in deep
//       water; a drifting net of thin caustic lines; the surface line glints.
//   1 = C, PIXEL BANDS: flat bands of blue by depth (light, mid, dark, deep) with
//       dithered edges (an ordered 4x4 pattern), gently wavy; sparkles in the top
//       band; hardly see-through. Retro.
//   2 = A, PLAIN: the B tint without the sway, caustics or glints.
//   3 = B+C: look B with the bands of C laid over it, each with its own alpha.
// Every pattern is computed on whole world pixels (floor), so it stays crisp pixel
// art and doesn't swim when the camera moves.

// The screen drawn so far (tiles, the player...): what we see through the water.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform int look_style = 0;
uniform vec4 shallow_color : source_color = vec4(0.184, 0.498, 0.820, 1.0);  // #2F7FD1
uniform vec4 deep_color : source_color = vec4(0.122, 0.306, 0.549, 1.0);     // #1F4E8C
uniform vec4 surface_color : source_color = vec4(0.749, 0.894, 1.0, 1.0);    // #BFE4FF
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
// The four bands of look C, top to bottom.
uniform vec4 band_light : source_color = vec4(0.373, 0.659, 0.910, 1.0);    // #5FA8E8
uniform vec4 band_mid : source_color = vec4(0.184, 0.498, 0.820, 1.0);      // #2F7FD1
uniform vec4 band_dark : source_color = vec4(0.145, 0.376, 0.675, 1.0);     // #2560AC
uniform vec4 band_deep : source_color = vec4(0.122, 0.306, 0.549, 1.0);     // #1F4E8C
// How much of the tint covers what's behind: at the surface, and at full depth.
uniform float shallow_alpha = 0.45;
uniform float deep_alpha = 0.88;
// Depth, px, at which the water looks fully deep.
uniform float deep_full_px = 48.0;
// How far, in whole pixels, things seen through water sway (look B).
uniform float wobble_px = 1.0;
// How bright the caustic lines are (look B; 0 = none).
uniform float caustic_strength = 0.16;
// The caustic cells' average size, px; how uneven / random their shapes are (0 = a
// regular grid of round cells); how thick their lines are (in pattern units).
uniform float caustic_size = 42.0;
uniform float caustic_warp = 1.0;
uniform float caustic_thickness = 0.08;
// How much the bands of look C cover what's behind (C alone and in B+C).
uniform float band_alpha = 0.9;
// Look B+C: how strongly the bands are laid over the see-through B (0 = pure B).
uniform float blend_band_alpha = 0.5;
// How tall each band of look C is, px.
uniform float band_px = 7.0;

// The corner's position in the world, px, handed from vertex() to fragment().
varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// A cheap pseudo-random number in 0..1 for a pixel (the same pixel gives the same number).
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The ordered-dither threshold of a pixel, 0..1: the classic 4x4 Bayer matrix, so
// neighbouring pixels get thresholds as different as possible (an even checker-like
// blend instead of random noise).
float bayer4(vec2 pixel) {
	int x = int(mod(pixel.x, 4.0));
	int y = int(mod(pixel.y, 4.0));
	int index = y * 4 + x;
	float matrix[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (matrix[index] + 0.5) / 16.0;
}

// White foam specks (re-rolled ~8 times a second) in the top few px, where churned.
vec3 add_foam(vec3 color, vec2 pixel, float foam, float below_px) {
	float foam_here = foam * (1.0 - clamp(below_px / 6.0, 0.0, 1.0));
	float speck = hash(pixel + vec2(floor(TIME * 8.0) * 17.0, 0.0));
	return mix(color, foam_color.rgb, step(1.0 - foam_here, speck) * 0.85);
}

void fragment() {
	vec2 pixel = floor(world_px);
	float below_px = COLOR.r * 64.0;
	float foam = COLOR.g;
	float kind = COLOR.b;
	if (kind > 0.75) {
		// A drop (light blue) or a spray speck (white).
		COLOR = vec4(mix(mix(shallow_color.rgb, surface_color.rgb, 0.35), foam_color.rgb, foam), 0.9);
	} else if (kind > 0.375) {
		// The surface line: light, white where the water is churned. B glints (a new
		// random few pixels ~6 times a second); C sparkles more, A not at all.
		float glint = 0.0;
		if (look_style == 0 || look_style == 3) {
			glint = step(0.9, hash(vec2(pixel.x, floor(TIME * 6.0)))) * 0.7;
		} else if (look_style == 1) {
			glint = step(0.85, hash(vec2(pixel.x, floor(TIME * 4.0))));
		}
		COLOR = vec4(mix(surface_color.rgb, foam_color.rgb, max(glint, foam)), 0.95);
	} else if (kind > 0.125) {
		// A soaked tile: darker and bluish where water went in (W8 makes the real look).
		COLOR = vec4(0.06, 0.12, 0.24, 0.2 + 0.35 * foam);
	} else {
		// B, A and B+C share the see-through tint; C and B+C share the bands.
		bool use_tint = look_style != 1;
		bool use_bands = look_style == 1 || look_style == 3;
		bool use_sway = look_style == 0 || look_style == 3;
		vec3 tinted = vec3(0.0);
		if (use_tint) {
			float deepness = clamp(below_px / deep_full_px, 0.0, 1.0);
			vec2 offset = vec2(0.0);
			if (use_sway) {
				// The sway: a slow wave along each row picks which pixel to the side to
				// show, rounded to whole pixels so the background stays pixel art.
				float sway = sin(pixel.y * 0.7 + TIME * 3.0) + 0.5 * sin(pixel.x * 0.13 + TIME * 1.7);
				offset = vec2(round(sway * 0.6 * wobble_px), 0.0);
			}
			vec3 behind = textureLod(screen_texture, SCREEN_UV + offset * SCREEN_PIXEL_SIZE, 0.0).rgb;
			vec3 tint = mix(shallow_color.rgb, deep_color.rgb, deepness);
			tinted = mix(behind, tint, mix(shallow_alpha, deep_alpha, deepness));
			if (use_sway) {
				// Caustics: two slowly bending sine waves multiplied make a field of
				// soft cells; a thin band of its values is their outlines, the wobbly
				// net of light you see on a pool floor. caustic_size sets how big the
				// cells are on average (one wave per caustic_size px); caustic_warp
				// bends each wave by the other (0 = a regular grid of round cells,
				// higher = stretched, uneven, random-looking cells), and past 1 a
				// second, finer bend joins in.
				vec2 p = pixel * (6.2832 / max(caustic_size, 4.0));
				float warp = caustic_warp * 1.5;
				float fine = max(caustic_warp - 1.0, 0.0) * 0.8;
				float pattern = sin(p.x + TIME * 1.1 + warp * sin(p.y * 1.3 + TIME * 0.7) + fine * sin(p.y * 2.9 - TIME * 1.3))
					* sin(p.y * 1.1 - TIME * 0.9 + warp * sin(p.x * 0.9 + TIME * 0.5) + fine * sin(p.x * 3.1 + TIME * 1.1));
				float caustic_line = 1.0 - step(caustic_thickness, abs(pattern - 0.5));
				tinted += caustic_line * caustic_strength * (1.0 - deepness);
			}
		}
		vec3 banded = vec3(0.0);
		if (use_bands) {
			// C: pixel bands. The depth, made gently wavy along the row, plus the
			// dither threshold, picks the band: near a band's edge the pixels
			// alternate in the Bayer pattern, which reads as a soft step in pixel art.
			float wavy_px = below_px + 0.8 * sin(pixel.x * 0.35 + TIME * 2.0);
			float level = wavy_px / band_px + (bayer4(pixel) - 0.5) * 0.9;
			int band = int(clamp(floor(level), 0.0, 3.0));
			vec3 band_color = band_deep.rgb;
			if (band == 0) {
				band_color = band_light.rgb;
			} else if (band == 1) {
				band_color = band_mid.rgb;
			} else if (band == 2) {
				band_color = band_dark.rgb;
			}
			// Sparkles: a rare pixel of the top band flashes white for a moment.
			float sparkle = step(0.992, hash(pixel + vec2(0.0, floor(TIME * 3.0) * 31.0)));
			band_color = mix(band_color, foam_color.rgb, sparkle * (band == 0 ? 1.0 : 0.0));
			// band_alpha: how much the bands cover what's behind (unswayed).
			vec3 behind = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
			banded = mix(behind, band_color, band_alpha);
		}
		vec3 color = tinted;
		if (look_style == 1) {
			color = banded;
		} else if (look_style == 3) {
			// B+C: the see-through B with the bands laid over it at blend_band_alpha.
			// (B's own cover is shallow_alpha / deep_alpha, the bands' is band_alpha.)
			color = mix(tinted, banded, blend_band_alpha);
		}
		color = add_foam(color, pixel, foam, below_px);
		// We mixed in what's behind ourselves, so the result is opaque.
		COLOR = vec4(color, 1.0);
	}
}
