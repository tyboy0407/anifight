extends Node2D
## 對戰主場景:依選角結果載入雙方角色、回合流程、鏡頭跟隨。

const STAGE_LEFT := 0.0
const STAGE_RIGHT := 2400.0
const FLOOR_Y := 560.0
const CAMERA_Y := 324.0
const CAMERA_HALF_WIDTH := 576.0
## 角色離鏡頭中心的最大距離,確保雙方都留在畫面內。
const VIEW_HALF := 520.0
const SPAWN_GAP := 220.0
const ROUNDS_TO_WIN := 2
const ROUND_TIME := 150.0
const ROUND_END_DELAY := 2.2
const SHAKE_TIME := 0.28
const STAGE_DIR := "res://assets/stage/"
const STAGE_SCALE := 3.0         # 背景點陣圖的放大倍率,和角色一樣
const SCENERY_LEFT := -1500.0    # 景物從多左邊開始鋪(要蓋過鏡頭看得到的範圍)
const SCENERY_WIDTH := 5400.0
const FAR_PARALLAX := 0.25
const MID_PARALLAX := 0.6
const KO_SLOWMO_SCALE := 0.35  # 打倒對手時的慢動作速度
const KO_SLOWMO_TIME := 0.6    # 慢動作持續的實際秒數
const COMMON_HINT := "移動 A/D  防禦 S  跳 K  攻擊 J  衝刺 L  大招 I(1格)  幽步 S+L(1格)  挨打時脫出 O(1格)   |   F1 切換 P2 電腦/玩家   M 聲音開關   Esc 回選角"
const NET_HINT := "移動 A/D  防禦 S  跳 K  攻擊 J  衝刺 L  大招 I(1格)  幽步 S+L(1格)  挨打時脫出 O(1格)   |   M 聲音開關   Esc 回選角"
# 連線對戰:雙方各自模擬,只互傳按鍵。每一格都要等雙方這一格的按鍵到齊才往前算,
# 所以兩邊算出來的每一格完全一樣;自己的按鍵延後 GameState.net_delay 格才生效,讓對方來得及收到。
const NET_CHECK_EVERY := 30     # 每隔幾格互相比對一次狀態,不一樣就是不同步
const NET_RESEND_LIMIT := 60    # 一個封包最多帶幾格按鍵(還沒被對方確認收到的都會重送)
const NET_RESEND_MS := 16      # 停著等對方時,每隔幾毫秒重送一次還沒被確認的按鍵
const NET_KEEP := 240           # 按鍵與比對紀錄保留多少格
const NET_STALL_NOTICE := 0.6   # 等對方的按鍵等超過這麼久,畫面上顯示「等待對手」
const NET_STALL_LIMIT := 12.0   # 等超過這麼久就當作斷線
const NET_LEAVE_DELAY := 2.5    # 斷線或不同步後,訊息顯示多久才回選角畫面
const NET_REMATCH := 1 << 13    # 按鍵裡多帶的一個位元:要求再戰一場(GameState.NET_ACTIONS 用掉前 13 個)
const PACKET_INPUT := 1
const NET_HEADER := 11          # 按鍵封包開頭固定的位元組數

var _fighters: Array[Fighter] = []
var _wins: Array[int] = [0, 0]
var _round_number := 0
var _time_left := ROUND_TIME
var _round_active := false
var _match_over := false
var _sky: TextureRect
var _scenery: Array[Dictionary] = []  # 跟著鏡頭移動的景物層:{sprite, parallax}
var _shake_time := 0.0
var _shake_strength := 0.0
var _cpu: CpuController
var _touch: TouchControls  # 只有觸控模式才會建立
# 連線對戰(_net 是 null 就是單機)
var _net: NetSession
var _net_tick := 0                  # 下一格要模擬第幾格
var _net_inputs: Array = [{}, {}]   # 每位玩家:格數 -> 那一格的按鍵
var _net_sampled := -1              # 自己的按鍵已經決定到第幾格
var _net_received := -1             # 對方的按鍵已經連續收到第幾格
var _net_peer_ack := -1             # 對方說他已經連續收到我的按鍵到第幾格
var _net_checks: Dictionary = {}       # 格數 -> 自己算出來的狀態摘要
var _net_peer_checks: Dictionary = {}  # 格數 -> 對方算出來的
var _net_stall_since := 0           # 從什麼時候開始等對方的按鍵(毫秒,真實時間);0 代表沒有在等
var _net_sent_at := 0               # 上一次送出按鍵的時間(毫秒)
var _net_rematch := false           # 自己按了「再戰一場」,等下一次取樣時送出去
var _net_ended := false             # 斷線或不同步:這場不再繼續
var _net_end_reason := ""
var _net_label_clock := 0.0
var _round_end_ticks := 0           # 連線對戰:回合結束後還要再過幾格才開始下一回合

@onready var _camera: Camera2D = $Camera2D
@onready var _hud: FightHUD = $HUD


func _enter_tree() -> void:
	GameState.setup_input()


func _ready() -> void:
	Sfx.warm_up()
	Sfx.play_music("battle")
	_build_backdrop()
	_spawn_fighters()
	_cpu = CpuController.new()
	_cpu.name = "Cpu"
	_cpu.fighter = _fighters[1]
	add_child(_cpu)
	if GameState.net_active():
		_setup_net()
	else:
		_set_cpu_enabled(GameState.cpu_enabled)
	_hud.set_names(GameState.character(0).name, GameState.character(1).name)
	if GameState.touch_enabled:
		_setup_touch()
	elif _net != null:
		_hud.set_hint("%s\n%s" % [NET_HINT, _skill_hint(GameState.local_player(), 0)])
	else:
		_hud.set_hint("%s\n%s      %s" % [COMMON_HINT, _skill_hint(0), _skill_hint(1)])
	_start_match()


## 觸控模式:加上螢幕按鈕,隱藏鍵盤操作提示。
func _setup_touch() -> void:
	_touch = TouchControls.new()
	_touch.fighter = _fighters[GameState.local_player()]
	if _net != null:
		_touch.player_id = 0  # 連線時按鈕按的是「這台裝置上的人」的動作,再照格數交給角色
	add_child(_touch)
	# 觸控用專用按鈕出招,方向鍵不再改變按鍵的意思(連線時雙方的設定在 _setup_net 一起套用)
	if _net == null:
		_fighters[0].direction_combos = false
	_touch.rematch_requested.connect(_on_rematch_requested)
	_touch.back_requested.connect(_back_to_select)
	_hud.set_hint("")
	OrientationNotice.attach_if_touch(self)


func _on_rematch_requested() -> void:
	if not _match_over:
		return
	if _net != null:
		_net_rematch = true  # 跟著按鍵一起送出去,雙方在同一格重新開始
	else:
		_start_match()


func _back_to_select() -> void:
	_cpu.set_enabled(false)
	if _net != null and not _net_ended:
		_net.send_message({"t": "to_select"})  # 對方也一起回選角畫面,房間還在
	get_tree().change_scene_to_file(GameState.SELECT_SCENE)


func _process(delta: float) -> void:
	_tick_shake(delta)
	if _net != null:
		# 倒數由模擬那邊照格數算(見 _sim_tick);這裡只更新右上角的連線狀態
		_net_label_clock -= delta
		if _net_label_clock <= 0.0:
			_net_label_clock = 0.5
			_hud.set_p2_mode("連線對戰  %s" % _net.describe())
		return
	if not _round_active:
		return
	_time_left -= delta
	_hud.set_time(_time_left)
	if _time_left <= 0.0:
		_on_time_up()


## 畫面震動:鏡頭的位置每個物理影格都會重設,所以震動加在 offset 上。
func _on_screen_shake(strength: float) -> void:
	if strength >= _shake_strength * _shake_time / SHAKE_TIME:
		_shake_strength = strength
		_shake_time = SHAKE_TIME


func _tick_shake(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(_shake_time - delta, 0.0)
	var amount := _shake_strength * _shake_time / SHAKE_TIME
	_camera.offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))


func _physics_process(delta: float) -> void:
	if _net != null:
		_net_frame(delta)
	var mid := (_fighters[0].global_position.x + _fighters[1].global_position.x) / 2.0
	var cam_x := clampf(mid, STAGE_LEFT + CAMERA_HALF_WIDTH, STAGE_RIGHT - CAMERA_HALF_WIDTH)
	_camera.global_position = Vector2(cam_x, CAMERA_Y)
	_update_scenery(cam_x)
	for fighter in _fighters:
		fighter.arena_min_x = cam_x - VIEW_HALF
		fighter.arena_max_x = cam_x + VIEW_HALF
		fighter.global_position.x = clampf(fighter.global_position.x, fighter.arena_min_x, fighter.arena_max_x)


func _unhandled_input(event: InputEvent) -> void:
	if _match_over and event.is_action_pressed("ui_accept"):
		_on_rematch_requested()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 and _net == null:
			_set_cpu_enabled(not _cpu.enabled)
		elif event.physical_keycode == KEY_ESCAPE:
			_back_to_select()


## 依選角結果建立雙方角色。
func _spawn_fighters() -> void:
	for i in 2:
		var scene: PackedScene = load(GameState.character(i).scene)
		var fighter: Fighter = scene.instantiate()
		fighter.name = "Fighter%d" % (i + 1)
		fighter.player_id = i + 1
		fighter.body_color = GameState.PLAYER_COLORS[i]
		add_child(fighter)
		_fighters.append(fighter)
	_fighters[0].opponent = _fighters[1]
	_fighters[1].opponent = _fighters[0]
	for i in 2:
		_fighters[i].health_changed.connect(_on_health_changed.bind(i))
		_fighters[i].energy_changed.connect(_on_energy_changed.bind(i))
		_fighters[i].meter_changed.connect(_on_meter_changed.bind(i))
		_fighters[i].defeated.connect(_on_defeated)
		_fighters[i].screen_shake.connect(_on_screen_shake)
		# 角色回報的是「自己被連段」,所以顯示在對手(攻擊方)那一側。
		_fighters[i].combo_changed.connect(_on_combo_changed.bind(1 - i))


## 某位玩家的招式按鍵提示。keys_of 是用哪一組按鍵(0 = P1 那組,1 = P2 那組);
## 不指定就是自己那組。連線對戰時兩邊的人都用 P1 那組按鍵。
func _skill_hint(player_index: int, keys_of: int = -1) -> String:
	var info := GameState.character(player_index)
	var skills: Array = info.skills
	var first_set := (player_index if keys_of < 0 else keys_of) == 0
	var keys: Array = ["U", "W+U", "S+I"] if first_set else ["Num4", "↑+Num4", "↓+Num5"]
	return "%s %s:%s %s  %s %s  %s %s" % [
		"你" if keys_of >= 0 else "P%d" % (player_index + 1),
		info.name, keys[0], skills[0], keys[1], skills[1], keys[2], skills[2]]


## 切換 P2 由電腦或玩家操作。
func _set_cpu_enabled(value: bool) -> void:
	GameState.cpu_enabled = value
	_cpu.set_enabled(value)
	_hud.set_p2_mode("電腦操作" if value else "玩家操作")


# ---------- 回合流程 ----------

func _start_match() -> void:
	_match_over = false
	if _touch != null:
		_touch.set_match_over(false)
	_wins = [0, 0]
	_round_number = 0
	_hud.set_wins(0, 0)
	for fighter in _fighters:
		fighter.new_match()
	_start_round()


func _start_round() -> void:
	_round_number += 1
	var center := (STAGE_LEFT + STAGE_RIGHT) / 2.0
	_fighters[0].reset(Vector2(center - SPAWN_GAP, FLOOR_Y), 1)
	_fighters[1].reset(Vector2(center + SPAWN_GAP, FLOOR_Y), -1)
	for fighter in _fighters:
		fighter.input_enabled = true
	_time_left = ROUND_TIME
	_hud.set_time(_time_left)
	_round_active = true
	_hud.show_message("ROUND %d" % _round_number, 1.2)
	Sfx.play("round_start")


func _on_health_changed(current: int, maximum: int, player_index: int) -> void:
	_hud.set_health(player_index, current, maximum)


func _on_energy_changed(current: int, maximum: int, player_index: int) -> void:
	_hud.set_energy(player_index, current, maximum)


func _on_meter_changed(ratio: float, full: bool, player_index: int) -> void:
	_hud.set_meter(player_index, _fighters[player_index].meter_info(), ratio, full)


func _on_combo_changed(hits: int, damage: int, attacker_index: int) -> void:
	_hud.set_combo(attacker_index, hits, damage)


## 打倒對手的那一刻短暫放慢時間,讓最後一擊看得清楚。
func _slow_motion() -> void:
	Engine.time_scale = KO_SLOWMO_SCALE
	# 計時不受慢動作影響;場景中途被換掉也照樣恢復原速
	get_tree().create_timer(KO_SLOWMO_TIME, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ---------- 連線對戰 ----------

func _setup_net() -> void:
	_net = NetSession.get_session()
	_net.take_packets()  # 上一場留下來的封包不要
	_cpu.set_enabled(false)
	GameState.rng.seed = GameState.net_seed
	for player in 2:
		# 角色不再自己每一格跑,改由 _sim_tick 在雙方按鍵到齊時一起推進
		_fighters[player].set_physics_process(false)
		_fighters[player].pad_driven = true
		_fighters[player].direction_combos = not GameState.net_touch[player]
	# 開場的前幾格還沒有人的按鍵會生效,直接當作沒按
	for tick in GameState.net_delay:
		_net_inputs[0][tick] = 0
		_net_inputs[1][tick] = 0
	_net_sampled = GameState.net_delay - 1
	_net_received = GameState.net_delay - 1
	_net_peer_ack = GameState.net_delay - 1
	_hud.set_p2_mode("連線對戰")


## 每個物理影格跑一次:收對方的資料、決定自己接下來那一格的按鍵並送出,雙方這一格的按鍵都到了才往前模擬一格。
func _net_frame(delta: float) -> void:
	_net_receive()
	if _net_ended:
		return
	var me := GameState.local_player()
	var target := _net_tick + GameState.net_delay
	var fresh := _net_sampled < target
	if fresh:
		_net_inputs[me][target] = _net_read_local()
		_net_sampled = target
	# 有新的按鍵就馬上送;停著等對方的時候也定時重送,掉了的封包才補得回來
	if fresh or Time.get_ticks_msec() - _net_sent_at >= NET_RESEND_MS:
		_net_sent_at = Time.get_ticks_msec()
		_net_send()
	if not _net_inputs[1 - me].has(_net_tick):
		# 對方這一格的按鍵還沒到:停在原地等
		if _net_stall_since == 0:
			_net_stall_since = Time.get_ticks_msec()
		var waited := (Time.get_ticks_msec() - _net_stall_since) / 1000.0
		if waited >= NET_STALL_LIMIT:
			_net_end("對手沒有回應")
		elif waited >= NET_STALL_NOTICE:
			_hud.set_notice("等待對手…")
		return
	if _net_stall_since != 0:
		_net_stall_since = 0
		_hud.set_notice("")
	var masks: Array[int] = [_net_inputs[0][_net_tick], _net_inputs[1][_net_tick]]
	for player in 2:
		_fighters[player].set_pad(masks[player])
	_sim_tick(delta, masks[0] | masks[1])
	for player in 2:
		_net_inputs[player].erase(_net_tick - NET_KEEP)


## 模擬一格:雙方角色各跑一格,再處理倒數、回合交替與再戰一場。兩邊的遊戲在同一格做同樣的事。
func _sim_tick(delta: float, pressed: int) -> void:
	for fighter in _fighters:
		fighter._physics_process(delta)
	if _round_active:
		_time_left -= delta
		_hud.set_time(_time_left)
		if _time_left <= 0.0:
			_on_time_up()
	elif _round_end_ticks > 0:
		_round_end_ticks -= 1
		if _round_end_ticks == 0:
			_start_round()
	elif _match_over and pressed & NET_REMATCH != 0:
		_start_match()
	if _net_tick % NET_CHECK_EVERY == 0:
		_net_check()
	_net_tick += 1


## 這台裝置上的人現在按著哪些鍵(每個動作一個位元,順序見 GameState.NET_ACTIONS)。
func _net_read_local() -> int:
	var mask := 0
	for index in GameState.NET_ACTIONS.size():
		var action_name := GameState.action(0, GameState.NET_ACTIONS[index])
		# 點一下就放開、短到兩格之間的按鍵也要算
		if Input.is_action_pressed(action_name) or Input.is_action_just_pressed(action_name):
			mask |= 1 << index
	if _net_rematch:
		_net_rematch = false
		mask |= NET_REMATCH
	return mask


## 把自己還沒被對方確認收到的按鍵都送出去(每個影格送一次,所以掉了的封包會自己補上),
## 順便告訴對方「你的按鍵我已經連續收到第幾格」。
## 封包:[種類][這一場的編號][我收到你的第幾格 u32][從第幾格開始 u32][幾格 u8][每一格的按鍵 u16 …]
## 帶這一場的編號,是為了丟掉上一場晚到的封包(每一場的格數都從 0 算起,混進來會被當成這一場的按鍵)。
func _net_send() -> void:
	var me := GameState.local_player()
	var start := maxi(_net_peer_ack + 1, _net_sampled - NET_RESEND_LIMIT + 1)
	var count := maxi(_net_sampled - start + 1, 0)
	var packet := PackedByteArray()
	packet.resize(NET_HEADER + count * 2)
	packet[0] = PACKET_INPUT
	packet[1] = GameState.net_seed & 0xFF
	packet.encode_u32(2, _net_received)
	packet.encode_u32(6, start)
	packet[10] = count
	for offset in count:
		packet.encode_u16(NET_HEADER + offset * 2, _net_inputs[me].get(start + offset, 0))
	_net.send_packet(packet)


func _net_receive() -> void:
	var other := 1 - GameState.local_player()
	for packet in _net.take_packets():
		if packet.size() < NET_HEADER or packet[0] != PACKET_INPUT or packet[1] != GameState.net_seed & 0xFF \
				or packet.size() < NET_HEADER + packet[10] * 2:
			continue
		_net_peer_ack = maxi(_net_peer_ack, packet.decode_u32(2))
		var start := packet.decode_u32(6)
		for offset in packet[10]:
			var tick := start + offset
			if tick > _net_received and not _net_inputs[other].has(tick):
				_net_inputs[other][tick] = packet.decode_u16(NET_HEADER + offset * 2)
		while _net_inputs[other].has(_net_received + 1):
			_net_received += 1
	var messages := _net.take_messages()
	for index in messages.size():
		var message: Dictionary = messages[index]
		if message.has("sys"):
			if str(message.sys) in ["left", "closed", "error"]:
				_net_end("對手已離線")
		elif str(message.get("t", "")) == "chk":
			_net_peer_checks[int(message.get("k", -1))] = int(message.get("h", 0))
			_net_compare(int(message.get("k", -1)))
		elif str(message.get("t", "")) == "to_select" and not _net_ended:
			# 對方按了回選角:一起回去,房間還在。後面還沒看的訊息留給選角畫面
			_net.put_back(messages.slice(index + 1))
			_net_ended = true
			get_tree().change_scene_to_file(GameState.SELECT_SCENE)
			return


## 把這一格雙方的狀態濃縮成一個數字,和對方算的比對。
func _net_check() -> void:
	var parts: Array = [_net_tick, roundi(_time_left * 60.0), _wins[0], _wins[1], _round_number]
	for fighter in _fighters:
		parts.append_array([roundi(fighter.global_position.x * 16.0), roundi(fighter.global_position.y * 16.0),
				fighter.health, fighter.energy, int(fighter.state), fighter.facing])
	var digest := hash(parts)
	_net_checks[_net_tick] = digest
	_net.send_message({"t": "chk", "k": _net_tick, "h": digest})
	_net_compare(_net_tick)
	_net_checks.erase(_net_tick - NET_KEEP * 4)
	_net_peer_checks.erase(_net_tick - NET_KEEP * 4)


func _net_compare(tick: int) -> void:
	if not _net_checks.has(tick) or not _net_peer_checks.has(tick) or _net_ended:
		return
	if _net_checks[tick] != _net_peer_checks[tick]:
		push_warning("連線對戰不同步:第 %d 格" % tick)
		_net_end("雙方的畫面不同步")


## 這場連線對戰打不下去了(對方離線、太久沒回應、不同步):顯示原因,過一會兒回到單機的選角畫面。
func _net_end(reason: String) -> void:
	if _net_ended:
		return
	_net_ended = true
	_net_end_reason = reason
	print("連線對戰中止(第 %d 格):%s" % [_net_tick, reason])
	_round_active = false
	for fighter in _fighters:
		fighter.input_enabled = false
	_hud.set_notice("")
	_hud.show_message("%s\n即將回到選角畫面" % reason)
	if _touch != null:
		_touch.set_match_over(false)
	await get_tree().create_timer(NET_LEAVE_DELAY, true, false, true).timeout
	_net.leave()
	GameState.set_net_role(0)
	if is_inside_tree():
		get_tree().change_scene_to_file(GameState.SELECT_SCENE)


func _on_defeated(loser: Fighter) -> void:
	# 連線對戰不放慢:慢動作會改變每一格經過的時間,兩邊結束慢動作的時機又不可能剛好一樣,會不同步
	if _net == null:
		_slow_motion()
	_end_round(1 - _fighters.find(loser), "K.O.")


func _on_time_up() -> void:
	var diff := _fighters[0].health - _fighters[1].health
	var winner := -1
	if diff > 0:
		winner = 0
	elif diff < 0:
		winner = 1
	# 打倒對手的音效由角色自己播;時間到沒有人倒下,另外播提示音
	if _round_active:
		Sfx.play("time_up")
	_end_round(winner, "TIME UP")


## winner 為 -1 代表平手,雙方都不計勝場。
func _end_round(winner: int, headline: String) -> void:
	if not _round_active:
		return
	_round_active = false
	for fighter in _fighters:
		fighter.input_enabled = false
	if winner >= 0:
		_wins[winner] += 1
	_hud.set_wins(_wins[0], _wins[1])

	if winner >= 0 and _wins[winner] >= ROUNDS_TO_WIN:
		_match_over = true
		Sfx.play("victory")
		var result_text := "%s\nP%d %s 獲勝" % [headline, winner + 1, GameState.character(winner).name]
		if _touch != null:
			_touch.set_match_over(true)
		else:
			result_text += "\nEnter 再戰一場   Esc 回選角"
		_hud.show_message(result_text)
		return

	var result := "DRAW" if winner < 0 else "P%d WIN" % (winner + 1)
	_hud.show_message("%s\n%s" % [headline, result])
	if _net != null:
		# 連線對戰照格數等,雙方才會在同一格開始下一回合(見 _sim_tick)
		_round_end_ticks = roundi(ROUND_END_DELAY * Engine.physics_ticks_per_second)
		return
	await get_tree().create_timer(ROUND_END_DELAY).timeout
	if is_inside_tree():
		_start_round()


# ---------- 場景佈置 ----------

## 點陣背景(圖由 tools/make_stage.py 產生):夜空固定在畫面上,遠山、中景、地面
## 跟著鏡頭移動,越遠的移動得越慢。圖檔不在時維持場景原本的純色天空與地面。
func _build_backdrop() -> void:
	var sky_texture := _stage_texture("sky")
	if sky_texture != null:
		var layer := CanvasLayer.new()
		layer.layer = -10  # 畫在整個對戰場景後面,不受鏡頭與畫面震動影響
		add_child(layer)
		_sky = TextureRect.new()
		_sky.texture = sky_texture
		_sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_sky)
		$Sky.visible = false
	_add_scenery("far", FAR_PARALLAX, -6)
	_add_scenery("mid", MID_PARALLAX, -5)
	var ground := _add_scenery("ground", 1.0, -4)
	if ground != null:
		# 地面的圖從地板線往下鋪;更下面露出來的部分用圖案最底下的顏色接上
		ground.position.y = FLOOR_Y
		$Ground.color = Color8(46, 42, 60)


func _stage_texture(layer_name: String) -> Texture2D:
	var path := "%s%s.png" % [STAGE_DIR, layer_name]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## 加一層左右重複鋪滿整個場地的景物,底邊貼齊地板線。parallax 是跟著鏡頭移動的比例:
## 1 = 和角色一樣固定在場地上,越小越像在遠方。
func _add_scenery(layer_name: String, parallax: float, z: int) -> Sprite2D:
	var texture := _stage_texture(layer_name)
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.centered = false
	sprite.scale = Vector2.ONE * STAGE_SCALE
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, SCENERY_WIDTH / STAGE_SCALE, texture.get_height())
	sprite.z_index = z
	sprite.position = Vector2(SCENERY_LEFT, FLOOR_Y - texture.get_height() * STAGE_SCALE)
	add_child(sprite)
	_scenery.append({"sprite": sprite, "parallax": parallax})
	return sprite


## 依鏡頭位置移動各層景物,做出遠近的層次。
func _update_scenery(camera_x: float) -> void:
	for layer: Dictionary in _scenery:
		var sprite: Sprite2D = layer.sprite
		var parallax: float = layer.parallax
		sprite.position.x = SCENERY_LEFT + (camera_x - (STAGE_LEFT + STAGE_RIGHT) / 2.0) * (1.0 - parallax)
