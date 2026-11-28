extends Control

const D = preload("res://scripts/DrawUtil.gd")

var value: float = 0.0

func set_value(v: float) -> void:
	value = clampf(v, 0.0, 100.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.40
	if r < 20.0:
		return
	var glow := D.ACCENT
	glow.a = 0.10
	draw_arc(c, r, 0.0, TAU, 96, glow, 14.0, true)
	draw_arc(c, r, 0.0, TAU, 96, D.LINE, 2.0, true)
	draw_circle(c, r * 0.86, Color("#121824"))

	for i in range(0, 101, 5):
		var a := PI * 0.5 - float(i) / 100.0 * PI
		var dir := Vector2(cos(a), sin(a))
		var long := i % 25 == 0
		var p1 := c + dir * (r - 4.0)
		var p2 := c + dir * (r - (16.0 if long else 10.0))
		draw_line(p1, p2, D.ACCENT if long else D.MUTED, 2.0 if long else 1.0, true)

	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, c + Vector2(-22, -r + 20), "100%", HORIZONTAL_ALIGNMENT_CENTER, 44, 13, D.MUTED)
		draw_string(font, c + Vector2(-r - 6, -4), "50%", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, D.MUTED)
		draw_string(font, c + Vector2(r - 34, -4), "50%", HORIZONTAL_ALIGNMENT_CENTER, 40, 13, D.MUTED)
		draw_string(font, c + Vector2(-18, r - 10), "0%", HORIZONTAL_ALIGNMENT_CENTER, 36, 13, D.MUTED)
		draw_string(font, c + Vector2(-60, -6), "ШАНС", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, D.MUTED)
		draw_string(font, c + Vector2(-60, 26), str(int(value)) + "%", HORIZONTAL_ALIGNMENT_CENTER, 120, 28, D.ACCENT)

	var a2 := PI * 0.5 - value / 100.0 * PI
	var dir2 := Vector2(cos(a2), sin(a2))
	var side := Vector2(-dir2.y, dir2.x)
	var tip := c + dir2 * r * 0.78
	var b1 := c + side * 6.0
	var b2 := c - side * 6.0
	draw_colored_polygon(PackedVector2Array([tip, b1, b2]), D.ACCENT)
	draw_circle(c, 7.0, D.ACCENT_DARK)
	draw_circle(c, 4.0, D.ACCENT)
