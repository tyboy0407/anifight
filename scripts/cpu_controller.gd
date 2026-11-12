class_name CpuController
extends Node
## 簡易電腦對手:透過按下 / 放開該玩家的輸入動作來操作角色,
## 所以對任何角色都適用,不需要改角色本身的程式。

const THINK_MIN := 0.08
const THINK_MAX := 0.22
const TAP := 0.05
const FAR := 380.0
const CLOSE := 115.0

var fighter: Fighter
var enabled: bool = true

var _held: Dictionary = {}  # 動作名稱 -> 剩餘按住秒數
var _think := 0.0


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_release_all()


func _exit_tree() -> void:
	_release_all()


func _physics_process(delta: float) -> void:
	if not enabled or fighter == null or fighter.opponent == null:
		return
	_tick_held(delta)
	if not fighter.input_enabled:
		_release_all()
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = randf_range(THINK_MIN, THINK_MAX)
	_decide()


func _decide() -> void:
	var me := fighter
	var foe := fighter.opponent
	var dx := foe.global_position.x - me.global_position.x
	var distance := absf(dx)
	var toward := "right" if dx > 0.0 else "left"
	var away := "left" if dx > 0.0 else "right"
	var roll := randf()

	match me.state:
		Fighter.State.HITSTUN:
			if me.energy >= Fighter.ESCAPE_COST and roll < 0.2:
				_press("escape", TAP)
			return
		Fighter.State.DOWN:
			if roll < 0.5:
				_press("dash", TAP)
			return
		Fighter.State.ATTACK:
			# 連段:繼續按攻擊,偶爾取消接大招。
			if roll < 0.7:
				_press("attack", TAP)
			elif roll < 0.8 and me.energy >= Fighter.SPECIAL_COST:
				_press("special", TAP)
			return

	if foe.is_invulnerable():
		# 對手倒地或無敵時不浪費招式,保持中距離。
		if distance < 200.0:
			_move(away, 0.2)
		return

	if foe.state == Fighter.State.ATTACK and distance < 170.0 and roll < 0.55:
		_release("left")
		_release("right")
		_press("down", 0.35)
		return

	if distance > FAR:
		if roll < 0.2 and me.energy >= Fighter.SPECIAL_COST:
			_press("up", 0.12)
			_press("skill", TAP)
		elif roll < 0.5:
			_press("skill", TAP)
		elif roll < 0.6:
			_move(toward, 0.1)
			_press("dash", TAP)
		else:
			_move(toward, 0.3)
	elif distance > CLOSE:
		if roll < 0.12:
			_press("jump", TAP)
			_move(toward, 0.3)
		elif roll < 0.22:
			_press("skill", TAP)
		else:
			_move(toward, 0.2)
	else:
		if roll < 0.5:
			_press("attack", TAP)
		elif roll < 0.6 and me.energy >= Fighter.SPECIAL_COST:
			# 上 + 技能:近身型技能(例如捌)在這個距離才放得出來
			_press("up", 0.12)
			_press("skill", TAP)
		elif roll < 0.68 and me.energy >= Fighter.SPECIAL_COST:
			_press("special", TAP)
		elif roll < 0.75 and me.energy >= me.super_cost():
			_press("down", 0.12)
			_press("special", TAP)
		elif roll < 0.88:
			_press("down", 0.3)
		else:
			_move(away, 0.25)


func _move(direction: String, duration: float) -> void:
	_release("right" if direction == "left" else "left")
	_press(direction, duration)


func _action(action_name: String) -> String:
	return "p%d_%s" % [fighter.player_id, action_name]


func _press(action_name: String, duration: float) -> void:
	if not _held.has(action_name):
		Input.action_press(_action(action_name))
	_held[action_name] = maxf(duration, _held.get(action_name, 0.0))


func _release(action_name: String) -> void:
	if _held.has(action_name):
		Input.action_release(_action(action_name))
		_held.erase(action_name)


func _tick_held(delta: float) -> void:
	for action_name: String in _held.keys():
		_held[action_name] -= delta
		if _held[action_name] <= 0.0:
			_release(action_name)


func _release_all() -> void:
	for action_name: String in _held.keys():
		_release(action_name)
