extends RefCounted

const SIZE := 32

static func generate(icon_name: String, base_color: Color) -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	match icon_name:
		"mushroom":
			_draw_circle(image, Vector2(16, 13), 12, base_color)
			_draw_rect(image, 12, 18, 8, 10, Color(0.85, 0.78, 0.63))
		"berry":
			_draw_circle(image, Vector2(12, 14), 7, base_color)
			_draw_circle(image, Vector2(20, 14), 7, base_color)
			_draw_circle(image, Vector2(16, 20), 7, base_color)
			_draw_rect(image, 15, 4, 2, 4, Color(0.29, 0.48, 0.23))
		"apple":
			_draw_circle(image, Vector2(16, 17), 12, base_color)
			_draw_rect(image, 15, 3, 3, 6, Color(0.35, 0.23, 0.13))
			_draw_circle(image, Vector2(21, 6), 3, Color(0.29, 0.6, 0.23))
		"nut":
			_draw_circle(image, Vector2(16, 17), 11, base_color)
			_draw_rect(image, 6, 16, 20, 2, base_color.darkened(0.3))
		"droplet":
			_draw_rect(image, 13, 6, 6, 14, base_color)
			_draw_circle(image, Vector2(16, 20), 10, base_color)
		"cube":
			_draw_rect(image, 8, 8, 16, 16, base_color)
			_draw_rect(image, 12, 12, 8, 8, base_color.darkened(0.25))
		"scroll":
			_draw_rect(image, 4, 10, 24, 12, base_color)
			_draw_rect(image, 8, 14, 16, 1, base_color.darkened(0.4))
			_draw_rect(image, 8, 18, 16, 1, base_color.darkened(0.4))
		"horn":
			_draw_circle(image, Vector2(10, 22), 8, base_color)
			_draw_rect(image, 14, 8, 14, 8, base_color)
			_draw_circle(image, Vector2(26, 10), 3, base_color)
		"soup":
			_draw_rect(image, 6, 16, 20, 10, base_color)
			_draw_rect(image, 6, 14, 20, 2, base_color.darkened(0.3))
			_draw_rect(image, 12, 4, 2, 8, Color(0.85, 0.85, 0.85))
			_draw_rect(image, 18, 4, 2, 8, Color(0.85, 0.85, 0.85))
		"jam":
			_draw_rect(image, 9, 10, 14, 18, base_color)
			_draw_rect(image, 8, 6, 16, 5, base_color.darkened(0.35))
		"pie":
			_draw_circle(image, Vector2(16, 17), 12, base_color.darkened(0.2))
			_draw_circle(image, Vector2(16, 17), 8, base_color)
		"juice":
			_draw_rect(image, 10, 8, 12, 16, base_color)
			_draw_rect(image, 22, 12, 4, 6, base_color)
		_:
			_draw_circle(image, Vector2(16, 16), 12, base_color)
	return ImageTexture.create_from_image(image)

static func _draw_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var min_x := int(max(0, center.x - radius))
	var max_x := int(min(SIZE - 1, center.x + radius))
	var min_y := int(max(0, center.y - radius))
	var max_y := int(min(SIZE - 1, center.y + radius))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				image.set_pixel(x, y, color)

static func _draw_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var max_x := mini(SIZE, x + w)
	var max_y := mini(SIZE, y + h)
	for py in range(maxi(0, y), max_y):
		for px in range(maxi(0, x), max_x):
			image.set_pixel(px, py, color)
