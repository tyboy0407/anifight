class_name SukunaFighter
extends Fighter
## 以兩面宿儺為藍本的角色。
## 解(skill):遠距離斬擊,判定高、飛得遠、傷害低。不耗氣,有冷卻。
## 捌(上 + skill):只有近身才能發動的多段斬擊,傷害高,最後一擊擊飛。耗 1 格氣。
## 領域展開・伏魔御廚子(下 + special):開放型領域,10 秒內場上隨機位置不斷落下斬擊。耗 3 格氣。

const SLASH_COLOR := Color(1.0, 0.95, 0.95)
const BLOOD_COLOR := Color(0.9, 0.15, 0.2)

# 解
const DISMANTLE_COOLDOWN := 1.2
const DISMANTLE_CAST := 0.42
const DISMANTLE_RELEASE := 0.16
const DISMANTLE_SIZE := Vector2(46, 150)
const DISMANTLE_OFFSET := Vector2(50, -75)
const DISMANTLE_SPEED := 1150.0
const DISMANTLE_LIFETIME := 0.75
# 捌
const CLEAVE_COST := 100
const CLEAVE_RANGE := 140.0
const CLEAVE_HEIGHT_TOLERANCE := 90.0
const CLEAVE_CAST := 0.95
const CLEAVE_FIRST_HIT := 0.15
const CLEAVE_INTERVAL := 0.11
const CLEAVE_HITS := 6
# 伏魔御廚子
const DOMAIN_CAST := 0.85
const DOMAIN_RELEASE := 0.55
const DOMAIN_DURATION := 10.0
const DOMAIN_SLASH_INTERVAL := 0.16
const DOMAIN_SLASH_WARN := 0.30  # 斬擊落下前的預兆時間,讓對手有機會閃
const DOMAIN_SLASH_ACTIVE := 0.10
const DOMAIN_SLASH_SIZE := Vector2(130, 700)

var _dismantle_cooldown := 0.0
var _dismantle_time := 0.0
var _dismantle_direction := 1
var _dismantle_node: ColorRect
var _dismantle_move: AttackData

var _cleave_hits_left := 0
var _cleave_timer := 0.0
var _cleave_move: AttackData
var _cleave_final_move: AttackData

var _domain_time := 0.0
var _domain_slash_timer := 0.0
var _domain_floor_y := 0.0
var _domain_backdrop: Node2D
var _domain_slashes: Array[Dictionary] = []  # {node, x, age, hit}
var _domain_move: AttackData
var _rng := RandomNumberGenerator.new()

@onready var _hair: ColorRect = $Hair
@onready var _marks: ColorRect = $Marks


func _ready() -> void:
	super()
	_rng.randomize()
	_dismantle_move = AttackData.make(55, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(200, 0), 0.30, false, 0.0)
	_cleave_move = AttackData.make(40, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.30, false, 0.0)
	_cleave_move.builds_energy = false
	_cleave_final_move = AttackData.make(60, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(380, -520), 0.0, true, 0.0)
	_cleave_final_move.builds_energy = false
	_domain_move = AttackData.make(35, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(60, 0), 0.22, false, 0.0)
	_domain_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_dismantle()
	_cleave_hits_left = 0
	_end_domain()
	_dismantle_cooldown = 0.0
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_dismantle_cooldown = maxf(_dismantle_cooldown - delta, 0.0)
	_tick_dismantle(delta)
	_tick_cleave(delta)
	_tick_domain(delta)


func _try_character_actions() -> bool:
	if _skill2_pressed():
		# 捌:對手不在近身範圍內就放不出來,也不扣氣。
		if _opponent_in_cleave_range(1.0) and _spend_energy(CLEAVE_COST):
			_start_cast(CLEAVE_CAST, CLEAVE_FIRST_HIT, _begin_cleave)
			return true
		return false
	if _skill1_pressed() and _dismantle_cooldown <= 0.0:
		_dismantle_cooldown = DISMANTLE_COOLDOWN
		_start_cast(DISMANTLE_CAST, DISMANTLE_RELEASE, _release_dismantle)
		return true
	return false


func _start_super() -> void:
	_start_cast(DOMAIN_CAST, DOMAIN_RELEASE, _release_domain)


func ai_skill2_range() -> float:
	return CLEAVE_RANGE


# ---------- 解 ----------

func _release_dismantle() -> void:
	_clear_dismantle()
	_dismantle_direction = facing
	_dismantle_time = DISMANTLE_LIFETIME
	var center := global_position + Vector2(DISMANTLE_OFFSET.x * facing, DISMANTLE_OFFSET.y)
	_dismantle_node = _spawn_rect(DISMANTLE_SIZE, SLASH_COLOR, center)
	_dismantle_node.rotation = 0.25 * facing
	_callout("解", SLASH_COLOR)


func _tick_dismantle(delta: float) -> void:
	if _dismantle_time <= 0.0:
		return
	_dismantle_time -= delta
	_dismantle_node.position.x += _dismantle_direction * DISMANTLE_SPEED * delta
	var center := _dismantle_node.position + DISMANTLE_SIZE / 2.0
	if _rect_hits_opponent(center, DISMANTLE_SIZE):
		opponent.take_hit(_dismantle_move, self)
		_clear_dismantle()
	elif _dismantle_time <= 0.0:
		_clear_dismantle()


func _clear_dismantle() -> void:
	_dismantle_time = 0.0
	if is_instance_valid(_dismantle_node):
		_dismantle_node.queue_free()
	_dismantle_node = null


# ---------- 捌 ----------

func _opponent_in_cleave_range(range_scale: float) -> bool:
	if opponent == null:
		return false
	var offset := opponent.global_position - global_position
	return absf(offset.x) <= CLEAVE_RANGE * range_scale and absf(offset.y) <= CLEAVE_HEIGHT_TOLERANCE


func _begin_cleave() -> void:
	_cleave_hits_left = CLEAVE_HITS
	_cleave_timer = 0.0
	_callout("捌", BLOOD_COLOR)


func _tick_cleave(delta: float) -> void:
	if _cleave_hits_left <= 0:
		return
	if state != State.CAST:
		# 被打斷
		_cleave_hits_left = 0
		return
	_cleave_timer -= delta
	if _cleave_timer > 0.0:
		return
	_cleave_timer = CLEAVE_INTERVAL
	_cleave_hits_left -= 1

	var slash_center := global_position + Vector2(facing * 85.0, -60.0) \
			+ Vector2(_rng.randf_range(-25, 25), _rng.randf_range(-35, 35))
	_flash_slash(slash_center, Vector2(190, 7), _rng.randf_range(-1.2, 1.2), SLASH_COLOR, 0.16)

	# 發動後對手被打退一點也還打得到,所以判定範圍放寬。
	if _opponent_in_cleave_range(1.4) and not opponent.is_invulnerable():
		opponent.take_hit(_cleave_final_move if _cleave_hits_left == 0 else _cleave_move, self)


# ---------- 領域展開・伏魔御廚子 ----------

func _release_domain() -> void:
	_end_domain()
	_domain_time = DOMAIN_DURATION
	_domain_slash_timer = 0.0
	_domain_floor_y = global_position.y
	_domain_backdrop = _make_domain_backdrop()


func _tick_domain(delta: float) -> void:
	if _domain_time <= 0.0:
		return
	_domain_time -= delta
	if state == State.KO or _domain_time <= 0.0:
		_end_domain()
		return

	_domain_slash_timer -= delta
	if _domain_slash_timer <= 0.0:
		_domain_slash_timer = DOMAIN_SLASH_INTERVAL
		_spawn_domain_slash()

	var finished: Array[Dictionary] = []
	for slash in _domain_slashes:
		slash.age += delta
		var node: ColorRect = slash.node
		if slash.age < DOMAIN_SLASH_WARN:
			continue
		if slash.age >= DOMAIN_SLASH_WARN + DOMAIN_SLASH_ACTIVE:
			finished.append(slash)
			continue
		node.color = SLASH_COLOR
		var center := Vector2(slash.x, _domain_floor_y - DOMAIN_SLASH_SIZE.y / 2.0)
		if not slash.hit and _rect_hits_opponent(center, DOMAIN_SLASH_SIZE):
			slash.hit = true
			opponent.take_hit(_domain_move, self)
	for slash in finished:
		slash.node.queue_free()
		_domain_slashes.erase(slash)


## 在場上隨機位置落下一道斬擊:先出現半透明預兆,之後才有判定。
func _spawn_domain_slash() -> void:
	var x := _rng.randf_range(arena_min_x, arena_max_x)
	var center := Vector2(x, _domain_floor_y - DOMAIN_SLASH_SIZE.y / 2.0)
	# z = -1:畫在領域背景之上、角色之後,斬擊落下時仍看得到角色。
	var node := _spawn_rect(DOMAIN_SLASH_SIZE, Color(BLOOD_COLOR, 0.28), center, -1)
	_domain_slashes.append({"node": node, "x": x, "age": 0.0, "hit": false})


func _make_domain_backdrop() -> Node2D:
	var effect := Node2D.new()
	effect.z_index = -1  # 蓋住背景,但在角色後面
	effect.modulate = Color(1, 1, 1, 0)
	get_parent().add_child(effect)

	var haze := ColorRect.new()
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.color = Color(0.22, 0.02, 0.04, 0.82)
	haze.size = Vector2(6000, 4000)
	haze.position = global_position + Vector2(0, -250) - haze.size / 2.0
	effect.add_child(haze)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "領域展開\n伏魔御廚子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	title.size = Vector2(700, 180)
	title.position = Vector2(global_position.x - 350, 110)
	effect.add_child(title)

	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 1.0, 0.25)
	tween.tween_interval(1.4)
	tween.tween_property(title, "modulate:a", 0.0, 0.4)
	return effect


func _end_domain() -> void:
	_domain_time = 0.0
	for slash in _domain_slashes:
		if is_instance_valid(slash.node):
			slash.node.queue_free()
	_domain_slashes.clear()
	if is_instance_valid(_domain_backdrop):
		var backdrop := _domain_backdrop
		var tween := backdrop.create_tween()
		tween.tween_property(backdrop, "modulate:a", 0.0, 0.3)
		tween.tween_callback(backdrop.queue_free)
	_domain_backdrop = null


# ---------- 共用 ----------

## 一閃即逝的斬擊線。
func _flash_slash(center: Vector2, slash_size: Vector2, angle: float, color: Color, duration: float) -> void:
	var node := _spawn_rect(slash_size, color, center, 2)
	node.rotation = angle
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_callback(node.queue_free)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	_marks.visible = _eye.visible
