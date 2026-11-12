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
const ROUND_TIME := 60.0
const ROUND_END_DELAY := 2.2
const COMMON_HINT := "移動 A/D  防禦 S  跳 K  攻擊 J  衝刺 L  大招 I(1格)  幽步 S+L(1格)  挨打時脫出 O(1格)   |   F1 切換 P2 電腦/玩家   Esc 回選角"

var _fighters: Array[Fighter] = []
var _wins: Array[int] = [0, 0]
var _round_number := 0
var _time_left := ROUND_TIME
var _round_active := false
var _match_over := false
var _cpu: CpuController
var _touch: TouchControls  # 只有觸控模式才會建立

@onready var _camera: Camera2D = $Camera2D
@onready var _hud: FightHUD = $HUD


func _enter_tree() -> void:
	GameState.setup_input()


func _ready() -> void:
	_build_backdrop()
	_spawn_fighters()
	_cpu = CpuController.new()
	_cpu.name = "Cpu"
	_cpu.fighter = _fighters[1]
	add_child(_cpu)
	_set_cpu_enabled(GameState.cpu_enabled)
	_hud.set_names(GameState.character(0).name, GameState.character(1).name)
	if GameState.touch_enabled:
		_setup_touch()
	else:
		_hud.set_hint("%s\n%s      %s" % [COMMON_HINT, _skill_hint(0), _skill_hint(1)])
	_start_match()


## 觸控模式:加上螢幕按鈕,隱藏鍵盤操作提示。
func _setup_touch() -> void:
	_touch = TouchControls.new()
	add_child(_touch)
	_touch.set_skill_labels(GameState.character(0).get("touch_labels", []))
	_touch.rematch_requested.connect(_on_rematch_requested)
	_touch.back_requested.connect(_back_to_select)
	_hud.set_hint("")
	OrientationNotice.attach_if_touch(self)


func _on_rematch_requested() -> void:
	if _match_over:
		_start_match()


func _back_to_select() -> void:
	_cpu.set_enabled(false)
	get_tree().change_scene_to_file(GameState.SELECT_SCENE)


func _process(delta: float) -> void:
	if not _round_active:
		return
	_time_left -= delta
	_hud.set_time(_time_left)
	if _time_left <= 0.0:
		_on_time_up()


func _physics_process(_delta: float) -> void:
	var mid := (_fighters[0].global_position.x + _fighters[1].global_position.x) / 2.0
	var cam_x := clampf(mid, STAGE_LEFT + CAMERA_HALF_WIDTH, STAGE_RIGHT - CAMERA_HALF_WIDTH)
	_camera.global_position = Vector2(cam_x, CAMERA_Y)
	for fighter in _fighters:
		fighter.arena_min_x = cam_x - VIEW_HALF
		fighter.arena_max_x = cam_x + VIEW_HALF
		fighter.global_position.x = clampf(fighter.global_position.x, fighter.arena_min_x, fighter.arena_max_x)


func _unhandled_input(event: InputEvent) -> void:
	if _match_over and event.is_action_pressed("ui_accept"):
		_start_match()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
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
		_fighters[i].defeated.connect(_on_defeated)
		# 角色回報的是「自己被連段」,所以顯示在對手(攻擊方)那一側。
		_fighters[i].combo_changed.connect(_on_combo_changed.bind(1 - i))


func _skill_hint(player_index: int) -> String:
	var info := GameState.character(player_index)
	var skills: Array = info.skills
	var keys: Array = ["U", "W+U", "S+I"] if player_index == 0 else ["Num4", "↑+Num4", "↓+Num5"]
	return "P%d %s:%s %s  %s %s  %s %s" % [
		player_index + 1, info.name, keys[0], skills[0], keys[1], skills[1], keys[2], skills[2]]


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


func _on_health_changed(current: int, maximum: int, player_index: int) -> void:
	_hud.set_health(player_index, current, maximum)


func _on_energy_changed(current: int, maximum: int, player_index: int) -> void:
	_hud.set_energy(player_index, current, maximum)


func _on_combo_changed(hits: int, damage: int, attacker_index: int) -> void:
	_hud.set_combo(attacker_index, hits, damage)


func _on_defeated(loser: Fighter) -> void:
	_end_round(1 - _fighters.find(loser), "K.O.")


func _on_time_up() -> void:
	var diff := _fighters[0].health - _fighters[1].health
	var winner := -1
	if diff > 0:
		winner = 0
	elif diff < 0:
		winner = 1
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
		var result_text := "%s\nP%d %s 獲勝" % [headline, winner + 1, GameState.character(winner).name]
		if _touch != null:
			_touch.set_match_over(true)
		else:
			result_text += "\nEnter 再戰一場   Esc 回選角"
		_hud.show_message(result_text)
		return

	var result := "DRAW" if winner < 0 else "P%d WIN" % (winner + 1)
	_hud.show_message("%s\n%s" % [headline, result])
	await get_tree().create_timer(ROUND_END_DELAY).timeout
	if is_inside_tree():
		_start_round()


# ---------- 場景佈置 ----------

func _build_backdrop() -> void:
	# 背景柱子,讓鏡頭移動時有參照物。
	var x := STAGE_LEFT - 400.0
	var index := 0
	while x < STAGE_RIGHT + 400.0:
		var pillar := ColorRect.new()
		pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pillar.z_index = -5
		var height := 220.0 + 90.0 * (index % 3)
		pillar.size = Vector2(70, height)
		pillar.position = Vector2(x, FLOOR_Y - height)
		pillar.color = Color(0.2, 0.23, 0.33)
		add_child(pillar)
		x += 260.0
		index += 1
