extends Control

const D = preload("res://scripts/DrawUtil.gd")

func _draw() -> void:
	D.draw_coin(self, Rect2(Vector2.ZERO, size))
