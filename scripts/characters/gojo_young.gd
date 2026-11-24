class_name GojoYoungFighter
extends Fighter
## 五條悟的另一個型態:青年五條悟。在選角畫面長按五條悟的卡片可以選到。
## 氣量上限是 5 格(在 gojo_young.tscn 設定 max_energy = 500)。
##
## 被動
##   每回合開場有 10 秒「無下限」:期間對手的所有攻擊都無效,
##   但每被打中一下,無下限的剩餘時間會少 0.5 秒。
## 招式
##   術式「蒼放」(skill,1 格):閃身到對手背後,凝聚一顆小蒼球向前甩出,命中擊飛。
##   無下限(上 + skill,2 格):進入「無下限」狀態 10 秒。
##   術式順轉「蒼」(下 + special,3 格):在前方凝聚巨大的吸引球體,把對手吸進去
##     持續造成微量傷害,3 秒後往自己身後甩出,造成大量傷害。施放期間自己不能行動。

const BLUE_COLOR := Color(0.3, 0.55, 1.0)
const INFINITY_COLOR := Color(0.72, 0.9, 1.0)

# 無下限
const NORMAL_DAMAGE_SCALE := 1.25   # 普通攻擊的傷害倍率(相對一般角色)
const NORMAL_RECOVERY_SCALE := 0.85 # 普通攻擊的收招時間倍率
const INFINITY_DURATION := 10.0
const INFINITY_HIT_PENALTY := 0.35  # 無下限期間每被打中一下,剩餘時間少這麼多
const INFINITY_COST := 200
const INFINITY_CAST := 0.5
const INFINITY_RELEASE := 0.3
# 蒼放
const PUSH_COST := 100
const PUSH_CAST := 0.5
const PUSH_RELEASE := 0.22          # 閃身後凝聚蒼球的時間,結束的瞬間甩出
const PUSH_BLINK_OFFSET := 110.0    # 閃到對手背後這個距離
const PUSH_HAND := Vector2(60, -68)
const PUSH_ORB_START := 12.0
const PUSH_ORB_SIZE := 36.0
const PUSH_ORB_SPEED := 900.0
const PUSH_ORB_LIFETIME := 0.55
const PUSH_DAMAGE := 130
# 術式順轉「蒼」
const ORB_CAST_IN := 0.5
const ORB_DURATION := 3.0
const ORB_SWING := 0.3
const ORB_CAST_OUT := 0.35
const ORB_OFFSET := Vector2(230, -150)
const ORB_BEHIND := Vector2(-140, -90)
const ORB_SIZE := 170.0
const ORB_RANGE := 620.0            # 對手離球體的水平距離在這之內就會被吸過去
const ORB_PULL_SPEED := 520.0
const ORB_LIFT_DISTANCE := 150.0    # 拉到這麼近之後開始往上吸進球體
const ORB_CAPTURE_RADIUS := 95.0
const ORB_TICK := 0.8
const ORB_TICK_DAMAGE := 25
const ORB_THROW_DAMAGE := 430

enum Orb { NONE, PULLING, SWING }

var _infinity_time := 0.0
var _aura: ColorRect
var _barrier: AnimatedSprite2D  # 無下限的點陣光球;有它就不顯示 _aura
var _barrier_tried := false

var _push_gathering := false
var _push_fly_time := 0.0
var _push_direction := 1
var _push_node: ColorRect
var _push_move: AttackData

var _orb := Orb.NONE
var _orb_time := 0.0
var _orb_tick := 0.0
var _orb_direction := 1
var _orb_position := Vector2.ZERO
var _orb_from := Vector2.ZERO
var _orb_captured := false
var _orb_node: ColorRect
var _orb_tick_move: AttackData
var _orb_throw_move: AttackData

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	# 無下限的光暈,畫在角色後面。要在 super() 之前建立,因為它會呼叫 _update_visual()
	_aura = ColorRect.new()
	_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aura.color = Color(INFINITY_COLOR, 0.22)
	_aura.size = Vector2(96, 142)
	_aura.position = Vector2(-48, -136)
	_aura.visible = false
	add_child(_aura)
	move_child(_aura, 0)
	super()

	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", INFINITY_COLOR)
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 青年時期以體術為主:普通攻擊比一般角色重,出手也快一點
	for move in _ground_moves:
		move.damage = int(round(move.damage * NORMAL_DAMAGE_SCALE))
		move.recovery *= NORMAL_RECOVERY_SCALE
	_push_move = AttackData.make(PUSH_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(620, -440), 0.0, true, 0.0)
	_push_move.builds_energy = false
	_orb_tick_move = AttackData.make(ORB_TICK_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.3, false, 0.0)
	_orb_tick_move.builds_energy = false
	_orb_throw_move = AttackData.make(ORB_THROW_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(950, -420), 0.0, true, 0.0)
	_orb_throw_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_push()
	_clear_orb()
	super(spawn_position, spawn_facing)
	# 被動:每回合開場的無下限(當替身時沒有:不然拷貝他任何一招都會附送一次)
	_infinity_time = INFINITY_DURATION if puppet_of == null else 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	# 回合開始前的倒數不算在無下限的時間內
	if input_enabled:
		_infinity_time = maxf(_infinity_time - delta, 0.0)
	_tick_push(delta)
	_tick_orb(delta)
	_status_label.text = "無下限 %.1f" % _infinity_time if in_infinity() else ""


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(INFINITY_COST):
			_start_cast(INFINITY_CAST, INFINITY_RELEASE, _release_infinity)
			return true
		return false
	if _skill1_pressed() and _spend_energy(PUSH_COST):
		_start_push()
		return true
	return false


func _start_super() -> void:
	_start_cast(ORB_CAST_IN + ORB_DURATION + ORB_SWING + ORB_CAST_OUT, ORB_CAST_IN, _release_orb)


## 電腦操作時:留氣給無下限與順轉「蒼」,不要花在通用大招上。
func ai_energy_reserve() -> int:
	return INFINITY_COST


## 順轉「蒼」要站著吸三秒,途中被打就白費 3 格氣:氣夠了就找打不到自己的時機放。
func ai_wants_super() -> bool:
	return energy >= super_cost()


## 無下限期間不怕被打斷;否則要等對手夠遠,或被擊飛、倒地、定身。
func ai_super_is_safe() -> bool:
	return in_infinity() or _ai_opponent_cannot_interrupt()


# ---------- 無下限 ----------

func in_infinity() -> bool:
	return _infinity_time > 0.0


func _release_infinity() -> void:
	_infinity_time = INFINITY_DURATION
	_callout("無下限", INFINITY_COLOR, "infinity")
	_power_burst(INFINITY_COLOR)


## 無下限期間被任何招式打中:攻擊停在身前、不造成任何效果,但每一下會讓無下限少 0.5 秒。
## (不把自己當成無敵,對手的招式才會照常打上來,電腦也才會主動進攻。)
func take_hit(move: AttackData, attacker: Fighter) -> void:
	if in_infinity():
		if not is_invulnerable():
			_absorb_hit(attacker)
		return
	super(move, attacker)


## 定身類的招式(例如無量空處)也算一次命中。
func stun(duration: float, damage: int = 0, damage_scale: float = 1.0) -> void:
	if in_infinity():
		if not is_invulnerable():
			_absorb_hit(opponent)
		return
	super(duration, damage, damage_scale)


## 不造成傷害的打斷效果直接無效,不扣時間。
func stagger(duration: float) -> void:
	if not in_infinity():
		super(duration)


## 無下限期間,吸引類的招式拉不動他。
func is_immovable() -> bool:
	return in_infinity() or super()


func _absorb_hit(attacker: Fighter) -> void:
	_infinity_time = maxf(_infinity_time - INFINITY_HIT_PENALTY, 0.0)
	if attacker != null:
		_infinity_ripple(attacker)


## 攻擊被無下限擋在身前的效果:面向攻擊者的那一側亮起半圓的屏障。沒有點陣特效時是一道淡藍色的線。
func _infinity_ripple(attacker: Fighter) -> void:
	var side := signf(attacker.global_position.x - global_position.x)
	if side == 0.0:
		side = facing
	if _spawn_effect("guard", global_position, _bright(INFINITY_COLOR, 1.3), 1.0, side < 0.0) != null:
		return
	var barrier := _spawn_rect(Vector2(10, 130), INFINITY_COLOR, global_position + Vector2(side * 42.0, -62), 3)
	var tween := barrier.create_tween()
	tween.tween_property(barrier, "scale", Vector2(2.2, 1.15), 0.2)
	tween.parallel().tween_property(barrier, "modulate:a", 0.0, 0.2)
	tween.tween_callback(barrier.queue_free)


# ---------- 術式「蒼放」 ----------

## 閃身到對手背後,開始在手邊凝聚蒼球。
func _start_push() -> void:
	_clear_push()
	# 原地留下一道散成光點的殘影,人出現在對手背後。沒有點陣特效時是一塊半透明的色塊
	if not _vanish_effect(INFINITY_COLOR):
		var afterimage := _spawn_rect(Vector2(BODY_SIZE.x, BODY_SIZE.y), Color(INFINITY_COLOR, 0.45), global_position + Vector2(0, -BODY_SIZE.y / 2.0), 0)
		var fade := afterimage.create_tween()
		fade.tween_property(afterimage, "modulate:a", 0.0, 0.25)
		fade.tween_callback(afterimage.queue_free)
	if opponent != null:
		_move_behind_opponent(PUSH_BLINK_OFFSET)
		_appear_effect(INFINITY_COLOR)
	_callout("蒼放", BLUE_COLOR, "blue")
	_push_gathering = true
	_push_node = _spawn_rect(Vector2(PUSH_ORB_START, PUSH_ORB_START), BLUE_COLOR, _push_hand_point(), 2)
	_start_cast(PUSH_CAST, PUSH_RELEASE, _release_push)


## 把凝聚好的蒼球向前甩出。
func _release_push() -> void:
	if not is_instance_valid(_push_node):
		return
	_push_gathering = false
	_push_fly_time = PUSH_ORB_LIFETIME
	_push_direction = facing
	_set_push_orb(PUSH_ORB_SIZE, _push_hand_point())


func _push_hand_point() -> Vector2:
	return global_position + Vector2(PUSH_HAND.x * facing, PUSH_HAND.y)


func _set_push_orb(orb_size: float, center: Vector2) -> void:
	_push_node.size = Vector2(orb_size, orb_size)
	_push_node.pivot_offset = _push_node.size / 2.0
	_push_node.position = center - _push_node.size / 2.0


func _tick_push(delta: float) -> void:
	if _push_gathering:
		if state != State.CAST:
			_clear_push()  # 凝聚途中被打斷
			return
		# 手邊的蒼球越聚越大
		var progress := clampf(_state_time / PUSH_RELEASE, 0.0, 1.0)
		_set_push_orb(lerpf(PUSH_ORB_START, PUSH_ORB_SIZE, progress), _push_hand_point())
		_push_node.rotation += delta * 14.0
		return
	if _push_fly_time <= 0.0:
		return

	# 甩出去的蒼球:直線飛行,碰到對手就擊飛
	_push_fly_time -= delta
	_push_node.position.x += _push_direction * PUSH_ORB_SPEED * delta
	_push_node.rotation += delta * 14.0
	var center := _push_node.position + _push_node.size / 2.0
	if _rect_hits_opponent(center, _push_node.size):
		opponent.take_hit(_push_move, self)
		# 蒼球在對手身上炸開。沒有點陣特效時是四條散開的線
		var burst := _spawn_effect("blast", center, _bright(BLUE_COLOR, 1.6), 0.6)
		for i in (0 if burst != null else 4):
			var streak := _spawn_rect(Vector2(120, 6), BLUE_COLOR, center, 3)
			streak.rotation = PI * i / 4.0
			var tween := streak.create_tween()
			tween.tween_property(streak, "modulate:a", 0.0, 0.2)
			tween.tween_callback(streak.queue_free)
		_clear_push()
	elif _push_fly_time <= 0.0:
		_clear_push()


func _clear_push() -> void:
	_push_gathering = false
	_push_fly_time = 0.0
	if is_instance_valid(_push_node):
		_push_node.queue_free()
	_push_node = null


# ---------- 術式順轉「蒼」 ----------

func _release_orb() -> void:
	_clear_orb()
	_callout("術式順轉「蒼」", BLUE_COLOR, "blue")
	_orb = Orb.PULLING
	_orb_time = ORB_DURATION
	_orb_tick = 0.0
	_orb_captured = false
	_orb_direction = facing
	_orb_position = global_position + Vector2(ORB_OFFSET.x * facing, ORB_OFFSET.y)
	_orb_position.x = clampf(_orb_position.x, arena_min_x, arena_max_x)
	# 把東西吸進去的漩渦。半透明,才看得到被吸在裡面的對手
	_orb_node = _spawn_rect(Vector2(ORB_SIZE, ORB_SIZE), Color(BLUE_COLOR, 0.5), _orb_position, 2, "void")
	if _orb_node.get_child_count() > 0:
		(_orb_node.get_child(0) as CanvasItem).modulate.a = 0.72
	else:
		# 沒有點陣圖時:色塊中間再疊一塊深色的球心
		var core := ColorRect.new()
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core.color = Color(0.05, 0.08, 0.3, 0.45)
		core.size = Vector2(ORB_SIZE, ORB_SIZE) * 0.5
		core.position = Vector2(ORB_SIZE, ORB_SIZE) * 0.25
		_orb_node.add_child(core)


func _tick_orb(delta: float) -> void:
	if _orb == Orb.NONE:
		return
	if state != State.CAST:
		_clear_orb()  # 施放途中被打斷:球體消失,對手掉下來
		return
	_orb_time -= delta
	_orb_node.rotation += delta * 3.0
	var pulse := 1.0 + 0.08 * sin(_orb_time * 22.0)
	_orb_node.scale = Vector2(pulse, pulse)
	var reachable := opponent != null and not opponent.is_invulnerable()

	if _orb == Orb.PULLING:
		_orb_captured = reachable and _pull_into_orb(delta)
		if _orb_time <= 0.0:
			_orb = Orb.SWING
			_orb_time = ORB_SWING
			_orb_from = _orb_position
		return

	# 甩出:球體帶著對手越過頭頂,甩到自己身後
	var progress := clampf(1.0 - _orb_time / ORB_SWING, 0.0, 1.0)
	var behind := global_position + Vector2(ORB_BEHIND.x * _orb_direction, ORB_BEHIND.y)
	_orb_position = _orb_from.lerp(behind, progress) + Vector2(0, -sin(progress * PI) * 110.0)
	_orb_node.position = _orb_position - _orb_node.size / 2.0
	var holding := _orb_captured and reachable
	if holding:
		opponent.global_position = _orb_position + Vector2(0, BODY_SIZE.y / 2.0)
		opponent.velocity = Vector2.ZERO
	if progress < 1.0:
		return
	var burst_at := _orb_position
	_clear_orb()
	if not holding:
		return
	# 大球帶著對手炸開。沒有點陣特效時是六條散開的線
	var burst := _spawn_effect("blast", burst_at, _bright(BLUE_COLOR, 1.7), 1.25)
	for i in (0 if burst != null else 6):
		var streak := _spawn_rect(Vector2(220, 8), BLUE_COLOR if i % 2 == 0 else Color.WHITE, burst_at, 3)
		streak.rotation = PI * i / 6.0
		var tween := streak.create_tween()
		tween.tween_property(streak, "modulate:a", 0.0, 0.25)
		tween.tween_callback(streak.queue_free)
	opponent.take_hit(_orb_throw_move, self)


## 把對手往球體吸。回傳對手是否已經在球體裡。
func _pull_into_orb(delta: float) -> bool:
	if opponent.is_immovable():
		return false
	var chest := opponent.global_position + Vector2(0, -BODY_SIZE.y / 2.0)
	var offset := _orb_position - chest
	if offset.length() <= ORB_CAPTURE_RADIUS:
		# 吸進球體:固定在球心,定時造成微量傷害
		opponent.global_position += offset * minf(12.0 * delta, 1.0)
		opponent.velocity = Vector2.ZERO
		_orb_tick -= delta
		if _orb_tick <= 0.0:
			_orb_tick = ORB_TICK
			opponent.take_hit(_orb_tick_move, self)
		return true
	if absf(offset.x) > ORB_RANGE:
		return false
	opponent.global_position.x = move_toward(opponent.global_position.x, _orb_position.x, ORB_PULL_SPEED * delta)
	if absf(_orb_position.x - opponent.global_position.x) <= ORB_LIFT_DISTANCE:
		# 夠近了:連人帶腳吸離地面
		opponent.global_position.y = move_toward(opponent.global_position.y, _orb_position.y + BODY_SIZE.y / 2.0, ORB_PULL_SPEED * delta)
		opponent.velocity = Vector2.ZERO
	return false


func _clear_orb() -> void:
	_orb = Orb.NONE
	_orb_captured = false
	if is_instance_valid(_orb_node):
		_orb_node.queue_free()
	_orb_node = null


# ---------- 顯示 ----------

func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	# 無下限的光球:第一次用到才建立(特效素材在 _ready 的後半才載入)。沒有點陣圖就用半透明的色塊
	if in_infinity() and not _barrier_tried:
		_barrier_tried = true
		_barrier = _effect_sprite("barrier")
		if _barrier != null:
			# 圖的原點在腳底;畫在角色後面,光球才不會蓋住人
			add_child(_barrier)
			move_child(_barrier, 0)
	if _barrier != null:
		_barrier.visible = in_infinity()
		_barrier.modulate.a = 0.8 + 0.2 * sin(Time.get_ticks_msec() / 110.0)
	_aura.visible = in_infinity() and _barrier == null
	if in_infinity():
		_aura.color.a = 0.18 + 0.1 * sin(Time.get_ticks_msec() / 110.0)
		if _has_sprite and state != State.KO:
			_sprite.modulate = Color(0.85, 1.1, 1.35)
