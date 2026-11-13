shader_type canvas_item;
render_mode unshaded;

// Blend two painted source textures only at actual coastline edges.
// No synthesized terrain texture: base art and sand are atlas sprites.
uniform sampler2D sand_art : source_color, filter_nearest;
uniform vec4 sea_edges = vec4(0.0); // N, E, S, W

void fragment() {
	vec4 ground = texture(TEXTURE, UV);
	vec4 sand = texture(sand_art, UV);
	float north = (1.0 - smoothstep(0.0, 0.19, UV.y)) * sea_edges.x;
	float east = smoothstep(0.81, 1.0, UV.x) * sea_edges.y;
	float south = smoothstep(0.81, 1.0, UV.y) * sea_edges.z;
	float west = (1.0 - smoothstep(0.0, 0.19, UV.x)) * sea_edges.w;
	float border = clamp(max(max(north, east), max(south, west)), 0.0, 1.0);
	// Retain the artist's original grassy/forest texture toward cell center.
	COLOR = mix(ground, sand, border * 0.88);
}
