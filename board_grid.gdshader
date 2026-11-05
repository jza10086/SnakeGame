shader_type spatial;
render_mode specular_disabled;

// UV spans the playable field; each unit is one logical snake cell.
uniform vec2 grid_size = vec2(28.0, 16.0);
uniform vec4 tile_dark : source_color = vec4(0.082, 0.204, 0.235, 1.0);
uniform vec4 tile_light : source_color = vec4(0.094, 0.231, 0.263, 1.0);
uniform vec4 line_color : source_color = vec4(0.30, 0.52, 0.54, 1.0);

void fragment() {
	vec2 cell = UV * grid_size;
	vec2 edge_distance = min(fract(cell), 1.0 - fract(cell));
	vec2 pixel_width = fwidth(cell);
	vec2 lines = 1.0 - smoothstep(vec2(0.025) - pixel_width, vec2(0.025) + pixel_width, edge_distance);
	float checker = mod(floor(cell.x) + floor(cell.y), 2.0);
	ALBEDO = mix(mix(tile_dark.rgb, tile_light.rgb, checker), line_color.rgb, max(lines.x, lines.y));
	ROUGHNESS = 1.0;
}
