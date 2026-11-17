extends Control
## 屏幕圆形按钮：多指同时按、按下/松开回调。

signal changed(down: bool)

var glyph := ""
var down := false
var base_color := Color(0.96, 0.91, 0.80, 0.55)
var active_color := Color(1.0, 0.72, 0.28, 0.9)
var _touches := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(150, 150)

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var c := size * 0.5
	draw_circle(c, r, base_color if not down else active_color)
	draw_arc(c, r, 0.0, TAU, 48, Color(0.55, 0.36, 0.2, 0.8), 3.0)
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.95)
	draw_string(font, c + Vector2(-r * 0.42, r * 0.32), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.4, 0.26, 0.12))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)
		_refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touches[-1] = true
		else:
			_touches.erase(-1)
		_refresh()

func _refresh() -> void:
	var now := not _touches.is_empty()
	if now != down:
		down = now
		changed.emit(down)
		queue_redraw()
