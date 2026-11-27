extends Control

const D = preload("res://scripts/DrawUtil.gd")

var skin: Dictionary = {}

func _draw() -> void:
	if not skin.is_empty():
		D.draw_weapon(self, skin, Rect2(Vector2.ZERO, size))
