class_name KaguneTails
extends Node2D
## 金木研背後的赫子尾巴(鱗赫)。尾巴的數量會變、還要伸出去打人,所以不放在角色圖裡,
## 而是每一格沿著曲線用一格一格的方塊畫出來,大小和角色點陣圖的像素一樣。
##
## 座標以角色腳底為原點;x 是「面向的方向為正」,畫的時候才依 facing 翻面。
## 平常尾巴在背後擺動;stab() 讓某一條伸到指定的位置再收回來,sweep() 讓全部一起從背後甩到身前。

const CELL := 3.0            # 一格的大小,和角色點陣圖放大後的像素相同
const MAX_TAILS := 4
const ROOT := Vector2(-9, -64)  # 尾巴從後腰長出來
## 每一條尾巴平常尾端停在哪裡(在背後、上方散開)
const REST_TIPS: Array[Vector2] = [Vector2(-88, -142), Vector2(-112, -92), Vector2(-64, -180), Vector2(-104, -44)]
const OUT_TIME := 0.06       # 伸出去花多久
const BACK_TIME := 0.16      # 收回來花多久
const SAMPLES := 34          # 一條尾巴畫幾格
const SWEEP_FROM := -2.35    # 橫掃的起點角度(背後上方),0 是正前方
const SWEEP_TO := 0.3        # 橫掃的終點角度(身前偏下)
const SWEEP_RADIUS := 236.0
const OUTLINE := Color(0.2, 0.02, 0.06)
const BODY := Color(0.8, 0.09, 0.13)
const SHADE := Color(0.55, 0.04, 0.1)
const SCALE_SHINE := Color(1.0, 0.36, 0.3)

var count := 1       # 現在有幾條
var facing := 1
var glow := 0.0      # 0 到 1:亢奮時尾巴發亮

var _time := 0.0
var _stab_clock: Array[float] = [-1.0, -1.0, -1.0, -1.0]  # 這條尾巴伸出去多久了;小於 0 代表沒有在伸
var _stab_hold: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _stab_target: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _sweep := -1.0   # 橫掃的進度 0 到 1;小於 0 代表沒有在掃


## 讓第 index 條尾巴伸到 target(以腳底為原點、面向為正),停 hold 秒後收回。
func stab(index: int, target: Vector2, hold: float = 0.05) -> void:
	if index < 0 or index >= MAX_TAILS:
		return
	_stab_clock[index] = 0.0
	_stab_hold[index] = hold
	_stab_target[index] = target


## 所有尾巴一起伸向 target,尾端上下錯開 spread。
func stab_all(target: Vector2, hold: float, spread: float = 20.0) -> void:
	for index in count:
		stab(index, target + Vector2(0, (index - (count - 1) / 2.0) * spread), hold)


## 橫掃的進度(0 到 1);掃完傳 -1。
func sweep(progress: float) -> void:
	_sweep = progress


## 全部收回背後(被打斷、回合重置時)。
func relax() -> void:
	_sweep = -1.0
	for index in MAX_TAILS:
		_stab_clock[index] = -1.0


func _process(delta: float) -> void:
	_time += delta
	for index in MAX_TAILS:
		if _stab_clock[index] >= 0.0:
			_stab_clock[index] += delta
			if _stab_clock[index] >= OUT_TIME + _stab_hold[index] + BACK_TIME:
				_stab_clock[index] = -1.0
	if visible:
		queue_redraw()


## 第 index 條尾巴現在伸出去的程度(0 = 在背後,1 = 完全伸到目標)。
func _reach(index: int) -> float:
	var clock := _stab_clock[index]
	if clock < 0.0:
		return 0.0
	if clock < OUT_TIME:
		return clock / OUT_TIME
	if clock < OUT_TIME + _stab_hold[index]:
		return 1.0
	return 1.0 - (clock - OUT_TIME - _stab_hold[index]) / BACK_TIME


func _rest_tip(index: int) -> Vector2:
	var sway := Vector2(sin(_time * 2.1 + index * 1.7) * 7.0, cos(_time * 1.6 + index * 2.3) * 6.0)
	return REST_TIPS[index] + sway


func _draw() -> void:
	for index in count:
		var tip := _rest_tip(index)
		var bulge := 0.36  # 曲線拱起來的程度:在背後時拱成弧形,伸出去時拉直
		if _sweep >= 0.0:
			# 幾條尾巴前後錯開一點,掃起來像一把扇子
			var angle := lerpf(SWEEP_FROM, SWEEP_TO, clampf(_sweep * 1.15 - index * 0.05, 0.0, 1.0))
			tip = ROOT + Vector2(cos(angle), sin(angle)) * (SWEEP_RADIUS + index * 12.0)
			bulge = 0.22
		else:
			var reach := _reach(index)
			if reach > 0.0:
				tip = tip.lerp(_stab_target[index], reach)
				bulge = lerpf(0.36, 0.1, reach)
		_draw_tail(tip, bulge)


## 從後腰到 tip 畫一條尾巴:根部粗、尾端尖,外面一圈深色的邊,身上一節一節的鱗片反光。
func _draw_tail(tip: Vector2, bulge: float) -> void:
	var along := tip - ROOT
	# 往上、往後拱:取和尾巴垂直、偏上的那個方向
	var normal := Vector2(along.y, -along.x).normalized()
	if normal.y > 0.0:
		normal = -normal
	var control := ROOT + along * 0.5 + normal * along.length() * bulge
	var points: Array[Vector2] = []
	var widths: Array[float] = []
	for step in SAMPLES:
		var t := step / float(SAMPLES - 1)
		var point := ROOT.lerp(control, t).lerp(control.lerp(tip, t), t)
		point = (point / CELL).round() * CELL
		points.append(Vector2(point.x * facing, point.y))
		widths.append(maxf(roundf(lerpf(4.4, 1.0, pow(t, 0.8))), 1.0) * CELL)
	for step in SAMPLES:
		var size := widths[step] + CELL * 2.0
		draw_rect(Rect2(points[step] - Vector2(size, size) / 2.0, Vector2(size, size)), OUTLINE)
	var body := BODY.lerp(SCALE_SHINE, glow * 0.45)
	for step in SAMPLES:
		var size := widths[step]
		draw_rect(Rect2(points[step] - Vector2(size, size) / 2.0, Vector2(size, size)), body)
		# 下緣一道陰影
		if size > CELL:
			draw_rect(Rect2(points[step] + Vector2(-size / 2.0, size / 2.0 - CELL), Vector2(size, CELL)), SHADE.lerp(BODY, glow * 0.5))
	for step in range(2, SAMPLES - 3, 4):
		# 鱗片:每隔幾格在上緣點一格亮色
		var size := widths[step]
		if size > CELL:
			draw_rect(Rect2(points[step] + Vector2(-CELL / 2.0, -size / 2.0), Vector2(CELL, CELL)), SCALE_SHINE)
