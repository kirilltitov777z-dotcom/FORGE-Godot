extends RefCounted

const BG := Color("#0d1119")
const SURFACE := Color("#161c28")
const SURFACE_2 := Color("#1d2532")
const LINE := Color("#293447")
const TEXT := Color("#edf1f6")
const MUTED := Color("#8e9aab")
const ACCENT := Color("#e0a83f")
const ACCENT_DARK := Color("#a87824")
const RED := Color("#ff6b7f")

static func hsl_to_color(h: float, s: float, l: float) -> Color:
	h = fmod(h, 360.0) / 360.0
	if h < 0.0:
		h += 1.0
	s = clampf(s / 100.0, 0.0, 1.0)
	l = clampf(l / 100.0, 0.0, 1.0)
	if is_equal_approx(s, 0.0):
		return Color(l, l, l)
	var q: float = l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p: float = 2.0 * l - q
	return Color(_hue_to_rgb(p, q, h + 1.0 / 3.0), _hue_to_rgb(p, q, h), _hue_to_rgb(p, q, h - 1.0 / 3.0))

static func _hue_to_rgb(p: float, q: float, t: float) -> float:
	var x := t
	if x < 0.0:
		x += 1.0
	if x > 1.0:
		x -= 1.0
	if x < 1.0 / 6.0:
		return p + (q - p) * 6.0 * x
	if x < 0.5:
		return q
	if x < 2.0 / 3.0:
		return p + (q - p) * (2.0 / 3.0 - x) * 6.0
	return p

static func rarity_color(id: String) -> Color:
	match id:
		"rare":
			return Color("#4da3ff")
		"epic":
			return Color("#b06bff")
		"legendary":
			return Color("#ffb23f")
		"unique":
			return Color("#ff5470")
		_:
			return Color("#98a3b3")

static func _pts(data: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pair in data:
		out.append(Vector2(float(pair[0]), float(pair[1])))
	return out

static func weapon_polygons(weapon: String) -> Array:
	var raw: Array = []
	match weapon:
		"rifle":
			raw = [
				[[6,29],[24,29],[32,22],[71,22],[79,29],[114,29],[114,35],[81,35],[74,39],[59,39],[51,55],[42,55],[46,39],[33,39],[27,44],[10,44]],
				[[43,17],[73,17],[73,22],[43,22]],
				[[96,35],[104,35],[104,44],[95,44]],
			]
		"pistol":
			raw = [
				[[16,22],[82,22],[82,33],[16,33]],
				[[56,33],[69,36],[62,61],[45,58],[53,40]],
				[[42,34],[54,34],[54,38],[42,38]],
			]
		"sniper":
			raw = [
				[[4,28],[26,28],[33,23],[83,23],[89,28],[116,28],[116,35],[89,35],[83,41],[35,41],[28,46],[4,46]],
				[[39,16],[77,16],[77,23],[39,23]],
				[[57,23],[57,28]],
			]
		"smg":
			raw = [
				[[13,25],[71,25],[71,37],[13,37]],
				[[50,37],[64,37],[67,56],[53,56]],
				[[68,28],[90,28],[90,33],[68,33]],
				[[22,25],[22,21],[42,21],[42,25]],
			]
		"shotgun":
			raw = [
				[[4,27],[90,27],[90,34],[4,34]],
				[[26,34],[52,34],[52,43],[26,43]],
				[[87,24],[107,24],[107,37],[87,37]],
				[[92,24],[92,37]],
			]
		"knife":
			raw = [
				[[10,31],[68,14],[87,18],[23,37]],
				[[66,36],[82,31],[93,41],[79,49]],
				[[14,32],[26,37]],
			]
		"carbine":
			raw = [
				[[10,29],[26,29],[33,23],[68,23],[74,29],[104,29],[104,35],[76,35],[70,39],[56,39],[49,53],[41,53],[45,39],[25,39],[19,44],[12,44]],
				[[44,18],[66,18],[66,22],[44,22]],
			]
		"revolver":
			raw = [
				[[18,23],[80,23],[80,32],[18,32]],
				[[63,37],[72,37],[72,46],[63,46],[59,43],[59,40]],
				[[56,43],[68,46],[61,63],[44,60],[52,46]],
				[[38,32],[50,32],[50,38],[38,38]],
			]
		"axe":
			raw = [
				[[56,8],[64,8],[60,58],[52,58]],
				[[60,9],[94,18],[84,35],[60,29]],
				[[60,12],[35,8],[43,26],[60,29]],
			]
		"bat":
			raw = [
				[[16,44],[86,14],[98,20],[28,50]],
				[[86,14],[98,20],[106,16],[94,10]],
			]
		_:
			raw = [[[10,28],[80,28],[80,38],[10,38]], [[30,38],[46,38],[46,54],[30,54]]]
	var out: Array = []
	for poly in raw:
		out.append(_pts(poly))
	return out

static func draw_weapon(node: Control, skin: Dictionary, rect: Rect2) -> void:
	if skin.is_empty():
		return
	var scale := minf(rect.size.x / 120.0, rect.size.y / 64.0)
	var used := Vector2(120.0 * scale, 64.0 * scale)
	var offset := rect.position + (rect.size - used) * 0.5
	var h := float(skin.get("hue", 200))
	var s := float(skin.get("sat", 40))
	var l := float(skin.get("light", 46))
	var base := hsl_to_color(h, s, l)
	var lighter := hsl_to_color(h, s, mini(92.0, l + 16.0))
	var darker := hsl_to_color(h + 20.0, s, maxf(10.0, l - 16.0))
	var polys := weapon_polygons(str(skin.get("weapon", "rifle")))
	for i in range(polys.size()):
		var pts := PackedVector2Array()
		for p in polys[i]:
			pts.append(offset + p * scale)
		var col := base
		if i % 3 == 1:
			col = lighter
		elif i % 3 == 2:
			col = darker
		node.draw_colored_polygon(pts, col)
		node.draw_polyline(pts, Color(0, 0, 0, 0.38), 1.2, true)

static func draw_cube(node: Control, hue: float, rect: Rect2) -> void:
	var s := minf(rect.size.x / 80.0, rect.size.y / 80.0)
	var off := rect.position + (rect.size - Vector2(80.0 * s, 80.0 * s)) * 0.5
	var top := PackedVector2Array([off + Vector2(40, 6) * s, off + Vector2(72, 24) * s, off + Vector2(40, 42) * s, off + Vector2(8, 24) * s])
	var left := PackedVector2Array([off + Vector2(8, 24) * s, off + Vector2(40, 42) * s, off + Vector2(40, 76) * s, off + Vector2(8, 58) * s])
	var right := PackedVector2Array([off + Vector2(72, 24) * s, off + Vector2(40, 42) * s, off + Vector2(40, 76) * s, off + Vector2(72, 58) * s])
	node.draw_colored_polygon(top, hsl_to_color(hue, 85, 68))
	node.draw_colored_polygon(left, hsl_to_color(hue, 65, 43))
	node.draw_colored_polygon(right, hsl_to_color(hue, 75, 55))
	for poly in [top, left, right]:
		node.draw_polyline(poly, Color(0, 0, 0, 0.25), 1.0, true)
	node.draw_polyline(top, Color(1, 1, 1, 0.3), 1.5, true)

static func draw_coin(node: Control, rect: Rect2) -> void:
	var center := rect.position + rect.size * 0.5
	var radius := minf(rect.size.x, rect.size.y) * 0.42
	node.draw_circle(center, radius, Color("#e8b33c"))
	node.draw_arc(center, radius * 0.84, 0.0, TAU, 32, Color("#fff3c4"), 1.0, true)
	node.draw_arc(center, radius, 0.0, TAU, 32, Color("#7a4c0c"), 1.0, true)
	var font := ThemeDB.fallback_font
	if font != null:
		node.draw_string(font, rect.position + Vector2(0, radius * 0.38), "₽", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, maxf(10.0, radius * 1.25), Color("#5e3a08"))

static func panel(node: Control, rect: Rect2, fill: Color, border: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	node.draw_style_box(sb, rect)
