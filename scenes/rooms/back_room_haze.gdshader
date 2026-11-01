// back_room_haze.gdshader: the look of a BACK ROOM (BackRoomView), the room seen
// one layer deeper behind the current one. Its colors are pulled toward the haze
// so it reads as further away, but its solid things stay SOLID (their alpha is
// kept): the backdrop shows only through the room's open air, never through its
// platforms and objects. The node's modulate alpha still fades the whole picture
// in and out when the back room changes.
shader_type canvas_item;

// The air the back room sits in, and how far its colors are pulled into it (0-1).
uniform vec4 haze_color : source_color = vec4(0.42, 0.47, 0.6, 1.0);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	// COLOR starts as the vertex color times modulate: keep only its alpha (the fade).
	COLOR = vec4(mix(picture.rgb, haze_color.rgb, haze_amount), picture.a * COLOR.a);
}
