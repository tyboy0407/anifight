class_name WaterDragon
extends Node2D
## 卡卡西「水遁.水龍波」的水龍:用一格一格的方塊即時畫出來的點陣水龍,不用圖檔。
## 節點的位置是龍頭;身體拖在後面像波浪一樣擺動。只負責畫,不做判定(判定在 kakashi.gd)。
##   facing  往哪邊游(1 = 右)
##   grown   身體長出來的比例(0 到 1):結印時在身後慢慢凝聚,放出去時是 1
##   fade    不透明度

const CELL := 4.0                 # 一格方塊的邊長
const SEGMENTS := 30              # 身體有幾節
const SPACING := 7.0              # 每一節之間的距離
const WAVE := 16.0                # 身體擺動的幅度
const DEEP := Color(0.1, 0.25, 0.62)
const BODY := Color(0.24, 0.55, 0.95)
const LIGHT := Color(0.6, 0.86, 1.0)
const FOAM := Color(0.93, 0.98, 1.0)

var facing := 1
var grown := 1.0
var fade := 1.0
var _time := 0.0


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var count := int(SEGMENTS * clampf(grown, 0.0, 1.0))
	# 從尾巴畫到頭,頭才會蓋在身體上面
	for index in range(count, 0, -1):
		var along := index * SPACING
		var sway := sin(index * 0.42 - _time * 13.0) * WAVE * minf(index / 6.0, 1.0)
		# 越靠近尾巴越細
		var thick := lerpf(5.0, 1.5, float(index) / SEGMENTS)
		var center := Vector2(-facing * along, sway)
		_blob(center, thick + 1.0, DEEP)
		_blob(center, thick, BODY)
		_cell(center + Vector2(0, -thick * CELL * 0.45), LIGHT)
		# 背上每隔幾節一片鰭,身邊偶爾甩出水花
		if index % 4 == 0:
			_cell(center + Vector2(0, -(thick + 1.5) * CELL * 0.5), FOAM)
		if index % 5 == 2:
			_cell(center + Vector2(-facing * 6.0, (thick + 2.5) * CELL * 0.5 * sin(_time * 9.0 + index)), LIGHT)
	if count <= 0:
		return
	# 頭:比身體大一圈,上下顎張開、一顆眼睛、往後飄的兩根鬚
	_blob(Vector2.ZERO, 7.5, DEEP)
	_blob(Vector2.ZERO, 6.5, BODY)
	for step in 5:
		_cell(Vector2(facing * (14.0 + step * CELL), -10.0 - step * 1.0), BODY)   # 上顎
		_cell(Vector2(facing * (12.0 + step * CELL), 10.0 + step * 1.5), BODY)    # 下顎
		_cell(Vector2(facing * (12.0 + step * CELL), 0.0), DEEP)                   # 嘴裡
	_cell(Vector2(facing * 30.0, -8.0), FOAM)   # 牙
	_cell(Vector2(facing * 28.0, 8.0), FOAM)
	_cell(Vector2(facing * 6.0, -8.0), FOAM)    # 眼睛
	_cell(Vector2(facing * 6.0 + CELL * facing, -8.0), Color(1.0, 0.95, 0.4))
	for step in 6:
		var back := -facing * (4.0 + step * 6.0)
		_cell(Vector2(back, -18.0 - step * 2.0 + sin(_time * 10.0 + step) * 3.0), LIGHT)
		_cell(Vector2(back, 18.0 + step * 2.0 + sin(_time * 10.0 + step + 2.0) * 3.0), LIGHT)


## 以 center 為中心、直徑 size 格的一團方塊(四個角削掉,看起來比較圓)。
func _blob(center: Vector2, size: float, color: Color) -> void:
	var half := size * CELL / 2.0
	var tinted := Color(color, color.a * fade)
	draw_rect(Rect2(_snap(center + Vector2(-half + CELL, -half)), Vector2(half * 2.0 - CELL * 2.0, half * 2.0)), tinted)
	draw_rect(Rect2(_snap(center + Vector2(-half, -half + CELL)), Vector2(half * 2.0, half * 2.0 - CELL * 2.0)), tinted)


func _cell(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(_snap(center - Vector2(CELL, CELL) / 2.0), Vector2(CELL, CELL)), Color(color, color.a * fade))


## 對齊到方塊的格線,才有點陣的感覺。
func _snap(point: Vector2) -> Vector2:
	return (point / CELL).round() * CELL
