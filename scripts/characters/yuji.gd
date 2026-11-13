class_name YujiFighter
extends Fighter
## 以虎杖悠仁為藍本的角色。徒手四連擊。
##
## 被動
##   黑閃:所有攻擊命中時有 1% 機率觸發,該次傷害 2 倍,並進入心流狀態。
##   心流:持續 30 秒,期間持續回復氣量,黑閃機率提升到 10%。
##         心流期間再觸發黑閃不會刷新時間,要等心流結束才能重新進入。
## 招式
##   逕庭拳(skill,1 格):揮拳命中時不造成傷害,約 1 秒後在對手身上爆出藍色咒力衝擊波並擊退。
##   格檔(上 + skill,1 格):舉手格檔 1 秒,期間被近身攻擊會抵銷該次傷害並反擊兩拳。
##   黑閃(下 + special,3 格):向前揮拳,命中必定觸發黑閃。

const FLASH_COLOR := Color(0.85, 0.08, 0.12)
const CURSE_COLOR := Color(0.35, 0.65, 1.0)

# 黑閃 / 心流
const BLACK_FLASH_CHANCE := 0.01
const FLOW_BLACK_FLASH_CHANCE := 0.10
const BLACK_FLASH_DAMAGE_SCALE := 2.0
const FLOW_DURATION := 30.0
const FLOW_ENERGY_PER_SECOND := 10.0
# 逕庭拳
const DIVERGENT_COST := 100
const DIVERGENT_CAST := 0.45
const DIVERGENT_RELEASE := 0.14
const DIVERGENT_REACH_OFFSET := Vector2(75, -60)
const DIVERGENT_REACH_SIZE := Vector2(140, 110)
const DIVERGENT_TOUCH_STAGGER := 0.25
const DIVERGENT_DELAY := 1.0
# 格檔
const PARRY_COST := 100
const PARRY_DURATION := 1.0
const PARRY_RANGE := 190.0     # 攻擊者在這個距離內才算近身攻擊;遠程招式擋不掉
const PARRY_STAGGER := 0.6
const COUNTER_CAST := 0.55
const COUNTER_FIRST_HIT := 0.10
const COUNTER_INTERVAL := 0.20
const COUNTER_REACH := 230.0
# 大招:黑閃
const ULTIMATE_DAMAGE := 180   # 必定黑閃,實際是 2 倍

## 黑閃機率。獨立成變數是為了測試時可以調整。
var black_flash_chance := BLACK_FLASH_CHANCE
var flow_black_flash_chance := FLOW_BLACK_FLASH_CHANCE

var _flow_time := 0.0
var _flow_energy := 0.0  # 尚未滿 1 點的回復量
var _doubled: Dictionary = {}  # 原招式 -> 傷害 2 倍的複本
var _strike_flash := false
var _strike_health := 0

var _ultimate_move: AttackData
var _divergent_time := 0.0
var _divergent_marker: ColorRect
var _divergent_burst_move: AttackData

var _parrying := false
var _counter_hits_left := 0
var _counter_timer := 0.0
var _counter_move: AttackData
var _counter_final_move: AttackData

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", FLASH_COLOR.lightened(0.45))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 徒手四連擊,最後一擊擊飛
	_ground_moves = [
		AttackData.make(40, 0.05, 0.10, 0.16, Vector2(60, -70), Vector2(70, 36), Vector2(170, 0), 0.32),
		AttackData.make(45, 0.06, 0.10, 0.16, Vector2(62, -62), Vector2(76, 40), Vector2(180, 0), 0.32),
		AttackData.make(55, 0.07, 0.10, 0.18, Vector2(66, -58), Vector2(86, 46), Vector2(190, 0), 0.34),
		AttackData.make(95, 0.10, 0.12, 0.30, Vector2(72, -65), Vector2(100, 60), Vector2(440, -540), 0.0, true, 230.0),
	]
	_ultimate_move = AttackData.make(ULTIMATE_DAMAGE, 0.16, 0.14, 0.40, Vector2(90, -62), Vector2(170, 90), Vector2(720, -560), 0.0, true, 420.0)
	_ultimate_move.builds_energy = false
	_ultimate_move.color = Color(0.1, 0.02, 0.04, 0.85)
	_divergent_burst_move = AttackData.make(120, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(650, -420), 0.0, true, 0.0)
	_divergent_burst_move.builds_energy = false
	_counter_move = AttackData.make(70, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(60, 0), 0.40, false, 0.0)
	_counter_move.builds_energy = false
	_counter_final_move = AttackData.make(90, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(460, -500), 0.0, true, 0.0)
	_counter_final_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_flow_time = 0.0
	_flow_energy = 0.0
	_parrying = false
	_counter_hits_left = 0
	_clear_divergent()
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_tick_flow(delta)
	_tick_divergent(delta)
	_tick_counter(delta)
	if _parrying and state != State.CAST:
		_parrying = false  # 格檔時間到,或被遠程招式打斷
	_status_label.text = "心流 %d" % ceili(_flow_time) if in_flow() else ""


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(PARRY_COST):
			_start_parry()
			return true
		return false
	if _skill1_pressed() and _spend_energy(DIVERGENT_COST):
		_start_cast(DIVERGENT_CAST, DIVERGENT_RELEASE, _release_divergent, "attack2")
		return true
	return false


func _start_super() -> void:
	_start_attack(_ultimate_move, SPECIAL_STEP)


func ai_skill_range() -> float:
	return DIVERGENT_REACH_SIZE.x


func ai_skill2_range() -> float:
	return PARRY_RANGE


# ---------- 黑閃與心流 ----------

func in_flow() -> bool:
	return _flow_time > 0.0


func current_black_flash_chance() -> float:
	return flow_black_flash_chance if in_flow() else black_flash_chance


## 出手前:決定這一擊是不是黑閃,並回傳實際要套用的招式數值。
func _prepare_strike(move: AttackData) -> AttackData:
	_strike_health = opponent.health if opponent != null else 0
	_strike_flash = move == _ultimate_move or randf() < current_black_flash_chance()
	if not _strike_flash:
		return move
	if not _doubled.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * BLACK_FLASH_DAMAGE_SCALE))
		_doubled[move] = copy
	return _doubled[move]


## 出手後:這一擊真的打中(沒被防禦、對手不是無敵)才算觸發黑閃。
func _finish_strike(target: Fighter) -> void:
	if not _strike_flash:
		return
	_strike_flash = false
	if target.health >= _strike_health or target.state == State.GUARD:
		return
	_callout("黑閃", FLASH_COLOR)
	_spark(target.global_position + Vector2(0, -60))
	if not in_flow():
		# 心流期間再觸發黑閃不會刷新時間
		_flow_time = FLOW_DURATION
		_flow_energy = 0.0


## 不經過攻擊框、直接命中對手的招式(衝擊波、反擊)也走同一套黑閃判定。
func _strike(move: AttackData) -> void:
	if opponent == null:
		return
	opponent.take_hit(_prepare_strike(move), self)
	_finish_strike(opponent)


func _effective_move(move: AttackData) -> AttackData:
	return _prepare_strike(move)


func _on_attack_hit(target: Fighter, _move_used: AttackData) -> void:
	_finish_strike(target)


func _tick_flow(delta: float) -> void:
	if not in_flow():
		return
	_flow_time = maxf(_flow_time - delta, 0.0)
	if state == State.KO:
		return
	_flow_energy += FLOW_ENERGY_PER_SECOND * delta
	if _flow_energy >= 1.0:
		var whole := int(_flow_energy)
		_flow_energy -= whole
		add_energy(whole)


## 黑閃的火花:黑色與紅色交錯的閃電狀線條。
func _spark(center: Vector2) -> void:
	for i in 7:
		var bolt := _spawn_rect(Vector2(randf_range(120, 210), 7), Color(0.05, 0.02, 0.04) if i % 2 == 0 else FLASH_COLOR, center, 3)
		bolt.rotation = randf_range(-PI, PI)
		var tween := bolt.create_tween()
		tween.tween_property(bolt, "modulate:a", 0.0, 0.28)
		tween.tween_callback(bolt.queue_free)


# ---------- 逕庭拳 ----------

func _release_divergent() -> void:
	_callout("逕庭拳", CURSE_COLOR)
	var center := global_position + Vector2(DIVERGENT_REACH_OFFSET.x * facing, DIVERGENT_REACH_OFFSET.y)
	if not _rect_hits_opponent(center, DIVERGENT_REACH_SIZE):
		return
	var side := int(signf(opponent.global_position.x - global_position.x))
	if opponent.state == State.GUARD and opponent.facing == -side:
		return  # 被防禦住,咒力沒有打進去
	# 拳頭本身不造成傷害,只讓對手頓一下;咒力稍後才爆開
	opponent.stagger(DIVERGENT_TOUCH_STAGGER)
	_clear_divergent()
	_divergent_time = DIVERGENT_DELAY
	_divergent_marker = _spawn_rect(Vector2(18, 18), CURSE_COLOR, opponent.global_position + Vector2(0, -60), 3)


func _tick_divergent(delta: float) -> void:
	if _divergent_time <= 0.0:
		return
	_divergent_time -= delta
	var chest := opponent.global_position + Vector2(0, -60)
	# 對手身上閃爍的咒力殘留,越接近爆發越大
	var grow := 18.0 + 22.0 * (1.0 - _divergent_time / DIVERGENT_DELAY)
	_divergent_marker.size = Vector2(grow, grow)
	_divergent_marker.pivot_offset = _divergent_marker.size / 2.0
	_divergent_marker.position = chest - _divergent_marker.size / 2.0
	_divergent_marker.rotation += delta * 9.0
	_divergent_marker.modulate.a = 0.55 + 0.45 * sin(_divergent_time * 40.0)
	if _divergent_time > 0.0:
		return

	_clear_divergent()
	# 衝擊波:由小變大的藍色方框
	for i in 2:
		var wave := _spawn_rect(Vector2(70, 70), Color(CURSE_COLOR, 0.75 - 0.3 * i), chest, 2)
		wave.rotation = PI / 4.0 * i
		var tween := wave.create_tween()
		tween.tween_property(wave, "scale", Vector2(4.0, 4.0), 0.3)
		tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.3)
		tween.tween_callback(wave.queue_free)
	_strike(_divergent_burst_move)


func _clear_divergent() -> void:
	_divergent_time = 0.0
	if is_instance_valid(_divergent_marker):
		_divergent_marker.queue_free()
	_divergent_marker = null


# ---------- 格檔 ----------

func _start_parry() -> void:
	_parrying = true
	_callout("格檔", Color(0.9, 0.9, 1.0))
	# release 時間設在結束之後,所以只會維持架式,不會觸發 callback
	_start_cast(PARRY_DURATION, PARRY_DURATION + 1.0, func() -> void: pass, "guard")


func _can_parry(attacker: Fighter) -> bool:
	var offset := attacker.global_position.x - global_position.x
	if absf(offset) > PARRY_RANGE:
		return false
	return absf(offset) < 10.0 or int(signf(offset)) == facing


## 格檔中被近身攻擊:抵銷這次傷害,改為反擊。其他情況照常受擊。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	if _parrying and state == State.CAST and _can_parry(attacker):
		_start_counter(attacker)
		return
	super(move, attacker)


func _start_counter(attacker: Fighter) -> void:
	_parrying = false
	_callout("反擊", Color(1.0, 0.9, 0.5))
	attacker.stagger(PARRY_STAGGER)
	_counter_hits_left = 2
	_counter_timer = COUNTER_FIRST_HIT
	_start_cast(COUNTER_CAST, COUNTER_CAST + 1.0, func() -> void: pass, "attack1")


func _tick_counter(delta: float) -> void:
	if _counter_hits_left <= 0:
		return
	if state != State.CAST:
		_counter_hits_left = 0
		return
	_counter_timer -= delta
	if _counter_timer > 0.0:
		return
	_counter_timer = COUNTER_INTERVAL
	_counter_hits_left -= 1
	var is_last := _counter_hits_left == 0
	# 第二拳換一個出拳動作
	_cast_anim = "attack2" if is_last else "attack1"
	_anim_restart = true
	if opponent == null or opponent.is_invulnerable():
		return
	if global_position.distance_to(opponent.global_position) > COUNTER_REACH:
		return
	var impact := _spawn_rect(Vector2(90, 40), Color(1.0, 0.95, 0.6, 0.85), opponent.global_position + Vector2(-facing * 20.0, -62), 2)
	var tween := impact.create_tween()
	tween.tween_property(impact, "modulate:a", 0.0, 0.14)
	tween.tween_callback(impact.queue_free)
	_strike(_counter_final_move if is_last else _counter_move)


# ---------- 顯示 ----------

func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	if _has_sprite and in_flow() and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH, State.CAST]:
		_sprite.modulate = Color(1.35, 0.85, 0.85)
