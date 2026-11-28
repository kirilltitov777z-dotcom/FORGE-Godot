extends Control

signal clicked(card_id: String)
signal sell_clicked(card_id: String)

const D = preload("res://scripts/DrawUtil.gd")

var skin: Dictionary = {}
var selected: bool = false
var card_id: String = ""
var compact: bool = false
var show_sell: bool = false
var type_label: String = ""

func _draw() -> void:
	if skin.is_empty():
		return
	var rect := Rect2(Vector2.ZERO, size)
	D.panel(self, rect, D.SURFACE_2 if selected else D.SURFACE, D.ACCENT if selected else D.LINE, 13)
	var bottom := 34.0 if show_sell else 0.0
	var art_h := (46.0 if compact else 66.0)
	var art_rect := Rect2(Vector2(4, 4), Vector2(size.x - 8, art_h))
	var glow := D.hsl_to_color(float(skin.get("hue", 200)), float(skin.get("sat", 40)), float(skin.get("light", 46)))
	glow.a = 0.18
	draw_rect(Rect2(4, 4, size.x - 8, art_h), glow)
	D.draw_weapon(self, skin, art_rect)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var type_text := type_label if type_label != "" else str(skin.get("weapon", "item")).to_upper()
	draw_string(font, Vector2(8, art_h + 14), type_text.substr(0, 18), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 9, D.MUTED)
	var name_text := str(skin.get("name", ""))
	if name_text.length() > (16 if compact else 19):
		name_text = name_text.substr(0, (16 if compact else 19) - 1) + "…"
	draw_string(font, Vector2(8, art_h + 33), name_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 11, D.TEXT)
	draw_string(font, Vector2(8, size.y - bottom - 7), str(int(skin.get("value", 0))) + " ₽", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 12, D.ACCENT)
	if selected:
		draw_string(font, Vector2(size.x - 10, 18), "✓", HORIZONTAL_ALIGNMENT_RIGHT, 20, 13, D.ACCENT)
	if show_sell:
		var btn := Rect2(6, size.y - 30, size.x - 12, 24)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1b2432")
		sb.border_color = D.ACCENT_DARK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(7)
		draw_style_box(sb, btn)
		draw_string(font, btn.position + Vector2(0, 17), "ПРОДАТЬ", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 11, D.ACCENT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var y := (event as InputEventMouseButton).position.y
		if show_sell and y >= size.y - 34.0:
			emit_signal("sell_clicked", card_id)
		else:
			emit_signal("clicked", card_id)
		accept_event()
