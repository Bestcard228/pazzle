shader_type canvas_item;

// Everything on this board is drawn with vector primitives -- draw_line, draw_circle,
// draw_arc -- so the pixel-art look is applied at the end rather than authored in.
// The whole frame is resolved down to a coarse grid, which gives the hard stair-stepped
// edges antialiased vectors never produce on their own.
//
// The resolve is a box filter, not a single sample. A one-tap resolve throws away
// everything in the block that the tap missed, and for text that means whole glyph
// strokes disappear depending on where the grid happens to land. Averaging keeps a thin
// stroke as a dimmer block instead of losing it, which is the difference between
// readable and not. The average is taken in linear light, because averaging sRGB values
// directly makes light-on-dark text come out thinner and muddier than it should be.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

// Design pixels per art pixel. The grid is derived from the project's 540x960 design
// resolution rather than the live window size, so the art pixels stay the same size on
// screen whatever the window is scaled to. 2.0 gives a 270x480 canvas.
uniform float pixel_size : hint_range(1.0, 8.0) = 2.0;
uniform vec2 design_resolution = vec2(540.0, 960.0);

// Shades per channel. 0 disables quantisation.
uniform int color_levels : hint_range(0, 64) = 32;

// How much of the block's centre sample is kept over the box average. Pure average is
// soft; a little centre bias holds the hard edges the pixel look depends on.
uniform float sharpness : hint_range(0.0, 1.0) = 0.35;

vec3 to_linear(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

vec3 to_srgb(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

void fragment() {
	vec2 blocks = max(vec2(1.0), floor(design_resolution / pixel_size));
	vec2 block_size = 1.0 / blocks;
	vec2 block_origin = floor(SCREEN_UV * blocks) * block_size;

	// 2x2 box over the block: exact at pixel_size 2, a fair approximation above it.
	vec3 sum = vec3(0.0);
	for (int x = 0; x < 2; x++) {
		for (int y = 0; y < 2; y++) {
			vec2 offset = (vec2(float(x), float(y)) + 0.5) * 0.5;
			sum += to_linear(texture(screen_tex, block_origin + offset * block_size).rgb);
		}
	}

	vec3 averaged = sum * 0.25;
	vec3 centre = to_linear(texture(screen_tex, block_origin + block_size * 0.5).rgb);
	vec3 c = to_srgb(mix(averaged, centre, sharpness));

	if (color_levels > 0) {
		float levels = float(color_levels);
		c = floor(c * levels + 0.5) / levels;
	}

	COLOR = vec4(c, 1.0);
}
