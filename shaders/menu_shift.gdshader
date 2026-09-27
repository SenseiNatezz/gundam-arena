shader_type canvas_item;

// Main-menu video: moves the painted "Gundam Customization", "Settings" and "Exit" buttons down one
// slot each, freeing the slot under "Continue" for the Level Select button (drawn by title.gd).
// Each destination rect shows the pixels of the painted button above it. Coordinates are in the
// video's 720x1280 space.

const vec2 SIZE = vec2(720.0, 1280.0);
// Painted button rects (x, y, w, h), grown slightly to include their glow.
const vec4 CUSTOMIZE = vec4(27.0, 443.0, 276.0, 57.0);
const vec4 SETTINGS = vec4(27.0, 502.0, 276.0, 56.0);
const vec4 EXIT = vec4(27.0, 560.0, 276.0, 56.0);
const float NEW_EXIT_Y = 619.0;

bool inside(vec2 p, vec4 r) {
	return p.x >= r.x && p.x < r.x + r.z && p.y >= r.y && p.y < r.y + r.w;
}

void fragment() {
	vec2 p = UV * SIZE;
	vec2 src = p;
	vec4 exit_dest = vec4(EXIT.x, NEW_EXIT_Y, EXIT.z, EXIT.w);
	if (inside(p, exit_dest)) {
		src.y = p.y - (NEW_EXIT_Y - EXIT.y);           // Exit -> new bottom slot
	} else if (inside(p, EXIT)) {
		src.y = p.y - (EXIT.y - SETTINGS.y);           // Settings -> Exit's slot
	} else if (inside(p, SETTINGS)) {
		src.y = p.y - (SETTINGS.y - CUSTOMIZE.y);      // Customization -> Settings' slot
	}
	// Note: COLOR already holds the unshifted texture sample, so replace it rather than multiply.
	COLOR = texture(TEXTURE, src / SIZE);
}
