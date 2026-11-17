extends Control
## 左下虚拟摇杆（双轴）：
##   往上推 = 前进（油门 0~1）
##   往下拉 = 刹车（0~1）
##   左右拖 = 转向（-1~1）

signal steer_changed(value: float)
signal throttle_changed(value: float)
signal brake_changed(value: float)

var radius := 84.0
var knob_radius := 34.0
var steer := 0.0
var throttle := 0.0
var brake := 0.0
var active := false
var _drag_index := -2
var _center := Vector2.ZERO
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resize()

func resize() -> void:
	_center = size * 0.5
	radius = minf(size.x, size.y) * 0.5 - 6.0
	knob_radius = radius * 0.4
	_knob = _center
	queue_redraw()

func _draw() -> void:
	# 底盘：淡到几乎透明，和农场那套一致
	draw_circle(_center, radius, Color(1, 0.97, 0.9, 0.14))
	draw_arc(_center, radius, 0.0, TAU, 64, Color(0.58, 0.45, 0.32, 0.42), 2.5)
	draw_arc(_center, radius * 0.62, 0.0, TAU, 48, Color(0.58, 0.45, 0.32, 0.22), 1.5)
	# 正上方的“前进”刻度提示，推上去会点亮
	draw_line(_center + Vector2(0, -radius * 0.62), _center + Vector2(0, -radius * 0.36),
		Color(0.98, 0.72, 0.30, 0.55 if throttle > 0.05 else 0.22), 3.0)
	# 小圆钮
	draw_circle(_knob, knob_radius, Color(0.97, 0.93, 0.82, 0.62 if not active else 0.9))
	draw_arc(_knob, knob_radius, 0.0, TAU, 40, Color(0.5, 0.35, 0.2, 0.8), 2.5)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_index = event.index
			_update_from(event.position)
		elif event.index == _drag_index:
			_drag_index = -2
			_release()
	elif event is InputEventScreenDrag and event.index == _drag_index:
		_update_from(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_from(event.position)
		else:
			_release()

func press_at(p: Vector2, idx: int) -> void:
	_drag_index = idx
	_update_from(p)

func drag_at(p: Vector2, idx: int) -> void:
	if idx == _drag_index:
		_update_from(p)

func release_at(idx: int) -> void:
	if idx == _drag_index:
		_drag_index = -2
		_release()

func _update_from(p: Vector2) -> void:
	active = true
	var span := radius * 0.62
	var d := p - _center
	steer = clampf(d.x / span, -1.0, 1.0)
	var up := clampf(-d.y / span, -1.0, 1.0)
	throttle = maxf(up, 0.0)
	brake = maxf(-up, 0.0)
	# 轻推起步：超过 12% 行程才开始给油/刹车，避免手抖误触
	if throttle < 0.12:
		throttle = 0.0
	if brake < 0.12:
		brake = 0.0
	_knob = _center + Vector2(steer, -up) * span
	queue_redraw()
	steer_changed.emit(steer)
	throttle_changed.emit(throttle)
	brake_changed.emit(brake)

func _release() -> void:
	active = false
	steer = 0.0
	throttle = 0.0
	brake = 0.0
	_knob = _center
	queue_redraw()
	steer_changed.emit(0.0)
	throttle_changed.emit(0.0)
	brake_changed.emit(0.0)
