class_name MegumiFighter
extends Fighter
## 以伏黑惠為藍本的角色。本人徒手三連擊,主要靠式神協同作戰。
##
## 被動
##   氣量上限是 5 格(在 megumi.tscn 設定 max_energy = 500)。
##   場上有式神時持續回復氣量。
## 招式
##   式神「鷲」(skill,2 格):召喚貓頭鷹式神 15 秒,定期俯衝攻擊對手。
##   式神「玉犬」(上 + skill,2 格):召喚狼犬式神 15 秒,定期撲咬對手。
##   式神合擊(下 + special,不耗氣):鷲與玉犬同時在場才能使用。
##     兩隻式神合力攻擊對手,並讓自己進入「咒力高漲」20 秒。
## 咒力高漲
##   自己與式神的傷害提高,所有氣量回復量大幅提高。期間不能再用式神合擊。

const OWL_COLOR := Color(1.0, 0.86, 0.4)
const DOG_COLOR := Color(0.94, 0.94, 0.98)
const SURGE_COLOR := Color(0.5, 0.62, 1.0)

# 召喚
const SUMMON_COST := 200
const SUMMON_CAST := 0.45
const SUMMON_RELEASE := 0.22
const SHIKIGAMI_DURATION := 15.0
const PASSIVE_ENERGY_PER_SECOND := 8.0
const FOLLOW_SPEED := 8.0
const SHIKIGAMI_RECOVER := 0.3
const RETRY_DELAY := 0.3       # 對手無敵時,過一會再試著出手
# 鷲:停在主人後上方,先往上拉高當預兆,再俯衝
const OWL_HOVER := Vector2(-45, -215)
const OWL_FIRST_ATTACK := 1.0
const OWL_INTERVAL := 2.5      # 從這次出手到下次出手的間隔
const OWL_WINDUP := 0.35
const OWL_DIVE_TIME := 0.22
const OWL_HIT_SIZE := Vector2(110, 110)
const OWL_DAMAGE := 50
# 玉犬:跟在主人前方,先壓低身體當預兆,再撲上去
const DOG_HEEL := 80.0
const DOG_FIRST_ATTACK := 0.7
const DOG_INTERVAL := 2.0
const DOG_WINDUP := 0.25
const DOG_POUNCE_TIME := 0.24
const DOG_HIT_SIZE := Vector2(120, 100)
const DOG_DAMAGE := 60
# 式神合擊與咒力高漲
const COMBINE_CAST := 0.6
const COMBINE_RELEASE := 0.25
const COMBINE_OWL_DELAY := 0.22
const COMBINE_STRIKE_TIME := 0.2
const COMBINE_HOLD := 0.7       # 各自打完後留在對手身邊,等最後一擊
const COMBINE_FINAL_DELAY := 0.3
const SURGE_DURATION := 20.0
const SURGE_DAMAGE_SCALE := 1.3
const SURGE_ENERGY_SCALE := 3.0

enum Phase { FOLLOW, WINDUP, STRIKE, RECOVER }
enum Combine { NONE, STRIKES, FINAL }


## 一隻式神的狀態。
class Shikigami:
	var node: Node2D
	var time := 0.0          # 剩餘的在場時間
	var attack_timer := 0.0
	var phase := 0
	var phase_time := 0.0
	var strike_time := 0.0
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var move: AttackData
	var homing := false      # 攻擊途中是否持續追著對手

	func active() -> bool:
		return time > 0.0


var _owl := Shikigami.new()
var _dog := Shikigami.new()
var _owl_move: AttackData
var _dog_move: AttackData
var _combine_owl_move: AttackData
var _combine_dog_move: AttackData
var _combine_final_move: AttackData

var _combine := Combine.NONE
var _combine_timer := 0.0
var _surge_time := 0.0
var _regen := 0.0  # 尚未滿 1 點的回復量
var _powered_moves: Dictionary = {}  # 原招式 -> 咒力高漲時的複本
var _ground_y := 0.0

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_ground_y = global_position.y
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", SURGE_COLOR.lightened(0.35))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(300, 20)
	_status_label.position = Vector2(-150, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	_owl_move = _shikigami_move(OWL_DAMAGE, Vector2(110, 0), 0.34, false)
	_dog_move = _shikigami_move(DOG_DAMAGE, Vector2(130, 0), 0.36, false)
	_combine_dog_move = _shikigami_move(70, Vector2(40, 0), 0.6, false)
	_combine_owl_move = _shikigami_move(70, Vector2(40, 0), 0.6, false)
	_combine_final_move = _shikigami_move(120, Vector2(480, -620), 0.0, true)


## 式神的攻擊不替主人累積氣量:氣量來自「式神在場」的被動回復。
func _shikigami_move(damage: int, knockback: Vector2, hitstun: float, launches: bool) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_dismiss(_owl, true)
	_dismiss(_dog, true)
	_combine = Combine.NONE
	_surge_time = 0.0
	_regen = 0.0
	_ground_y = spawn_position.y
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	if is_on_floor():
		_ground_y = global_position.y
	_surge_time = maxf(_surge_time - delta, 0.0)
	_tick_shikigami(_owl, delta, true)
	_tick_shikigami(_dog, delta, false)
	_tick_combine(delta)
	_tick_regen(delta)
	_update_status()


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if not _dog.active() and _spend_energy(SUMMON_COST):
			_start_cast(SUMMON_CAST, SUMMON_RELEASE, _summon_dog)
			return true
		return false
	if _skill1_pressed() and not _owl.active() and _spend_energy(SUMMON_COST):
		_start_cast(SUMMON_CAST, SUMMON_RELEASE, _summon_owl)
		return true
	return false


## 式神合擊不耗氣,條件是兩隻式神都在場,而且不在咒力高漲期間。
func super_cost() -> int:
	return 0 if can_combine() else max_energy + 1


func _start_super() -> void:
	_start_cast(COMBINE_CAST, COMBINE_RELEASE, _release_combine)


## 電腦操作時:兩隻式神還沒到齊之前,留著氣召喚,不要花在通用大招上。
func ai_energy_reserve() -> int:
	return 0 if _owl.active() and _dog.active() else SUMMON_COST


## 兩隻式神同時在場的時間不長,湊齊了就優先放合擊。
func ai_wants_super() -> bool:
	return can_combine()


# ---------- 被動與咒力高漲 ----------

func has_shikigami() -> bool:
	return _owl.active() or _dog.active()


func in_surge() -> bool:
	return _surge_time > 0.0


func can_combine() -> bool:
	return _owl.active() and _dog.active() and not in_surge() and _combine == Combine.NONE


func _tick_regen(delta: float) -> void:
	if not has_shikigami() or state == State.KO:
		return
	_regen += PASSIVE_ENERGY_PER_SECOND * delta
	if _regen >= 1.0:
		var whole := int(_regen)
		_regen -= whole
		add_energy(whole)


## 咒力高漲期間,所有氣量回復(被動回復、打人、挨打)都放大。
func add_energy(amount: int) -> void:
	if amount > 0 and in_surge():
		amount = int(round(amount * SURGE_ENERGY_SCALE))
	super(amount)


## 咒力高漲期間,自己與式神的招式傷害提高。
func _powered(move: AttackData) -> AttackData:
	if not in_surge():
		return move
	if not _powered_moves.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * SURGE_DAMAGE_SCALE))
		_powered_moves[move] = copy
	return _powered_moves[move]


func _effective_move(move: AttackData) -> AttackData:
	return _powered(move)


# ---------- 召喚 ----------

func _summon_owl() -> void:
	_callout("鷲", OWL_COLOR)
	_summon(_owl, _make_owl(), global_position + Vector2(OWL_HOVER.x * facing, OWL_HOVER.y), OWL_FIRST_ATTACK)


func _summon_dog() -> void:
	_callout("玉犬", DOG_COLOR)
	_summon(_dog, _make_dog(), Vector2(global_position.x + DOG_HEEL * facing, _ground_y), DOG_FIRST_ATTACK)


func _summon(shikigami: Shikigami, node: Node2D, at: Vector2, first_attack: float) -> void:
	_dismiss(shikigami, true)
	shikigami.node = node
	shikigami.time = SHIKIGAMI_DURATION
	shikigami.attack_timer = first_attack
	shikigami.phase = Phase.FOLLOW
	node.global_position = at
	# 從影子裡冒出來
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.2)
	var shadow := _spawn_rect(Vector2(110, 14), Color(0.05, 0.05, 0.1, 0.8), Vector2(at.x, _ground_y - 4), 0)
	var tween := shadow.create_tween()
	tween.tween_property(shadow, "modulate:a", 0.0, 0.4)
	tween.tween_callback(shadow.queue_free)


func _dismiss(shikigami: Shikigami, instantly: bool = false) -> void:
	shikigami.time = 0.0
	shikigami.phase = Phase.FOLLOW
	if is_instance_valid(shikigami.node):
		var node := shikigami.node
		if instantly:
			node.queue_free()
		else:
			var tween := node.create_tween()
			tween.tween_property(node, "modulate:a", 0.0, 0.3)
			tween.tween_callback(node.queue_free)
	shikigami.node = null


# ---------- 式神的行動 ----------

func _tick_shikigami(shikigami: Shikigami, delta: float, is_owl: bool) -> void:
	if not shikigami.active():
		return
	if state == State.KO or not is_instance_valid(shikigami.node):
		_dismiss(shikigami)
		return
	var busy := shikigami.phase != Phase.FOLLOW or _combine != Combine.NONE
	shikigami.time -= delta
	if shikigami.phase != Phase.FOLLOW:
		shikigami.attack_timer -= delta  # 出手期間也算在間隔內
	if shikigami.time <= 0.0:
		if not busy:
			_dismiss(shikigami)
			return
		shikigami.time = 0.001  # 攻擊到一半,等這一下打完再消失

	var node := shikigami.node
	match shikigami.phase:
		Phase.FOLLOW:
			_follow(shikigami, delta, is_owl)
			shikigami.attack_timer -= delta
			if shikigami.attack_timer <= 0.0 and _combine == Combine.NONE:
				if _can_shikigami_attack():
					shikigami.attack_timer = OWL_INTERVAL if is_owl else DOG_INTERVAL
					_begin_attack(shikigami, OWL_WINDUP if is_owl else DOG_WINDUP, OWL_DIVE_TIME if is_owl else DOG_POUNCE_TIME,
							_owl_move if is_owl else _dog_move, false)
				else:
					shikigami.attack_timer = RETRY_DELAY
		Phase.WINDUP:
			shikigami.phase_time -= delta
			# 出手前的預兆:閃爍,鷲往上拉高、玉犬壓低身體
			node.modulate = Color(1.7, 1.7, 1.3) if int(shikigami.phase_time * 24.0) % 2 == 0 else Color.WHITE
			if is_owl:
				node.position.y -= 70.0 * delta
			else:
				node.scale.y = 0.8
			if shikigami.phase_time <= 0.0:
				node.modulate = Color.WHITE
				node.scale.y = 1.0
				shikigami.phase = Phase.STRIKE
				shikigami.phase_time = 0.0
				shikigami.from = node.global_position
				shikigami.to = _strike_point(shikigami, is_owl)
		Phase.STRIKE:
			shikigami.phase_time += delta
			if shikigami.homing:
				shikigami.to = _strike_point(shikigami, is_owl)
			var progress := minf(shikigami.phase_time / shikigami.strike_time, 1.0)
			node.global_position = shikigami.from.lerp(shikigami.to, progress)
			var heading := signf(shikigami.to.x - shikigami.from.x)
			if heading != 0.0:
				node.scale.x = heading
			if progress >= 1.0:
				_shikigami_hit(shikigami, is_owl)
				shikigami.phase = Phase.RECOVER
				shikigami.phase_time = COMBINE_HOLD if _combine != Combine.NONE else SHIKIGAMI_RECOVER
		Phase.RECOVER:
			shikigami.phase_time -= delta
			if shikigami.phase_time <= 0.0:
				shikigami.phase = Phase.FOLLOW


## 回到主人身邊:鷲在後上方盤旋,玉犬在前方地面。
func _follow(shikigami: Shikigami, delta: float, is_owl: bool) -> void:
	var target: Vector2
	if is_owl:
		target = global_position + Vector2(OWL_HOVER.x * facing, OWL_HOVER.y)
		target.y += sin(Time.get_ticks_msec() / 220.0) * 8.0
	else:
		target = Vector2(clampf(global_position.x + DOG_HEEL * facing, arena_min_x, arena_max_x), _ground_y)
	shikigami.node.global_position = shikigami.node.global_position.lerp(target, minf(FOLLOW_SPEED * delta, 1.0))
	shikigami.node.scale = Vector2(facing, 1.0)


func _can_shikigami_attack() -> bool:
	return input_enabled and opponent != null and not opponent.is_invulnerable()


func _begin_attack(shikigami: Shikigami, windup: float, strike_time: float, move: AttackData, homing: bool) -> void:
	shikigami.phase = Phase.WINDUP
	shikigami.phase_time = windup
	shikigami.strike_time = strike_time
	shikigami.move = move
	shikigami.homing = homing


## 這一下要衝到哪裡:鷲撞向對手胸口,玉犬撲到對手腳邊(對手在空中就跳起來咬)。
func _strike_point(shikigami: Shikigami, is_owl: bool) -> Vector2:
	if opponent == null:
		return shikigami.node.global_position
	if is_owl:
		return opponent.global_position + Vector2(0, -60)
	var side := signf(opponent.global_position.x - shikigami.node.global_position.x)
	return opponent.global_position + Vector2(-side * 35.0, 0)


func _shikigami_center(shikigami: Shikigami, is_owl: bool) -> Vector2:
	return shikigami.node.global_position + (Vector2.ZERO if is_owl else Vector2(0, -45))


func _shikigami_hit(shikigami: Shikigami, is_owl: bool) -> void:
	var center := _shikigami_center(shikigami, is_owl)
	if not _rect_hits_opponent(center, OWL_HIT_SIZE if is_owl else DOG_HIT_SIZE):
		return
	_impact(opponent.global_position + Vector2(0, -60), OWL_COLOR if is_owl else DOG_COLOR, 4, 110.0)
	opponent.take_hit(_powered(shikigami.move), self)


## 命中特效:幾道往外散開的線條。
func _impact(center: Vector2, color: Color, count: int, length: float) -> void:
	for i in count:
		var streak := _spawn_rect(Vector2(length, 6), color, center, 3)
		streak.rotation = PI * i / count + randf_range(-0.2, 0.2)
		var tween := streak.create_tween()
		tween.tween_property(streak, "modulate:a", 0.0, 0.22)
		tween.tween_callback(streak.queue_free)


# ---------- 式神合擊 ----------

func _release_combine() -> void:
	if not (_owl.active() and _dog.active()):
		return  # 施法途中式神剛好消失
	_callout("式神合擊", SURGE_COLOR)
	_surge_time = SURGE_DURATION
	_combine = Combine.STRIKES
	# 玉犬先撲上去咬住,鷲緊接著俯衝;合擊中的式神會追著對手跑
	_begin_attack(_dog, 0.02, COMBINE_STRIKE_TIME, _combine_dog_move, true)
	_begin_attack(_owl, COMBINE_OWL_DELAY, COMBINE_STRIKE_TIME, _combine_owl_move, true)


func _tick_combine(delta: float) -> void:
	if _combine == Combine.NONE:
		return
	if not (_owl.active() and _dog.active()):
		_combine = Combine.NONE  # 主人被打倒,式神已經消失
		return
	if _combine == Combine.STRIKES:
		var done := [Phase.RECOVER, Phase.FOLLOW]
		if _owl.phase in done and _dog.phase in done:
			_combine = Combine.FINAL
			_combine_timer = COMBINE_FINAL_DELAY
		return
	_combine_timer -= delta
	if _combine_timer > 0.0:
		return
	# 最後一擊:兩隻式神從兩側同時夾擊
	_combine = Combine.NONE
	for shikigami: Shikigami in [_owl, _dog]:
		shikigami.phase = Phase.RECOVER
		shikigami.phase_time = SHIKIGAMI_RECOVER
		shikigami.attack_timer = DOG_INTERVAL
	if opponent == null or opponent.is_invulnerable():
		return
	var chest := opponent.global_position + Vector2(0, -60)
	_owl.node.global_position = chest + Vector2(-60, -30)
	_owl.node.scale.x = 1.0
	_dog.node.global_position = opponent.global_position + Vector2(70, 0)
	_dog.node.scale.x = -1.0
	_impact(chest, OWL_COLOR, 5, 200.0)
	_impact(chest, DOG_COLOR, 5, 160.0)
	opponent.take_hit(_powered(_combine_final_move), self)


# ---------- 式神的外觀(色塊暫代) ----------

## 鷲:原點在身體中心,面向右。
func _make_owl() -> Node2D:
	var feather := Color(0.74, 0.47, 0.26)
	var wing := Color(0.55, 0.33, 0.18)
	var bone := Color(0.95, 0.93, 0.88)
	return _make_figure([
		# [位置, 大小, 顏色]
		[Vector2(-56, -16), Vector2(42, 16), wing],                      # 後翼
		[Vector2(14, -16), Vector2(42, 16), wing],                       # 前翼
		[Vector2(-66, -6), Vector2(20, 10), wing.darkened(0.2)],         # 後翼尖
		[Vector2(46, -6), Vector2(20, 10), wing.darkened(0.2)],          # 前翼尖
		[Vector2(-17, -18), Vector2(34, 38), feather],                   # 身體
		[Vector2(-13, -38), Vector2(26, 22), bone],                      # 面具般的臉
		[Vector2(-8, -31), Vector2(6, 6), Color(0.1, 0.08, 0.1)],        # 眼
		[Vector2(3, -31), Vector2(6, 6), Color(0.1, 0.08, 0.1)],
		[Vector2(-3, -24), Vector2(7, 7), OWL_COLOR],                    # 喙
		[Vector2(-11, 20), Vector2(7, 9), OWL_COLOR],                    # 爪
		[Vector2(4, 20), Vector2(7, 9), OWL_COLOR],
	])


## 玉犬:原點在腳底中央,面向右。
func _make_dog() -> Node2D:
	var fur := DOG_COLOR
	var shade := Color(0.78, 0.79, 0.86)
	return _make_figure([
		[Vector2(-60, -56), Vector2(22, 10), fur],                       # 尾巴
		[Vector2(-38, -22), Vector2(12, 22), shade],                     # 後腿(遠側)
		[Vector2(14, -22), Vector2(12, 22), shade],                      # 前腿(遠側)
		[Vector2(-42, -50), Vector2(72, 30), fur],                       # 身體
		[Vector2(-26, -22), Vector2(12, 22), fur],                       # 後腿
		[Vector2(26, -22), Vector2(12, 22), fur],                        # 前腿
		[Vector2(22, -72), Vector2(34, 32), fur],                        # 頭
		[Vector2(26, -84), Vector2(9, 14), fur],                         # 耳
		[Vector2(42, -84), Vector2(9, 14), fur],
		[Vector2(52, -56), Vector2(20, 14), fur],                        # 吻部
		[Vector2(66, -56), Vector2(6, 6), Color(0.12, 0.1, 0.12)],       # 鼻
		[Vector2(44, -64), Vector2(6, 6), Color(0.12, 0.1, 0.12)],       # 眼
		[Vector2(32, -70), Vector2(9, 5), Color(0.82, 0.16, 0.2)],       # 額頭的紋樣
		[Vector2(54, -44), Vector2(14, 4), Color(0.82, 0.16, 0.2)],      # 嘴
	])


func _make_figure(parts: Array) -> Node2D:
	var figure := Node2D.new()
	for part: Array in parts:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = part[0]
		rect.size = part[1]
		rect.color = part[2]
		figure.add_child(rect)
	figure.z_index = 1
	get_parent().add_child(figure)
	return figure


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = []
	if _owl.active():
		parts.append("鷲 %d" % ceili(_owl.time))
	if _dog.active():
		parts.append("玉犬 %d" % ceili(_dog.time))
	if in_surge():
		parts.append("咒力高漲 %d" % ceili(_surge_time))
	_status_label.text = "  ".join(parts)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	if _has_sprite and in_surge() and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH, State.CAST]:
		_sprite.modulate = Color(0.85, 0.95, 1.6)
