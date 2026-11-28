extends Control

const D = preload("res://scripts/DrawUtil.gd")
const SkinCardScene = preload("res://scripts/SkinCard.gd")
const CaseCardScene = preload("res://scripts/CaseCard.gd")
const SkinArtScene = preload("res://scripts/SkinArt.gd")
const CoinScene = preload("res://scripts/CoinIcon.gd")
const WheelScene = preload("res://scripts/Wheel.gd")
const SND_CLICK = preload("res://audio/click.wav")
const SND_TOGGLE = preload("res://audio/toggle.wav")
const SND_CASE = preload("res://audio/case.wav")
const SND_WIN = preload("res://audio/win.wav")
const SND_LOSE = preload("res://audio/lose.wav")
const SND_REWARD = preload("res://audio/reward.wav")
const SND_DAILY = preload("res://audio/daily.wav")

const SKINS_FILE := "res://data/skins.json"
const CASES_FILE := "res://data/cases.json"
const CONFIG_FILE := "res://data/config.json"
const SAVE_FILE := "user://forge_save.json"
const DATA_FILE := "user://forge_dataset.json"
const BACKUP_FILE := "user://forge_backup.json"

var config: Dictionary = {}
var skins: Array = []
var cases: Array = []
var rarities: Array = []
var weapons: Array = []

var balance: int = 0
var inventory: Array = []
var stats: Dictionary = {}
var custom_cases: Array = []
var settings: Dictionary = {}
var last_daily: int = 0
var log_entries: Array = []

var current_tab := "cases"
var inv_rarity := "all"
var inv_weapon := "all"
var inv_sort := "value_desc"
var selected: Dictionary = {}

var up_source_uid := ""
var up_target_id := ""
var up_chance := 75
var up_custom := false
var up_multiplier := 1
var wheel: Control = null
var case_search := ""
var case_sort := 0
var case_grid: GridContainer = null
var case_count_label: Label = null
var audio: AudioStreamPlayer = null
var up_chance_label: Label = null
var up_topup_label: Label = null
var up_start_button: Button = null

var ws_editing := ""
var ws_name: String = ""
var ws_pool: Dictionary = {}
var ws_weights: Dictionary = {}
var ws_search := ""
var ws_rarity := "all"
var ws_name_edit: LineEdit = null
var ws_price_edit: LineEdit = null
var ws_desc_edit: LineEdit = null
var ws_search_edit: LineEdit = null
var ws_json_edit: TextEdit = null
var ws_total_label: Label = null
var ws_pool_grid: GridContainer = null

var root_box: VBoxContainer = null
var content_vbox: VBoxContainer = null
var balance_label: Label = null
var toast_label: Label = null
var overlay: Control = null
var overlay_vbox: VBoxContainer = null
var overlay_token := 0
var tab_buttons: Dictionary = {}

func _ready() -> void:
	randomize()
	_load_data()
	_load_game()
	audio = AudioStreamPlayer.new()
	audio.volume_db = -7.0
	add_child(audio)
	theme = _make_theme()
	_build_ui()
	_show_tab("cases")
	resized.connect(_on_resized)

# ---------------------------------------------------------------- data / save

func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)

func _write_json(path: String, value: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(value, "  "))
		f.close()

func _default_rarities() -> Array:
	return [
		{"id": "common", "name": "Обычный"},
		{"id": "rare", "name": "Редкий"},
		{"id": "epic", "name": "Эпический"},
		{"id": "legendary", "name": "Легендарный"},
		{"id": "unique", "name": "Уникальный"},
	]

func _default_weapons() -> Array:
	return [
		{"id": "rifle", "name": "Винтовка"},
		{"id": "pistol", "name": "Пистолет"},
		{"id": "sniper", "name": "Снайперская винтовка"},
		{"id": "smg", "name": "Пистолет-пулемёт"},
		{"id": "shotgun", "name": "Дробовик"},
		{"id": "knife", "name": "Нож"},
		{"id": "carbine", "name": "Карабин"},
		{"id": "revolver", "name": "Револьвер"},
		{"id": "axe", "name": "Топор"},
		{"id": "bat", "name": "Дубина"},
	]

func _load_data() -> void:
	var source: Variant = null
	if FileAccess.file_exists(DATA_FILE):
		source = _read_json(DATA_FILE)
	if not (source is Dictionary):
		source = {
			"skins": _read_json(SKINS_FILE),
			"cases": _read_json(CASES_FILE),
		}
	var conf: Variant = _read_json(CONFIG_FILE)
	config = conf if conf is Dictionary else {
		"starting_balance": 3000, "case_create_cost": 1500, "sell_rate": 0.65,
		"daily_bonus": 500, "house_edge": 0.12, "presets": [25, 55, 75],
	}
	if source is Dictionary and source.has("config") and source["config"] is Dictionary:
		for k in source["config"].keys():
			config[k] = source["config"][k]
	skins = source.get("skins", []) if source is Dictionary else []
	cases = source.get("cases", []) if source is Dictionary else []
	if not (skins is Array):
		skins = []
	if not (cases is Array):
		cases = []
	rarities = source.get("rarities", []) if source is Dictionary else []
	weapons = source.get("weapons", []) if source is Dictionary else []
	if not (rarities is Array) or rarities.is_empty():
		rarities = _default_rarities()
	if not (weapons is Array) or weapons.is_empty():
		weapons = _default_weapons()

func _load_game() -> void:
	var saved: Variant = null
	if FileAccess.file_exists(SAVE_FILE):
		saved = _read_json(SAVE_FILE)
	if not (saved is Dictionary):
		saved = {}
	balance = int(saved.get("balance", config.get("starting_balance", 3000)))
	inventory = saved.get("inventory", [])
	if not (inventory is Array):
		inventory = []
	stats = saved.get("stats", {})
	if not (stats is Dictionary):
		stats = {}
	for k in ["opened", "upgrades", "wins", "sold", "earned", "spent"]:
		if not stats.has(k):
			stats[k] = 0
	custom_cases = saved.get("custom_cases", [])
	if not (custom_cases is Array):
		custom_cases = []
	settings = saved.get("settings", {})
	if not (settings is Dictionary):
		settings = {}
	if not settings.has("sound"):
		settings["sound"] = true
	if not settings.has("auto_sell_dupes"):
		settings["auto_sell_dupes"] = false
	last_daily = int(saved.get("last_daily", 0))
	log_entries = saved.get("log", [])
	if not (log_entries is Array):
		log_entries = []

func _save_game() -> void:
	_write_json(SAVE_FILE, {
		"balance": balance,
		"inventory": inventory,
		"stats": stats,
		"custom_cases": custom_cases,
		"settings": settings,
		"last_daily": last_daily,
		"log": log_entries,
	})

func _log(text: String) -> void:
	var stamp := Time.get_time_string_from_system()
	log_entries.append(stamp.substr(0, 5) + " · " + text)
	if log_entries.size() > 40:
		log_entries.remove_at(0)

func _fmt(value: int) -> String:
	var s := str(abs(value))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out = " " + out
		out = s.substr(i, 1) + out
	return ("-" if value < 0 else "") + out

func _skin_by_id(id: String) -> Dictionary:
	for s in skins:
		if str(s.get("id", "")) == id:
			return s
	return {}

func _case_by_id(id: String) -> Dictionary:
	for c in cases:
		if str(c.get("id", "")) == id:
			return c
	for c in custom_cases:
		if str(c.get("id", "")) == id:
			return c
	return {}

func _rarity_by_id(id: String) -> Dictionary:
	for r in rarities:
		if str(r.get("id", "")) == id:
			return r
	return {}

func _all_cases() -> Array:
	var out: Array = []
	out.append_array(cases)
	out.append_array(custom_cases)
	return out

func _inventory_items() -> Array:
	var out: Array = []
	for it in inventory:
		var sk := _skin_by_id(str(it.get("skin_id", "")))
		if sk.is_empty():
			continue
		var copy: Dictionary = it.duplicate(true)
		copy["skin"] = sk
		out.append(copy)
	return out

func _inventory_value() -> int:
	var total := 0
	for it in _inventory_items():
		total += int(it["skin"].get("value", 0))
	return total

func _count_skin(id: String) -> int:
	var n := 0
	for it in inventory:
		if str(it.get("skin_id", "")) == id:
			n += 1
	return n

func _new_uid() -> String:
	return "i" + str(Time.get_ticks_usec()) + str(randi() % 100000)

func _add_item(skin_id: String) -> Dictionary:
	var sk := _skin_by_id(skin_id)
	if sk.is_empty():
		return {"duplicated": false, "gain": 0}
	if bool(settings.get("auto_sell_dupes", false)) and _count_skin(skin_id) > 0:
		var gain := int(round(float(sk.get("value", 0)) * float(config.get("sell_rate", 0.65))))
		balance += gain
		stats["earned"] = int(stats["earned"]) + gain
		stats["sold"] = int(stats["sold"]) + 1
		return {"duplicated": true, "gain": gain}
	inventory.append({"uid": _new_uid(), "skin_id": skin_id, "at": Time.get_unix_time_from_system()})
	return {"duplicated": false, "gain": 0}

func _weighted_rarity(weights: Dictionary) -> String:
	var total := 0.0
	for r in rarities:
		total += maxf(0.0, float(weights.get(str(r.get("id", "")), 0)))
	if total <= 0.0:
		return str(rarities[0].get("id", "common"))
	var roll := randf() * total
	for r in rarities:
		var id := str(r.get("id", ""))
		roll -= maxf(0.0, float(weights.get(id, 0)))
		if roll <= 0.0:
			return id
	return str(rarities[rarities.size() - 1].get("id", "common"))

func _pick_case_skin(box: Dictionary) -> Dictionary:
	var wanted := _weighted_rarity(box.get("weights", {}))
	var pool: Array = box.get("pool", [])
	var candidates: Array = []
	for id in pool:
		var sk := _skin_by_id(str(id))
		if not sk.is_empty() and str(sk.get("rarity", "")) == wanted:
			candidates.append(sk)
	if candidates.is_empty():
		var order: Array = []
		for r in rarities:
			order.append(str(r.get("id", "")))
		var target := order.find(wanted)
		for id in pool:
			var sk := _skin_by_id(str(id))
			if not sk.is_empty():
				var d := absi(order.find(str(sk.get("rarity", ""))) - target)
				if d <= 1:
					candidates.append(sk)
	if candidates.is_empty():
		candidates = skins.duplicate()
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func _open_case(id: String) -> Dictionary:
	var box := _case_by_id(id)
	if box.is_empty():
		return {"ok": false, "reason": "Кейс не найден"}
	var price := int(box.get("price", 0))
	if balance < price:
		return {"ok": false, "reason": "Не хватает монет"}
	balance -= price
	stats["spent"] = int(stats["spent"]) + price
	var sk := _pick_case_skin(box)
	if sk.is_empty():
		balance += price
		stats["spent"] = int(stats["spent"]) - price
		return {"ok": false, "reason": "Пустой набор скинов"}
	var added := _add_item(str(sk.get("id", "")))
	stats["opened"] = int(stats["opened"]) + 1
	if added["duplicated"]:
		_log("Дубликат " + str(sk.get("name", "")) + ": +" + _fmt(int(added["gain"])) + " ₽")
	else:
		_log("Кейс «" + str(box.get("name", "")) + "»: " + str(sk.get("name", "")))
	_save_game()
	_refresh_header()
	return {"ok": true, "skin": sk, "duplicated": added["duplicated"], "gain": added["gain"], "box": box}

func _upgrade_topup(source: Dictionary, target: Dictionary, chance: int, mult: int = 1) -> int:
	var edge := clampf(float(config.get("house_edge", 0.12)), 0.0, 0.9)
	var needed := float(chance) / 100.0 * float(target.get("value", 0)) / (1.0 - edge)
	return maxi(0, int(ceil(needed - float(source.get("value", 0)) * float(mult))))

func _upgrade(uid: String, target_id: String, chance: int, mult: int = 1) -> Dictionary:
	var item: Dictionary = {}
	for it in inventory:
		if str(it.get("uid", "")) == uid:
			item = it
			break
	var source := _skin_by_id(str(item.get("skin_id", "")))
	var target := _skin_by_id(target_id)
	if source.is_empty() or target.is_empty():
		return {"ok": false, "reason": "Ошибка данных"}
	var owned := _count_skin(str(source.get("id", "")))
	if owned < mult:
		return {"ok": false, "reason": "Нужно больше копий этого скина"}
	if int(target.get("value", 0)) <= int(source.get("value", 0)) * mult:
		return {"ok": false, "reason": "Цель должна быть дороже ставки"}
	chance = clampi(chance, 5, 95)
	var topup := _upgrade_topup(source, target, chance, mult)
	if balance < topup:
		return {"ok": false, "reason": "Не хватает монет на доплату"}
	balance -= topup
	stats["spent"] = int(stats["spent"]) + topup
	var sid := str(source.get("id", ""))
	var removed := 0
	var keep: Array = []
	for it in inventory:
		if removed < mult and str(it.get("skin_id", "")) == sid:
			removed += 1
		else:
			keep.append(it)
	inventory = keep
	stats["upgrades"] = int(stats["upgrades"]) + 1
	var win := randf() * 100.0 < float(chance)
	var added := {"duplicated": false, "gain": 0}
	if win:
		added = _add_item(target_id)
		stats["wins"] = int(stats["wins"]) + 1
		_log("Апгрейд " + str(chance) + "%: " + str(source.get("name", "")) + " → " + str(target.get("name", "")))
	else:
		_log("Апгрейд " + str(chance) + "%: потерян " + str(source.get("name", "")))
	_save_game()
	_refresh_header()
	return {"ok": true, "win": win, "source": source, "target": target, "chance": chance, "topup": topup, "added": added}

func _sell_items(uids: Array) -> Dictionary:
	var ids: Dictionary = {}
	for u in uids:
		ids[str(u)] = true
	var total := 0
	var count := 0
	var keep: Array = []
	for it in inventory:
		if ids.has(str(it.get("uid", ""))):
			var sk := _skin_by_id(str(it.get("skin_id", "")))
			if not sk.is_empty():
				total += int(round(float(sk.get("value", 0)) * float(config.get("sell_rate", 0.65))))
				count += 1
		else:
			keep.append(it)
	if count == 0:
		return {"ok": false, "reason": "Выберите предметы"}
	inventory = keep
	balance += total
	stats["earned"] = int(stats["earned"]) + total
	stats["sold"] = int(stats["sold"]) + count
	_log("Продажа " + str(count) + " предметов: +" + _fmt(total) + " ₽")
	_save_game()
	_refresh_header()
	return {"ok": true, "total": total, "count": count}

func _check_daily() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	if last_daily > 0 and now - last_daily < 86400:
		return {"ok": false, "wait": 86400 - (now - last_daily)}
	var bonus := int(config.get("daily_bonus", 500))
	last_daily = now
	balance += bonus
	stats["earned"] = int(stats["earned"]) + bonus
	_log("Ежедневный бонус: +" + _fmt(bonus) + " ₽")
	_save_game()
	_refresh_header()
	return {"ok": true, "amount": bonus}

func _create_case(form: Dictionary) -> Dictionary:
	var cost := int(config.get("case_create_cost", 1500))
	if balance < cost:
		return {"ok": false, "reason": "Не хватает монет на создание кейса"}
	var name := str(form.get("name", "")).strip_edges().substr(0, 28)
	var pool: Array = form.get("pool", [])
	var clean_pool: Array = []
	for id in pool:
		if not _skin_by_id(str(id)).is_empty():
			clean_pool.append(str(id))
	clean_pool = _unique(clean_pool)
	if name.length() < 2:
		return {"ok": false, "reason": "Введите название"}
	if clean_pool.size() < 3:
		return {"ok": false, "reason": "Нужно минимум 3 скина"}
	for c in _all_cases():
		if str(c.get("name", "")).to_lower() == name.to_lower():
			return {"ok": false, "reason": "Кейс с таким названием уже есть"}
	balance -= cost
	stats["spent"] = int(stats["spent"]) + cost
	var box := {
		"id": "u" + str(Time.get_ticks_usec()),
		"name": name,
		"price": maxi(50, int(form.get("price", 300))),
		"hue": int(form.get("hue", 120)) % 360,
		"weights": form.get("weights", {}),
		"pool": clean_pool,
		"desc": str(form.get("desc", "")).substr(0, 120),
		"custom": true,
	}
	custom_cases.insert(0, box)
	_log("Создан кейс «" + name + "» за " + _fmt(cost) + " ₽")
	_save_game()
	_refresh_header()
	return {"ok": true, "box": box}

func _unique(arr: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for v in arr:
		if not seen.has(str(v)):
			seen[str(v)] = true
			out.append(v)
	return out

func _update_case(id: String, form: Dictionary) -> Dictionary:
	for c in custom_cases:
		if str(c.get("id", "")) == id:
			for k in form.keys():
				c[k] = form[k]
			_save_game()
			return {"ok": true, "box": c}
	return {"ok": false, "reason": "Свой кейс не найден"}

func _delete_case(id: String) -> Dictionary:
	for i in range(custom_cases.size()):
		if str(custom_cases[i].get("id", "")) == id:
			var box: Dictionary = custom_cases[i]
			custom_cases.remove_at(i)
			_log("Удалён кейс «" + str(box.get("name", "")) + "»")
			_save_game()
			return {"ok": true}
	return {"ok": false, "reason": "Свой кейс не найден"}

# ---------------------------------------------------------------- ui helpers

func _make_theme() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", D.TEXT)
	t.set_color("font_color", "Button", D.TEXT)
	t.set_color("font_color", "LineEdit", D.TEXT)
	t.set_color("font_color", "TextEdit", D.TEXT)
	t.set_font_size("font_size", "Label", 15)
	t.set_font_size("font_size", "Button", 14)
	var normal := StyleBoxFlat.new()
	normal.bg_color = D.SURFACE_2
	normal.border_color = D.LINE
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(11)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#232833")
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#2b3240")
	var disabled: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("#101319")
	for kind in ["Button", "OptionButton"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		t.set_stylebox("pressed", kind, pressed)
		t.set_stylebox("disabled", kind, disabled)
	var panel := StyleBoxFlat.new()
	panel.bg_color = D.SURFACE
	panel.border_color = D.LINE
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", panel)
	var field := StyleBoxFlat.new()
	field.bg_color = D.BG
	field.border_color = D.LINE
	field.set_border_width_all(1)
	field.set_corner_radius_all(10)
	field.content_margin_left = 10
	field.content_margin_right = 10
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("normal", "TextEdit", field)
	return t

func _label(text: String, size: int = 14, color: Color = D.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _button(text: String, action: String, id: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.connect("pressed", Callable(self, "_on_action").bind(action, id, b))
	return b

func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = maxi(1, columns)
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

func _columns(card_width: int) -> int:
	var w := get_viewport_rect().size.x
	return maxi(1, int((w - 40.0) / float(card_width)))

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()

func _build_ui() -> void:
	root_box = VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation", 10)
	add_child(root_box)

	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 46)
	root_box.add_child(head)
	var brand := _label("FORGE", 21, D.ACCENT)
	brand.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(brand)
	var tagline := _label("кейсы · апгрейд", 11, D.MUTED)
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(tagline)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	balance_label = _label("", 15, D.TEXT)
	balance_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head.add_child(balance_label)
	var coin := CoinScene.new()
	coin.custom_minimum_size = Vector2(22, 22)
	head.add_child(coin)
	var daily := _button("+", "daily")
	daily.custom_minimum_size = Vector2(38, 38)
	head.add_child(daily)
	var settings_btn := _button("⚙", "settings")
	settings_btn.custom_minimum_size = Vector2(38, 38)
	head.add_child(settings_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(content_vbox)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 2)
	nav.custom_minimum_size = Vector2(0, 58)
	root_box.add_child(nav)
	for item in [
		["upgrade", "▲", "Апгрейд"],
		["cases", "▤", "Магазин"],
		["workshop", "◫", "Режимы"],
		["inventory", "▣", "Инвентарь"],
		["profile", "☻", "Профиль"],
	]:
		var b := _button(str(item[1]) + "\n" + str(item[2]), "tab", str(item[0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		nav.add_child(b)
		tab_buttons[str(item[0])] = b

	toast_label = _label("", 13, D.ACCENT)
	toast_label.visible = false
	root_box.add_child(toast_label)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.04, 0.05, 0.82)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 28.0), 0)
	center.add_child(panel)
	overlay_vbox = VBoxContainer.new()
	overlay_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(overlay_vbox)
	_refresh_header()

func _play_sound(stream: AudioStream) -> void:
	if audio != null and bool(settings.get("sound", true)):
		audio.stream = stream
		audio.play()

func _refresh_header() -> void:
	if balance_label != null:
		balance_label.text = "Баланс: " + _fmt(balance) + " ₽"

func _on_resized() -> void:
	if not is_inside_tree() or content_vbox == null:
		return
	_render_screen()

func _show_tab(tab: String) -> void:
	if tab == "profile":
		_settings_modal()
		return
	current_tab = tab
	for k in tab_buttons.keys():
		var b: Button = tab_buttons[k]
		b.add_theme_color_override("font_color", D.ACCENT if k == tab else D.MUTED)
	_render_screen()

func _render_screen() -> void:
	if content_vbox == null:
		return
	_clear(content_vbox)
	if current_tab == "cases":
		_render_cases()
	elif current_tab == "upgrade":
		_render_upgrade()
	elif current_tab == "inventory":
		_render_inventory()
	else:
		_render_workshop()

func _section(title: String, subtitle: String) -> void:
	content_vbox.add_child(_label(title, 24, D.TEXT))
	content_vbox.add_child(_label(subtitle, 12, D.MUTED))

func _toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	await get_tree().create_timer(2.6).timeout
	if toast_label != null:
		toast_label.visible = false

# ---------------------------------------------------------------- screens

func _render_cases() -> void:
	content_vbox.add_child(_label("МАГАЗИН", 24, D.TEXT))
	var search := LineEdit.new()
	search.placeholder_text = "Поиск по названию"
	search.text = case_search
	search.custom_minimum_size = Vector2(0, 42)
	search.text_changed.connect(func(t): case_search = str(t); _render_case_grid())
	content_vbox.add_child(search)
	var tools := HBoxContainer.new()
	tools.add_child(_button("Фильтры", "tab", "workshop"))
	var sort := OptionButton.new()
	sort.add_item("Сначала дешёвые", 0)
	sort.add_item("Сначала дорогие", 1)
	sort.selected = case_sort
	sort.item_selected.connect(func(idx): case_sort = idx; _render_case_grid())
	tools.add_child(sort)
	content_vbox.add_child(tools)
	case_count_label = _label("", 11, D.MUTED)
	content_vbox.add_child(case_count_label)
	case_grid = _grid(2)
	content_vbox.add_child(case_grid)
	_render_case_grid()

func _render_case_grid() -> void:
	if case_grid == null:
		return
	_clear(case_grid)
	var all := _all_cases()
	var q := str(case_search).to_lower().strip_edges()
	var list: Array = []
	for box in all:
		if q != "" and not str(box.get("name", "")).to_lower().contains(q):
			continue
		list.append(box)
	if case_sort == 0:
		list.sort_custom(func(a, b): return int(a.get("price", 0)) < int(b.get("price", 0)))
	else:
		list.sort_custom(func(a, b): return int(a.get("price", 0)) > int(b.get("price", 0)))
	if case_count_label != null:
		case_count_label.text = str(list.size()) + " предметов"
	for box in list:
		var card := CaseCardScene.new()
		card.case_data = box
		card.card_id = str(box.get("id", ""))
		card.custom_minimum_size = Vector2(0, 176)
		var cid := card.card_id
		card.clicked.connect(func(_x): _play_sound(SND_CLICK); _on_action("case", cid, card))
		case_grid.add_child(card)

func _slot(label: String, skin: Dictionary, action: String, decoration: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	vbox.add_child(_label(label, 11, D.MUTED))
	if decoration != "":
		vbox.add_child(_label(decoration, 13, D.ACCENT))
	if skin.is_empty():
		vbox.add_child(_label("Пусто", 13, D.MUTED))
	else:
		var art := SkinArtScene.new()
		art.skin = skin
		art.custom_minimum_size = Vector2(0, 74)
		vbox.add_child(art)
		vbox.add_child(_label(str(skin.get("name", "")), 12, D.TEXT))
		vbox.add_child(_label(str(skin.get("value", 0)) + " ₽", 12, D.ACCENT))
	if action != "":
		var choose := _button("Выбрать", action, "")
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(choose)
	return panel

func _source_skin() -> Dictionary:
	for it in _inventory_items():
		if str(it.get("uid", "")) == up_source_uid:
			return it["skin"]
	return {}

func _target_skin() -> Dictionary:
	return _skin_by_id(up_target_id)

func _render_upgrade() -> void:
	content_vbox.add_child(_label("UPGRADER", 24, D.TEXT))
	var top := HBoxContainer.new()
	var sound := _button("♪", "toggle_sound")
	sound.custom_minimum_size = Vector2(44, 36)
	top.add_child(sound)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_button("▤ Кейсы", "tab", "cases"))
	top.add_child(_button("⚙", "settings"))
	content_vbox.add_child(top)

	wheel = WheelScene.new()
	wheel.custom_minimum_size = Vector2(0, 290)
	wheel.set_value(float(up_chance))
	content_vbox.add_child(wheel)

	var source := _source_skin()
	var target := _target_skin()
	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 8)
	var left := _slot("ВАША СТАВКА", source, "pick_source", "▼ ▼ ▼")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(left)
	stage.add_child(_label("→", 20, D.ACCENT))
	var right := _slot("ЦЕЛЬ", target, "pick_target", "▲ ▲ ▲")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(right)
	content_vbox.add_child(stage)
	content_vbox.add_child(_button("ВЫБЕРИТЕ СКИНЫ ДЛЯ СТАВКИ", "pick_source"))

	var mults := HBoxContainer.new()
	for m in [1, 2, 4, 8]:
		var b := _button("x" + str(m), "mult", str(m))
		if up_multiplier == int(m):
			b.add_theme_color_override("font_color", D.ACCENT)
		mults.add_child(b)
	content_vbox.add_child(mults)

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	for p in [25, 35, 55, 75]:
		var b := _button(str(p) + "%", "chance", str(p))
		if not up_custom and up_chance == int(p):
			b.add_theme_color_override("font_color", D.ACCENT)
		presets.add_child(b)
	var custom := _button("свой", "custom_chance")
	if up_custom:
		custom.add_theme_color_override("font_color", D.ACCENT)
	presets.add_child(custom)
	content_vbox.add_child(presets)

	if up_custom:
		var slider := HSlider.new()
		slider.min_value = 5
		slider.max_value = 95
		slider.step = 1
		slider.value = up_chance
		content_vbox.add_child(slider)
		up_chance_label = _label("Шанс: " + str(up_chance) + "%", 14, D.TEXT)
		content_vbox.add_child(up_chance_label)
		slider.value_changed.connect(Callable(self, "_on_chance_slider"))
	else:
		up_chance_label = null

	var topup := 0
	var owned := 0
	if not source.is_empty():
		owned = _count_skin(str(source.get("id", "")))
	if not source.is_empty() and not target.is_empty():
		topup = _upgrade_topup(source, target, up_chance, up_multiplier)
	up_topup_label = _label("Ставка: " + str(up_multiplier) + " шт. · доплата: " + _fmt(topup) + " ₽ · комиссия " + str(int(round(float(config.get("house_edge", 0.12)) * 100.0))) + "%", 13, D.MUTED)
	content_vbox.add_child(up_topup_label)

	var can := not source.is_empty() and not target.is_empty() and owned >= up_multiplier and int(target.get("value", 0)) > int(source.get("value", 0)) * up_multiplier and balance >= topup
	up_start_button = _button("НАЧАТЬ АПГРЕЙД", "do_upgrade")
	up_start_button.disabled = not can
	content_vbox.add_child(up_start_button)
	if not source.is_empty() and owned < up_multiplier:
		content_vbox.add_child(_label("Нужно " + str(up_multiplier) + " копий этого скина.", 12, D.RED))
	elif not source.is_empty() and not target.is_empty() and int(target.get("value", 0)) <= int(source.get("value", 0)) * up_multiplier:
		content_vbox.add_child(_label("Цель должна быть дороже ставки.", 12, D.RED))
	if balance < topup and not source.is_empty() and not target.is_empty():
		content_vbox.add_child(_label("Не хватает монет на доплату.", 12, D.RED))

func _on_chance_slider(value: float) -> void:
	up_chance = int(value)
	if up_chance_label != null:
		up_chance_label.text = "Шанс: " + str(up_chance) + "%"
	var source := _source_skin()
	var target := _target_skin()
	var topup := 0
	if not source.is_empty() and not target.is_empty():
		topup = _upgrade_topup(source, target, up_chance, up_multiplier)
	if up_topup_label != null:
		up_topup_label.text = "Ставка: " + str(up_multiplier) + " шт. · доплата: " + _fmt(topup) + " ₽ · комиссия " + str(int(round(float(config.get("house_edge", 0.12)) * 100.0))) + "%"
	if up_start_button != null:
		var owned := 0
		if not source.is_empty():
			owned = _count_skin(str(source.get("id", "")))
		up_start_button.disabled = not (not source.is_empty() and not target.is_empty() and owned >= up_multiplier and int(target.get("value", 0)) > int(source.get("value", 0)) * up_multiplier and balance >= topup)
	if wheel != null:
		wheel.set_value(float(up_chance))

func _weapon_name(id: String) -> String:
	for w in weapons:
		if str(w.get("id", "")) == id:
			return str(w.get("name", "")).to_upper()
	return id.to_upper()

func _render_inventory() -> void:
	var all := _inventory_items()
	var head := HBoxContainer.new()
	head.add_child(_label("ИНВЕНТАРЬ", 24, D.TEXT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_label("ПРЕДМЕТОВ: " + str(all.size()), 12, D.MUTED))
	content_vbox.add_child(head)

	var stats_row := HBoxContainer.new()
	var items = [
		[_fmt(balance) + " ₽", "баланс"],
		[_fmt(_inventory_value()) + " ₽", "ценность"],
	]
	for pair in items:
		var box := PanelContainer.new()
		var v := VBoxContainer.new()
		box.add_child(v)
		v.add_child(_label(str(pair[0]), 16, D.ACCENT))
		v.add_child(_label(str(pair[1]), 10, D.MUTED))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(box)
	stats_row.add_child(_button("⊕ КЕЙС ЗА БОНУС", "daily"))
	content_vbox.add_child(stats_row)
	var sell_all := _button("✦ ПРОДАТЬ ВСЁ · " + _fmt(int(_inventory_value() * float(config.get("sell_rate", 0.65)))) + " ₽", "sell_all")
	sell_all.disabled = all.is_empty()
	content_vbox.add_child(sell_all)

	var filters := HBoxContainer.new()
	filters.add_child(_button("⚙ Фильтры", "tab", "workshop"))
	var sort := OptionButton.new()
	sort.add_item("↕ Сначала дорогие", 0)
	sort.add_item("↕ Сначала дешёвые", 1)
	sort.selected = 0 if inv_sort == "value_desc" else 1
	sort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort.item_selected.connect(func(idx): inv_sort = "value_desc" if idx == 0 else "value_asc"; _render_screen())
	filters.add_child(sort)
	content_vbox.add_child(filters)
	var rarity_row := HBoxContainer.new()
	rarity_row.add_child(_button("Все", "inv_rarity", "all"))
	for r in rarities:
		rarity_row.add_child(_button(str(r.get("name", "")), "inv_rarity", str(r.get("id", ""))))
	content_vbox.add_child(rarity_row)

	var sell_sum := 0
	var count := 0
	for it in all:
		if selected.has(str(it.get("uid", ""))):
			sell_sum += int(round(float(it["skin"].get("value", 0)) * float(config.get("sell_rate", 0.65))))
			count += 1
	if count > 0:
		content_vbox.add_child(_button("ПРОДАТЬ ВЫБРАННОЕ · " + _fmt(sell_sum) + " ₽", "sell_selected"))
		content_vbox.add_child(_button("Снять выделение", "clear_selected"))

	var shown: Array = []
	for it in all:
		if inv_rarity != "all" and str(it["skin"].get("rarity", "")) != inv_rarity:
			continue
		shown.append(it)
	if inv_sort == "value_asc":
		shown.sort_custom(func(a, b): return int(a["skin"].get("value", 0)) < int(b["skin"].get("value", 0)))
	else:
		shown.sort_custom(func(a, b): return int(a["skin"].get("value", 0)) > int(b["skin"].get("value", 0)))
	if shown.is_empty():
		content_vbox.add_child(_label("Здесь пока пусто. Откройте кейс, чтобы получить скины.", 13, D.MUTED))
		return
	var grid := _grid(2)
	for it in shown:
		var sk: Dictionary = it["skin"]
		var card := SkinCardScene.new()
		card.skin = sk
		card.selected = selected.has(str(it.get("uid", "")))
		card.card_id = str(it.get("uid", ""))
		card.show_sell = true
		card.type_label = _weapon_name(str(sk.get("weapon", "")))
		card.custom_minimum_size = Vector2(0, 168)
		var uid := card.card_id
		card.clicked.connect(func(_x): _play_sound(SND_CLICK); _on_action("select_item", uid, card))
		card.sell_clicked.connect(func(_x): _on_action("sell_one", uid, card))
		grid.add_child(card)
	content_vbox.add_child(grid)

func _rarity_index(sk: Dictionary) -> int:
	var id := str(sk.get("rarity", ""))
	for i in range(rarities.size()):
		if str(rarities[i].get("id", "")) == id:
			return i
	return 0

func _render_workshop() -> void:
	_section("Мастерская", "Свои кейсы из любых скинов · создание " + _fmt(int(config.get("case_create_cost", 1500))) + " ₽")
	if not ws_weights.has("common"):
		for r in rarities:
			ws_weights[str(r.get("id", ""))] = 0.0
	var form := PanelContainer.new()
	var fv := VBoxContainer.new()
	form.add_child(fv)
	var row := HBoxContainer.new()
	ws_name_edit = LineEdit.new()
	ws_name_edit.placeholder_text = "Название кейса"
	ws_name_edit.text = ws_name_edit.text if ws_name_edit.text != "" else ""
	ws_name_edit.custom_minimum_size = Vector2(0, 40)
	ws_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ws_name_edit.text_changed.connect(func(t): ws_name = str(t))
	row.add_child(ws_name_edit)
	ws_price_edit = LineEdit.new()
	ws_price_edit.text = "300"
	ws_price_edit.custom_minimum_size = Vector2(110, 40)
	ws_price_edit.text_changed.connect(func(t): pass)
	row.add_child(ws_price_edit)
	fv.add_child(row)
	ws_desc_edit = LineEdit.new()
	ws_desc_edit.placeholder_text = "Описание"
	ws_desc_edit.text_changed.connect(func(t): pass)
	fv.add_child(ws_desc_edit)
	fv.add_child(_label("Шансы, %", 13, D.MUTED))
	for r in rarities:
		var id := str(r.get("id", ""))
		var h := HBoxContainer.new()
		h.add_child(_label(str(r.get("name", "")), 12, D.rarity_color(id)))
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 0.5
		slider.value = float(ws_weights.get(id, 0))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v): ws_weights[id] = v; _update_ws_total())
		h.add_child(slider)
		fv.add_child(h)
	ws_total_label = _label("Сумма: 100% · нормализуется при сохранении", 11, D.MUTED)
	fv.add_child(ws_total_label)
	_update_ws_total()
	fv.add_child(_label("Скины в наборе: " + str(ws_pool.size()) + " (минимум 3)", 12, D.MUTED))
	ws_search_edit = LineEdit.new()
	ws_search_edit.placeholder_text = "Поиск скина"
	ws_search_edit.text = ws_search
	ws_search_edit.text_changed.connect(func(t): ws_search = str(t); _render_pool())
	fv.add_child(ws_search_edit)
	ws_pool_grid = _grid(_columns(130))
	fv.add_child(ws_pool_grid)
	_render_pool()
	var actions := HBoxContainer.new()
	var save_text := "Создать за " + _fmt(int(config.get("case_create_cost", 1500))) + " ₽"
	if ws_editing != "":
		save_text = "Сохранить изменения"
	actions.add_child(_button(save_text, "save_case"))
	actions.add_child(_button("Очистить", "reset_ws"))
	fv.add_child(actions)
	content_vbox.add_child(form)

	var mine := PanelContainer.new()
	var mv := VBoxContainer.new()
	mine.add_child(mv)
	mv.add_child(_label("Мои кейсы: " + str(custom_cases.size()), 17, D.TEXT))
	for c in custom_cases:
		var cid := str(c.get("id", ""))
		var line := HBoxContainer.new()
		line.add_child(_label(str(c.get("name", "")) + " · " + _fmt(int(c.get("price", 0))) + " ₽ · " + str((c.get("pool", []) as Array).size()) + " скинов", 12, D.MUTED))
		line.add_child(_button("Открыть", "case", cid))
		line.add_child(_button("✎", "edit_case", cid))
		line.add_child(_button("×", "delete_case", cid))
		mv.add_child(line)
	content_vbox.add_child(mine)

	var db := PanelContainer.new()
	var dv := VBoxContainer.new()
	db.add_child(dv)
	dv.add_child(_label("База данных", 17, D.TEXT))
	dv.add_child(_label("Вставьте JSON со скинами и кейсами или полный бэкап FORGE:", 11, D.MUTED))
	ws_json_edit = TextEdit.new()
	ws_json_edit.custom_minimum_size = Vector2(0, 110)
	dv.add_child(ws_json_edit)
	var db_actions := HBoxContainer.new()
	db_actions.add_child(_button("Загрузить JSON", "import_db"))
	db_actions.add_child(_button("Скачать бэкап", "export_db"))
	db_actions.add_child(_button("Базовая база", "clear_db"))
	dv.add_child(db_actions)
	content_vbox.add_child(db)

	var setg := PanelContainer.new()
	var sv := VBoxContainer.new()
	setg.add_child(sv)
	sv.add_child(_label("Настройки", 17, D.TEXT))
	sv.add_child(_button("Звук: " + ("вкл" if bool(settings.get("sound", true)) else "выкл"), "toggle_sound"))
	sv.add_child(_button("Дубликаты: " + ("продавать" if bool(settings.get("auto_sell_dupes", false)) else "в инвентарь"), "toggle_dupes"))
	sv.add_child(_button("Сбросить прогресс", "reset_game"))
	sv.add_child(_label("Все монеты виртуальные. Реальных денег нет.", 10, D.MUTED))
	content_vbox.add_child(setg)

func _update_ws_total() -> void:
	if ws_total_label == null:
		return
	var total := 0.0
	for v in ws_weights.values():
		total += float(v)
	ws_total_label.text = "Сумма: " + str(int(total)) + "% · нормализуется при сохранении"

func _render_pool() -> void:
	if ws_pool_grid == null:
		return
	_clear(ws_pool_grid)
	var q: String = str(ws_search).to_lower().strip_edges()
	var shown := 0
	for s in skins:
		if shown >= 120:
			break
		var name := str(s.get("name", "")).to_lower()
		if q != "" and not name.contains(q):
			continue
		var id := str(s.get("id", ""))
		var card := SkinCardScene.new()
		card.skin = s
		card.card_id = id
		card.compact = true
		card.selected = ws_pool.has(id)
		card.custom_minimum_size = Vector2(0, 120)
		card.clicked.connect(func(_x): _on_action("pool_toggle", id, card))
		ws_pool_grid.add_child(card)
		shown += 1

# ---------------------------------------------------------------- overlays

func _show_overlay(build: Callable) -> int:
	overlay_token += 1
	_clear(overlay_vbox)
	build.call(overlay_vbox)
	overlay.visible = true
	return overlay_token

func _close_overlay() -> void:
	overlay_token += 1
	overlay.visible = false

func _modal_title(vbox: VBoxContainer, title: String, subtitle: String) -> void:
	vbox.add_child(_label(title, 21, D.TEXT))
	if subtitle != "":
		vbox.add_child(_label(subtitle, 12, D.MUTED))

func _odds_box(box: Dictionary) -> VBoxContainer:
	var vb := VBoxContainer.new()
	var total := 0.0
	var weights: Dictionary = box.get("weights", {})
	for r in rarities:
		total += maxf(0.0, float(weights.get(str(r.get("id", "")), 0)))
	if total <= 0.0:
		total = 1.0
	for r in rarities:
		var id := str(r.get("id", ""))
		var p := maxf(0.0, float(weights.get(id, 0))) / total
		if p <= 0.0:
			continue
		var h := HBoxContainer.new()
		h.add_child(_label(str(r.get("name", "")), 12, D.rarity_color(id)))
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = p * 100.0
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 8)
		h.add_child(bar)
		h.add_child(_label(str(int(round(p * 100.0))) + "%", 11, D.MUTED))
		vb.add_child(h)
	return vb

func _case_modal(id: String) -> void:
	var box := _case_by_id(id)
	if box.is_empty():
		return
	_show_overlay(func(vbox):
		_modal_title(vbox, str(box.get("name", "")), str(box.get("desc", "")))
		vbox.add_child(_odds_box(box))
		vbox.add_child(_label("Скинов в наборе: " + str((box.get("pool", []) as Array).size()), 11, D.MUTED))
		var row := HBoxContainer.new()
		row.add_child(_button("Открыть за " + _fmt(int(box.get("price", 0))) + " ₽", "open_case", id))
		if bool(box.get("custom", false)):
			row.add_child(_button("Изменить", "edit_case", id))
		row.add_child(_button("Закрыть", "close_modal"))
		vbox.add_child(row)
	)

func _case_anim(id: String) -> void:
	var res := _open_case(id)
	if not bool(res.get("ok", false)):
		_toast(str(res.get("reason", "Ошибка")))
		return
	var box: Dictionary = res.get("box", {})
	_play_sound(SND_CASE)
	var pool: Array = box.get("pool", [])
	var roll_label := _label("", 16, D.ACCENT)
	roll_label.custom_minimum_size = Vector2(0, 46)
	var label_ref: Label = roll_label
	var token := _show_overlay(func(vbox):
		_modal_title(vbox, str(box.get("name", "")), "Открытие кейса")
		vbox.add_child(label_ref)
	)
	for i in range(28):
		if token != overlay_token:
			return
		if not pool.is_empty():
			var sk := _skin_by_id(str(pool[randi() % pool.size()]))
			label_ref.text = str(sk.get("name", ""))
		await get_tree().create_timer(0.075).timeout
	if token != overlay_token:
		return
	var winner: Dictionary = res.get("skin", {})
	_clear(overlay_vbox)
	_modal_title(overlay_vbox, str(winner.get("name", "")), "Редкость: " + str(_rarity_by_id(str(winner.get("rarity", ""))).get("name", "")))
	var art := SkinArtScene.new()
	art.skin = winner
	art.custom_minimum_size = Vector2(0, 120)
	overlay_vbox.add_child(art)
	var msg := "Новый предмет в инвентаре"
	if bool(res.get("duplicated", false)):
		msg = "Дубликат · +" + _fmt(int(res.get("gain", 0))) + " ₽"
	overlay_vbox.add_child(_label(msg, 12, D.MUTED))
	overlay_vbox.add_child(_label("Стоимость: " + _fmt(int(winner.get("value", 0))) + " ₽", 13, D.ACCENT))
	var row := HBoxContainer.new()
	row.add_child(_button("Ещё за " + _fmt(int(box.get("price", 0))) + " ₽", "open_case", id))
	row.add_child(_button("Назад", "close_modal"))
	overlay_vbox.add_child(row)
	_render_screen()

func _pick_source_modal() -> void:
	var items := _inventory_items()
	items.sort_custom(func(a, b): return int(a["skin"].get("value", 0)) > int(b["skin"].get("value", 0)))
	_show_overlay(func(vbox):
		_modal_title(vbox, "Ваш предмет", str(items.size()) + " предметов в инвентаре")
		if items.is_empty():
			vbox.add_child(_label("Откройте кейс, чтобы получить скины.", 12, D.MUTED))
		else:
			var grid := _grid(_columns(130))
			for it in items:
				var sk: Dictionary = it["skin"]
				var card := SkinCardScene.new()
				card.skin = sk
				card.card_id = str(it.get("uid", ""))
				card.custom_minimum_size = Vector2(0, 132)
				var uid := card.card_id
				card.clicked.connect(func(_x): up_source_uid = uid; _close_overlay(); _render_screen())
				grid.add_child(card)
			vbox.add_child(grid)
		vbox.add_child(_button("Отмена", "close_modal"))
	)

func _pick_target_modal() -> void:
	var list: Array = skins.duplicate()
	list.sort_custom(func(a, b): return int(a.get("value", 0)) > int(b.get("value", 0)))
	_show_overlay(func(vbox):
		_modal_title(vbox, "Предмет-цель", str(list.size()) + " скинов в каталоге")
		var search := LineEdit.new()
		search.placeholder_text = "Поиск по названию"
		vbox.add_child(search)
		var grid := _grid(_columns(130))
		vbox.add_child(grid)
		var limit := mini(90, list.size())
		for i in range(limit):
			var sk: Dictionary = list[i]
			var card := SkinCardScene.new()
			card.skin = sk
			card.card_id = str(sk.get("id", ""))
			card.custom_minimum_size = Vector2(0, 132)
			var sid := card.card_id
			card.clicked.connect(func(_x): up_target_id = sid; _close_overlay(); _render_screen())
			grid.add_child(card)
		search.text_changed.connect(func(t):
			_clear(grid)
			var q: String = str(t).to_lower().strip_edges()
			var shown := 0
			for sk in list:
				if shown >= 90:
					break
				if q != "" and not str(sk.get("name", "")).to_lower().contains(q):
					continue
				var card := SkinCardScene.new()
				card.skin = sk
				card.card_id = str(sk.get("id", ""))
				card.custom_minimum_size = Vector2(0, 132)
				var sid := card.card_id
				card.clicked.connect(func(_x): up_target_id = sid; _close_overlay(); _render_screen())
				grid.add_child(card)
				shown += 1
		)
		vbox.add_child(_label("Показаны первые 90 · уточните поиск", 10, D.MUTED))
		vbox.add_child(_button("Отмена", "close_modal"))
	)

func _upgrade_anim() -> void:
	var source := _source_skin()
	var target := _target_skin()
	var res := _upgrade(up_source_uid, up_target_id, up_chance, up_multiplier)
	if not bool(res.get("ok", false)):
		_toast(str(res.get("reason", "Ошибка")))
		return
	_play_sound(SND_TOGGLE)
	var spin_wheel := WheelScene.new()
	spin_wheel.custom_minimum_size = Vector2(0, 260)
	var wheel_ref: Control = spin_wheel
	var token := _show_overlay(func(vbox):
		_modal_title(vbox, "Апгрейд " + str(res.get("chance", 0)) + "%", "Ставка x" + str(up_multiplier) + " · доплата " + _fmt(int(res.get("topup", 0))) + " ₽")
		vbox.add_child(wheel_ref)
	)
	var tween := create_tween()
	tween.tween_method(Callable(wheel_ref, "set_value"), 0.0, float(res.get("chance", 0)), 1.5).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.7).timeout
	if token != overlay_token:
		return
	var win := bool(res.get("win", false))
	wheel_ref.set_value(float(res.get("chance", 0)) if win else 0.0)
	_play_sound(SND_WIN if win else SND_LOSE)
	_clear(overlay_vbox)
	var title := "НЕ ПОВЕЗЛО"
	var color := D.RED
	if win:
		title = "УСПЕХ"
		color = D.ACCENT
	_modal_title(overlay_vbox, title, "")
	var result_label: Label
	if win:
		var got: Dictionary = res.get("target", {})
		var msg := str(got.get("name", "")) + " теперь ваш"
		if bool(res.get("added", {}).get("duplicated", false)):
			msg += " · дубликат: +" + _fmt(int(res.get("added", {}).get("gain", 0))) + " ₽"
		result_label = _label(msg, 14, color)
	else:
		result_label = _label(str(source.get("name", "")) + " потерян", 14, color)
	overlay_vbox.add_child(result_label)
	overlay_vbox.add_child(_button("Продолжить", "show_upgrade"))
	up_source_uid = ""
	up_target_id = ""
	_render_screen()

func _settings_modal() -> void:
	_show_overlay(func(vbox):
		_modal_title(vbox, "Настройки", "Прогресс хранится локально")
		vbox.add_child(_label("Открыто кейсов: " + str(int(stats.get("opened", 0))), 13, D.TEXT))
		vbox.add_child(_label("Побед в апгрейде: " + str(int(stats.get("wins", 0))) + " / " + str(int(stats.get("upgrades", 0))), 13, D.TEXT))
		vbox.add_child(_label("Получено: " + _fmt(int(stats.get("earned", 0))) + " ₽ · потрачено: " + _fmt(int(stats.get("spent", 0))) + " ₽", 12, D.MUTED))
		vbox.add_child(_button("Звук: " + ("вкл" if bool(settings.get("sound", true)) else "выкл"), "toggle_sound"))
		vbox.add_child(_button("Дубликаты: " + ("продавать" if bool(settings.get("auto_sell_dupes", false)) else "в инвентарь"), "toggle_dupes"))
		vbox.add_child(_button("Сбросить прогресс", "reset_game"))
		vbox.add_child(_button("Закрыть", "close_modal"))
	)

# ---------------------------------------------------------------- actions

func _on_action(action: String, id: String, node: Node) -> void:
	match action:
		"tab":
			_play_sound(SND_CLICK)
			_close_overlay()
			_show_tab(id)
		"show_upgrade":
			_close_overlay()
			_show_tab("upgrade")
		"close_modal":
			_close_overlay()
		"case":
			_case_modal(id)
		"open_case":
			_case_anim(id)
		"pick_source":
			_pick_source_modal()
		"pick_target":
			_pick_target_modal()
		"chance":
			_play_sound(SND_CLICK)
			up_chance = int(id)
			up_custom = false
			_render_screen()
		"custom_chance":
			_play_sound(SND_CLICK)
			up_custom = true
			_render_screen()
		"mult":
			_play_sound(SND_CLICK)
			up_multiplier = int(id)
			_render_screen()
		"do_upgrade":
			_upgrade_anim()
		"inv_rarity":
			inv_rarity = id
			selected.clear()
			_render_screen()
		"select_item":
			if selected.has(id):
				selected.erase(id)
			else:
				selected[id] = true
			_render_screen()
		"clear_selected":
			selected.clear()
			_render_screen()
		"sell_selected":
			var res := _sell_items(selected.keys())
			if bool(res.get("ok", false)):
				_play_sound(SND_REWARD)
				_toast("Продано " + str(res.get("count", 0)) + " · +" + _fmt(int(res.get("total", 0))) + " ₽")
				selected.clear()
				_render_screen()
			else:
				_toast(str(res.get("reason", "Ошибка")))
		"sell_one":
			var res := _sell_items([id])
			if bool(res.get("ok", false)):
				_play_sound(SND_REWARD)
				_toast("Продано · +" + _fmt(int(res.get("total", 0))) + " ₽")
				selected.erase(id)
				_render_screen()
		"sell_all":
			var uids: Array = []
			for it in _inventory_items():
				uids.append(str(it.get("uid", "")))
			var res := _sell_items(uids)
			if bool(res.get("ok", false)):
				_play_sound(SND_REWARD)
				_toast("Продано " + str(res.get("count", 0)) + " · +" + _fmt(int(res.get("total", 0))) + " ₽")
				selected.clear()
				_render_screen()
		"daily":
			var r := _check_daily()
			if bool(r.get("ok", false)):
				_play_sound(SND_DAILY)
				_toast("Бонус: +" + _fmt(int(r.get("amount", 0))) + " ₽")
				_render_screen()
			else:
				_toast("Бонус будет через " + str(int(int(r.get("wait", 0)) / 3600)) + " ч")
		"settings":
			_settings_modal()
		"pool_toggle":
			if ws_pool.has(id):
				ws_pool.erase(id)
			else:
				ws_pool[id] = true
			_render_pool()
		"reset_ws":
			_reset_ws()
			_render_screen()
		"save_case":
			_save_case()
		"edit_case":
			_edit_case(id)
		"delete_case":
			if not bool((node as Button).get_meta("confirm", false)):
				(node as Button).set_meta("confirm", true)
				(node as Button).text = "Точно?"
				return
			_delete_case(id)
			_toast("Кейс удалён")
			_render_screen()
		"import_db":
			_import_database()
		"export_db":
			_export_database()
		"clear_db":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(DATA_FILE))
			_load_data()
			inventory = inventory.filter(func(it): return not _skin_by_id(str(it.get("skin_id", ""))).is_empty())
			_toast("Базовая база восстановлена")
			_render_screen()
		"toggle_sound":
			if bool(settings.get("sound", true)):
				_play_sound(SND_TOGGLE)
			settings["sound"] = not bool(settings.get("sound", true))
			_save_game()
			if overlay.visible:
				_settings_modal()
			_render_screen()
		"toggle_dupes":
			settings["auto_sell_dupes"] = not bool(settings.get("auto_sell_dupes", false))
			_save_game()
			if overlay.visible:
				_settings_modal()
			_render_screen()
		"reset_game":
			if not bool((node as Button).get_meta("confirm", false)):
				(node as Button).set_meta("confirm", true)
				(node as Button).text = "Точно?"
				return
			balance = int(config.get("starting_balance", 3000))
			inventory = []
			stats = {"opened": 0, "upgrades": 0, "wins": 0, "sold": 0, "earned": 0, "spent": 0}
			custom_cases = []
			last_daily = 0
			log_entries = []
			selected.clear()
			up_source_uid = ""
			up_target_id = ""
			_reset_ws()
			_save_game()
			_close_overlay()
			_show_tab("cases")
			_toast("Прогресс сброшен")

func _reset_ws() -> void:
	ws_editing = ""
	ws_name = ""
	ws_pool.clear()
	ws_weights.clear()
	ws_search = ""
	for r in rarities:
		ws_weights[str(r.get("id", ""))] = 0.0
	ws_weights["common"] = 45.0
	ws_weights["rare"] = 30.0
	ws_weights["epic"] = 17.0
	ws_weights["legendary"] = 6.0
	ws_weights["unique"] = 2.0

func _save_case() -> void:
	var total := 0.0
	for v in ws_weights.values():
		total += float(v)
	if total <= 0.0:
		_toast("Хотя бы один шанс должен быть больше нуля")
		return
	var weights: Dictionary = {}
	for r in rarities:
		var id := str(r.get("id", ""))
		weights[id] = float(ws_weights.get(id, 0)) / total * 100.0
	var price := 300
	if ws_price_edit != null:
		price = maxi(50, int(ws_price_edit.text))
	var form := {
		"name": ws_name,
		"price": price,
		"hue": 120,
		"desc": ws_desc_edit.text if ws_desc_edit != null else "",
		"pool": ws_pool.keys(),
		"weights": weights,
	}
	var res := Dictionary()
	if ws_editing != "":
		res = _update_case(ws_editing, form)
	else:
		res = _create_case(form)
	if not bool(res.get("ok", false)):
		_toast(str(res.get("reason", "Ошибка")))
		return
	_toast("Кейс сохранён" if ws_editing != "" else "Кейс создан за " + _fmt(int(config.get("case_create_cost", 1500))) + " ₽")
	_reset_ws()
	_render_screen()

func _edit_case(id: String) -> void:
	var box := _case_by_id(id)
	if box.is_empty() or not bool(box.get("custom", false)):
		return
	_reset_ws()
	ws_editing = str(box.get("id", ""))
	ws_name = str(box.get("name", ""))
	ws_weights = (box.get("weights", {}) as Dictionary).duplicate(true)
	ws_pool.clear()
	for sid in (box.get("pool", []) as Array):
		ws_pool[str(sid)] = true
	_close_overlay()
	_show_tab("workshop")

func _import_database() -> void:
	if ws_json_edit == null:
		return
	var text := ws_json_edit.text.strip_edges()
	if text == "":
		_toast("Вставьте JSON")
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_toast("Не удалось прочитать JSON")
		return
	if str(parsed.get("format", "")) == "forge-backup-v2":
		var data_part: Variant = parsed.get("data", {})
		if not (data_part is Dictionary):
			_toast("Некорректный бэкап")
			return
		_write_json(DATA_FILE, data_part)
		var state_part: Variant = parsed.get("state", {})
		if state_part is Dictionary:
			_write_json(SAVE_FILE, state_part)
		_load_data()
		_load_game()
		_toast("Бэкап восстановлен")
		_show_tab("cases")
		return
	var incoming_skins: Variant = parsed.get("skins", [])
	var incoming_cases: Variant = parsed.get("cases", [])
	if not (incoming_skins is Array) or not (incoming_cases is Array) or incoming_skins.is_empty():
		_toast("Нужны массивы skins и cases")
		return
	var clean_skins: Array = []
	for s in incoming_skins:
		if not (s is Dictionary):
			continue
		clean_skins.append({
			"id": str(s.get("id", "")),
			"name": str(s.get("name", "")),
			"weapon": str(s.get("weapon", "rifle")),
			"rarity": str(s.get("rarity", "common")),
			"series": str(s.get("series", "")),
			"value": maxi(1, int(s.get("value", 1))),
			"hue": int(s.get("hue", 200)) % 360,
			"sat": clampi(int(s.get("sat", 40)), 0, 100),
			"light": clampi(int(s.get("light", 46)), 10, 90),
		})
	var ids: Dictionary = {}
	for s in clean_skins:
		ids[str(s.get("id", ""))] = true
	var clean_cases: Array = []
	for c in incoming_cases:
		if not (c is Dictionary):
			continue
		var pool: Array = []
		for pid in (c.get("pool", []) as Array):
			if ids.has(str(pid)):
				pool.append(str(pid))
		if pool.is_empty():
			continue
		clean_cases.append({
			"id": str(c.get("id", "")),
			"name": str(c.get("name", "")),
			"price": maxi(1, int(c.get("price", 300))),
			"hue": int(c.get("hue", 180)) % 360,
			"weights": c.get("weights", {}),
			"pool": pool,
			"desc": str(c.get("desc", "")),
		})
	if clean_cases.is_empty():
		_toast("Нет валидных кейсов")
		return
	var payload: Dictionary = {
		"skins": clean_skins,
		"cases": clean_cases,
		"config": config,
		"rarities": rarities,
		"weapons": weapons,
	}
	_write_json(DATA_FILE, payload)
	_load_data()
	inventory = inventory.filter(func(it): return not _skin_by_id(str(it.get("skin_id", ""))).is_empty())
	_save_game()
	_toast("Загружено: " + str(clean_skins.size()) + " скинов, " + str(clean_cases.size()) + " кейсов")
	_reset_ws()
	_render_screen()

func _export_database() -> void:
	_write_json(BACKUP_FILE, {
		"format": "forge-backup-v2",
		"exported_at": Time.get_datetime_string_from_system(),
		"data": {"config": config, "rarities": rarities, "weapons": weapons, "skins": skins, "cases": cases},
		"state": {
			"balance": balance, "inventory": inventory, "stats": stats,
			"custom_cases": custom_cases, "settings": settings, "last_daily": last_daily, "log": log_entries,
		},
	})
	_toast("Бэкап: " + BACKUP_FILE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay.visible:
			_close_overlay()
		elif current_tab != "cases":
			_show_tab("cases")
