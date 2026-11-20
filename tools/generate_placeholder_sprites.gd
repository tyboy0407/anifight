extends SceneTree
## 用程式畫出臨時的點陣角色,輸出成 assets/characters/<id>/sheet.png 與 sheet.json。
## 找到正式素材後,直接用新的 sheet.png / sheet.json 取代即可。
##
## 執行方式(在專案資料夾):
##   godot --headless --path . --script tools/generate_placeholder_sprites.gd
##   godot --headless --path . --script tools/generate_placeholder_sprites.gd -- toji toji_dagger
## 第二種只重畫指定的角色,不會動到其他已經換成正式素材的角色。
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
	{
		"id": "yuta",
		"hair": Color(0.14, 0.14, 0.19), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.94, 0.94, 0.96), "sleeve": Color(0.94, 0.94, 0.96),
		"pants": Color(0.14, 0.15, 0.22), "sash": Color(0, 0, 0, 0),
		"sword": true,
	},
	{
		"id": "yuji",
		"hair": Color(0.98, 0.68, 0.6), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.14, 0.15, 0.26), "sleeve": Color(0.14, 0.15, 0.26),
		"pants": Color(0.12, 0.13, 0.22), "sash": Color(0, 0, 0, 0),
		"hood": Color(0.85, 0.16, 0.18),
	},
	{
		"id": "megumi",
		"hair": Color(0.1, 0.11, 0.17), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.15, 0.17, 0.3), "sleeve": Color(0.15, 0.17, 0.3),
		"pants": Color(0.12, 0.13, 0.23), "sash": Color(0, 0, 0, 0),
		"tall_hair": true,
	},
	{
		"id": "gojo_young",
		"hair": Color(0.96, 0.97, 1.0), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.16, 0.18, 0.32), "sleeve": Color(0.16, 0.18, 0.32),
		"pants": Color(0.13, 0.14, 0.24), "sash": Color(0, 0, 0, 0),
		"eye": Color(0.2, 0.62, 1.0),  # 六眼的蒼藍色,不戴眼罩也不戴墨鏡
	},
	# 伏黑甚爾:黑色緊身上衣、露出手臂、淺色寬褲、嘴角有疤。兩把武器各一套圖。
	{
		"id": "toji",
		"hair": Color(0.09, 0.09, 0.12), "spiky": false, "blindfold": false, "marks": false,
		"top": Color(0.1, 0.1, 0.13), "sleeve": Color(0.9, 0.76, 0.66),
		"pants": Color(0.84, 0.83, 0.79), "sash": Color(0, 0, 0, 0),
		"scar": true,
		# 狼牙刀:又長又寬的大砍刀
		"sword": true, "blade_length": 17, "blade_width": 4, "blade_color": Color(0.72, 0.76, 0.84),
	},
	{
		"id": "toji_dagger",
		"hair": Color(0.09, 0.09, 0.12), "spiky": false, "blindfold": false, "marks": false,
		"top": Color(0.1, 0.1, 0.13), "sleeve": Color(0.9, 0.76, 0.66),
		"pants": Color(0.84, 0.83, 0.79), "sash": Color(0, 0, 0, 0),
		"scar": true,
		# 天逆牟:短刀
		"sword": true, "blade_length": 7, "blade_width": 2, "blade_color": Color(0.96, 0.88, 0.55),
	},
	# 波風湊:金色刺蝟頭與兩側長鬢角、木葉護額、白色長袍(下襬是紅色火焰)披在綠色背心外、
	# 藍色的袖子與褲子,手上一把三叉苦無。有自己的出招動作(見 _minato_animations)。
	{
		"id": "minato",
		"hair": Color(0.99, 0.84, 0.24), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.95, 0.95, 0.93), "sleeve": Color(0.17, 0.25, 0.5),
		"pants": Color(0.15, 0.21, 0.44), "sash": Color(0, 0, 0, 0),
		"eye": Color(0.25, 0.55, 0.98),
		"headband": Color(0.17, 0.25, 0.5), "bangs": true,
		"vest": Color(0.32, 0.5, 0.33), "coat_hem": Color(0.88, 0.2, 0.16),
		"sword": true, "blade_length": 6, "blade_width": 2, "blade_color": Color(0.82, 0.87, 0.95),
		"guard_color": Color(0.6, 0.66, 0.78),
		"moves": "minato",
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
	# 只想重畫某幾個角色時,把 id 接在 -- 後面;不指定就全部重畫
	var only := OS.get_cmdline_user_args()
	for style: Dictionary in STYLES:
		if only.is_empty() or only.has(style.id):
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
		{"name": "idle", "fps": 6, "loop": true, "frames": [
			# 呼吸:身體微微下沉再回來,前手跟著上下晃
			pose(),
			pose({"head": v(25, 14), "neck": v(24, 20), "hand_b": v(28, 26), "hand_f": v(32, 24)}),
			pose({"head": v(25, 14), "neck": v(24, 20), "hand_b": v(28, 26), "hand_f": v(33, 24), "elbow_f": v(27, 28)}),
			pose({"hand_f": v(33, 22), "elbow_f": v(28, 27)}),
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
		{"name": "stunned", "fps": 5, "loop": true, "frames": [
			# 定身:雙手垂下,頭左右晃
			pose({"head": v(23, 15), "neck": v(23, 20), "hand_f": v(29, 31), "hand_b": v(21, 31)}.merged(straight)),
			pose({"head": v(26, 15), "neck": v(24, 20), "hand_f": v(30, 31), "hand_b": v(22, 31)}.merged(straight)),
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


## 波風湊專用的動作:同名的取代通用動作,其餘的加在後面。
## 姿勢裡的 "blade": false 代表這一格手上沒有苦無(丟出去了,或正在用螺旋丸)。
func _minato_animations() -> Array:
	var empty := {"blade": false}
	# 丟苦無的瞬間:人往後跳起,手臂往前甩直
	var throwing := {"head": v(23, 11), "neck": v(23, 17), "hip": v(23, 28),
		"foot_b": v(16, 40), "knee_b": v(18, 35), "foot_f": v(27, 41), "knee_f": v(29, 35),
		"hand_f": v(41, 19), "elbow_f": null, "hand_b": v(14, 21), "elbow_b": null}
	# 由上往下的一刀、由下往上的反手一刀:揮到底的那一格
	var cut_down := {"head": v(27, 13), "neck": v(26, 19), "hand_f": v(41, 24), "elbow_f": null}
	var cut_up := {"head": v(28, 13), "neck": v(27, 19), "hip": v(25, 31), "hand_f": v(41, 17), "elbow_f": null}
	return [
		{"name": "attack1", "fps": 12, "loop": false, "frames": [
			pose({"hand_f": v(30, 14), "elbow_f": v(26, 19)}),
			pose(cut_down),
			pose({"hand_f": v(35, 28), "elbow_f": v(30, 26)}),
		]},
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_f": v(26, 29), "elbow_f": v(23, 26)}),
			pose(cut_up),
			pose({"hand_f": v(37, 15), "elbow_f": v(31, 19)}),
		]},
		# 普攻第四段:往後轉身跳開,同時把苦無往前丟
		{"name": "attack4", "fps": 12, "loop": false, "frames": [
			pose({"head": v(22, 14), "neck": v(22, 20), "hip": v(23, 32), "hand_f": v(17, 22), "elbow_f": v(21, 25),
				"hand_b": v(27, 26), "foot_f": v(28, 45), "knee_f": v(29, 39), "foot_b": v(18, 46), "knee_b": v(19, 40)}),
			pose(throwing.merged(empty)),
			pose(throwing.merged(empty).merged({"hand_f": v(40, 22)})),
			pose({"head": v(25, 14), "neck": v(24, 20), "hip": v(24, 32), "hand_f": v(34, 25)}.merged(empty)),
		]},
		# 招式一:蹲低後往正上方踢
		{"name": "upkick", "fps": 12, "loop": false, "frames": [
			pose({"head": v(25, 15), "neck": v(24, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(21, 40)}),
			pose({"head": v(19, 15), "neck": v(20, 21), "hip": v(23, 31), "foot_f": v(36, 13), "knee_f": v(30, 23),
				"hand_f": v(25, 28), "elbow_f": null, "hand_b": v(14, 25), "elbow_b": null}),
			pose({"head": v(19, 15), "neck": v(20, 21), "hip": v(23, 31), "foot_f": v(36, 14), "knee_f": v(30, 24),
				"hand_f": v(25, 28), "elbow_f": null, "hand_b": v(14, 26), "elbow_b": null}),
			pose({"foot_f": v(33, 37), "knee_f": v(31, 31)}),
		]},
		# 以下都只有一格,由遊戲依招式的階段切換
		{"name": "throw", "fps": 8, "loop": false, "frames": [pose(throwing.merged(empty))]},
		{"name": "strike1", "fps": 8, "loop": false, "frames": [pose(cut_down)]},
		{"name": "strike2", "fps": 8, "loop": false, "frames": [pose(cut_up)]},
		# 螺旋丸:在腰側凝聚、往前推出、從上方往下砸
		{"name": "rasengan_charge", "fps": 8, "loop": false, "frames": [
			pose({"head": v(25, 14), "neck": v(24, 20), "hip": v(24, 32), "hand_f": v(30, 27), "elbow_f": v(25, 28),
				"hand_b": v(29, 23), "elbow_b": v(23, 25)}.merged(empty)),
		]},
		{"name": "rasengan_push", "fps": 8, "loop": false, "frames": [
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(42, 22), "elbow_f": null, "hand_b": v(20, 27), "elbow_b": v(22, 24)}.merged(empty)),
		]},
		{"name": "slam", "fps": 8, "loop": false, "frames": [
			pose({"head": v(29, 17), "neck": v(26, 21), "hip": v(20, 27), "hand_f": v(33, 33), "elbow_f": null,
				"hand_b": v(17, 16), "elbow_b": null, "knee_f": v(26, 31), "foot_f": v(20, 36),
				"knee_b": v(14, 30), "foot_b": v(10, 34)}.merged(empty)),
		]},
	]


## 這個角色實際要畫的動作:通用動作,加上(或換成)角色自己的。
func _animations_for(style: Dictionary) -> Array:
	var animations := _animations()
	if style.get("moves", "") != "minato":
		return animations
	for extra: Dictionary in _minato_animations():
		var replaced := false
		for index in animations.size():
			if animations[index].name == extra.name:
				animations[index] = extra
				replaced = true
		if not replaced:
			animations.append(extra)
	return animations


func _generate(style: Dictionary) -> void:
	_style = style
	var animations := _animations_for(style)
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

	# 軀幹:背側一條陰影、胸前一條受光,看起來才有厚度
	var top: Color = _style.top
	if _style.has("coat_hem"):
		_draw_coat_tail(shoulder, p.hip, top, _style.coat_hem)
	_draw_line(shoulder, p.hip, top, 6)
	_draw_line(shoulder + Vector2i(-3, 1), p.hip + Vector2i(-3, -1), top.darkened(0.3), 1)
	if _style.has("vest"):
		# 敞開的外袍底下露出的背心
		_draw_line(shoulder + Vector2i(1, 1), p.hip + Vector2i(1, -3), _style.vest, 2)
	else:
		_draw_line(shoulder + Vector2i(2, 1), p.hip + Vector2i(2, -3), top.lightened(0.16), 1)
	var sash: Color = _style.sash
	if sash.a > 0.0:
		_fill(p.hip + Vector2i(-3, -3), Vector2i(7, 2), sash)
	else:
		# 腰帶
		_fill(p.hip + Vector2i(-3, -2), Vector2i(7, 1), pants.darkened(0.35))
	_fill(p.neck + Vector2i(-1, -1), Vector2i(3, 2), SKIN)
	if _style.has("hood"):
		# 制服的連帽:披在肩膀與後頸
		_fill(p.neck + Vector2i(-5, 0), Vector2i(9, 3), _style.hood)
		_fill(p.neck + Vector2i(-6, -2), Vector2i(3, 4), _style.hood)

	_draw_head(p.head)

	# 近側的手腳
	_draw_limb(p.hip + Vector2i(1, 0), p.get("knee_f"), p.foot_f, pants, 3)
	_fill(p.foot_f + Vector2i(-1, -1), Vector2i(4, 2), SHOE)
	_plot(p.foot_f + Vector2i(1, -1), SHOE.lightened(0.3))  # 鞋尖的反光
	_draw_limb(shoulder, p.get("elbow_f"), p.hand_f, sleeve, 3)
	# 近側手臂下緣的陰影
	_draw_limb(shoulder + Vector2i(0, 1), _below(p.get("elbow_f")), p.hand_f + Vector2i(0, 1), sleeve.darkened(0.22), 1)
	if _style.get("sword", false) and p.get("blade", true):
		_draw_sword(p.get("elbow_f", shoulder), p.hand_f)
	_fill(p.hand_f + Vector2i(-1, -1), Vector2i(3, 3), SKIN)


## 長袍的下襬:從腰往下垂在身後,最底下是一圈火焰花紋。方向跟著軀幹走,
## 所以倒地時下襬是順著腿的方向攤開,不會插進地面。
func _draw_coat_tail(shoulder: Vector2i, hip: Vector2i, coat: Color, hem: Color) -> void:
	var along := Vector2(hip - shoulder)
	if along.length() < 0.5:
		along = Vector2.DOWN
	along = along.normalized()
	var behind := Vector2(-along.y, along.x)  # 站著的時候是往背後(左)
	var from := hip + Vector2i((behind * 2.0).round())
	var to := hip + Vector2i((along * 9.0 + behind * 4.0).round())
	_draw_line(from, to, coat.darkened(0.12), 4)
	var hem_from := hip + Vector2i((along * 8.0 + behind * 4.0).round())
	_draw_line(hem_from, to, hem, 4)
	# 火焰的尖端往上竄兩個像素
	_plot(hem_from + Vector2i((-along * 1.0 - behind * 1.0).round()), hem)
	_plot(hem_from + Vector2i((-along * 1.0 + behind * 1.0).round()), hem)


## 關節往下一個像素的位置;沒有這個關節(手臂打直)就回傳 null。
func _below(joint: Variant) -> Variant:
	if joint == null:
		return null
	return (joint as Vector2i) + Vector2i(0, 1)


## 刀:從近側的手沿著前臂方向往外延伸。
func _draw_sword(arm_from: Vector2i, hand: Vector2i) -> void:
	var direction := Vector2(hand - arm_from)
	if direction.length() < 0.5:
		direction = Vector2.RIGHT
	direction = direction.normalized()
	var tip := hand + Vector2i((direction * float(_style.get("blade_length", 13))).round())
	_draw_line(hand, tip, _style.get("blade_color", Color(0.86, 0.92, 0.98)), _style.get("blade_width", 2))
	# 護手
	var guard := Vector2i((direction.orthogonal() * 2.0).round())
	_draw_line(hand - guard, hand + guard, _style.get("guard_color", Color(0.5, 0.42, 0.2)), 1)


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
	# 頭髮的高光,以及下巴後側的陰影
	_fill(center + Vector2i(1, -4), Vector2i(2, 1), hair.lightened(0.14))
	_plot(center + Vector2i(-2, 2), SKIN.darkened(0.14))
	_plot(center + Vector2i(-2, 3), SKIN.darkened(0.14))
	if _style.spiky:
		for dx: int in [-3, -1, 1, 3]:
			_plot(center + Vector2i(dx, -6), hair)
		_plot(center + Vector2i(-5, -4), hair)
	if _style.get("tall_hair", false):
		# 往上、往後炸開的刺蝟頭
		for dx: int in [-4, -2, 0, 2, 4]:
			_fill(center + Vector2i(dx, -7), Vector2i(1, 2), hair)
		_plot(center + Vector2i(-3, -8), hair)
		_plot(center + Vector2i(1, -8), hair)
		_fill(center + Vector2i(-6, -5), Vector2i(2, 3), hair)
	if _style.get("bangs", false):
		# 垂到下巴的長鬢角,後腦的頭髮也比較長
		_fill(center + Vector2i(0, -1), Vector2i(1, 5), hair)
		_fill(center + Vector2i(-5, 3), Vector2i(2, 2), hair)
		_plot(center + Vector2i(-6, -2), hair)
	if _style.has("headband"):
		# 護額:額頭上一條布,正面一塊金屬片;瀏海蓋在它下緣
		_fill(center + Vector2i(-4, -3), Vector2i(9, 1), _style.headband)
		_fill(center + Vector2i(0, -3), Vector2i(4, 1), Color(0.78, 0.83, 0.9))

	if _style.blindfold:
		_fill(center + Vector2i(-4, -1), Vector2i(9, 2), Color(0.08, 0.08, 0.11))
	elif _style.has("eye"):
		# 指定顏色的大眼睛:2x2,上緣一點白色高光,上方一道深色眼線
		var eye: Color = _style.eye
		_fill(center + Vector2i(2, -1), Vector2i(2, 2), eye)
		_plot(center + Vector2i(3, -1), eye.lightened(0.6))
		_fill(center + Vector2i(1, -2), Vector2i(3, 1), Color(0.16, 0.18, 0.26))
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
	if _style.get("scar", false):
		# 嘴角往下的一道疤
		_plot(center + Vector2i(2, 2), Color(0.62, 0.36, 0.34))
		_plot(center + Vector2i(2, 3), Color(0.62, 0.36, 0.34))
		_plot(center + Vector2i(2, 4), Color(0.62, 0.36, 0.34))


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
