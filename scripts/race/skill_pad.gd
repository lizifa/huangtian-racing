extends Control
## 右下技能圆盘：正圆 + 双层描边 + 顶部高光 + 居中文字，可选外圈能量环。
## 冷却/不可用只降透明度，不隐藏（QQ飞车那套状态表达）。

signal changed(down: bool)

var label_text := ""
var icon := ""                          ## "" 显示文字；"refresh" 画刷新环形箭头图标
var base_color := Color(0.96, 0.91, 0.80, 0.92)
var active_color := Color(1.0, 0.72, 0.28, 0.98)
var dim := false
var ring := -1.0                      ## <0 不画环；0..1 画能量环
var ring_color := Color(0.45, 0.78, 1.0, 0.95)
var down := false
var _touches := {}
var _lbl: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon == "":
		_lbl = Label.new()
		_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lbl.text = label_text
		_lbl.add_theme_font_size_override("font_size", int(minf(size.x, size.y) * 0.24))
		_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.9))
		_lbl.add_theme_color_override("font_outline_color", Color(0.22, 0.11, 0.03))
		_lbl.add_theme_constant_override("outline_size", 6)
		add_child(_lbl)
	queue_redraw()

func set_dim(v: bool) -> void:
	if dim == v:
		return
	dim = v
	if _lbl:
		_lbl.modulate.a = 0.55 if v else 1.0
	queue_redraw()

func set_ring(v: float) -> void:
	ring = v
	queue_redraw()

func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 7.0
	var c := size * 0.5
	var a := 0.5 if dim else 1.0
	var fill := base_color if not down else active_color
	# 外圈能量环（氮气）
	if ring >= 0.0:
		draw_arc(c, r + 7.0, 0.0, TAU, 64, Color(0.1, 0.18, 0.28, 0.55), 7.0)
		if ring > 0.01:
			draw_arc(c, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(ring, 0.0, 1.0), 64, ring_color, 7.0, true)
	# 底盘
	draw_circle(c, r + 1.0, Color(1, 1, 1, 0.16 * a))
	draw_circle(c, r, Color(fill.r, fill.g, fill.b, fill.a * a))
	# 双层描边：外亮内暗
	draw_arc(c, r, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.62 * a), 3.0)
	draw_arc(c, r - 5.0, 0.0, TAU, 64, Color(0.16, 0.08, 0.03, 0.55 * a), 2.5)
	# 顶部高光
	draw_arc(c, r - 12.0, PI * 0.92, PI * 1.45, 20, Color(1.0, 1.0, 1.0, 0.34 * a), 7.0)
	# 图标（刷新环形箭头）
	if icon == "refresh":
		var ir: float = minf(size.x, size.y) * 0.19
		var a0: float = deg_to_rad(38.0)
		var a1: float = deg_to_rad(322.0)
		var ic := Color(1.0, 0.97, 0.9, a)
		draw_arc(c, ir, a0, a1, 48, ic, 11.0, true)
		var tip := c + Vector2(cos(a0), sin(a0)) * ir
		var tang := Vector2(sin(a0), -cos(a0))   # 顺时针切向
		var out := Vector2(cos(a0), sin(a0))
		var wing := tang * 20.0 - out * 4.0
		draw_colored_polygon([tip, tip - wing + out * 5.0, tip - wing - out * 5.0], ic)
	# 按下时的内压感
	if down:
		draw_circle(c, r - 8.0, Color(1.0, 1.0, 1.0, 0.10))

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

## 集中式触摸分发入口（不走 GUI 命中，避免 iOS 上漏事件）
func press(idx: int) -> void:
	_touches[idx] = true
	_refresh()

func release(idx: int) -> void:
	_touches.erase(idx)
	_refresh()

func _refresh() -> void:
	var now := not _touches.is_empty()
	if now != down:
		down = now
		changed.emit(down)
		queue_redraw()
