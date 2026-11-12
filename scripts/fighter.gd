class_name Fighter
extends CharacterBody2D
## 原型用格鬥角色:狀態機 + 攻擊框 / 受擊框。目前用色塊代替美術。

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal defeated(fighter: Fighter)
## 自己「被」連段的狀況:hits 為連續受擊數,damage 為這段連段的累計傷害。歸零代表連段結束。
signal combo_changed(hits: int, damage: int)

enum State { IDLE, MOVE, JUMP, DASH, ATTACK, GUARD, HITSTUN, LAUNCHED, DOWN, GETUP, KO, TELEPORT, BURST, CAST, STUNNED }

# 氣量:一格 100,預設最多三格(實際上限看 max_energy)。
const MAX_ENERGY := 300
const START_ENERGY := 100
const SPECIAL_COST := 100
const SUPER_COST := 300
const TELEPORT_COST := 100
const ESCAPE_COST := 100
const ENERGY_PER_DAMAGE_DEALT := 0.3
const ENERGY_PER_DAMAGE_TAKEN := 0.2
const ENERGY_PER_DAMAGE_BLOCKED := 0.1
const TELEPORT_OFFSET := 75.0
const TELEPORT_TIME := 0.1
const BURST_TIME := 0.3
const BURST_RADIUS := 170.0
# 連段保護:每多一段傷害少 10%,最低 30%;到達上限的那一擊強制擊飛倒地。
const COMBO_DAMAGE_STEP := 0.1
const COMBO_DAMAGE_FLOOR := 0.3
const COMBO_HIT_LIMIT := 10
## 耗氣招式用的連段編號:視為地面招式,但不能再接下一段。
const SPECIAL_STEP := 99

const MOVE_SPEED := 320.0
const JUMP_VELOCITY := -720.0
const GRAVITY := 2000.0
const DASH_SPEED := 950.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.35
const DOWN_TIME := 0.7
const QUICK_GETUP_AFTER := 0.15
const GETUP_TIME := 0.25
const GUARD_DAMAGE_SCALE := 0.1
const GROUND_FRICTION := 3000.0
const BODY_SIZE := Vector2(50, 110)
const LYING_SIZE := Vector2(110, 36)

@export var player_id: int = 1
@export var body_color: Color = Color(0.9, 0.35, 0.3)
@export var max_health: int = 1000
## 氣量上限(每格 100)。預設三格,個別角色可以在場景裡調整。
@export var max_energy: int = MAX_ENERGY
## 角色素材資料夾(內含 sheet.png 與 sheet.json)。留空或沒有素材時以色塊顯示。
@export_dir var sprite_dir: String = ""

## 缺少某個動畫時改播的替代動畫。不在表內的名稱(角色專屬動作)會先試 "cast"。
const ANIM_FALLBACKS := {
	"walk": "idle", "jump": "idle", "dash": "walk", "teleport": "dash", "guard": "idle",
	"attack1": "idle", "attack2": "attack1", "attack3": "attack1", "air_attack": "attack1",
	"attack4": "attack2", "attack5": "attack3",
	"special": "attack3", "super": "special", "cast": "special", "burst": "cast",
	"hit": "idle", "stunned": "hit", "launched": "hit", "down": "launched", "ko": "down",
	"getup": "idle",
}

var opponent: Fighter
var state: State = State.IDLE
var facing: int = 1
var health: int = 0
var energy: int = 0
var input_enabled: bool = true
## 目前可活動的水平範圍,由主場景依鏡頭位置更新。
var arena_min_x: float = -INF
var arena_max_x: float = INF

var _state_time := 0.0
var _dash_cooldown := 0.0
var _dash_dir := 1
var _stun_time := 0.0
var _move: AttackData
var _combo_step := 0  # 地面連段的第幾段;-1 代表空中攻擊
var _combo_queued := false
var _hit_targets: Array[Fighter] = []
var _ground_moves: Array[AttackData] = []
var _air_move: AttackData
var _special_move: AttackData
var _super_move: AttackData
# 施法(CAST)狀態:到 release 時間點呼叫一次 callback,到 duration 結束。
var _cast_duration := 0.0
var _cast_release := 0.0
var _cast_callback: Callable
var _cast_fired := false
var _combo_hits := 0
var _combo_damage := 0
var _has_sprite := false
var _current_anim := ""
var _anim_restart := false
var _attack_anim := "attack1"
var _cast_anim := "cast"

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body: ColorRect = $Body
@onready var _eye: ColorRect = $Eye
@onready var _hitbox: Area2D = $Hitbox
@onready var _hit_shape: CollisionShape2D = $Hitbox/Shape
@onready var _hit_visual: ColorRect = $Hitbox/Visual


func _ready() -> void:
	# 場景內的子資源會被所有實例共用,所以攻擊框形狀在這裡各自建立。
	_hit_shape.shape = RectangleShape2D.new()
	_load_sprite()
	_build_moves()
	health = max_health
	_set_hitbox(false)
	_update_visual()


func _build_moves() -> void:
	# 地面三連擊:輕、輕、重(第三段擊飛倒地)
	_ground_moves = [
		AttackData.make(40, 0.06, 0.10, 0.18, Vector2(60, -70), Vector2(70, 36), Vector2(180, 0), 0.32),
		AttackData.make(50, 0.07, 0.10, 0.20, Vector2(65, -60), Vector2(80, 40), Vector2(200, 0), 0.34),
		AttackData.make(90, 0.10, 0.12, 0.30, Vector2(70, -65), Vector2(95, 60), Vector2(420, -520), 0.0, true, 220.0),
	]
	_air_move = AttackData.make(60, 0.05, 0.20, 0.10, Vector2(45, -40), Vector2(80, 60), Vector2(260, 0), 0.30, false, 0.0)
	# 大招(耗 1 格):前衝的大範圍擊飛,可以從連段第一、二段取消接上。
	_special_move = AttackData.make(160, 0.14, 0.14, 0.34, Vector2(95, -60), Vector2(170, 90), Vector2(520, -560), 0.0, true, 380.0)
	_special_move.builds_energy = false
	_special_move.color = Color(0.3, 0.95, 1.0, 0.8)
	# 超必殺(耗 3 格)
	_super_move = AttackData.make(380, 0.22, 0.20, 0.50, Vector2(140, -75), Vector2(300, 150), Vector2(700, -700), 0.0, true, 500.0)
	_super_move.builds_energy = false
	_super_move.color = Color(1.0, 0.35, 0.9, 0.8)


## 回合開始時重置角色。
func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = spawn_facing
	health = max_health
	_dash_cooldown = 0.0
	_set_hitbox(false)
	_end_combo()
	_set_state(State.IDLE, true)
	health_changed.emit(health, max_health)
	_set_energy(START_ENERGY)
	_update_visual()


func _physics_process(delta: float) -> void:
	_state_time += delta
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if state != State.DASH:
		velocity.y += GRAVITY * delta

	match state:
		State.IDLE, State.MOVE: _tick_ground()
		State.JUMP: _tick_air()
		State.DASH: _tick_dash()
		State.ATTACK: _tick_attack(delta)
		State.GUARD: _tick_guard(delta)
		State.HITSTUN: _tick_hitstun(delta)
		State.LAUNCHED: _tick_launched()
		State.DOWN: _tick_down(delta)
		State.GETUP: _tick_getup()
		State.KO: _apply_friction(delta)
		State.TELEPORT: _tick_teleport()
		State.BURST: _tick_burst()
		State.CAST: _tick_cast(delta)
		State.STUNNED: _tick_stunned(delta)

	move_and_slide()
	_update_visual()


# ---------- 各狀態 ----------

func _tick_ground() -> void:
	_face_opponent()
	if not is_on_floor():
		_set_state(State.JUMP)
		return
	if _try_energy_actions():
		return
	if _pressed("attack"):
		_start_attack(_ground_moves[0], 0)
		return
	if _pressed("jump"):
		velocity.y = JUMP_VELOCITY
		_set_state(State.JUMP)
		return
	if _pressed("dash") and _dash_cooldown <= 0.0:
		_start_dash()
		return
	if _held("down"):
		velocity.x = 0.0
		_set_state(State.GUARD)
		return
	var axis := _axis()
	velocity.x = axis * MOVE_SPEED
	_set_state(State.MOVE if axis != 0.0 else State.IDLE)


func _tick_air() -> void:
	velocity.x = _axis() * MOVE_SPEED
	if _pressed("attack"):
		_start_attack(_air_move, -1)
		return
	if _landed():
		_set_state(State.IDLE)


func _tick_dash() -> void:
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	if _state_time >= DASH_TIME:
		velocity.x = 0.0
		_dash_cooldown = DASH_COOLDOWN
		_set_state(State.IDLE)


func _tick_attack(delta: float) -> void:
	var airborne := _combo_step < 0
	if airborne:
		if _landed():
			_end_attack()
			return
	else:
		_apply_friction(delta)
		# 普通招式命中後,可以取消接大招、超必殺或幽步。
		if _combo_step < _ground_moves.size() and not _hit_targets.is_empty() and _try_energy_actions():
			return

	var active_end := _move.startup + _move.active
	var active_now := _state_time >= _move.startup and _state_time < active_end
	_set_hitbox(active_now)
	if active_now:
		_check_hits()

	if airborne:
		if _state_time >= active_end + _move.recovery:
			_end_attack()
		return

	if _pressed("attack"):
		_combo_queued = true
	# 判定結束後就能取消接下一段,手感比等收招結束更順。
	if _state_time >= active_end and _combo_queued and _combo_step + 1 < _ground_moves.size():
		_start_attack(_ground_moves[_combo_step + 1], _combo_step + 1)
	elif _state_time >= active_end + _move.recovery:
		_end_attack()


func _tick_guard(delta: float) -> void:
	_face_opponent()
	_apply_friction(delta)
	if not is_on_floor():
		_set_state(State.JUMP)
	elif _try_energy_actions():
		return
	elif not _held("down"):
		_set_state(State.IDLE)


func _tick_hitstun(delta: float) -> void:
	_apply_friction(delta)
	if _pressed("escape") and _spend_energy(ESCAPE_COST):
		_start_burst()
	elif _state_time >= _stun_time:
		_set_state(State.IDLE)


func _tick_teleport() -> void:
	velocity.x = 0.0
	if _state_time >= TELEPORT_TIME:
		_set_state(State.IDLE)


func _tick_burst() -> void:
	velocity.x = 0.0
	if _state_time >= BURST_TIME:
		_set_hitbox(false)
		_set_state(State.IDLE)


func _tick_cast(delta: float) -> void:
	_apply_friction(delta)
	if not _cast_fired and _state_time >= _cast_release:
		_cast_fired = true
		_cast_callback.call()
	if state == State.CAST and _state_time >= _cast_duration:
		_set_state(State.IDLE)


func _tick_stunned(delta: float) -> void:
	_apply_friction(delta)
	if _state_time >= _stun_time:
		_set_state(State.IDLE)


func _tick_launched() -> void:
	if _state_time > 0.05 and _landed():
		velocity.x = 0.0
		_set_state(State.DOWN)


func _tick_down(delta: float) -> void:
	_apply_friction(delta)
	var quick := _pressed("dash") and _state_time >= QUICK_GETUP_AFTER
	if quick or _state_time >= DOWN_TIME:
		_set_state(State.GETUP)


func _tick_getup() -> void:
	velocity.x = 0.0
	if _state_time >= GETUP_TIME:
		_set_state(State.IDLE)


# ---------- 動作 ----------

## 耗氣動作:大招(special)、超必殺(下 + special)、幽步(上或下 + dash)。
func _try_energy_actions() -> bool:
	if _try_character_actions():
		return true
	if _pressed("special"):
		if _held("down"):
			if _spend_energy(super_cost()):
				_start_super()
				return true
		elif _spend_energy(SPECIAL_COST):
			_start_attack(_special_move, SPECIAL_STEP)
			return true
	if _pressed("dash") and (_held("down") or _held("up")) and opponent != null:
		if _spend_energy(TELEPORT_COST):
			_start_teleport()
			return true
	return false


## 角色專屬技能的掛勾。子類別覆寫;有發動就回傳 true。
func _try_character_actions() -> bool:
	return false


## 超必殺的內容。子類別可覆寫成自己的招式;氣量已在呼叫前扣除。
func _start_super() -> void:
	_start_attack(_super_move, SPECIAL_STEP)


## 進入施法狀態:release_at 秒時呼叫 callback,duration 秒後恢復行動。
## 施法途中被打會中斷,callback 不會觸發。
## animation 是施法時播放的動畫名稱;素材沒有這個動畫時會退回 "cast"。
func _start_cast(duration: float, release_at: float, callback: Callable, animation: String = "cast") -> void:
	_set_hitbox(false)
	_cast_anim = animation
	_cast_duration = duration
	_cast_release = release_at
	_cast_callback = callback
	_cast_fired = false
	_set_state(State.CAST, true)


## 被定身:期間無法行動,仍會受到攻擊。幽步、脫出與 KO 期間無效。
func stun(duration: float, damage: int = 0) -> void:
	if state in [State.KO, State.TELEPORT, State.BURST]:
		return
	_set_hitbox(false)
	_set_health(health - _register_hit(damage))
	if health <= 0:
		velocity = Vector2(0.0, -300.0)
		_set_state(State.KO, true)
		defeated.emit(self)
		return
	velocity.x = 0.0
	_stun_time = duration
	_set_state(State.STUNNED, true)


func is_invulnerable() -> bool:
	return state in [State.KO, State.DOWN, State.GETUP, State.LAUNCHED, State.TELEPORT, State.BURST]


## 幽步:瞬間移動到對手背後。
func _start_teleport() -> void:
	_set_hitbox(false)
	var side := int(signf(opponent.global_position.x - global_position.x))
	if side == 0:
		side = facing
	var target_x := opponent.global_position.x + side * TELEPORT_OFFSET
	if target_x < arena_min_x or target_x > arena_max_x:
		# 對手貼在畫面邊緣,背後沒有空間:改為瞬移到對手面前。
		side = -side
		target_x = opponent.global_position.x + side * TELEPORT_OFFSET
	global_position.x = target_x
	velocity = Vector2.ZERO
	facing = -side
	_set_state(State.TELEPORT, true)


## 受擊脫出:無敵並把附近的對手彈開,不造成傷害。
func _start_burst() -> void:
	velocity = Vector2.ZERO
	_set_state(State.BURST, true)
	var burst_size := Vector2(BURST_RADIUS, BURST_RADIUS) * 2.0
	_hit_visual.color = Color(1, 1, 1, 0.45)
	_hit_visual.size = burst_size
	_hit_visual.position = Vector2(0, -BODY_SIZE.y / 2.0) - burst_size / 2.0
	_hit_visual.visible = true
	if opponent != null and global_position.distance_to(opponent.global_position) <= BURST_RADIUS:
		opponent.blown_away(self)


## 被對手的受擊脫出彈開。
func blown_away(source: Fighter) -> void:
	if state in [State.KO, State.DOWN, State.GETUP, State.LAUNCHED, State.TELEPORT, State.BURST]:
		return
	var away := int(signf(global_position.x - source.global_position.x))
	if away == 0:
		away = -source.facing
	_set_hitbox(false)
	velocity = Vector2(away * 500.0, -420.0)
	_set_state(State.LAUNCHED, true)

func _start_dash() -> void:
	var axis := _axis()
	_dash_dir = int(signf(axis)) if axis != 0.0 else facing
	_set_state(State.DASH)


func _start_attack(move: AttackData, combo_step: int) -> void:
	_move = move
	_combo_step = combo_step
	if combo_step < 0:
		_attack_anim = "air_attack"
	elif combo_step < _ground_moves.size():
		_attack_anim = "attack%d" % (combo_step + 1)
	else:
		_attack_anim = "super" if move == _super_move else "special"
	_combo_queued = false
	_hit_targets.clear()
	var shape := _hit_shape.shape as RectangleShape2D
	shape.size = move.hitbox_size
	var offset := Vector2(move.hitbox_offset.x * facing, move.hitbox_offset.y)
	_hit_shape.position = offset
	_hit_visual.color = move.color
	_hit_visual.size = move.hitbox_size
	_hit_visual.position = offset - move.hitbox_size / 2.0
	if combo_step >= 0:
		velocity.x = facing * move.lunge
	_set_state(State.ATTACK, true)


func _end_attack() -> void:
	_set_hitbox(false)
	_set_state(State.IDLE)


func _check_hits() -> void:
	for area in _hitbox.get_overlapping_areas():
		var target := area.get_parent() as Fighter
		if target == null or target == self or _hit_targets.has(target):
			continue
		_hit_targets.append(target)
		target.take_hit(_effective_move(_move), self)
		_on_attack_hit(target, _move)


## 實際套用到對手身上的招式數值。子類別可覆寫來做傷害強化等效果。
func _effective_move(move: AttackData) -> AttackData:
	return move


## 自己的招式命中對手後呼叫。子類別可覆寫來做追擊等效果。
func _on_attack_hit(_target: Fighter, _move: AttackData) -> void:
	pass


## 超必殺的耗氣量。子類別可依狀態改變。
func super_cost() -> int:
	return SUPER_COST


## 被招式命中。倒地、起身、被擊飛、幽步、脫出與 KO 期間無敵。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	if is_invulnerable():
		return
	var away := int(signf(global_position.x - attacker.global_position.x))
	if away == 0:
		away = attacker.facing

	if state == State.GUARD and facing == -away:
		# 防禦成功:只吃少量傷害,不會被防禦傷害打倒。
		_set_health(maxi(health - int(move.damage * GUARD_DAMAGE_SCALE), 1))
		velocity.x = away * 160.0
		add_energy(int(move.damage * ENERGY_PER_DAMAGE_BLOCKED))
		if move.builds_energy:
			attacker.add_energy(int(move.damage * ENERGY_PER_DAMAGE_BLOCKED))
		return

	_set_hitbox(false)
	var damage := _register_hit(move.damage)
	_set_health(health - damage)
	add_energy(int(damage * ENERGY_PER_DAMAGE_TAKEN))
	if move.builds_energy:
		attacker.add_energy(int(damage * ENERGY_PER_DAMAGE_DEALT))
	if health <= 0:
		velocity = Vector2(away * 350.0, -450.0)
		_set_state(State.KO, true)
		defeated.emit(self)
	elif move.launches:
		velocity = Vector2(away * move.knockback.x, move.knockback.y)
		_set_state(State.LAUNCHED, true)
	elif _combo_hits >= COMBO_HIT_LIMIT:
		# 連段到達上限:強制擊飛倒地,結束這段連段。
		velocity = Vector2(away * 320.0, -420.0)
		_set_state(State.LAUNCHED, true)
	elif not is_on_floor():
		velocity = Vector2(away * move.knockback.x, -300.0)
		_set_state(State.LAUNCHED, true)
	elif state == State.STUNNED:
		# 定身中被普通招式打到:扣血但維持定身,不重置時間。
		velocity.x = 0.0
	else:
		velocity.x = away * move.knockback.x
		_stun_time = move.hitstun
		_set_state(State.HITSTUN, true)


# ---------- 工具 ----------

func _set_state(new_state: State, force: bool = false) -> void:
	if new_state == state and not force:
		return
	state = new_state
	_state_time = 0.0
	_anim_restart = true
	if new_state == State.IDLE:
		_end_combo()


## 記錄一次受擊,回傳套用連段衰減後的實際傷害。
func _register_hit(raw_damage: int) -> int:
	var scale_factor := maxf(1.0 - COMBO_DAMAGE_STEP * _combo_hits, COMBO_DAMAGE_FLOOR)
	var damage := maxi(int(round(raw_damage * scale_factor)), 1) if raw_damage > 0 else 0
	_combo_hits += 1
	_combo_damage += damage
	combo_changed.emit(_combo_hits, _combo_damage)
	return damage


func _end_combo() -> void:
	if _combo_hits == 0:
		return
	_combo_hits = 0
	_combo_damage = 0
	combo_changed.emit(0, 0)


func _set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)


func add_energy(amount: int) -> void:
	_set_energy(energy + amount)


func _set_energy(value: int) -> void:
	energy = clampi(value, 0, max_energy)
	energy_changed.emit(energy, max_energy)


func _spend_energy(cost: int) -> bool:
	if energy < cost:
		return false
	_set_energy(energy - cost)
	return true


func _set_hitbox(enabled: bool) -> void:
	_hit_shape.disabled = not enabled
	_hit_visual.visible = enabled


func _apply_friction(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)


func _landed() -> bool:
	return is_on_floor() and velocity.y >= 0.0


func _face_opponent() -> void:
	if opponent == null:
		return
	var diff := opponent.global_position.x - global_position.x
	if absf(diff) > 1.0:
		facing = int(signf(diff))


## 在場景中放一個色塊(招式特效的暫代品,之後換成點陣特效)。
func _spawn_rect(rect_size: Vector2, color: Color, center: Vector2, z: int = 1) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	rect.size = rect_size
	rect.pivot_offset = rect_size / 2.0
	rect.position = center - rect_size / 2.0
	rect.z_index = z
	get_parent().add_child(rect)
	return rect


## 招式名稱浮字。
func _callout(text: String, color: Color) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color.lightened(0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.size = Vector2(400, 60)
	label.position = global_position + Vector2(-200, -200)
	label.z_index = 2
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)


## 以 center、rect_size 描述的矩形是否碰到對手的身體(對手無敵時為 false)。
func _rect_hits_opponent(center: Vector2, rect_size: Vector2) -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	var target_center := opponent.global_position + Vector2(0, -BODY_SIZE.y / 2.0)
	var reach := (rect_size + BODY_SIZE) / 2.0
	return absf(target_center.x - center.x) <= reach.x and absf(target_center.y - center.y) <= reach.y


func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func _axis() -> float:
	if not input_enabled:
		return 0.0
	return Input.get_axis(_action("left"), _action("right"))


func _pressed(action_name: String) -> bool:
	return input_enabled and Input.is_action_just_pressed(_action(action_name))


func _held(action_name: String) -> bool:
	return input_enabled and Input.is_action_pressed(_action(action_name))


## 載入角色素材。成功時改用動畫顯示並隱藏色塊。
func _load_sprite() -> void:
	var loaded := SpriteSheetLoader.load_character(sprite_dir)
	if loaded.is_empty():
		_sprite.visible = false
		return
	var canvas: Vector2 = loaded.canvas
	_sprite.sprite_frames = loaded.frames
	_sprite.scale = Vector2.ONE * float(loaded.scale)
	_sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y + float(loaded.foot_offset))
	_sprite.visible = true
	_has_sprite = true
	_body.visible = false
	_eye.visible = false

	# 同角色對戰時靠頭上的標籤分辨玩家。
	var tag := Label.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.text = "%dP" % player_id
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", body_color.lightened(0.25))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 5)
	tag.size = Vector2(60, 22)
	tag.position = Vector2(-30, -BODY_SIZE.y - 44)
	add_child(tag)


func _resolve_animation(animation: String) -> String:
	var frames := _sprite.sprite_frames
	for attempt in 8:
		if frames.has_animation(animation):
			return animation
		if ANIM_FALLBACKS.has(animation):
			animation = ANIM_FALLBACKS[animation]
		elif animation != "idle":
			animation = "cast"
		else:
			break
	return ""


func _update_sprite() -> void:
	var animation := "idle"
	var duration := 0.0  # 大於 0 時,調整播放速度讓動畫剛好在這段時間內播完
	match state:
		State.MOVE: animation = "walk"
		State.JUMP: animation = "jump"
		State.DASH: animation = "dash"
		State.TELEPORT: animation = "teleport"
		State.GUARD: animation = "guard"
		State.ATTACK:
			animation = _attack_anim
			duration = _move.startup + _move.active + _move.recovery
		State.CAST:
			animation = _cast_anim
			duration = _cast_duration
		State.BURST: animation = "burst"
		State.HITSTUN: animation = "hit"
		State.STUNNED: animation = "stunned"
		State.LAUNCHED: animation = "launched"
		State.DOWN: animation = "down"
		State.GETUP:
			animation = "getup"
			duration = GETUP_TIME
		State.KO: animation = "ko" if is_on_floor() else "launched"

	animation = _resolve_animation(animation)
	if animation != "" and (animation != _current_anim or _anim_restart):
		var frames := _sprite.sprite_frames
		var natural := frames.get_frame_count(animation) / maxf(frames.get_animation_speed(animation), 0.01)
		_sprite.speed_scale = natural / duration if duration > 0.0 else 1.0
		_sprite.stop()
		_sprite.play(animation)
		_current_anim = animation
	_anim_restart = false
	_sprite.flip_h = facing < 0

	var tint := Color.WHITE
	match state:
		State.HITSTUN, State.LAUNCHED: tint = Color(1.8, 1.8, 1.8)
		State.GUARD: tint = Color(0.6, 0.6, 0.7)
		State.GETUP, State.TELEPORT: tint = Color(1, 1, 1, 0.5)
		State.BURST: tint = Color(1.6, 1.6, 1.0)
		State.STUNNED: tint = Color(0.75, 0.55, 1.0)
		State.KO: tint = Color(0.55, 0.55, 0.55)
	_sprite.modulate = tint


func _update_visual() -> void:
	if _has_sprite:
		_update_sprite()
		return
	var lying := state == State.DOWN or (state == State.KO and is_on_floor())
	if lying:
		_body.size = LYING_SIZE
		_body.position = Vector2(-LYING_SIZE.x / 2.0, -LYING_SIZE.y)
	else:
		_body.size = BODY_SIZE
		_body.position = Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y)
	_eye.visible = not lying
	_eye.position = Vector2(facing * 14.0 - _eye.size.x / 2.0, -98.0)

	var color := body_color
	match state:
		State.HITSTUN, State.LAUNCHED: color = body_color.lerp(Color.WHITE, 0.7)
		State.GUARD: color = body_color.darkened(0.45)
		State.DASH: color = body_color.lightened(0.35)
		State.GETUP, State.TELEPORT: color = Color(body_color, 0.5)
		State.BURST: color = body_color.lerp(Color(1, 1, 0.6), 0.8)
		State.CAST: color = body_color.lerp(Color(0.75, 0.9, 1.0), 0.6)
		State.STUNNED: color = body_color.lerp(Color(0.55, 0.3, 0.8), 0.75)
		State.KO: color = body_color.darkened(0.6)
	_body.color = color
