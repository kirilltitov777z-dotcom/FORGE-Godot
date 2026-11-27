extends Control

signal clicked(card_id: String)

const D = preload("res://scripts/DrawUtil.gd")

var skin: Dictionary = {}
var selected: bool = false
var card_id: String = ""
var compact: bool = false

func _draw() -> void:
	if skin.is_empty():
		return
	var rect := Rect2(Vector2.ZERO, size)
	D.panel(self, rect, D.SURFACE_2 if selected else D.SURFACE, D.ACCENT if selected else D.LINE, 13)
	var art_h := 52.0 if compact else 68.0
	var art_rect := Rect2(Vector2(4, 4), Vector2(size.x - 8, art_h))
	var glow := D.hsl_to_color(float(skin.get("hue", 200)), float(skin.get("sat", 40)), float(skin.get("light", 46)))
	glow.a = 0.16
	draw_rect(Rect2(4, 4, size.x - 8, art_h), glow)
	D.draw_weapon(self, skin, art_rect)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var name_text := str(skin.get("name", ""))
	if name_text.length() > (16 if compact else 20):
		name_text = name_text.substr(0, (16 if compact else 20) - 1) + "…"
	var y := art_h + 16.0
	draw_string(font, Vector2(8, y), name_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, D.TEXT)
	var rarity := str(skin.get("rarity", "common"))
	var r_color := D.rarity_color(rarity)
	draw_circle(Vector2(12, size.y - 11), 3.0, r_color)
	draw_string(font, Vector2(19, size.y - 7), _rarity_name(rarity), HORIZONTAL_ALIGNMENT_LEFT, 74, 10, r_color)
	var value_text := str(int(skin.get("value", 0))) + " ₽"
	draw_string(font, Vector2(8, size.y - 7), value_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, 10, D.MUTED)
	if selected:
		draw_string(font, Vector2(size.x - 10, 18), "✓", HORIZONTAL_ALIGNMENT_RIGHT, 20, 13, D.ACCENT)

func _rarity_name(id: String) -> String:
	match id:
		"rare": return "Редкий"
		"epic": return "Эпический"
		"legendary": return "Легендарный"
		"unique": return "Уникальный"
		_: return "Обычный"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", card_id)
		accept_event()
