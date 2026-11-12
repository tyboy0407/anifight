class_name GameState
extends RefCounted
## 跨場景共用的設定:角色名單、雙方選角結果、P2 是否由電腦操作、輸入對應。

const SELECT_SCENE := "res://scenes/select.tscn"
const FIGHT_SCENE := "res://scenes/main.tscn"
const PLAYER_COLORS: Array[Color] = [Color(0.95, 0.4, 0.35), Color(0.35, 0.6, 0.95)]

## 新增角色時在這裡加一筆。skills 依序是:技能、上+技能、超必殺。
const CHARACTERS: Array[Dictionary] = [
	{
		"name": "五條悟",
		"scene": "res://scenes/characters/gojo.tscn",
		"sprites": "res://assets/characters/gojo",
		"hair": Color(0.95, 0.96, 1.0),
		"skills": ["蒼", "赫(1格)", "無量空處(3格)"],
		"touch_labels": ["蒼", "赫", "領域"],
		"summary": "蒼:吸引對手\n赫:遠程擊飛\n無量空處:定身 2.6 秒",
	},
	{
		"name": "兩面宿儺",
		"scene": "res://scenes/characters/sukuna.tscn",
		"sprites": "res://assets/characters/sukuna",
		"hair": Color(0.95, 0.6, 0.65),
		"skills": ["解", "捌(1格,需近身)", "伏魔御廚子(3格)"],
		"touch_labels": ["解", "捌", "領域"],
		"summary": "解:遠距離斬擊\n捌:近身多段斬\n伏魔御廚子:10 秒隨機斬擊",
	},
	{
		"name": "乙骨憂太",
		"scene": "res://scenes/characters/yuta.tscn",
		"sprites": "res://assets/characters/yuta",
		"hair": Color(0.13, 0.13, 0.17),
		"skills": ["飛走吧!(1格)", "我也可以!(1格)", "來吧,里香!(3格)/純愛砲"],
		"touch_labels": ["咒言", "附刀", "里香"],
		"summary": "氣量上限 5 格\n飛走吧!:咒言擊飛\n我也可以!:普攻強化 10 秒\n來吧,里香!:里香狀態 60 秒",
	},
]

## 雙方選到的角色索引。直接執行對戰場景時使用這組預設值。
static var selection: Array[int] = [0, 1]
static var cpu_enabled: bool = true
## 是否顯示觸控按鈕。網頁版在觸控裝置上自動開啟;
## 測試時可在網址加上 ?touch=1,或在桌面版加上啟動參數 -- --touch。
static var touch_enabled: bool = false

## 只有觸控按鈕會用到的動作:一顆按鈕直接放出鍵盤上要搭配方向鍵的招式。
const DIRECT_ACTIONS: Array[String] = ["skill2", "super", "teleport"]
static var _initialized: bool = false


static func character(player_index: int) -> Dictionary:
	return CHARACTERS[selection[player_index]]


static func action(player_id: int, action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


## 註冊雙方的輸入動作。可重複呼叫。
static func setup_input() -> void:
	if _initialized:
		return
	_initialized = true
	_detect_touch()
	for player_id in [1, 2]:
		for action_name in DIRECT_ACTIONS:
			_ensure_action(player_id, action_name)
	_bind_keys(1, {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"attack": KEY_J, "jump": KEY_K, "dash": KEY_L,
		"special": KEY_I, "escape": KEY_O, "skill": KEY_U,
	})
	_bind_keys(2, {
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"attack": KEY_KP_1, "jump": KEY_KP_2, "dash": KEY_KP_3,
		"special": KEY_KP_5, "escape": KEY_KP_6, "skill": KEY_KP_4,
	})
	# 沒有數字鍵盤時,P2 可以改用第一支手把。
	_bind_pad(2, {
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
		"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
		"attack": JOY_BUTTON_X, "jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B,
		"special": JOY_BUTTON_Y, "escape": JOY_BUTTON_RIGHT_SHOULDER, "skill": JOY_BUTTON_LEFT_SHOULDER,
	})


static func _detect_touch() -> void:
	if OS.get_cmdline_user_args().has("--touch"):
		touch_enabled = true
	elif OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search")
		var forced := query is String and (query as String).contains("touch=1")
		touch_enabled = forced or DisplayServer.is_touchscreen_available()
	if touch_enabled:
		cpu_enabled = true  # 觸控只有一組按鈕,對手固定由電腦操作


static func _bind_keys(player_id: int, bindings: Dictionary) -> void:
	for action_name: String in bindings:
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action_name]
		InputMap.action_add_event(_ensure_action(player_id, action_name), event)


static func _bind_pad(player_id: int, bindings: Dictionary) -> void:
	for action_name: String in bindings:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = bindings[action_name]
		InputMap.action_add_event(_ensure_action(player_id, action_name), event)


static func _ensure_action(player_id: int, action_name: String) -> String:
	var action_id := action(player_id, action_name)
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)
	return action_id
