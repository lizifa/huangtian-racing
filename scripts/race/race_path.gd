class_name RacePath
extends RefCounted
## 环形赛道中心线：圆角矩形参数化，按弧长取样，供道路网格、AI、圈数判定共用。

const ROAD_HALF := 3.5      ## 路面半宽
const A := 44.0             ## 半长（X 方向）
const B := 27.0             ## 半深（Z 方向）
const R := 13.0             ## 圆角半径

var points: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var total := 0.0

func _init(step := 1.0) -> void:
	_build(step)

func _build(step: float) -> void:
	var segs := []
	# 逆时针一圈：下直道 → 右下弯 → 右直道 → 右上弯 → 上直道 → 左上弯 → 左直道 → 左下弯
	segs.append({"kind": "line", "from": Vector2(-(A - R), -B), "to": Vector2(A - R, -B)})
	segs.append({"kind": "arc", "center": Vector2(A - R, -(B - R)), "a0": -PI * 0.5, "a1": 0.0})
	segs.append({"kind": "line", "from": Vector2(A, -(B - R)), "to": Vector2(A, B - R)})
	segs.append({"kind": "arc", "center": Vector2(A - R, B - R), "a0": 0.0, "a1": PI * 0.5})
	segs.append({"kind": "line", "from": Vector2(A - R, B), "to": Vector2(-(A - R), B)})
	segs.append({"kind": "arc", "center": Vector2(-(A - R), B - R), "a0": PI * 0.5, "a1": PI})
	segs.append({"kind": "line", "from": Vector2(-A, B - R), "to": Vector2(-A, -(B - R))})
	segs.append({"kind": "arc", "center": Vector2(-(A - R), -(B - R)), "a0": PI, "a1": PI * 1.5})
	var acc := 0.0
	points.clear()
	tangents.clear()
	for seg in segs:
		var len_seg := 0.0
		if seg.kind == "line":
			len_seg = seg.from.distance_to(seg.to)
		else:
			len_seg = R * (seg.a1 - seg.a0)
		var n: int = maxi(1, int(ceil(len_seg / step)))
		for i in n:
			var t := float(i) / float(n)
			var p: Vector2
			var tan: Vector2
			if seg.kind == "line":
				p = seg.from.lerp(seg.to, t)
				tan = (seg.to - seg.from).normalized()
			else:
				var ang: float = lerp(seg.a0, seg.a1, t)
				p = seg.center + Vector2(cos(ang), sin(ang)) * R
				tan = Vector2(-sin(ang), cos(ang))
			points.append(Vector3(p.x, 0.0, p.y))
			tangents.append(Vector3(tan.x, 0.0, tan.y))
			acc += len_seg / float(n)
	if points.size() > 0:
		points.append(points[0])
		tangents.append(tangents[0])
		total = acc

## 取弧长 s 处的位置与切向（自动环绕）。
func at(s: float) -> Array:
	var n := points.size() - 1
	var u := fposmod(s, total) / total * float(n)
	var i := int(floor(u))
	var t := u - float(i)
	var p: Vector3 = points[i].lerp(points[mini(i + 1, n)], t)
	var d: Vector3 = tangents[i].lerp(tangents[mini(i + 1, n)], t).normalized()
	return [p, d]

## 距离某个世界坐标最近的中心线信息：返回 [s, 横向偏移(左正右负), 切向, 中心点]
func nearest(pos: Vector3) -> Array:
	var best := INF
	var best_i: int = 0
	for i in range(points.size() - 1):
		var d: float = Vector2(pos.x - points[i].x, pos.z - points[i].z).length_squared()
		if d < best:
			best = d
			best_i = i
	var p := points[best_i]
	var tan := tangents[best_i]
	var side := Vector3(-tan.z, 0.0, tan.x)  # 左侧
	var offset := Vector3(pos.x - p.x, 0.0, pos.z - p.z).dot(side)
	var seg_len := p.distance_to(points[best_i + 1])
	var along := Vector3(pos.x - p.x, 0.0, pos.z - p.z).dot(tan)
	var s := 0.0
	# 累计到 best_i
	s = best_i * (total / float(points.size() - 1))
	s += clampf(along, 0.0, seg_len)
	return [s, offset, tan, p]
