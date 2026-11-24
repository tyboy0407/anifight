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
	# 藍色的袖子與褲子,腰間收著三叉苦無(出招時才抽出來)。有自己的出招動作(見 _minato_animations)。
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
		"holstered": true,  # 苦無平常收在腰間,出招的那幾格才拿在手上
		"moves": "minato",
	},
	# 宇智波佐助:往後翹的黑髮、寫輪眼、敞開的淺色上衣、紫色腰繩、深色褲子,
	# 腰後橫插著一把草薙劍(平常收在鞘裡,出招時才拔出來)。有自己的出招動作(見 _sasuke_animations)。
	{
		"id": "sasuke",
		"hair": Color(0.1, 0.11, 0.18), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.84, 0.85, 0.91), "sleeve": Color(0.84, 0.85, 0.91),
		"pants": Color(0.17, 0.18, 0.3), "sash": Color(0.5, 0.35, 0.68),
		"eye": Color(0.93, 0.16, 0.16), "back_hair": true,
		"sword": true, "sheathed": true, "blade_length": 12, "blade_width": 2, "blade_color": Color(0.85, 0.9, 0.98),
		"guard_color": Color(0.2, 0.2, 0.27),
		"moves": "sasuke",
	},
	# 五條悟(澀谷事變):和平常一樣的黑色高領制服與眼罩,但平常雙手插在口袋裡;
	# 開領域時把眼罩拉到脖子上、露出六眼。有自己的出招動作(見 _gojo_shibuya_animations)。
	{
		"id": "gojo_shibuya",
		"hair": Color(0.96, 0.97, 1.0), "spiky": true, "blindfold": true, "marks": false,
		"top": Color(0.12, 0.13, 0.23), "sleeve": Color(0.12, 0.13, 0.23),
		"pants": Color(0.1, 0.11, 0.19), "sash": Color(0, 0, 0, 0),
		"eye": Color(0.2, 0.62, 1.0), "collar": true,
		"moves": "gojo_shibuya",
	},
	# 金木研:凌亂的白髮、黑色戰鬥服、遮住下半張臉的黑色面具(一排拉鍊似的牙齒),露出來的那隻眼是紅色的赫眼。
	# 背後的赫子尾巴不在圖裡,由遊戲另外畫(scripts/kagune_tails.gd)。有自己的出招動作(見 _kaneki_animations)。
	{
		"id": "kaneki",
		"hair": Color(0.93, 0.93, 0.96), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.17, 0.17, 0.22), "sleeve": Color(0.17, 0.17, 0.22),
		"pants": Color(0.14, 0.14, 0.18), "sash": Color(0, 0, 0, 0),
		"eye": Color(0.92, 0.1, 0.14), "mask": true, "collar": true,
		"moves": "kaneki",
	},
	# 卡卡西:往上翹的銀髮、木葉護額、遮住下半張臉的深藍面罩、綠色背心、深藍衣褲。有自己的出招動作(見 _kakashi_animations)。
	# 平常那一套圖眼睛是黑的;開寫輪眼時換成另一套(kakashi_sharingan):露出紅色的寫輪眼。
	{
		"id": "kakashi",
		"hair": Color(0.83, 0.85, 0.91), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.37, 0.48, 0.36), "sleeve": Color(0.17, 0.21, 0.38),
		"pants": Color(0.15, 0.19, 0.34), "sash": Color(0, 0, 0, 0),
		"headband": Color(0.17, 0.21, 0.38), "face_mask": Color(0.13, 0.16, 0.29), "tall_hair": true,
		"moves": "kakashi",
	},
	{
		"id": "kakashi_sharingan",
		"hair": Color(0.83, 0.85, 0.91), "spiky": true, "blindfold": false, "marks": false,
		"top": Color(0.37, 0.48, 0.36), "sleeve": Color(0.17, 0.21, 0.38),
		"pants": Color(0.15, 0.19, 0.34), "sash": Color(0, 0, 0, 0),
		"headband": Color(0.17, 0.21, 0.38), "face_mask": Color(0.13, 0.16, 0.29), "tall_hair": true,
		"eye": Color(0.95, 0.12, 0.14),
		"moves": "kakashi",
	},
	# 低級咒靈(只在故事模式出現的對手):灰紫色的皮膚、光禿禿的頭上兩支角、一隻黃色的大眼、裂到耳邊的嘴。
	{
		"id": "curse",
		"skin": Color(0.58, 0.48, 0.68),
		"hair": Color(0.46, 0.37, 0.57), "spiky": false, "blindfold": false, "marks": false,
		"top": Color(0.42, 0.34, 0.53), "sleeve": Color(0.52, 0.43, 0.62),
		"pants": Color(0.34, 0.28, 0.45), "sash": Color(0, 0, 0, 0),
		"eye": Color(0.98, 0.85, 0.25), "maw": true, "horns": Color(0.88, 0.85, 0.76),
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
var _unmasked := false  # 正在畫的這一格:眼罩是不是拉下來了


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
## 他的苦無平常收在腰間,姿勢裡寫了 "blade": true 的那一格才拿在手上;
## "blade_b": true 是另一隻手也拿一把(第五段的雙苦無)。
func _minato_animations() -> Array:
	var empty := {"blade": false}
	var drawn := {"blade": true}
	var both := {"blade": true, "blade_b": true}
	# 丟苦無的瞬間:人往後跳起,手臂往前甩直
	var throwing := {"head": v(23, 11), "neck": v(23, 17), "hip": v(23, 28),
		"foot_b": v(16, 40), "knee_b": v(18, 35), "foot_f": v(27, 41), "knee_f": v(29, 35),
		"hand_f": v(41, 19), "elbow_f": null, "hand_b": v(14, 21), "elbow_b": null}
	# 由上往下的一刀、由下往上的反手一刀:揮到底的那一格
	var cut_down := {"head": v(27, 13), "neck": v(26, 19), "hand_f": v(41, 24), "elbow_f": null, "blade": true}
	var cut_up := {"head": v(28, 13), "neck": v(27, 19), "hip": v(25, 31), "hand_f": v(41, 17), "elbow_f": null, "blade": true}
	# 迴旋踢踢到底:身體往後仰,腿橫著掃出去
	var roundhouse := {"head": v(18, 15), "neck": v(20, 21), "hip": v(23, 30), "foot_f": v(43, 24), "knee_f": v(33, 27),
		"hand_f": v(14, 27), "elbow_f": null, "hand_b": v(26, 26), "blade": true}
	return [
		# 第一段:手伸到腰間抽出苦無,由上往下揮
		{"name": "attack1", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_f": v(24, 30), "elbow_f": v(28, 27)}),
			pose(cut_down),
			pose({"hand_f": v(35, 28), "elbow_f": v(30, 26)}.merged(drawn)),
		]},
		# 第二段:反手由下往上揮
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_f": v(26, 29), "elbow_f": v(23, 26)}.merged(drawn)),
			pose(cut_up),
			pose({"hand_f": v(37, 15), "elbow_f": v(31, 19)}.merged(drawn)),
		]},
		# 第三段:轉過身去,迴旋踢掃向對手
		{"name": "attack3", "fps": 12, "loop": false, "frames": [
			pose({"head": v(23, 13), "neck": v(23, 19), "hand_f": v(19, 24), "elbow_f": v(24, 26), "hand_b": v(27, 24),
				"foot_f": v(25, 45), "knee_f": v(26, 39), "foot_b": v(21, 46), "knee_b": v(22, 39)}.merged(drawn)),
			pose(roundhouse),
			pose(roundhouse.merged({"foot_f": v(43, 25), "knee_f": v(33, 28)})),
			pose({"foot_f": v(33, 41), "knee_f": v(32, 35), "hand_f": v(28, 26)}.merged(drawn)),
		]},
		# 第四段:往後轉身跳開,同時把苦無往前丟
		{"name": "attack4", "fps": 12, "loop": false, "frames": [
			pose({"head": v(22, 14), "neck": v(22, 20), "hip": v(23, 32), "hand_f": v(17, 22), "elbow_f": v(21, 25),
				"hand_b": v(27, 26), "foot_f": v(28, 45), "knee_f": v(29, 39), "foot_b": v(18, 46), "knee_b": v(19, 40)}.merged(drawn)),
			pose(throwing.merged(empty)),
			pose(throwing.merged(empty).merged({"hand_f": v(40, 22)})),
			pose({"head": v(25, 14), "neck": v(24, 20), "hip": v(24, 32), "hand_f": v(34, 25)}.merged(empty)),
		]},
		# 第四段按住後退:往後跳開時把苦無往腳邊的地面甩下去
		{"name": "plant", "fps": 12, "loop": false, "frames": [
			pose(throwing.merged(empty).merged({"hand_f": v(37, 31), "elbow_f": v(31, 25)})),
			pose(throwing.merged(empty).merged({"hand_f": v(36, 32), "elbow_f": v(31, 26)})),
			pose({"head": v(25, 14), "neck": v(24, 20), "hip": v(24, 32), "hand_f": v(33, 28)}.merged(empty)),
		]},
		# 瞬身到地上的苦無旁:蹲下去撿起來、壓低身體往前滑著砍、收勢
		{"name": "slide", "fps": 14, "loop": false, "frames": [
			pose({"head": v(28, 24), "neck": v(26, 29), "hip": v(22, 36), "foot_f": v(31, 46), "knee_f": v(32, 41),
				"foot_b": v(14, 46), "knee_b": v(17, 41), "hand_f": v(34, 42), "elbow_f": v(30, 36),
				"hand_b": v(17, 33), "elbow_b": null}.merged(drawn)),
			pose({"head": v(32, 23), "neck": v(29, 27), "hip": v(21, 35), "foot_f": v(35, 46), "knee_f": v(31, 40),
				"foot_b": v(7, 45), "knee_b": v(14, 41), "hand_f": v(44, 28), "elbow_f": null,
				"hand_b": v(14, 31), "elbow_b": null}.merged(drawn)),
			pose({"head": v(32, 23), "neck": v(29, 27), "hip": v(21, 35), "foot_f": v(35, 46), "knee_f": v(31, 40),
				"foot_b": v(8, 45), "knee_b": v(14, 41), "hand_f": v(44, 29), "elbow_f": null,
				"hand_b": v(14, 32), "elbow_b": null}.merged(drawn)),
			pose({"head": v(32, 23), "neck": v(29, 27), "hip": v(21, 35), "foot_f": v(35, 46), "knee_f": v(31, 40),
				"foot_b": v(8, 45), "knee_b": v(14, 41), "hand_f": v(43, 24), "elbow_f": v(37, 28),
				"hand_b": v(14, 32), "elbow_b": null}.merged(drawn)),
			pose({"head": v(28, 17), "neck": v(26, 23), "hip": v(23, 33), "hand_f": v(37, 22), "elbow_f": v(31, 25)}.merged(drawn)),
		]},
		# 第五段:雙手各一把苦無交叉在胸前、往外斬開、收勢
		{"name": "attack5", "fps": 12, "loop": false, "frames": [
			pose({"head": v(26, 15), "neck": v(25, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(21, 40),
				"hand_f": v(22, 22), "elbow_f": v(28, 26), "hand_b": v(30, 22), "elbow_b": v(23, 26)}.merged(both)),
			pose({"head": v(28, 13), "neck": v(27, 19), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(41, 28), "elbow_f": null, "hand_b": v(40, 13), "elbow_b": null}.merged(both)),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_f": v(37, 32), "elbow_f": v(31, 28),
				"hand_b": v(36, 11), "elbow_b": v(30, 16)}.merged(both)),
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


## 宇智波佐助專用的動作:同名的取代通用動作,其餘的加在後面。
## 他的劍平常收在鞘裡,姿勢裡寫了 "blade": true 的那一格才拿在手上。
func _sasuke_animations() -> Array:
	var drawn := {"blade": true}
	# 高高往上踢的那一腳(千鳥雷槍的起手)
	var kick_up := {"head": v(19, 15), "neck": v(20, 21), "hip": v(23, 31), "foot_f": v(36, 13), "knee_f": v(30, 23),
		"hand_f": v(25, 28), "elbow_f": null, "hand_b": v(14, 25), "elbow_b": null}
	# 往後跳到空中,後手往斜下方甩出苦無,劍收在身側
	var air_throw := {"head": v(22, 11), "neck": v(22, 17), "hip": v(23, 28),
		"foot_b": v(17, 40), "knee_b": v(18, 35), "foot_f": v(28, 40), "knee_f": v(29, 34),
		"hand_b": v(36, 29), "elbow_b": null, "hand_f": v(15, 21), "elbow_f": v(19, 20)}
	return [
		# 第一段:手按劍柄,拔刀往前揮
		{"name": "attack1", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_f": v(23, 29), "elbow_f": v(28, 27)}),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_f": v(41, 22), "elbow_f": null}.merged(drawn)),
			pose({"hand_f": v(38, 27), "elbow_f": v(31, 25)}.merged(drawn)),
		]},
		# 第二段:往前踢,劍收在身後
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose({"hip": v(23, 31), "foot_f": v(27, 40), "knee_f": v(31, 34), "hand_f": v(18, 27), "elbow_f": v(21, 23)}.merged(drawn)),
			pose({"head": v(20, 14), "neck": v(21, 20), "hip": v(23, 31), "foot_f": v(43, 26), "knee_f": v(33, 29),
				"hand_f": v(16, 28), "elbow_f": v(20, 24), "hand_b": v(26, 24)}.merged(drawn)),
			pose({"foot_f": v(32, 42), "knee_f": v(31, 36), "hand_f": v(20, 28), "elbow_f": v(22, 24)}.merged(drawn)),
		]},
		# 第三段:轉過身,劍從背後橫著掃到身前
		{"name": "attack3", "fps": 12, "loop": false, "frames": [
			pose({"head": v(23, 13), "neck": v(23, 19), "hand_f": v(13, 21), "elbow_f": v(19, 22), "hand_b": v(26, 25)}.merged(drawn)),
			pose({"head": v(28, 13), "neck": v(27, 19), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(42, 24), "elbow_f": null}.merged(drawn)),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_f": v(39, 29), "elbow_f": v(32, 26)}.merged(drawn)),
		]},
		# 第四段:蹲低,由下往上挑
		{"name": "attack4", "fps": 12, "loop": false, "frames": [
			pose({"head": v(26, 15), "neck": v(25, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(21, 40),
				"hand_f": v(31, 37), "elbow_f": v(27, 32)}.merged(drawn)),
			pose({"head": v(27, 12), "neck": v(26, 18), "hip": v(25, 30), "hand_f": v(36, 10), "elbow_f": null}.merged(drawn)),
			pose({"head": v(26, 12), "neck": v(25, 18), "hip": v(24, 30), "hand_f": v(33, 9), "elbow_f": v(31, 15)}.merged(drawn)),
		]},
		# 第五段:往後跳、在空中往斜下方丟苦無、落地、收刀
		{"name": "attack5", "fps": 12, "loop": false, "frames": [
			pose({"head": v(23, 15), "neck": v(23, 21), "hip": v(23, 33), "knee_f": v(29, 40), "knee_b": v(20, 40),
				"hand_f": v(27, 30), "elbow_f": v(25, 27)}.merged(drawn)),
			pose(air_throw.merged(drawn)),
			pose(air_throw.merged(drawn).merged({"hand_b": v(35, 31)})),
			pose({"head": v(25, 15), "neck": v(24, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(20, 40),
				"hand_f": v(28, 29), "elbow_f": v(26, 26)}.merged(drawn)),
			pose({"hand_f": v(23, 29), "elbow_f": v(28, 27), "hand_b": v(21, 30), "elbow_b": v(20, 26)}),
		]},
		# 第六段:壓低身體手按劍柄、拔刀衝過去、停在對手身後、收刀、站直
		{"name": "attack6", "fps": 12, "loop": false, "frames": [
			pose({"head": v(26, 16), "neck": v(25, 21), "hip": v(23, 33), "knee_f": v(29, 40), "knee_b": v(20, 40),
				"hand_f": v(23, 30), "elbow_f": v(28, 28)}),
			pose({"head": v(33, 18), "neck": v(30, 22), "hip": v(23, 32), "hand_b": v(16, 27), "elbow_b": null,
				"hand_f": v(43, 25), "elbow_f": null, "foot_b": v(10, 44), "knee_b": v(16, 38), "foot_f": v(27, 46), "knee_f": v(28, 39)}.merged(drawn)),
			pose({"head": v(26, 14), "neck": v(25, 20), "hand_f": v(38, 32), "elbow_f": v(31, 28)}.merged(drawn)),
			pose({"hand_f": v(24, 29), "elbow_f": v(29, 27), "hand_b": v(21, 30), "elbow_b": v(20, 26)}),
			pose({"hand_f": v(26, 27), "elbow_f": v(28, 26)}),
		]},
		# 麒麟的起手:一拳把對手打飛
		{"name": "punch", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_b": v(23, 24), "elbow_b": v(19, 26)}),
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31),
				"hand_b": v(43, 23), "elbow_b": null, "hand_f": v(26, 24), "elbow_f": v(22, 27)}),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_b": v(36, 25), "elbow_b": v(30, 26)}),
		]},
		# 千鳥雷槍的起手:蹲低後往正上方踢
		{"name": "spear_kick", "fps": 12, "loop": false, "frames": [
			pose({"head": v(25, 15), "neck": v(24, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(21, 40)}),
			pose(kick_up),
			pose(kick_up.merged({"foot_f": v(36, 14), "knee_f": v(30, 24)})),
		]},
		# 以下都只有一格,由遊戲依招式的階段切換
		# 千鳥:壓低身體,一手握住另一手的手腕,雷電聚在朝下的手掌
		{"name": "chidori_charge", "fps": 8, "loop": false, "frames": [
			pose({"head": v(27, 16), "neck": v(25, 21), "hip": v(23, 33), "knee_f": v(29, 40), "knee_b": v(20, 40),
				"hand_f": v(31, 37), "elbow_f": null, "hand_b": v(29, 31), "elbow_b": v(24, 28)}),
		]},
		# 千鳥:壓低身體往前衝,手往前推
		{"name": "chidori_rush", "fps": 8, "loop": false, "frames": [
			pose({"head": v(34, 18), "neck": v(30, 22), "hip": v(22, 32), "hand_b": v(15, 27), "elbow_b": null,
				"hand_f": v(43, 24), "elbow_f": null, "foot_b": v(10, 44), "knee_b": v(16, 38), "foot_f": v(27, 46), "knee_f": v(28, 39)}),
		]},
		# 千鳥雷槍:手指向斜上方
		{"name": "spear", "fps": 8, "loop": false, "frames": [
			pose({"head": v(24, 13), "neck": v(24, 19), "hand_f": v(36, 10), "elbow_f": null, "hand_b": v(22, 28), "elbow_b": v(20, 24)}),
		]},
		# 手往正前方伸直:麒麟的雷槍、蛇咬
		{"name": "reach", "fps": 8, "loop": false, "frames": [
			pose({"head": v(27, 14), "neck": v(26, 20), "hand_f": v(42, 21), "elbow_f": null, "hand_b": v(21, 27), "elbow_b": v(20, 24)}),
		]},
		# 蛇咬拉近之後的那一刀:橫掃到底
		{"name": "slash_pose", "fps": 8, "loop": false, "frames": [
			pose({"head": v(28, 13), "neck": v(27, 19), "hip": v(25, 31), "foot_b": v(15, 46), "knee_b": v(19, 39),
				"hand_f": v(42, 24), "elbow_f": null}.merged(drawn)),
		]},
		# 豪火球:身體前傾,手在嘴邊結印
		{"name": "fire", "fps": 8, "loop": false, "frames": [
			pose({"head": v(28, 14), "neck": v(26, 20), "hip": v(24, 31), "hand_f": v(32, 18), "elbow_f": v(29, 23),
				"hand_b": v(30, 19), "elbow_b": v(26, 24)}),
		]},
		# 麒麟:一手高舉指向天空;雷落下時把手揮下來
		{"name": "kirin", "fps": 8, "loop": false, "frames": [
			pose({"head": v(24, 13), "neck": v(24, 19), "hand_f": v(27, 4), "elbow_f": null, "hand_b": v(21, 28), "elbow_b": v(20, 24)}),
		]},
		{"name": "kirin_down", "fps": 8, "loop": false, "frames": [
			pose({"head": v(27, 14), "neck": v(26, 20), "hand_f": v(40, 27), "elbow_f": null, "hand_b": v(20, 27), "elbow_b": v(19, 23)}),
		]},
	]


## 五條悟(澀谷事變)專用的動作:同名的取代通用動作,其餘的加在後面。
## 姿勢裡的 "pocket_f" / "pocket_b" 是那隻手插在口袋裡(不畫手掌);
## "unmasked" 是眼罩拉下來、露出六眼的樣子(開領域之後的那幾個動作)。
func _gojo_shibuya_animations() -> Array:
	var eyes := {"unmasked": true}
	# 站得直挺挺的,雙手插在口袋裡
	var relaxed := {"head": v(25, 12), "neck": v(24, 18), "hip": v(24, 31),
		"hand_f": v(26, 31), "elbow_f": v(29, 25), "hand_b": v(21, 31), "elbow_b": v(19, 25),
		"foot_b": v(21, 46), "knee_b": v(22, 39), "foot_f": v(28, 46), "knee_f": v(27, 39),
		"pocket_f": true, "pocket_b": true}
	# 只有後面那隻手插在口袋裡(前手出招)
	var back_pocket := {"hand_b": v(21, 31), "elbow_b": v(19, 25), "pocket_b": true}
	# 連打:前手、後手各打出去的那一格,以及兩拳之間收在胸前的那一格
	var jab_f := {"head": v(27, 13), "neck": v(26, 19), "hand_f": v(42, 21), "elbow_f": null,
		"hand_b": v(27, 24), "elbow_b": v(22, 26)}
	var jab_b := {"head": v(28, 14), "neck": v(27, 20), "hip": v(25, 31), "hand_b": v(42, 24), "elbow_b": null,
		"hand_f": v(27, 23), "elbow_f": v(23, 26)}
	var tucked := {"head": v(26, 13), "neck": v(25, 19), "hand_f": v(31, 22), "elbow_f": v(26, 25),
		"hand_b": v(30, 24), "elbow_b": v(23, 26)}
	# 側踢踢到底:身體往後仰,手還插在口袋裡
	var side_kick := {"head": v(18, 15), "neck": v(20, 21), "hip": v(23, 31), "foot_f": v(43, 25), "knee_f": v(33, 28),
		"hand_f": v(25, 31), "elbow_f": v(26, 26), "hand_b": v(20, 32), "elbow_b": v(16, 27),
		"pocket_f": true, "pocket_b": true}
	# 重拳打到底:整個人往前踏出去
	var heavy := {"head": v(30, 14), "neck": v(28, 20), "hip": v(25, 31), "foot_b": v(14, 46), "knee_b": v(19, 39),
		"hand_f": v(44, 20), "elbow_f": null, "hand_b": v(23, 31), "elbow_b": v(22, 26), "pocket_b": true}
	# 走路:腳照常走,手一樣插在口袋裡
	var steps := [
		{"foot_b": v(17, 46), "knee_b": v(20, 39), "foot_f": v(31, 46), "knee_f": v(28, 39)},
		{"foot_b": v(21, 45), "knee_b": v(23, 39), "foot_f": v(28, 46), "knee_f": v(27, 39), "head": v(25, 13), "neck": v(24, 19)},
		{"foot_b": v(27, 43), "knee_b": v(27, 37), "foot_f": v(23, 46), "knee_f": v(24, 39)},
		{"foot_b": v(31, 46), "knee_b": v(28, 39), "foot_f": v(17, 46), "knee_f": v(20, 39)},
		{"foot_b": v(28, 46), "knee_b": v(27, 39), "foot_f": v(21, 45), "knee_f": v(23, 39), "head": v(25, 13), "neck": v(24, 19)},
		{"foot_b": v(23, 46), "knee_b": v(24, 39), "foot_f": v(27, 43), "knee_f": v(27, 37)},
	]
	var walk: Array = []
	for step: Dictionary in steps:
		walk.append(pose(relaxed.merged(step, true)))
	return [
		{"name": "idle", "fps": 5, "loop": true, "frames": [
			pose(relaxed),
			pose(relaxed.merged({"head": v(25, 13), "neck": v(24, 19)}, true)),
			pose(relaxed.merged({"head": v(25, 13), "neck": v(24, 19), "elbow_f": v(29, 26), "elbow_b": v(19, 26)}, true)),
			pose(relaxed),
		]},
		{"name": "walk", "fps": 10, "loop": true, "frames": walk},
		# 第一段:左右開弓連打四拳(四拳打出去的那幾格對上四次命中)
		{"name": "attack1", "fps": 14, "loop": false, "frames": [
			pose(jab_f), pose(tucked), pose(jab_b), pose(jab_f), pose(jab_b), pose(tucked),
			pose({"hand_f": v(33, 23), "elbow_f": v(28, 26)}), pose(relaxed),
		]},
		# 瞬身過去的第一段:先以插口袋的樣子出現在對手面前,再開始連打
		{"name": "blink_flurry", "fps": 14, "loop": false, "frames": [
			pose(relaxed), pose(tucked), pose(jab_f), pose(jab_b), pose(tucked), pose(jab_f), pose(jab_b), pose(tucked),
			pose({"hand_f": v(33, 23), "elbow_f": v(28, 26)}), pose(relaxed),
		]},
		# 第二段:手插在口袋裡,一腳側踢把人踢出去
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose(relaxed.merged({"head": v(22, 12), "neck": v(22, 18), "hip": v(23, 31), "foot_f": v(28, 40), "knee_f": v(32, 34)}, true)),
			pose(side_kick),
			pose(side_kick.merged({"foot_f": v(43, 26), "knee_f": v(33, 29)}, true)),
			pose(relaxed.merged({"head": v(22, 12), "neck": v(22, 18), "foot_f": v(33, 41), "knee_f": v(32, 35)}, true)),
			pose(relaxed),
		]},
		# 第三段:抬起前手、掌心朝前,用「蒼」把人吸過來;另一隻手還在口袋裡
		{"name": "attack3", "fps": 8, "loop": false, "frames": [
			pose(relaxed.merged({"hand_f": v(33, 20), "elbow_f": v(29, 24), "pocket_f": false}, true)),
			pose(relaxed.merged({"hand_f": v(41, 18), "elbow_f": null, "pocket_f": false}, true)),
			pose(relaxed.merged({"hand_f": v(40, 19), "elbow_f": v(33, 22), "pocket_f": false}, true)),
		]},
		# 第四段:手往後拉滿、整個人踏出去的單手重拳
		{"name": "attack4", "fps": 9, "loop": false, "frames": [
			pose({"head": v(23, 13), "neck": v(23, 19), "hand_f": v(17, 22), "elbow_f": v(21, 26)}.merged(back_pocket, true)),
			pose(heavy),
			pose(heavy.merged({"hand_f": v(44, 21)}, true)),
			pose({"head": v(28, 13), "neck": v(27, 19), "hand_f": v(38, 22), "elbow_f": v(32, 24)}.merged(back_pocket, true)),
			pose(relaxed),
		]},
		# 以下都只有一格,由遊戲依招式的階段切換
		# 蒼迫:浮在對手上方,前手掌心往下壓
		{"name": "press", "fps": 8, "loop": false, "frames": [
			pose({"head": v(26, 14), "neck": v(24, 19), "hip": v(22, 29), "hand_f": v(33, 33), "elbow_f": null,
				"hand_b": v(15, 22), "elbow_b": null, "knee_f": v(28, 35), "foot_f": v(24, 41),
				"knee_b": v(18, 34), "foot_b": v(14, 39)}),
		]},
		# 塵殺:壓低身體起手、往前衝的那一下
		{"name": "dust_ready", "fps": 8, "loop": false, "frames": [
			pose({"head": v(27, 17), "neck": v(25, 23), "hip": v(23, 34), "knee_f": v(30, 40), "knee_b": v(19, 41),
				"hand_f": v(26, 34), "elbow_f": v(29, 29), "hand_b": v(20, 34), "elbow_b": v(18, 29),
				"pocket_f": true, "pocket_b": true}),
		]},
		{"name": "dust", "fps": 8, "loop": false, "frames": [
			pose({"head": v(34, 18), "neck": v(30, 22), "hip": v(22, 32), "hand_b": v(15, 27), "elbow_b": null,
				"hand_f": v(42, 24), "elbow_f": null, "foot_b": v(10, 44), "knee_b": v(16, 38),
				"foot_f": v(27, 46), "knee_f": v(28, 39)}),
		]},
		# 領域展開:眼罩拉下來,前手在面前結印
		{"name": "domain", "fps": 8, "loop": false, "frames": [
			pose(relaxed.merged({"hand_f": v(32, 15), "elbow_f": v(33, 22), "pocket_f": false}, true).merged(eyes)),
		]},
		# 領域之後的連打、把人抓起來、扔出去
		{"name": "jab1", "fps": 8, "loop": false, "frames": [pose(jab_f.merged(eyes))]},
		{"name": "jab2", "fps": 8, "loop": false, "frames": [pose(jab_b.merged(eyes))]},
		{"name": "grab", "fps": 8, "loop": false, "frames": [
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_f": v(42, 13), "elbow_f": null}.merged(back_pocket, true).merged(eyes)),
		]},
		{"name": "toss", "fps": 8, "loop": false, "frames": [
			pose({"head": v(31, 15), "neck": v(29, 20), "hip": v(25, 31), "foot_b": v(14, 46), "knee_b": v(19, 39),
				"hand_f": v(42, 28), "elbow_f": null, "hand_b": v(17, 24), "elbow_b": null}.merged(eyes)),
		]},
	]


## 金木研專用的動作:同名的取代通用動作,其餘的加在後面。
## 尾巴由遊戲另外畫,這裡只畫身體:尾巴出擊的那幾個動作是壓低身體、雙手往後甩。
func _kaneki_animations() -> Array:
	# 微微駝背的站姿,前手抬在臉旁
	var stance := {"head": v(26, 14), "neck": v(24, 20), "hand_f": v(31, 22), "elbow_f": v(28, 27),
		"hand_b": v(26, 28), "elbow_b": v(21, 28)}
	# 尾巴出擊:身體往前壓,雙手往後甩開
	var lunge := {"head": v(30, 16), "neck": v(27, 21), "hip": v(23, 32), "hand_f": v(22, 30), "elbow_f": null,
		"hand_b": v(16, 27), "elbow_b": null, "foot_b": v(16, 46), "knee_b": v(19, 39)}
	var front_kick := {"head": v(20, 14), "neck": v(21, 20), "hip": v(23, 31), "foot_f": v(43, 27), "knee_f": v(33, 30),
		"hand_f": v(24, 27), "hand_b": v(15, 24), "elbow_b": null}
	# 往後跳開:雙腳離地縮起來
	var hop := {"head": v(23, 12), "neck": v(23, 18), "hip": v(23, 29), "foot_b": v(16, 41), "knee_b": v(18, 35),
		"foot_f": v(28, 42), "knee_f": v(29, 36), "hand_f": v(33, 22), "elbow_f": v(28, 25), "hand_b": v(17, 24), "elbow_b": null}
	var crouch := {"head": v(25, 15), "neck": v(24, 21), "hip": v(24, 33), "knee_f": v(29, 40), "knee_b": v(21, 40)}
	# 四條尾巴一起刺出去:整個人壓得更低
	var pierce := {"head": v(31, 18), "neck": v(28, 23), "hip": v(22, 33), "hand_f": v(20, 31), "elbow_f": null,
		"hand_b": v(14, 27), "elbow_b": null, "foot_b": v(13, 46), "knee_b": v(17, 40), "foot_f": v(31, 46), "knee_f": v(30, 40)}
	# 撲過去:身體打斜,雙手往前抓
	var pounce := {"head": v(33, 17), "neck": v(29, 21), "hip": v(20, 28), "hand_f": v(41, 25), "elbow_f": null,
		"hand_b": v(38, 29), "elbow_b": null, "foot_b": v(8, 36), "knee_b": v(13, 31), "foot_f": v(13, 40), "knee_f": v(19, 35)}
	# 抓住對手的肩膀咬下去
	var bite := {"head": v(33, 15), "neck": v(29, 20), "hip": v(24, 32), "hand_f": v(39, 22), "elbow_f": v(33, 25),
		"hand_b": v(38, 26), "elbow_b": v(31, 28), "foot_b": v(15, 46), "knee_b": v(19, 39)}
	return [
		{"name": "idle", "fps": 6, "loop": true, "frames": [
			pose(stance),
			pose(stance.merged({"head": v(26, 15), "neck": v(24, 21), "hand_f": v(31, 23)}, true)),
			pose(stance.merged({"head": v(26, 15), "neck": v(24, 21), "hand_f": v(32, 23), "hand_b": v(26, 29)}, true)),
			pose(stance.merged({"hand_f": v(32, 21)}, true)),
		]},
		# 第二段:尾巴追擊
		{"name": "attack2", "fps": 12, "loop": false, "frames": [
			pose(crouch),
			pose(lunge),
			pose(lunge.merged({"head": v(30, 17), "hand_b": v(16, 28)}, true)),
		]},
		# 第三段:換另一隻手出拳
		{"name": "attack3", "fps": 12, "loop": false, "frames": [
			pose({"neck": v(25, 19), "hand_b": v(23, 24), "elbow_b": v(19, 26)}),
			pose({"head": v(29, 14), "neck": v(27, 20), "hip": v(25, 31),
				"hand_b": v(43, 24), "elbow_b": null, "hand_f": v(26, 24), "elbow_f": v(22, 27)}),
			pose({"head": v(27, 13), "neck": v(26, 19), "hand_b": v(36, 25), "elbow_b": v(30, 26)}),
		]},
		# 第四段:往前踢一腳,接著往後跳開
		{"name": "attack4", "fps": 10, "loop": false, "frames": [
			pose({"hip": v(23, 31), "foot_f": v(27, 40), "knee_f": v(31, 34)}),
			pose(front_kick),
			pose(hop),
			pose(hop.merged({"head": v(23, 13), "foot_f": v(28, 43), "foot_b": v(16, 42)}, true)),
			pose(crouch),
		]},
		# 第五段:四條尾巴一起往前穿刺
		{"name": "attack5", "fps": 10, "loop": false, "frames": [
			pose(crouch),
			pose(pierce),
			pose(pierce.merged({"head": v(31, 19), "hand_b": v(14, 28)}, true)),
			pose(lunge),
		]},
		# 跳擊:撲過去、落地
		{"name": "leap", "fps": 8, "loop": false, "frames": [
			pose(pounce),
			pose(pounce.merged({"hand_f": v(41, 27), "hand_b": v(38, 31)}, true)),
			pose(pounce),
			pose(crouch),
		]},
		# 尾殺:扭身蓄力、整個人甩出去、收勢
		{"name": "sweep", "fps": 8, "loop": false, "frames": [
			pose({"head": v(22, 14), "neck": v(22, 20), "hand_f": v(18, 24), "elbow_f": v(23, 26), "hand_b": v(15, 22), "elbow_b": null}),
			pose({"head": v(30, 15), "neck": v(27, 20), "hip": v(24, 32), "hand_f": v(38, 30), "elbow_f": null,
				"hand_b": v(16, 24), "elbow_b": null, "foot_b": v(15, 46), "knee_b": v(19, 39)}),
			pose(crouch),
		]},
		# 以下都只有一格,由遊戲依招式的階段切換
		{"name": "leap_tails", "fps": 8, "loop": false, "frames": [pose(lunge)]},
		{"name": "hunt_ready", "fps": 8, "loop": false, "frames": [
			pose({"head": v(28, 18), "neck": v(26, 23), "hip": v(23, 34), "knee_f": v(30, 40), "knee_b": v(19, 41),
				"hand_f": v(32, 36), "elbow_f": null, "hand_b": v(18, 32), "elbow_b": null}),
		]},
		{"name": "hunt", "fps": 8, "loop": false, "frames": [
			pose({"head": v(35, 19), "neck": v(31, 23), "hip": v(22, 32), "hand_b": v(12, 26), "elbow_b": null,
				"hand_f": v(16, 30), "elbow_f": null, "foot_b": v(10, 44), "knee_b": v(16, 38),
				"foot_f": v(27, 46), "knee_f": v(28, 39)}),
		]},
		{"name": "bite1", "fps": 8, "loop": false, "frames": [pose(bite)]},
		{"name": "bite2", "fps": 8, "loop": false, "frames": [pose(bite.merged({"head": v(30, 13), "neck": v(27, 19)}, true))]},
	]


## 卡卡西專用的動作:同名的取代通用動作,其餘的加在後面。
func _kakashi_animations() -> Array:
	var crouch := {"head": v(25, 17), "neck": v(24, 23), "hip": v(23, 34), "knee_f": v(30, 40), "knee_b": v(20, 40)}
	# 俯身下踢:一手撐地,腿貼著地面掃出去
	var sweep := {"head": v(20, 23), "neck": v(21, 28), "hip": v(23, 37), "foot_f": v(44, 44), "knee_f": v(34, 42),
		"foot_b": v(15, 46), "knee_b": v(17, 41), "hand_f": v(28, 44), "elbow_f": null, "hand_b": v(14, 33), "elbow_b": null}
	# 土流壁:單膝跪下,雙手按在地上
	var slam := {"head": v(31, 25), "neck": v(28, 29), "hip": v(21, 36), "hand_f": v(37, 45), "elbow_f": null,
		"hand_b": v(33, 45), "elbow_b": null, "foot_f": v(31, 46), "knee_f": v(31, 40), "foot_b": v(14, 46), "knee_b": v(17, 42)}
	# 結印:雙手在胸前交疊,每一格手勢稍微不同
	var seal_a := {"hand_f": v(30, 24), "elbow_f": v(27, 28), "hand_b": v(30, 25), "elbow_b": v(24, 28)}
	var seal_b := {"hand_f": v(31, 22), "elbow_f": v(28, 27), "hand_b": v(29, 25), "elbow_b": v(24, 28)}
	var palms := {"head": v(27, 14), "neck": v(26, 20), "hand_f": v(41, 22), "elbow_f": null, "hand_b": v(40, 26), "elbow_b": null}
	# 雷切:壓低身體,一手握住另一隻手的手腕在腰側蓄力;接著整個人往前刺出去
	var charge := {"head": v(27, 17), "neck": v(25, 23), "hip": v(23, 34), "knee_f": v(30, 40), "knee_b": v(19, 40),
		"hand_f": v(22, 36), "elbow_f": v(27, 31), "hand_b": v(24, 33), "elbow_b": v(21, 29)}
	var thrust := {"head": v(33, 17), "neck": v(29, 21), "hip": v(22, 31), "hand_f": v(44, 24), "elbow_f": null,
		"hand_b": v(16, 27), "elbow_b": null, "foot_b": v(11, 45), "knee_b": v(16, 38), "foot_f": v(30, 46), "knee_f": v(30, 39)}
	return [
		# 第二段:俯身下踢
		{"name": "attack3", "fps": 12, "loop": false, "frames": [
			pose(crouch),
			pose(sweep),
			pose(sweep.merged({"foot_f": v(44, 43), "hand_b": v(14, 34)}, true)),
			pose(crouch),
		]},
		# 第三段:土遁.土流壁
		{"name": "attack4", "fps": 10, "loop": false, "frames": [
			pose(seal_a),
			pose(slam),
			pose(slam.merged({"head": v(31, 26)}, true)),
			pose(slam),
			pose(crouch),
		]},
		# 雷切:蓄力兩格、刺出去兩格、收勢
		{"name": "raikiri", "fps": 8, "loop": false, "frames": [
			pose(charge),
			pose(charge.merged({"head": v(27, 18), "hand_f": v(22, 37)}, true)),
			pose(thrust),
			pose(thrust.merged({"hand_f": v(45, 24)}, true)),
			pose(crouch),
		]},
		# 水龍波:結印三格,雙掌往前推兩格
		{"name": "water", "fps": 8, "loop": false, "frames": [
			pose(seal_a),
			pose(seal_b),
			pose(seal_a),
			pose(palms),
			pose(palms.merged({"hand_f": v(42, 22), "hand_b": v(41, 26)}, true)),
		]},
		# 雷流引:一手往斜上方指著空中的對手
		{"name": "raiton", "fps": 10, "loop": true, "frames": [
			pose({"head": v(26, 13), "hand_f": v(40, 11), "elbow_f": v(32, 17), "hand_b": v(31, 20), "elbow_b": v(25, 24)}),
			pose({"head": v(26, 13), "hand_f": v(40, 12), "elbow_f": v(32, 18), "hand_b": v(31, 21), "elbow_b": v(25, 24)}),
		]},
		# 開 / 關寫輪眼:手伸到護額上
		{"name": "sharingan", "fps": 8, "loop": false, "frames": [
			pose({"hand_f": v(30, 18), "elbow_f": v(31, 24)}),
			pose({"hand_f": v(29, 10), "elbow_f": v(33, 17)}),
			pose({"hand_f": v(29, 10), "elbow_f": v(33, 17)}),
		]},
		# 結印(拷貝來的招式出手前)
		{"name": "seal", "fps": 10, "loop": true, "frames": [pose(seal_a), pose(seal_b)]},
	]


## 這個角色實際要畫的動作:通用動作,加上(或換成)角色自己的。
func _animations_for(style: Dictionary) -> Array:
	var animations := _animations()
	var extras: Array = []
	match style.get("moves", ""):
		"minato": extras = _minato_animations()
		"sasuke": extras = _sasuke_animations()
		"gojo_shibuya": extras = _gojo_shibuya_animations()
		"kaneki": extras = _kaneki_animations()
		"kakashi": extras = _kakashi_animations()
	for extra: Dictionary in extras:
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

## 這個角色的膚色(咒靈這類不是人的角色會指定自己的)。
func _skin() -> Color:
	return _style.get("skin", SKIN)


func _draw_figure(p: Dictionary) -> void:
	var shoulder: Vector2i = p.neck + Vector2i(0, 2)
	var sleeve: Color = _style.sleeve
	var pants: Color = _style.pants

	# 遠側的手腳先畫,顏色較暗
	_draw_limb(shoulder, p.get("elbow_b"), p.hand_b, sleeve.darkened(1.0 - BACK_SHADE), 3)
	if not p.get("pocket_b", false):  # 插在口袋裡的手不畫手掌
		_fill(p.hand_b + Vector2i(-1, -1), Vector2i(3, 3), _skin().darkened(1.0 - BACK_SHADE))
	_draw_limb(p.hip + Vector2i(-1, 0), p.get("knee_b"), p.foot_b, pants.darkened(1.0 - BACK_SHADE), 3)
	_fill(p.foot_b + Vector2i(-1, -1), Vector2i(4, 2), SHOE)

	# 軀幹:背側一條陰影、胸前一條受光,看起來才有厚度
	var top: Color = _style.top
	if _style.has("coat_hem"):
		_draw_coat_tail(shoulder, p.hip, top, _style.coat_hem)
	var sheathed: bool = _style.get("sheathed", false)
	var blade_in_hand: bool = _style.get("sword", false) and p.get("blade", not (sheathed or _style.get("holstered", false)))
	if _style.get("sword", false) and p.get("blade_b", false):
		# 遠側的手也拿著一把(先畫,會被身體擋住一部分)
		_draw_sword(p.get("elbow_b", shoulder), p.hand_b)
		_fill(p.hand_b + Vector2i(-1, -1), Vector2i(3, 3), _skin().darkened(1.0 - BACK_SHADE))
	if sheathed:
		_draw_scabbard(shoulder, p.hip, not blade_in_hand)
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
	_fill(p.neck + Vector2i(-1, -1), Vector2i(3, 2), _skin())
	if _style.get("collar", false):
		# 制服的高領,遮住脖子的下半截
		_fill(p.neck + Vector2i(-2, 0), Vector2i(5, 1), top.lightened(0.12))
	_unmasked = p.get("unmasked", false)
	if _unmasked and _style.blindfold:
		# 拉下來的眼罩掛在脖子上
		_fill(p.neck + Vector2i(-2, -1), Vector2i(5, 1), Color(0.08, 0.08, 0.11))
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
	if blade_in_hand:
		_draw_sword(p.get("elbow_f", shoulder), p.hand_f)
	if not p.get("pocket_f", false):
		_fill(p.hand_f + Vector2i(-1, -1), Vector2i(3, 3), _skin())


## 橫插在腰後的劍鞘:從腰帶往背後斜斜伸出去。with_sword 為 true 時劍還在鞘裡,腰前露出劍柄。
## 方向跟著軀幹走(和長袍下襬一樣),倒地時不會插進地面。
func _draw_scabbard(shoulder: Vector2i, hip: Vector2i, with_sword: bool) -> void:
	var along := Vector2(hip - shoulder)
	if along.length() < 0.5:
		along = Vector2.DOWN
	along = along.normalized()
	var behind := Vector2(-along.y, along.x)  # 站著的時候是往背後(左)
	var scabbard := Color(0.14, 0.13, 0.22)
	_draw_line(hip + Vector2i((behind * 1.0 - along * 3.0).round()), hip + Vector2i((behind * 11.0 + along * 1.0).round()), scabbard, 2)
	if with_sword:
		var grip_from := hip + Vector2i((-behind * 1.0 - along * 3.0).round())
		var grip_to := hip + Vector2i((-behind * 5.0 - along * 5.0).round())
		_draw_line(grip_from, grip_to, Color(0.3, 0.28, 0.42), 1)
		_plot(grip_to, Color(0.8, 0.8, 0.88))


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
	_fill(center + Vector2i(-4, -4), Vector2i(9, 9), _skin())
	for corner: Vector2i in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		_clear(center + corner)
	# 頭髮:頭頂與後腦
	_fill(center + Vector2i(-4, -5), Vector2i(9, 4), hair)
	_fill(center + Vector2i(-5, -3), Vector2i(3, 6), hair)
	_clear(center + Vector2i(-4, -5))
	_clear(center + Vector2i(4, -5))
	# 頭髮的高光,以及下巴後側的陰影
	_fill(center + Vector2i(1, -4), Vector2i(2, 1), hair.lightened(0.14))
	_plot(center + Vector2i(-2, 2), _skin().darkened(0.14))
	_plot(center + Vector2i(-2, 3), _skin().darkened(0.14))
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
	if _style.get("back_hair", false):
		# 後腦往後、往上翹的頭髮
		for point: Vector2i in [Vector2i(-6, -4), Vector2i(-7, -5), Vector2i(-6, -2), Vector2i(-7, -3), Vector2i(-8, -6),
				Vector2i(-6, 0), Vector2i(-7, -1), Vector2i(-5, -6), Vector2i(-6, -6)]:
			_plot(center + point, hair)
		# 垂在臉頰旁的鬢角
		_fill(center + Vector2i(0, -1), Vector2i(1, 4), hair)
	if _style.get("bangs", false):
		# 垂到下巴的長鬢角,後腦的頭髮也比較長
		_fill(center + Vector2i(0, -1), Vector2i(1, 5), hair)
		_fill(center + Vector2i(-5, 3), Vector2i(2, 2), hair)
		_plot(center + Vector2i(-6, -2), hair)
	if _style.has("headband"):
		# 護額:額頭上一條布,正面一塊金屬片;瀏海蓋在它下緣
		_fill(center + Vector2i(-4, -3), Vector2i(9, 1), _style.headband)
		_fill(center + Vector2i(0, -3), Vector2i(4, 1), Color(0.78, 0.83, 0.9))

	if _style.blindfold and not _unmasked:
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
	if _style.has("face_mask"):
		# 面罩:布料蓋住鼻子以下,沒有花紋
		var cloth: Color = _style.face_mask
		_fill(center + Vector2i(-2, 1), Vector2i(7, 4), cloth)
		_clear(center + Vector2i(4, 4))
		_fill(center + Vector2i(1, 2), Vector2i(3, 1), cloth.lightened(0.12))
	if _style.get("mask", false):
		# 面具:蓋住下半張臉,嘴的位置一排牙齒;眼睛周圍是黑的(赫眼)
		var leather := Color(0.09, 0.09, 0.12)
		_fill(center + Vector2i(-1, 1), Vector2i(6, 4), leather)
		_clear(center + Vector2i(4, 4))
		_plot(center + Vector2i(1, 3), Color(0.92, 0.92, 0.88))
		_plot(center + Vector2i(3, 3), Color(0.92, 0.92, 0.88))
		_plot(center + Vector2i(1, 0), leather)
		_plot(center + Vector2i(4, 0), leather)
	if _style.has("horns"):
		# 頭頂往上翹的兩支角
		var horn: Color = _style.horns
		for point: Vector2i in [Vector2i(-3, -6), Vector2i(-4, -7), Vector2i(-4, -8), Vector2i(2, -6), Vector2i(3, -7), Vector2i(3, -8)]:
			_plot(center + point, horn)
	if _style.get("maw", false):
		# 裂到耳邊的嘴:深色的口腔裡上下兩排交錯的牙
		_fill(center + Vector2i(-1, 2), Vector2i(6, 2), Color(0.2, 0.05, 0.1))
		for dx: int in [0, 2, 4]:
			_plot(center + Vector2i(dx, 2), Color(0.95, 0.94, 0.88))
		for dx: int in [1, 3]:
			_plot(center + Vector2i(dx, 3), Color(0.95, 0.94, 0.88))
	if _style.marks:
		var mark := Color(0.12, 0.1, 0.14)
		_plot(center + Vector2i(1, 2), mark)
		_plot(center + Vector2i(3, 2), mark)
		_plot(center + Vector2i(2, -2), mark)
	# 嘴(戴面具的看不到;咒靈的大嘴上面畫過了)
	if not _style.get("mask", false) and not _style.get("maw", false) and not _style.has("face_mask"):
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
