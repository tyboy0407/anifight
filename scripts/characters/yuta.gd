class_name YutaFighter
extends Fighter
## 以乙骨憂太為藍本的角色。普通攻擊用刀,判定比徒手角色長。
##
## 一般狀態
## 氣量上限是 5 格(在 yuta.tscn 設定 max_energy = 500)。
##   飛走吧!(skill):咒言,前方大範圍微量傷害並擊飛。耗 1 格氣,有冷卻。
##   我也可以!(上 + skill):咒力附刀,10 秒內普通攻擊傷害提升。耗 1 格氣。
##   來吧,里香!(下 + special):召喚里香,進入里香狀態 60 秒。耗 3 格氣。
## 里香狀態
##   地面連段由 3 段變 5 段,每次普攻命中里香都會追加一擊。
##   下 + special 改為「真是失禮,這可是純愛」:里香在身後蓄力 3 秒後向前射出
##   大範圍咒力砲,結束後退出里香狀態。不耗氣。
##   被動「不准欺負憂太!」:憂太被打中時有 10% 機率,里香出手把對手拍飛。

const SPEECH_COLOR := Color(1.0, 0.95, 0.6)
const CURSE_COLOR := Color(0.55, 0.85, 1.0)
const RIKA_COLOR := Color(1.0, 0.7, 0.88)

# 飛走吧!
const SPEECH_COST := 100
const SPEECH_COOLDOWN := 3.0
const SPEECH_CAST := 0.50
const SPEECH_RELEASE := 0.22
const SPEECH_SIZE := Vector2(380, 170)
const SPEECH_OFFSET := Vector2(215, -65)
# 我也可以!
const BUFF_COST := 100
const BUFF_CAST := 0.40
const BUFF_RELEASE := 0.20
const BUFF_DURATION := 10.0
const BUFF_DAMAGE_SCALE := 1.5
# 來吧,里香!
const RIKA_CAST := 0.80
const RIKA_RELEASE := 0.50
const RIKA_DURATION := 60.0
const RIKA_FOLLOW_OFFSET := Vector2(-85, -25)
const RIKA_FOLLOW_SPEED := 9.0
const RIKA_STRIKE_DELAY := 0.10
const RIKA_STRIKE_REACH := 280.0
# 不准欺負憂太!
const PROTECT_CHANCE := 0.10
const PROTECT_REACH := 420.0  # 對手在這個距離內里香才撲得到;遠程攻擊打中憂太不會觸發
const PROTECT_DAMAGE := 40
# 真是失禮,這可是純愛
const CANNON_CAST := 0.50
const CANNON_RELEASE := 0.20
const CANNON_CHARGE := 3.0
const CANNON_FIRE := 0.60
const CANNON_TICK := 0.12
const CANNON_SIZE := Vector2(1500, 180)
const CANNON_HEIGHT := -70.0

enum Cannon { NONE, CHARGING, FIRING }

var _speech_cooldown := 0.0
var _speech_move: AttackData

var _buff_time := 0.0
var _boosted: Dictionary = {}  # 原招式 -> 強化後的複本

var _normal_chain: Array[AttackData] = []
var _rika_chain: Array[AttackData] = []
var _rika_time := 0.0
var _rika_node: Node2D
var _rika_strike_timer := -1.0
var _rika_move: AttackData
var _protect_move: AttackData
## 被動的觸發機率。獨立成變數是為了測試時可以調成必定觸發。
var protect_chance := PROTECT_CHANCE

var _cannon := Cannon.NONE
var _cannon_time := 0.0
var _cannon_tick := 0.0
var _cannon_direction := 1
var _cannon_origin := Vector2.ZERO
var _cannon_charge_node: ColorRect
var _cannon_beam_node: ColorRect
var _cannon_move: AttackData
var _cannon_final_move: AttackData

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 刀的三連擊:比徒手打得遠
	_normal_chain = [
		_slash(45, 0.07, 0.20, 0.32, false),
		_slash(55, 0.08, 0.22, 0.34, false),
		_slash(95, 0.11, 0.32, 0.0, true),
	]
	# 里香狀態的五連擊
	_rika_chain = [
		_slash(45, 0.07, 0.18, 0.34, false),
		_slash(50, 0.07, 0.18, 0.34, false),
		_slash(55, 0.08, 0.20, 0.34, false),
		_slash(60, 0.08, 0.20, 0.36, false),
		_slash(100, 0.11, 0.32, 0.0, true),
	]
	_ground_moves = _normal_chain
	_air_move = AttackData.make(65, 0.05, 0.20, 0.10, Vector2(60, -40), Vector2(110, 70), Vector2(260, 0), 0.30, false, 0.0)

	_speech_move = AttackData.make(20, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(900, -420), 0.0, true, 0.0)
	_speech_move.builds_energy = false
	_rika_move = AttackData.make(30, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.36, false, 0.0)
	_protect_move = AttackData.make(PROTECT_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(720, -480), 0.0, true, 0.0)
	_protect_move.builds_energy = false
	_cannon_move = AttackData.make(70, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(120, 0), 0.30, false, 0.0)
	_cannon_move.builds_energy = false
	_cannon_final_move = AttackData.make(70, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(800, -600), 0.0, true, 0.0)
	_cannon_final_move.builds_energy = false


func _slash(damage: int, startup: float, recovery: float, hitstun: float, launches: bool) -> AttackData:
	var knockback := Vector2(440, -540) if launches else Vector2(170, 0)
	var move := AttackData.make(damage, startup, 0.10, recovery, Vector2(80, -62), Vector2(120, 56), knockback, hitstun, launches, 230.0 if launches else 130.0)
	move.color = Color(0.85, 0.92, 1.0, 0.75)
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_speech_cooldown = 0.0
	_buff_time = 0.0
	_cancel_cannon()
	_exit_rika()
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_speech_cooldown = maxf(_speech_cooldown - delta, 0.0)
	_buff_time = maxf(_buff_time - delta, 0.0)
	_tick_rika(delta)
	_tick_cannon(delta)
	_update_status()


func in_rika_state() -> bool:
	return _rika_time > 0.0


func _try_character_actions() -> bool:
	if not _pressed("skill"):
		return false
	if _held("up"):
		if _spend_energy(BUFF_COST):
			_start_cast(BUFF_CAST, BUFF_RELEASE, _release_buff)
			return true
		return false
	if _speech_cooldown <= 0.0 and _spend_energy(SPEECH_COST):
		_speech_cooldown = SPEECH_COOLDOWN
		_start_cast(SPEECH_CAST, SPEECH_RELEASE, _release_speech)
		return true
	return false


## 里香狀態下的純愛砲不耗氣(代價是結束里香狀態);蓄力中不能再放一次。
func super_cost() -> int:
	if _cannon != Cannon.NONE:
		return max_energy + 1
	return 0 if in_rika_state() else SUPER_COST


func _start_super() -> void:
	if in_rika_state():
		_start_cast(CANNON_CAST, CANNON_RELEASE, _begin_cannon)
	else:
		_start_cast(RIKA_CAST, RIKA_RELEASE, _enter_rika)


# ---------- 飛走吧! ----------

func _release_speech() -> void:
	_callout("飛走吧!", SPEECH_COLOR)
	var origin := global_position + Vector2(0, SPEECH_OFFSET.y)
	# 聲波:三道由小到大、往前擴散的波紋
	for i in 3:
		var wave := _spawn_rect(Vector2(12, 60 + i * 45), Color(SPEECH_COLOR, 0.8), origin + Vector2(facing * (60 + i * 55), 0), 2)
		var tween := wave.create_tween()
		tween.tween_property(wave, "position:x", wave.position.x + facing * 160.0, 0.3)
		tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.3)
		tween.tween_callback(wave.queue_free)
	var center := global_position + Vector2(SPEECH_OFFSET.x * facing, SPEECH_OFFSET.y)
	if _rect_hits_opponent(center, SPEECH_SIZE):
		opponent.take_hit(_speech_move, self)


# ---------- 我也可以! ----------

func _release_buff() -> void:
	_buff_time = BUFF_DURATION
	_callout("我也可以!", CURSE_COLOR)


## 強化期間,刀的普通攻擊(地面與空中)傷害提升;里香的追擊與耗氣招式不受影響。
func _effective_move(move: AttackData) -> AttackData:
	if _buff_time <= 0.0 or not _is_normal_attack(move):
		return move
	if not _boosted.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * BUFF_DAMAGE_SCALE))
		_boosted[move] = copy
	return _boosted[move]


func _is_normal_attack(move: AttackData) -> bool:
	return move == _air_move or _normal_chain.has(move) or _rika_chain.has(move)


# ---------- 里香狀態 ----------

func _enter_rika() -> void:
	_rika_time = RIKA_DURATION
	_ground_moves = _rika_chain
	_callout("來吧,里香!", RIKA_COLOR)
	if not is_instance_valid(_rika_node):
		_rika_node = _make_rika()
		_rika_node.global_position = global_position + Vector2(RIKA_FOLLOW_OFFSET.x * facing, RIKA_FOLLOW_OFFSET.y - 60)


func _exit_rika() -> void:
	_rika_time = 0.0
	_rika_strike_timer = -1.0
	_ground_moves = _normal_chain
	if is_instance_valid(_rika_node):
		var node := _rika_node
		var tween := node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.35)
		tween.tween_callback(node.queue_free)
	_rika_node = null


func _tick_rika(delta: float) -> void:
	if not in_rika_state():
		return
	if state == State.KO:
		_cancel_cannon()
		_exit_rika()
		return
	_rika_time -= delta
	if _rika_time <= 0.0:
		if _cannon == Cannon.NONE:
			_exit_rika()
			return
		_rika_time = 0.01  # 純愛砲進行中,等它結束再退出

	# 開砲時里香留在原地,其餘時間跟在憂太身後
	if _cannon != Cannon.FIRING:
		var target := global_position + Vector2(RIKA_FOLLOW_OFFSET.x * facing, RIKA_FOLLOW_OFFSET.y)
		target.y += sin(Time.get_ticks_msec() / 260.0) * 6.0
		_rika_node.global_position = _rika_node.global_position.lerp(target, minf(RIKA_FOLLOW_SPEED * delta, 1.0))
		_rika_node.scale.x = facing

	if _rika_strike_timer >= 0.0:
		_rika_strike_timer -= delta
		if _rika_strike_timer < 0.0:
			_rika_strike()


## 普通攻擊命中後,里香稍後追加一擊。
func _on_attack_hit(_target: Fighter, move: AttackData) -> void:
	if in_rika_state() and _cannon == Cannon.NONE and _is_normal_attack(move):
		_rika_strike_timer = RIKA_STRIKE_DELAY


func _rika_strike() -> void:
	if opponent == null or opponent.is_invulnerable():
		return
	if global_position.distance_to(opponent.global_position) > RIKA_STRIKE_REACH:
		return
	_rika_claw(opponent, 130.0)
	opponent.take_hit(_rika_move, self)


## 里香撲到目標身旁揮爪的演出(不含傷害)。
func _rika_claw(target: Fighter, claw_length: float) -> void:
	var side := int(signf(target.global_position.x - global_position.x))
	if side == 0:
		side = facing
	_rika_node.global_position = target.global_position + Vector2(-side * 55.0, -20.0)
	_rika_node.scale.x = side
	var claw_center := target.global_position + Vector2(0, -60)
	for angle: float in [-0.5, 0.0, 0.5]:
		var claw := _spawn_rect(Vector2(claw_length, 6), RIKA_COLOR, claw_center, 2)
		claw.rotation = 0.9 * side + angle * 0.35
		var tween := claw.create_tween()
		tween.tween_property(claw, "modulate:a", 0.0, 0.18)
		tween.tween_callback(claw.queue_free)


# ---------- 不准欺負憂太! ----------

## 里香狀態的被動:憂太實際被打中(防禦成功不算)時,有機率由里香把攻擊者拍飛。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	var health_before := health
	super(move, attacker)
	var was_hit := health < health_before and state != State.GUARD and state != State.KO
	if not was_hit or not in_rika_state() or _cannon != Cannon.NONE:
		return
	if attacker.is_invulnerable() or global_position.distance_to(attacker.global_position) > PROTECT_REACH:
		return
	if randf() >= protect_chance:
		return
	_callout("不准欺負憂太!", RIKA_COLOR)
	_rika_claw(attacker, 190.0)
	attacker.take_hit(_protect_move, self)


## 里香的暫代外觀:用色塊拼出的大型咒靈。
func _make_rika() -> Node2D:
	var rika := Node2D.new()
	var parts := [
		# [位置, 大小, 顏色]
		[Vector2(-38, -150), Vector2(76, 120), Color(0.16, 0.15, 0.2)],       # 軀幹
		[Vector2(-30, -196), Vector2(64, 58), Color(0.93, 0.92, 0.95)],       # 頭
		[Vector2(-30, -196), Vector2(64, 16), Color(0.16, 0.15, 0.2)],        # 頭髮
		[Vector2(-18, -158), Vector2(46, 10), Color(0.75, 0.15, 0.2)],        # 嘴
		[Vector2(10, -176), Vector2(12, 8), Color(0.1, 0.1, 0.12)],           # 眼
		[Vector2(30, -130), Vector2(52, 20), Color(0.93, 0.92, 0.95)],        # 前臂
		[Vector2(70, -138), Vector2(22, 36), Color(0.93, 0.92, 0.95)],        # 爪
		[Vector2(-58, -120), Vector2(24, 70), Color(0.93, 0.92, 0.95)],       # 後臂
	]
	for part: Array in parts:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = part[0]
		rect.size = part[1]
		rect.color = part[2]
		rika.add_child(rect)
	rika.modulate = Color(1, 1, 1, 0.92)
	get_parent().add_child(rika)
	# 排在憂太前面的節點順序 = 畫在憂太後面
	get_parent().move_child(rika, get_index())
	return rika


# ---------- 真是失禮,這可是純愛 ----------

func _begin_cannon() -> void:
	if not in_rika_state():
		return
	_cannon = Cannon.CHARGING
	_cannon_time = CANNON_CHARGE
	_rika_strike_timer = -1.0
	_callout("真是失禮,這可是純愛", RIKA_COLOR)
	_cannon_charge_node = _spawn_rect(Vector2(20, 20), RIKA_COLOR, _cannon_charge_point(), 2)


## 蓄力球的位置:里香的嘴前,在憂太身後上方,不會蓋住憂太。
func _cannon_charge_point() -> Vector2:
	return _rika_node.global_position + Vector2(facing * 30.0, -205.0)


## 砲擊的起點:里香所在位置、對手身體的高度。
func _cannon_muzzle() -> Vector2:
	return _rika_node.global_position + Vector2(facing * 70.0, CANNON_HEIGHT - RIKA_FOLLOW_OFFSET.y)


func _tick_cannon(delta: float) -> void:
	if _cannon == Cannon.NONE:
		return
	_cannon_time -= delta
	if _cannon == Cannon.CHARGING:
		# 蓄力球逐漸變大並閃爍
		var progress := 1.0 - _cannon_time / CANNON_CHARGE
		var orb_size := lerpf(20.0, 110.0, progress)
		_cannon_charge_node.size = Vector2(orb_size, orb_size)
		_cannon_charge_node.pivot_offset = _cannon_charge_node.size / 2.0
		_cannon_charge_node.position = _cannon_charge_point() - _cannon_charge_node.size / 2.0
		_cannon_charge_node.rotation += delta * 4.0
		_cannon_charge_node.modulate.a = 0.7 + 0.3 * sin(_cannon_time * 25.0)
		if _cannon_time <= 0.0:
			_fire_cannon()
		return

	# 開砲中:每隔一小段時間判定一次,最後一下擊飛
	_cannon_tick -= delta
	if _cannon_tick <= 0.0:
		_cannon_tick = CANNON_TICK
		var center := _cannon_origin + Vector2(_cannon_direction * CANNON_SIZE.x / 2.0, 0)
		if _rect_hits_opponent(center, CANNON_SIZE):
			opponent.take_hit(_cannon_final_move if _cannon_time <= CANNON_TICK else _cannon_move, self)
	if _cannon_time <= 0.0:
		_cancel_cannon()
		_exit_rika()


func _fire_cannon() -> void:
	_cannon = Cannon.FIRING
	_cannon_time = CANNON_FIRE
	_cannon_tick = 0.0
	_cannon_direction = facing
	_cannon_origin = _cannon_muzzle()
	if is_instance_valid(_cannon_charge_node):
		_cannon_charge_node.queue_free()
	_cannon_charge_node = null
	var center := _cannon_origin + Vector2(_cannon_direction * CANNON_SIZE.x / 2.0, 0)
	_cannon_beam_node = _spawn_rect(CANNON_SIZE, Color(RIKA_COLOR, 0.9), center, 1)
	var core := ColorRect.new()
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.color = Color(1, 1, 1, 0.9)
	core.size = Vector2(CANNON_SIZE.x, CANNON_SIZE.y * 0.45)
	core.position = Vector2(0, CANNON_SIZE.y * 0.275)
	_cannon_beam_node.add_child(core)
	var tween := _cannon_beam_node.create_tween()
	tween.tween_interval(CANNON_FIRE * 0.6)
	tween.tween_property(_cannon_beam_node, "modulate:a", 0.0, CANNON_FIRE * 0.4)


func _cancel_cannon() -> void:
	_cannon = Cannon.NONE
	for node: ColorRect in [_cannon_charge_node, _cannon_beam_node]:
		if is_instance_valid(node):
			node.queue_free()
	_cannon_charge_node = null
	_cannon_beam_node = null


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = []
	if _cannon == Cannon.CHARGING:
		parts.append("純愛砲 %.1f" % _cannon_time)
	elif in_rika_state() and _cannon == Cannon.NONE:
		parts.append("里香 %d" % ceili(_rika_time))
	if _buff_time > 0.0:
		parts.append("咒力附刀 %d" % ceili(_buff_time))
	_status_label.text = "   ".join(parts)
	_status_label.add_theme_color_override("font_color", CURSE_COLOR if _buff_time > 0.0 else RIKA_COLOR)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	if _has_sprite and _buff_time > 0.0 and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH]:
		_sprite.modulate = Color(0.8, 1.15, 1.5)
