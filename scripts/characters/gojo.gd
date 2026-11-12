class_name GojoFighter
extends Fighter
## 以五條悟為藍本的角色。
## 蒼(skill):在前方生成吸引點,把對手拉過去並造成多段小傷害。不耗氣,有冷卻。
## 赫(上 + skill):向前射出排斥彈,命中造成大傷害並擊飛。耗 1 格氣。
## 領域展開・無量空處(下 + special):定身對手一段時間。耗 3 格氣,取代通用超必殺。

# 蒼
const BLUE_COOLDOWN := 2.0
const BLUE_CAST := 0.45
const BLUE_RELEASE := 0.20
const BLUE_OFFSET := Vector2(240, -60)
const BLUE_DURATION := 0.9
const BLUE_RANGE := 430.0
const BLUE_PULL_SPEED := 430.0
const BLUE_TICK := 0.2
const BLUE_HIT_RADIUS := 80.0
const BLUE_SIZE := 64.0
const BLUE_COLOR := Color(0.3, 0.55, 1.0)
# 赫
const RED_COST := 100
const RED_CAST := 0.50
const RED_RELEASE := 0.28
const RED_OFFSET := Vector2(50, -60)
const RED_SPEED := 950.0
const RED_LIFETIME := 0.9
const RED_SIZE := 56.0
const RED_COLOR := Color(1.0, 0.25, 0.25)
# 領域展開
const DOMAIN_CAST := 0.90
const DOMAIN_RELEASE := 0.55
const DOMAIN_STUN := 2.6
const DOMAIN_DAMAGE := 120
const DOMAIN_FADE := 0.25

var _blue_cooldown := 0.0
var _blue_time := 0.0
var _blue_tick := 0.0
var _blue_position := Vector2.ZERO
var _blue_node: ColorRect
var _blue_move: AttackData

var _red_time := 0.0
var _red_direction := 1
var _red_node: ColorRect
var _red_move: AttackData

var _domain_node: Node2D

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_blue_move = AttackData.make(25, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.28, false, 0.0)
	_blue_move.builds_energy = false
	_red_move = AttackData.make(180, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(750, -500), 0.0, true, 0.0)
	_red_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_blue()
	_clear_red()
	_clear_domain()
	_blue_cooldown = 0.0
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_blue_cooldown = maxf(_blue_cooldown - delta, 0.0)
	_tick_blue(delta)
	_tick_red(delta)


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(RED_COST):
			_start_cast(RED_CAST, RED_RELEASE, _release_red)
			return true
		return false
	if _skill1_pressed() and _blue_cooldown <= 0.0:
		_blue_cooldown = BLUE_COOLDOWN
		_start_cast(BLUE_CAST, BLUE_RELEASE, _release_blue)
		return true
	return false


func _start_super() -> void:
	_start_cast(DOMAIN_CAST, DOMAIN_RELEASE, _release_domain)


# ---------- 蒼 ----------

func _release_blue() -> void:
	_clear_blue()
	_blue_position = global_position + Vector2(BLUE_OFFSET.x * facing, BLUE_OFFSET.y)
	_blue_position.x = clampf(_blue_position.x, arena_min_x, arena_max_x)
	_blue_time = BLUE_DURATION
	_blue_tick = 0.0
	_blue_node = _make_orb(BLUE_SIZE, BLUE_COLOR, _blue_position)
	_callout("蒼", BLUE_COLOR)


func _tick_blue(delta: float) -> void:
	if _blue_time <= 0.0:
		return
	_blue_time -= delta
	_blue_tick -= delta
	# 讓吸引點有脈動感
	var pulse := 1.0 + 0.25 * sin(_blue_time * 30.0)
	_blue_node.scale = Vector2(pulse, pulse)

	if opponent != null and not opponent.is_invulnerable():
		var distance := absf(_blue_position.x - opponent.global_position.x)
		if distance <= BLUE_RANGE:
			opponent.global_position.x = move_toward(opponent.global_position.x, _blue_position.x, BLUE_PULL_SPEED * delta)
			distance = absf(_blue_position.x - opponent.global_position.x)
			if distance <= BLUE_HIT_RADIUS and _blue_tick <= 0.0:
				_blue_tick = BLUE_TICK
				opponent.take_hit(_blue_move, self)

	if _blue_time <= 0.0:
		_clear_blue()


func _clear_blue() -> void:
	_blue_time = 0.0
	if is_instance_valid(_blue_node):
		_blue_node.queue_free()
	_blue_node = null


# ---------- 赫 ----------

func _release_red() -> void:
	_clear_red()
	_red_direction = facing
	_red_time = RED_LIFETIME
	_red_node = _make_orb(RED_SIZE, RED_COLOR, global_position + Vector2(RED_OFFSET.x * facing, RED_OFFSET.y))
	_callout("赫", RED_COLOR)


func _tick_red(delta: float) -> void:
	if _red_time <= 0.0:
		return
	_red_time -= delta
	_red_node.position.x += _red_direction * RED_SPEED * delta
	var center := _red_node.position + _red_node.size / 2.0

	if opponent != null and not opponent.is_invulnerable():
		var target_center := opponent.global_position + Vector2(0, -BODY_SIZE.y / 2.0)
		var reach := Vector2(RED_SIZE + BODY_SIZE.x, RED_SIZE + BODY_SIZE.y) / 2.0
		if absf(target_center.x - center.x) <= reach.x and absf(target_center.y - center.y) <= reach.y:
			opponent.take_hit(_red_move, self)
			_clear_red()
			return

	if _red_time <= 0.0:
		_clear_red()


func _clear_red() -> void:
	_red_time = 0.0
	if is_instance_valid(_red_node):
		_red_node.queue_free()
	_red_node = null


# ---------- 領域展開・無量空處 ----------

func _release_domain() -> void:
	_clear_domain()
	_domain_node = _make_domain_effect()
	if opponent != null:
		opponent.stun(DOMAIN_STUN, DOMAIN_DAMAGE)


func _make_domain_effect() -> Node2D:
	var effect := Node2D.new()
	effect.z_index = -1  # 蓋住背景,但在角色後面
	effect.modulate = Color(1, 1, 1, 0)
	get_parent().add_child(effect)

	var center := global_position + Vector2(0, -250)
	var darkness := ColorRect.new()
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.color = Color(0.02, 0.02, 0.07, 0.94)
	darkness.size = Vector2(6000, 4000)
	darkness.position = center - darkness.size / 2.0
	effect.add_child(darkness)

	# 星點
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261111
	for i in 140:
		var star := ColorRect.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star_size := rng.randf_range(2.0, 6.0)
		star.size = Vector2(star_size, star_size)
		star.position = center + Vector2(rng.randf_range(-1300, 1300), rng.randf_range(-520, 320))
		star.color = Color(0.8, 0.9, 1.0, rng.randf_range(0.4, 1.0))
		effect.add_child(star)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "領域展開\n無量空處"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.size = Vector2(700, 180)
	title.position = Vector2(global_position.x - 350, 110)
	effect.add_child(title)

	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 1.0, DOMAIN_FADE)
	tween.tween_interval(DOMAIN_STUN - DOMAIN_FADE * 2.0)
	tween.tween_property(effect, "modulate:a", 0.0, DOMAIN_FADE)
	tween.tween_callback(effect.queue_free)
	return effect


func _clear_domain() -> void:
	if is_instance_valid(_domain_node):
		_domain_node.queue_free()
	_domain_node = null


# ---------- 共用 ----------

## 在場景中建立一個方形能量體(之後換成點陣特效)。
func _make_orb(orb_size: float, color: Color, center: Vector2) -> ColorRect:
	return _spawn_rect(Vector2(orb_size, orb_size), color, center)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
