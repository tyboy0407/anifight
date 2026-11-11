extends SceneTree
## 用程式畫出臨時的點陣角色,輸出成 assets/characters/<id>/sheet.png 與 sheet.json。
## 找到正式素材後,直接用新的 sheet.png / sheet.json 取代即可。
##
## 執行方式(在專案資料夾):
##   godot --headless --path . --script tools/generate_placeholder_sprites.gd
##
## 角色面向右。每個姿勢用幾個關節點描述,再用粗線連成四肢與軀幹。

const CELL := Vector2i(48, 48)
const OUTLINE := Color(0.07, 0.06, 0.09)
const SKIN := Color(0.97, 0.84, 0.74)
const SHOE := Color(0.1, 0.1, 0.13)
const BACK_SHADE := 0.72  # 遠側手腳的明暗

## 角色外觀
const STYLES := [
	{
		"id": "gojo",
		"hair": Color(0.96, 0.97, 1.0), "spiky": true, "blindfold": true, "marks": false,
		"top": Color(0.13, 0.14, 0.24), "sleeve": Color(0.13, 0.14, 0.24),
		"pants": Color(0.11, 0.12, 0.2), "sash": Color(0, 0, 0, 0),
	},
	{
		"id": "sukuna",
		"hair": Color(0.96, 0.58, 0.64), "spiky": true, "blindfold": false, "marks": true,
		"top": Color(0.93, 0.91, 0.88), "sleeve": Color(0.93, 0.91, 0.88),
		"pants": Color(0.16, 0.15, 0.2), "sash": Color(0.2, 0.18, 0.26),
	},
]

## 站姿(格鬥架式)。其他姿勢只寫和它不同的關節。
const BASE := {
	"head": Vector2i(25, 13), "neck": Vector2i(24, 19), "hip": Vector2i(24, 31),
	"hand_b": Vector2i(28, 25), "elbow_b": Vector2i(22, 27),
	"hand_f": Vector2i(32, 23), "elbow_f": Vector2i(27, 27),
	"foot_b": Vector2i(19, 46), "knee_b": Vector2i(21, 39),
	"foot_f": Vector2i(30, 46), "knee_f": Vector2i(28, 39),
}

var _image: Image
var _origin := Vector2i.ZERO
var _style: Dictionary


func _initialize() -> void:
	for style: Dictionary in STYLES:
		_generate(style)
	quit()


static func v(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


## 以站姿為底,套用差異。值為 null 代表拿掉該關節(手肘 / 膝蓋變成直線)。
static func pose(changes: Dictionary = {}) -> Dictionary:
	var result := BASE.duplicate()
	for key: String in changes:
		if changes[key] == null:
			result.erase(key)
		else:
			result[key] = changes[key]
	return result


func _animations() -> Array:
	var straight := {"elbow_b": null, "elbow_f": null}
	return [
		{"name": "idle", "fps": 4, "loop": true, "frames": [
			pose(),
			pose({"head": v(25, 14), "neck": v(24, 20), "hand_b": v(28, 26), "hand_f": v(32, 24)}),
		]},
		{"name": "walk", "fps": 10, "loop": true, "frames": [
			pose({"foot_b": v(17, 46), "knee_b": v(20, 39), "foot_f": v(31, 46), "knee_f": v(28, 39)}),
			pose({"foot_b": v(21, 45), "knee_b": v(23, 39), "foot_f": v(28, 46), "knee_f": v(27, 39), "head": v(25, 14), "neck": v(24, 20)}),
			pose({"foot_b": v(27, 43), "knee_b": v(27, 37), "foot_f": v(23, 46), "knee_f": v(24, 39)}),
			pose({"foot_b": v(31, 46), "knee_b": v(28, 39), "foot_f": v(17, 46), "knee_f": v(20, 39)}),
			pose({"foot_b": v(28, 46), "knee_b": v(27, 39), "foot_f": v(21, 45), "knee_f": v(23, 39), "head": v(25, 14), "neck": v(24, 20)}),
			pose({"foot_b": v(23, 46), "knee_b": v(24, 39), "foot_f": v(27, 43), "knee_f": v(27, 37)}),
		]},
		{"name": "jump", "fps": 8, "loop": false, "frames": [
			pose({"head": v(25, 11), "neck": v(24, 17), "hip": v(24, 29),
				"foot_b": v(20, 41), "knee_b": v(18, 35), "foot_f": v(29, 39), "knee_f": v(31, 33),
				"hand_b": v(17, 15), "elbow_b": v(19, 21), "hand_f": v(32, 13), "elbow_f": v(30, 20)}),
		]},
		{"name": "dash", "fps": 12, "loop": true, "frames": [
			pose({"head": v(34, 18), "neck": v(30, 22), "hip": v(22, 32),
				"hand_b": v(15, 27), "elbow_b": null, "hand_f": v(37, 28), "elbow_f": null,
				"foot_b": v(10, 44), "knee_b": v(16, 38), "foot_f": v(27, 46), "knee_f": v(28, 39)}),
			pose({"head": v(34, 18), "neck": v(30, 22), "hip": v(22, 32),
				"hand_b": v(17, 29), "elbow_b": null, "hand_f": v(36, 26), "elbow_f": null,
				"foot_b": v(13, 45), "knee_b": v(18, 38), "foot_f": v(30, 45), "knee_f": v(30, 38)}),
		]},
		{"name": "guard", "fps": 8, "loop": false, "frames": [
			pose({"head": v(23, 15), "neck": v(23, 21), "hip": v(23, 32),
				"hand_f": v(29, 15), "elbow_f": v(31, 23), "hand_b": v(28, 20), "elbow_b": v(27, 26)}),
		]},
		{"name": "attack1", "fps": 12, "loop": false, "frames": [
			pose({"hand_f": v(27, 22), "elbow_f": v(22, 25)}),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_f": v(42, 21), "elbow_f": null}),
			pose({"hand_f": v(36, 22), "elbow_f": v(30, 24)}),
		]},
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_b": v(23, 24), "elbow_b": v(19, 26)}),
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31),
				"hand_b": v(43, 24), "elbow_b": null, "hand_f": v(26, 24), "elbow_f": v(22, 27)}),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_b": v(36, 25), "elbow_b": v(30, 26)}),
		]},
		{"name": "attack3", "fps": 12, "loop": false, "frames": [
			pose({"hip": v(23, 31), "foot_f": v(27, 40), "knee_f": v(31, 34)}),
			pose({"head": v(20, 14), "neck": v(21, 20), "hip": v(23, 31),
				"foot_f": v(43, 26), "knee_f": v(33, 29), "hand_f": v(24, 27), "hand_b": v(15, 24), "elbow_b": null}),
			pose({"head": v(20, 14), "neck": v(21, 20), "hip": v(23, 31),
				"foot_f": v(43, 27), "knee_f": v(33, 30), "hand_f": v(24, 27), "hand_b": v(15, 25), "elbow_b": null}),
			pose({"foot_f": v(32, 42), "knee_f": v(31, 36)}),
		]},
		{"name": "air_attack", "fps": 8, "loop": false, "frames": [
			pose({"head": v(22, 12), "neck": v(22, 18), "hip": v(24, 29),
				"foot_f": v(41, 38), "knee_f": v(33, 33), "foot_b": v(22, 39), "knee_b": v(18, 35),
				"hand_f": v(30, 22), "hand_b": v(15, 20), "elbow_b": null}),
		]},
		{"name": "special", "fps": 12, "loop": false, "frames": [
			pose({"hip": v(23, 31), "hand_f": v(21, 24), "elbow_f": v(25, 27), "hand_b": v(20, 27), "elbow_b": v(23, 29)}),
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(42, 21), "hand_b": v(42, 25), "elbow_f": null, "elbow_b": null}),
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(43, 21), "hand_b": v(43, 25), "elbow_f": null, "elbow_b": null}),
			pose({"hand_f": v(36, 22), "hand_b": v(35, 25)}),
		]},
		{"name": "cast", "fps": 8, "loop": false, "frames": [
			pose({"hand_f": v(30, 18), "elbow_f": v(27, 23)}),
			pose({"hand_f": v(37, 16), "elbow_f": v(30, 20), "hand_b": v(21, 29), "elbow_b": null}),
			pose({"hand_f": v(38, 15), "elbow_f": v(30, 19), "hand_b": v(21, 30), "elbow_b": null}),
		]},
		{"name": "burst", "fps": 8, "loop": false, "frames": [
			pose({"head": v(24, 12), "hand_b": v(10, 17), "hand_f": v(39, 17), "elbow_b": null, "elbow_f": null}),
		]},
		{"name": "hit", "fps": 10, "loop": false, "frames": [
			pose({"head": v(19, 14), "neck": v(21, 20), "hand_f": v(26, 27), "hand_b": v(14, 24), "elbow_b": null, "elbow_f": null}),
			pose({"head": v(20, 15), "neck": v(22, 20), "hand_f": v(27, 28), "hand_b": v(15, 25), "elbow_b": null, "elbow_f": null}),
		]},
		{"name": "launched", "fps": 8, "loop": true, "frames": [
			pose({"head": v(13, 23), "neck": v(18, 26), "hip": v(27, 30), "hand_b": v(10, 31), "hand_f": v(22, 35),
				"foot_f": v(40, 27), "knee_f": v(34, 29), "foot_b": v(39, 33), "knee_b": v(33, 33)}.merged(straight)),
			pose({"head": v(13, 24), "neck": v(18, 27), "hip": v(27, 30), "hand_b": v(9, 30), "hand_f": v(22, 36),
				"foot_f": v(40, 29), "knee_f": v(34, 30), "foot_b": v(39, 35), "knee_b": v(33, 34)}.merged(straight)),
		]},
		{"name": "down", "fps": 8, "loop": false, "frames": [
			pose({"head": v(9, 42), "neck": v(15, 43), "hip": v(28, 43), "hand_b": v(18, 46), "hand_f": v(23, 46),
				"foot_b": v(41, 46), "knee_b": null, "foot_f": v(42, 44), "knee_f": null}.merged(straight)),
		]},
		{"name": "getup", "fps": 8, "loop": false, "frames": [
			pose({"head": v(28, 22), "neck": v(26, 28), "hip": v(24, 37), "hand_f": v(31, 41), "hand_b": v(20, 41),
				"foot_b": v(18, 46), "knee_b": v(17, 40), "foot_f": v(31, 46), "knee_f": v(33, 40)}.merged(straight)),
			pose({"head": v(26, 17), "neck": v(25, 23), "hip": v(24, 33)}),
		]},
	]


func _generate(style: Dictionary) -> void:
	_style = style
	var animations := _animations()
	var columns := 0
	for animation: Dictionary in animations:
		columns = maxi(columns, animation.frames.size())
	_image = Image.create(CELL.x * columns, CELL.y * animations.size(), false, Image.FORMAT_RGBA8)

	var sheet_animations := {}
	for row in animations.size():
		var animation: Dictionary = animations[row]
		var rects: Array = []
		for column in animation.frames.size():
			_origin = Vector2i(column * CELL.x, row * CELL.y)
			_draw_figure(animation.frames[column])
			_draw_outline()
			rects.append([_origin.x, _origin.y, CELL.x, CELL.y])
		sheet_animations[animation.name] = {"fps": animation.fps, "loop": animation.loop, "frames": rects}

	var dir := "res://assets/characters/%s" % style.id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_image.save_png(ProjectSettings.globalize_path(dir.path_join("sheet.png")))
	var data := {"scale": 3.0, "foot_offset": 1, "animations": sheet_animations}
	var file := FileAccess.open(dir.path_join("sheet.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("generated %s: %dx%d, %d animations" % [dir, _image.get_width(), _image.get_height(), animations.size()])


# ---------- 繪圖 ----------

func _draw_figure(p: Dictionary) -> void:
	var shoulder: Vector2i = p.neck + Vector2i(0, 2)
	var sleeve: Color = _style.sleeve
	var pants: Color = _style.pants

	# 遠側的手腳先畫,顏色較暗
	_draw_limb(shoulder, p.get("elbow_b"), p.hand_b, sleeve.darkened(1.0 - BACK_SHADE), 3)
	_fill(p.hand_b + Vector2i(-1, -1), Vector2i(3, 3), SKIN.darkened(1.0 - BACK_SHADE))
	_draw_limb(p.hip + Vector2i(-1, 0), p.get("knee_b"), p.foot_b, pants.darkened(1.0 - BACK_SHADE), 3)
	_fill(p.foot_b + Vector2i(-1, -1), Vector2i(4, 2), SHOE)

	# 軀幹
	_draw_line(shoulder, p.hip, _style.top, 6)
	var sash: Color = _style.sash
	if sash.a > 0.0:
		_fill(p.hip + Vector2i(-3, -3), Vector2i(7, 2), sash)
	_fill(p.neck + Vector2i(-1, -1), Vector2i(3, 2), SKIN)

	_draw_head(p.head)

	# 近側的手腳
	_draw_limb(p.hip + Vector2i(1, 0), p.get("knee_f"), p.foot_f, pants, 3)
	_fill(p.foot_f + Vector2i(-1, -1), Vector2i(4, 2), SHOE)
	_draw_limb(shoulder, p.get("elbow_f"), p.hand_f, sleeve, 3)
	_fill(p.hand_f + Vector2i(-1, -1), Vector2i(3, 3), SKIN)


func _draw_head(center: Vector2i) -> void:
	var hair: Color = _style.hair
	# 臉:9x9,四個角削掉
	_fill(center + Vector2i(-4, -4), Vector2i(9, 9), SKIN)
	for corner: Vector2i in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		_clear(center + corner)
	# 頭髮:頭頂與後腦
	_fill(center + Vector2i(-4, -5), Vector2i(9, 4), hair)
	_fill(center + Vector2i(-5, -3), Vector2i(3, 6), hair)
	_clear(center + Vector2i(-4, -5))
	_clear(center + Vector2i(4, -5))
	if _style.spiky:
		for dx: int in [-3, -1, 1, 3]:
			_plot(center + Vector2i(dx, -6), hair)
		_plot(center + Vector2i(-5, -4), hair)

	if _style.blindfold:
		_fill(center + Vector2i(-4, -1), Vector2i(9, 2), Color(0.08, 0.08, 0.11))
	else:
		_plot(center + Vector2i(2, 0), Color(0.3, 0.05, 0.08))
		_plot(center + Vector2i(3, 0), Color(0.3, 0.05, 0.08))
	if _style.marks:
		var mark := Color(0.12, 0.1, 0.14)
		_plot(center + Vector2i(1, 2), mark)
		_plot(center + Vector2i(3, 2), mark)
		_plot(center + Vector2i(2, -2), mark)
	# 嘴
	_plot(center + Vector2i(3, 3), Color(0.55, 0.3, 0.3))


func _draw_limb(from: Vector2i, joint: Variant, to: Vector2i, color: Color, thickness: int) -> void:
	if joint == null:
		_draw_line(from, to, color, thickness)
	else:
		_draw_line(from, joint, color, thickness)
		_draw_line(joint, to, color, thickness)


func _draw_line(from: Vector2i, to: Vector2i, color: Color, thickness: int) -> void:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	var half := thickness / 2
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1)
		var point := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		_fill(point - Vector2i(half, half), Vector2i(thickness, thickness), color)


func _fill(top_left: Vector2i, rect_size: Vector2i, color: Color) -> void:
	for y in rect_size.y:
		for x in rect_size.x:
			_plot(top_left + Vector2i(x, y), color)


## 在目前格子內畫一個像素;超出格子的部分忽略。
func _plot(local: Vector2i, color: Color) -> void:
	if local.x < 1 or local.y < 1 or local.x >= CELL.x - 1 or local.y >= CELL.y - 1:
		return
	_image.set_pixelv(_origin + local, color)


func _clear(local: Vector2i) -> void:
	_plot(local, Color(0, 0, 0, 0))


## 替目前格子裡的圖形描一圈深色外框,讓角色在任何背景上都看得清楚。
func _draw_outline() -> void:
	var edge: Array[Vector2i] = []
	for y in CELL.y:
		for x in CELL.x:
			var local := Vector2i(x, y)
			if _image.get_pixelv(_origin + local).a > 0.0:
				continue
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor := local + offset
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= CELL.x or neighbor.y >= CELL.y:
					continue
				if _image.get_pixelv(_origin + neighbor).a > 0.0:
					edge.append(local)
					break
	for local in edge:
		_image.set_pixelv(_origin + local, OUTLINE)
