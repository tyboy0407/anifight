class_name GameState
extends RefCounted
## 跨場景共用的設定:角色名單、雙方選角結果、P2 是否由電腦操作、輸入對應。

const SELECT_SCENE := "res://scenes/select.tscn"
const FIGHT_SCENE := "res://scenes/main.tscn"
const PLAYER_COLORS: Array[Color] = [Color(0.95, 0.4, 0.35), Color(0.35, 0.6, 0.95)]
## 真人對戰的連線中繼伺服器:發房間號碼、轉送雙方的訊息。程式與說明在 server/src/index.js,
## 改過之後要重新部署(npm --prefix server run deploy)。開房間連 /create,加入連 /join?code=四位數。
const RELAY_URL := "wss://anifight-relay.dylanworkersdev.workers.dev"

## 作品系列。選角畫面先選系列,再選裡面的角色;還沒有角色的系列不會顯示。
## 新增系列時在這裡加一筆,角色的 "series" 填這裡的 id。
const SERIES: Array[Dictionary] = [
	{"id": "jjk", "name": "咒術迴戰", "color": Color(0.5, 0.42, 0.95)},
	{"id": "naruto", "name": "火影忍者", "color": Color(1.0, 0.6, 0.2)},
	{"id": "tokyo_ghoul", "name": "東京喰種", "color": Color(0.9, 0.2, 0.26)},
]

## 新增角色時在這裡加一筆。series 是所屬系列的 id(見 SERIES);skills 依序是:技能、上+技能、超必殺。
const CHARACTERS: Array[Dictionary] = [
	{
		"name": "五條悟",
		"series": "jjk",
		"scene": "res://scenes/characters/gojo.tscn",
		"sprites": "res://assets/characters/gojo",
		"hair": Color(0.95, 0.96, 1.0),
		"skills": ["蒼", "赫(1格)", "無量空處(4格)"],
		"summary": "氣量上限 5 格\n蒼:吸引對手\n赫:長按蓄力,遠程擊飛\n無量空處:定身 5 秒\n受傷 1.5 倍、氣閉 20 秒",
		# 同一個角色的其他時期 / 型態。選角畫面長按角色卡片可以切換。
		"forms": [
			{
				"name": "青年五條悟",
				"scene": "res://scenes/characters/gojo_young.tscn",
				"sprites": "res://assets/characters/gojo_young",
				"hair": Color(0.95, 0.96, 1.0),
				"skills": ["蒼放(1格)", "無下限(2格)", "順轉「蒼」(3格)"],
				"summary": "氣量上限 5 格\n開場 10 秒無下限\n蒼放:閃到背後甩出蒼球\n無下限:10 秒攻擊無效\n順轉「蒼」:吸入後甩出",
			},
			{
				"name": "五條悟(澀谷事變)",
				"scene": "res://scenes/characters/gojo_shibuya.tscn",
				"sprites": "res://assets/characters/gojo_shibuya",
				"hair": Color(0.95, 0.96, 1.0),
				"skills": ["蒼迫(1格)", "塵殺(1格)", "0.2秒領域展開(4格)"],
				"summary": "氣量上限 5 格\n普攻:瞬身連打、踢遠吸回\n蒼迫:壓制 2 秒,可接普攻\n塵殺:來回兩擊,破防 10 秒\n破防:受到的傷害 +50%\n領域:僵直 2 秒、氣閉 15 秒\n接 15 連打後扔出",
			},
		],
	},
	{
		"name": "兩面宿儺",
		"series": "jjk",
		"scene": "res://scenes/characters/sukuna.tscn",
		"sprites": "res://assets/characters/sukuna",
		"hair": Color(0.95, 0.6, 0.65),
		"skills": ["解", "捌(1格,需近身)", "伏魔御廚子(4格)"],
		"summary": "氣量上限 5 格\n解:遠距離斬擊\n捌:近身多段斬\n伏魔御廚子:15 秒追蹤斬擊",
	},
	{
		"name": "乙骨憂太",
		"series": "jjk",
		"scene": "res://scenes/characters/yuta.tscn",
		"sprites": "res://assets/characters/yuta",
		"hair": Color(0.13, 0.13, 0.17),
		"skills": ["飛走吧!(1格)", "我也可以!(1格)", "來吧,里香!(5格)/純愛砲"],
		"summary": "氣量上限 8 格\n飛走吧!:咒言擊飛\n我也可以!:普攻強化 10 秒\n來吧,里香!:里香狀態 60 秒\n4 格氣:咒力滿盈,緩慢回氣\n招式一變黑閃拳,耗氣加倍",
	},
	{
		"name": "虎杖悠仁",
		"series": "jjk",
		"scene": "res://scenes/characters/yuji.tscn",
		"sprites": "res://assets/characters/yuji",
		"hair": Color(0.98, 0.7, 0.62),
		"skills": ["逕庭拳(1格)", "格檔(1格)", "黑閃(3格)"],
		"summary": "被動:攻擊 1% 機率黑閃\n逕庭拳:延遲的衝擊波\n格檔:擋下近身攻擊並反擊\n黑閃:必定黑閃的一拳",
	},
	{
		"name": "伏黑惠",
		"series": "jjk",
		"scene": "res://scenes/characters/megumi.tscn",
		"sprites": "res://assets/characters/megumi",
		"hair": Color(0.1, 0.11, 0.16),
		"skills": ["鷲(2格)", "玉犬(2格)", "式神合擊(需兩隻式神)"],
		"summary": "氣量上限 4 格\n式神在場時持續回氣\n鷲:式神定期俯衝\n玉犬:式神定期撲咬\n式神合擊:進入咒力高漲",
	},
	{
		"name": "伏黑甚爾",
		"series": "jjk",
		"scene": "res://scenes/characters/toji.tscn",
		"sprites": "res://assets/characters/toji",
		"hair": Color(0.08, 0.08, 0.1),
		"skills": ["狼牙刀", "天逆牟", "咒縛狀態(冷卻30秒)"],
		"summary": "沒有氣格,招式不耗氣\n跑得快,緩慢回血\n狼牙刀:兩刀後踢飛\n天逆牟:四刀後閃到背後\n再按一次:旋斬 / 破防背刺\n咒縛狀態:10 秒強化",
	},
	{
		"name": "波風湊",
		"series": "naruto",
		"scene": "res://scenes/characters/minato.tscn",
		"sprites": "res://assets/characters/minato",
		"hair": Color(0.99, 0.84, 0.24),
		"skills": ["瞬身踢(1格)", "螺旋丸(1格)", "飛光連擊閃身二式(4格)"],
		"summary": "氣量上限 5 格\n普攻四段丟苦無:飛雷神\n按住後退:苦無留在地上\n再按普攻:瞬身滑行斬\n瞬身踢命中:可接螺旋丸\n有飛雷神:五段與招式強化",
	},
	{
		"name": "宇智波佐助",
		"series": "naruto",
		"scene": "res://scenes/characters/sasuke.tscn",
		"sprites": "res://assets/characters/sasuke",
		"hair": Color(0.1, 0.11, 0.18),
		"skills": ["千鳥(1格)/連段中:千鳥雷槍", "豪火球之術(1格)", "麒麟(5格)"],
		"summary": "氣量上限 5 格\n千鳥:蓄力後衝刺\n普攻中按招式一:千鳥雷槍\n豪火球:命中後燃燒 5 秒\n麒麟:出拳、雷槍、落雷\n大蛇之力滿:蛇咬 / 蛇籠",
	},
	{
		"name": "金木研",
		"series": "tokyo_ghoul",
		"scene": "res://scenes/characters/kaneki.tscn",
		"sprites": "res://assets/characters/kaneki",
		"hair": Color(0.93, 0.93, 0.96),
		"skills": ["跳擊(1格)", "尾殺(2格)", "獵殺本能(3格)"],
		"summary": "氣量上限 5 格\n赫胞:攻擊與挨打都累積\n每滿一層多一條尾巴\n最多四條,整場保留\n跳擊尾殺:尾巴越多越強\n獵殺本能:撕咬回血\n亢奮:速度傷害 +30%",
	},
]

## 雙方選到的角色索引。直接執行對戰場景時使用這組預設值。
static var selection: Array[int] = [0, 1]
## 雙方選到的型態:0 是角色原本的樣子,1 以後是該角色 "forms" 裡的第幾個。
static var forms: Array[int] = [0, 0]
## 選角畫面上次看的是哪個系列(SERIES 的索引);-1 代表還沒選過,進選角畫面先看到系列清單。
static var series: int = -1
static var cpu_enabled: bool = true
## 是否顯示觸控按鈕。網頁版在觸控裝置上自動開啟;
## 測試時可在網址加上 ?touch=1,或在桌面版加上啟動參數 -- --touch。
static var touch_enabled: bool = false

## 只有觸控按鈕會用到的動作:一顆按鈕直接放出鍵盤上要搭配方向鍵的招式。
const DIRECT_ACTIONS: Array[String] = ["skill2", "super", "teleport"]
static var _initialized: bool = false

# ---------- 真人對戰(連線) ----------
## 連線對戰時每一格要同步的按鍵,順序就是傳輸時的位元順序(改了順序,雙方的版本就不相容)。
const NET_ACTIONS: Array[String] = ["left", "right", "up", "down", "attack", "jump", "dash", "special", "escape", "skill",
		"skill2", "super", "teleport"]
## 連線雙方的遊戲內容要一樣才能同步。改了會影響對戰結果的東西(招式數值、角色、同步的做法)就把這個數字加一,
## 版本不同的兩個人會在房間裡被擋下來,不會打到一半才不同步。
const NET_VERSION := 1
const P1_KEYS := {
	"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
	"attack": KEY_J, "jump": KEY_K, "dash": KEY_L,
	"special": KEY_I, "escape": KEY_O, "skill": KEY_U,
}
const P2_KEYS := {
	"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
	"attack": KEY_KP_1, "jump": KEY_KP_2, "dash": KEY_KP_3,
	"special": KEY_KP_5, "escape": KEY_KP_6, "skill": KEY_KP_4,
}
const PAD_BUTTONS := {
	"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
	"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
	"attack": JOY_BUTTON_X, "jump": JOY_BUTTON_A, "dash": JOY_BUTTON_B,
	"special": JOY_BUTTON_Y, "escape": JOY_BUTTON_RIGHT_SHOULDER, "skill": JOY_BUTTON_LEFT_SHOULDER,
}
## 0 = 單機;1 = 連線對戰的房主(操作 P1);2 = 加入的人(操作 P2)。
static var net_role: int = 0
## 連線雙方是不是用觸控按鈕(觸控的招式不看方向鍵,兩邊模擬時要一致)。
static var net_touch: Array[bool] = [false, false]
## 連線對戰時雙方共用的亂數種子,以及按鍵延後幾格才生效(由房主決定)。
static var net_seed: int = 0
static var net_delay: int = 3
## 會影響勝負的亂數(黑閃的機率這類)都從這裡取。連線時雙方用同一顆種子,結果才會一樣;
## 特效、電腦對手用的亂數不要從這裡取,不然兩邊取的次數會不一樣。
static var rng := RandomNumberGenerator.new()


## 某個系列裡的角色(CHARACTERS 的索引),依名單順序。
static func characters_in(series_index: int) -> Array[int]:
	var found: Array[int] = []
	if series_index < 0 or series_index >= SERIES.size():
		return found
	for index in CHARACTERS.size():
		if CHARACTERS[index].get("series", "") == SERIES[series_index].id:
			found.append(index)
	return found


## 有角色的系列(SERIES 的索引),依清單順序。還沒有角色的系列不算。
static func playable_series() -> Array[int]:
	var found: Array[int] = []
	for index in SERIES.size():
		if not characters_in(index).is_empty():
			found.append(index)
	return found


## 某位玩家實際出戰的角色資料(已套用選到的型態)。
static func character(player_index: int) -> Dictionary:
	return form_info(selection[player_index], forms[player_index])


## 這個角色共有幾種型態(含原本的樣子)。
static func form_count(character_index: int) -> int:
	return 1 + (CHARACTERS[character_index].get("forms", []) as Array).size()


## 取得某個角色指定型態的資料;型態編號超出範圍時回到原本的樣子。
static func form_info(character_index: int, form_index: int) -> Dictionary:
	var base: Dictionary = CHARACTERS[character_index]
	var alternates: Array = base.get("forms", [])
	if form_index <= 0 or form_index > alternates.size():
		return base
	return alternates[form_index - 1]


static func action(player_id: int, action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


## 註冊雙方的輸入動作。可重複呼叫。
static func setup_input() -> void:
	if _initialized:
		return
	_initialized = true
	_detect_touch()
	rng.randomize()
	# 0 號玩家是「這台裝置上的人」:連線對戰時鍵盤和觸控按鈕都改按 p0_ 開頭的動作,
	# 再由對戰場景照格數把雙方的按鍵交給角色(見 main.gd 的 _net_frame 與 Fighter.set_pad)。
	for player_id in [0, 1, 2]:
		for action_name in NET_ACTIONS:
			_ensure_action(player_id, action_name)
	_bind_devices()


## 某個動作在連線按鍵裡是哪一個位元;不在同步清單裡的動作回傳 0(永遠沒按)。
static func net_bit(action_name: String) -> int:
	var index := NET_ACTIONS.find(action_name)
	return 1 << index if index >= 0 else 0


static func net_active() -> bool:
	return net_role != 0


## 這台裝置上的人操作的是第幾位玩家(0 或 1)。單機時是 0。
static func local_player() -> int:
	return maxi(net_role - 1, 0)


## 進入或離開連線對戰:換掉鍵盤的對應,並放開所有還按著的動作。
static func set_net_role(role: int) -> void:
	net_role = role
	setup_input()
	for player_id in [0, 1, 2]:
		for action_name in NET_ACTIONS:
			Input.action_release(action(player_id, action_name))
	_bind_devices()


## 把鍵盤與手把接到動作上。單機:兩組按鍵分別操作 P1、P2。
## 連線:這台裝置上只有一個人,P1 那組按鍵(和手把)接到 0 號玩家,P1 / P2 的動作不直接接任何按鍵。
static func _bind_devices() -> void:
	for player_id in [0, 1, 2]:
		for action_name in NET_ACTIONS:
			InputMap.action_erase_events(action(player_id, action_name))
	if net_active():
		_bind_keys(0, P1_KEYS)
		_bind_pad(0, PAD_BUTTONS)
	else:
		_bind_keys(1, P1_KEYS)
		_bind_keys(2, P2_KEYS)
		# 沒有數字鍵盤時,P2 可以改用第一支手把。
		_bind_pad(2, PAD_BUTTONS)


## 測試用:直接指定安全區內縮量(邏輯像素),格式同 safe_area() 的回傳值。
static var safe_area_override: Variant = null


## 網頁版的裝置資訊,由 web/shell.html 提供:
## insets(安全區,上右下左,CSS 像素)、width(畫布的 CSS 寬度)、
## fullscreen(瀏覽器是否支援全螢幕)、ios、standalone(是否從主畫面開啟)。
## 不是網頁版時回傳空字典。
static func web_platform() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	var raw: Variant = JavaScriptBridge.eval("window.anifightPlatform ? window.anifightPlatform() : ''")
	if raw is String and not (raw as String).is_empty():
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			return parsed
	return {}


## 螢幕安全區的內縮量,單位是遊戲的邏輯像素:Vector4(左, 上, 右, 下)。
## 手機的瀏海、圓角與底部橫條會佔用這些區域,介面要往內縮才不會被擋住。
static func safe_area(viewport: Viewport) -> Vector4:
	if safe_area_override != null:
		return safe_area_override
	var info := web_platform()
	var css_width := float(info.get("width", 0.0))
	var insets: Array = info.get("insets", [])
	if css_width <= 0.0 or insets.size() < 4:
		return Vector4.ZERO
	var to_logical := viewport.get_visible_rect().size.x / css_width
	return Vector4(float(insets[3]), float(insets[0]), float(insets[1]), float(insets[2])) * to_logical


## 把鋪滿畫面的 Control 往內縮到安全區內。
static func fit_to_safe_area(control: Control) -> void:
	var area := safe_area(control.get_viewport())
	control.offset_left = area.x
	control.offset_top = area.y
	control.offset_right = -area.z
	control.offset_bottom = -area.w


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
