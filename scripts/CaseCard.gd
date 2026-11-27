extends Control

signal clicked(card_id: String)

const D = preload("res://scripts/DrawUtil.gd")

var case_data: Dictionary = {}
var card_id: String = ""

func _draw() -> void:
	if case_data.is_empty():
		return
	var rect := Rect2(Vector2.ZERO, size)
	D.panel(self, rect, D.SURFACE, D.LINE, 16)
	var hue := float(case_data.get("hue", 200))
	var art_rect := Rect2(Vector2(6, 6), Vector2(size.x - 12, 96))
	var glow := D.hsl_to_color(hue, 70, 36)
	glow.a = 0.28
	draw_rect(Rect2(1, 1, size.x - 2, 104), glow)
	D.draw_cube(self, hue, art_rect)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var name_text := str(case_data.get("name", ""))
	if name_text.length() > 17:
		name_text = name_text.substr(0, 16) + "…"
	draw_string(font, Vector2(10, 124), name_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 13, D.TEXT)
	draw_string(font, Vector2(10, size.y - 8), str(int(case_data.get("price", 0))) + " ₽", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, D.ACCENT)
	var tag := "свой" if case_data.get("custom", false) else str((case_data.get("pool", []) as Array).size()) + " скинов"
	draw_string(font, Vector2(10, size.y - 8), tag, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 20, 10, D.MUTED)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", card_id)
		accept_event()
