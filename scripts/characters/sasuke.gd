class_name SasukeFighter
extends Fighter
## 以宇智波佐助為藍本的角色(火影忍者)。氣量上限是 5 格(在 sasuke.tscn 設定 max_energy = 500)。
##
## 普通攻擊(五段)
##   拔出腰後的草薙劍往前揮、往前踢、轉身橫掃、由下往上挑,
##   最後往後跳起,在空中往斜下方丟苦無,落地後收刀。
## 招式
##   千鳥(skill,1 格):手往下凝聚雷電 1 秒(期間被打會中斷),接著衝向前方把雷推到對手身上。
##     普通攻擊打到一半時按下去會變成「千鳥雷槍」(1 格):一腳把對手踢上空中,
##     再從手上射出一道長長的雷電刺向空中。
##   豪火球之術(上 + skill,1 格):往前吐出一顆巨大的火球。確實打中的話對手會燃燒 5 秒,持續扣血。
##   麒麟(下 + special,4 格):舉手凝聚雷電 2 秒,頭頂的雷雲跟著對手走;
##     落雷前 0.5 秒才定住位置,接著一條龍形的雷電落下。防禦擋不住,
##     被打中會受到大量傷害並麻痺 2 秒,期間無法動彈。

const LIGHTNING_COLOR := Color(0.62, 0.85, 1.0)
const FIRE_COLOR := Color(1.0, 0.55, 0.2)
const BLADE_COLOR := Color(0.88, 0.92, 1.0)
const FX_DIR := "res://assets/sasuke_fx"        # 千鳥、雷槍、火球、燃燒、雷雲、麒麟
const KUNAI_FX_DIR := "res://assets/naruto_fx"  # 苦無和波風湊共用同一張圖
const CHEST := Vector2(0, -55)                  # 身體中心相對腳底的位置

# 普攻第五段:往後跳起,在空中往斜下方丟苦無
const THROW_STEP := 4                 # 這一段在連段裡的編號
const THROW_HOP := Vector2(-250, -520)  # 跳起的速度(x 是相對面向)
const KUNAI_HAND := Vector2(38, -56)  # 苦無離手的位置(相對當時的腳底)
const KUNAI_SPEED := 1400.0
const KUNAI_ANGLE := 0.6              # 沒有目標時往下的角度(弧度)
const KUNAI_ANGLE_MIN := 0.2          # 會稍微瞄準對手,但只在這個範圍內
const KUNAI_ANGLE_MAX := 1.1
const KUNAI_LIFETIME := 0.6
const KUNAI_SIZE := Vector2(56, 40)
const KUNAI_DAMAGE := 50
const KUNAI_HITSTUN := 0.75           # 被苦無釘住的時間(比收刀久,所以佐助先能動)
# 千鳥
const CHIDORI_COST := 100
const CHIDORI_CHARGE := 1.0           # 凝聚雷電的時間,期間被打會中斷
const CHIDORI_RUSH_TIME := 0.42
const CHIDORI_RUSH_SPEED := 1150.0
const CHIDORI_RECOVERY := 0.32
const CHIDORI_DAMAGE := 240
const CHIDORI_LOW := Vector2(22, -28)   # 凝聚時雷電的位置(朝下的手掌)
const CHIDORI_HAND := Vector2(62, -68)  # 衝刺時雷電的位置(往前推的手)
const CHIDORI_SIZE := Vector2(90, 100)
const CHIDORI_ART_SCALE := 0.7        # 手上那團雷電的圖縮小到這個比例,才不會把人蓋住
const CHIDORI_WAKEUP_MIN := 140.0      # 電腦:對手倒在這個距離以外才趁機蓄千鳥
const CHIDORI_SAFE_GAP := 480.0       # 電腦:對手在這個距離內又能動,就不蓄千鳥(1 秒內衝得過來打斷)
# 千鳥雷槍
const SPEAR_COST := 100
const SPEAR_KICK_DAMAGE := 50
const SPEAR_CHARGE := 0.24            # 踢完後在手上聚雷的時間
const SPEAR_TIME := 0.22              # 雷槍停留的時間
const SPEAR_RECOVERY := 0.26
const SPEAR_HAND := Vector2(38, -112) # 指向斜上方的那隻手
const SPEAR_LENGTH := 560.0
const SPEAR_ART_LENGTH := 440.0       # 雷槍在點陣圖上的長度,見 tools/pixelfx_custom/anifight/lightning-spear.js
const SPEAR_REACH := 62.0             # 對手離雷槍多近算被刺中
const SPEAR_ANGLE := 0.96             # 沒踢到人時往上的角度(弧度,約 55 度)
const SPEAR_ANGLE_MIN := 0.35
const SPEAR_ANGLE_MAX := 1.45
const SPEAR_DAMAGE := 150
# 豪火球之術
const FIRE_COST := 100
const FIRE_CAST := 0.60
const FIRE_RELEASE := 0.30
const FIRE_MOUTH := Vector2(66, -86)
const FIRE_SPEED := 620.0
const FIRE_LIFETIME := 1.0
const FIRE_SIZE := Vector2(130, 120)
const FIRE_ART_SCALE := 1.8           # 火球的圖再放大這麼多倍(「巨大的火球」)
const FIRE_DAMAGE := 110
const FIRE_SAFE_GAP := 230.0           # 電腦:對手在這個距離內又能動,就不放火球
const BURN_DURATION := 5.0
const BURN_TICK := 0.5
const BURN_TICK_DAMAGE := 12          # 5 秒共 10 下
# 麒麟
const KIRIN_COST := 400
const KIRIN_CHARGE := 2.0
const KIRIN_LOCK := 0.5               # 落雷前這麼久定住位置
const KIRIN_AFTER := 0.5              # 落雷後收招的時間
const KIRIN_DROP := 0.16              # 龍頭從天上落到地面的時間(點陣圖動畫的前段);傷害在落地那一刻
const KIRIN_TRACK_SPEED := 1100.0     # 雷雲追著對手移動的速度
const KIRIN_WIDTH := 180.0            # 定住位置後馬上走開或衝刺就出得去
const KIRIN_HEIGHT := 760.0
const KIRIN_DAMAGE := 380
const KIRIN_STUN := 2.0
const KIRIN_CLOUD_HEIGHT := 455.0     # 雷雲在地面上方多高
const KIRIN_HAND := Vector2(9, -130)  # 高舉的手
const KIRIN_SAFE_GAP := 200.0         # 電腦:對手被轟飛、正在翻滾,而且離這麼遠,才放麒麟

enum Chidori { NONE, CHARGE, RUSH, RECOVER }
enum Spear { NONE, CHARGE, FIRE }
enum Kirin { NONE, CHARGE, AFTER }

var _throw_move: AttackData
var _kunai_move: AttackData
var _chidori_move: AttackData
var _spear_kick_move: AttackData
var _spear_move: AttackData
var _fire_move: AttackData

var _kunai: Array[Dictionary] = []   # 飛行中的苦無:{node, velocity, time}
var _floor_y := 0.0                  # 最近一次站在地上時的高度(苦無飛到這裡就落地)

var _chidori := Chidori.NONE
var _chidori_time := 0.0
var _chidori_node: Node2D

var _spear := Spear.NONE
var _spear_time := 0.0
var _spear_hit := false
var _spear_from := Vector2.ZERO
var _spear_to := Vector2.ZERO
var _spear_node: Node2D              # 手上的雷電,射出後換成雷槍

var _fires: Array[Dictionary] = []   # 飛行中的火球:{node, direction, time}
var _burn_time := 0.0
var _burn_timer := 0.0
var _burn_node: Node2D

var _kirin := Kirin.NONE
var _kirin_x := 0.0
var _kirin_locked := false
var _kirin_falling := false          # 龍形的雷電已經開始往下落
var _kirin_cloud: Node2D
var _kirin_warning: ColorRect
var _kirin_hand: Node2D
var _shock_time := 0.0               # 對手被麒麟麻痺還剩幾秒(只管特效;動不了是定身狀態)
var _shock_node: Node2D

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_preload_sheet(FX_DIR)
	_preload_sheet(KUNAI_FX_DIR)
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", FIRE_COLOR.lightened(0.35))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 拔刀、踢、轉身橫掃、由下往上挑(都不擊飛,最後的苦無才丟得中),最後往後跳起丟苦無。
	# 連段比別人長、打完又會跳開讓出主動權,所以每一下的傷害比一般角色高一點
	var kick := AttackData.make(40, 0.07, 0.10, 0.17, Vector2(72, -58), Vector2(104, 52), Vector2(190, 0), 0.34, false, 150.0)
	# 丟苦無這一段本身沒有攻擊判定,傷害在飛出去的苦無上;收招要撐到落地後把刀收好
	_throw_move = AttackData.make(0, 0.20, 0.06, 0.42, KUNAI_HAND, Vector2(10, 10), Vector2.ZERO, 0.0, false, 0.0)
	_ground_moves = [
		_blade(38, 0.06, 0.16, Vector2(66, -64), Vector2(100, 54), 170.0, 0.32, 130.0),
		kick,
		_blade(46, 0.07, 0.17, Vector2(70, -62), Vector2(120, 60), 190.0, 0.36, 150.0),
		_blade(52, 0.07, 0.19, Vector2(62, -84), Vector2(96, 120), 150.0, 0.60, 120.0),
		_throw_move,
	]
	# 苦無:連段的收尾。不把人打倒,而是釘在原地一段時間:收刀之後衝上去還接得上
	_kunai_move = AttackData.make(KUNAI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(110, 0), KUNAI_HITSTUN, false, 0.0)

	# 千鳥:衝過去一掌打穿,把人轟到場邊。可以防禦
	_chidori_move = _remote(CHIDORI_DAMAGE, Vector2(850, -380), 0.0, true)
	_chidori_move.tumbles = true
	# 千鳥雷槍:先一腳踢上空中,再用雷槍刺上去
	_spear_kick_move = AttackData.make(SPEAR_KICK_DAMAGE, 0.07, 0.10, 0.05, Vector2(50, -96), Vector2(96, 130), Vector2(60, -760), 0.0, true, 0.0)
	_spear_kick_move.builds_energy = false
	_spear_kick_move.color = Color(LIGHTNING_COLOR, 0.8)
	_spear_move = _remote(SPEAR_DAMAGE, Vector2(320, -520), 0.0, true)
	# 豪火球:可以防禦;確實打中才會燒起來
	_fire_move = _remote(FIRE_DAMAGE, Vector2(260, 0), 0.45)


func _blade(damage: int, startup: float, recovery: float, offset: Vector2, hit_size: Vector2,
		push: float, hitstun: float, lunge: float) -> AttackData:
	var move := AttackData.make(damage, startup, 0.10, recovery, offset, hit_size, Vector2(push, 0), hitstun, false, lunge)
	move.color = Color(BLADE_COLOR, 0.75)
	return move


## 不經過攻擊框、由招式自己判定命中的攻擊。耗氣招式,打中不回氣。
func _remote(damage: int, knockback: Vector2, hitstun: float, launches: bool = false) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_kunai()
	_clear_chidori()
	_clear_spear()
	_clear_fires()
	_clear_burn()
	_clear_kirin()
	_clear_shock()
	super(spawn_position, spawn_facing)
	_floor_y = spawn_position.y


func _physics_process(delta: float) -> void:
	super(delta)
	if is_on_floor():
		_floor_y = global_position.y
	_tick_kunai(delta)
	_tick_chidori(delta)
	_tick_spear(delta)
	_tick_fires(delta)
	_tick_burn(delta)
	_tick_kirin(delta)
	_tick_shock(delta)
	_status_label.text = "燃燒 %d" % ceili(_burn_time) if _burn_time > 0.0 else ""


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(FIRE_COST):
			_start_fire()
			return true
		return false
	if _skill1_pressed():
		if _in_normal_chain():
			# 普通攻擊打到一半:招式一變成千鳥雷槍
			if _can_spear() and _spend_energy(SPEAR_COST):
				_start_spear_kick()
				return true
			return false
		if _spend_energy(CHIDORI_COST):
			_start_chidori()
			return true
	return false


func super_cost() -> int:
	return KIRIN_COST


# ---------- 普通攻擊 ----------

func _in_normal_chain() -> bool:
	return state == State.ATTACK and _combo_step >= 0 and _combo_step < _ground_moves.size()


## 千鳥雷槍要站在地上才踢得出來(第五段已經跳到空中了)。
func _can_spear() -> bool:
	return _in_normal_chain() and _combo_step < THROW_STEP and is_on_floor()


## 普通攻擊的任何時候都可以接千鳥雷槍,不必等打中。
func _tick_attack(delta: float) -> void:
	if _can_spear() and _skill1_pressed() and _spend_energy(SPEAR_COST):
		_buffer.clear()
		_start_spear_kick()
		return
	super(delta)


## 揮劍的幾段是刀光,踢擊是拳腳的弧線。
func _slash_effect() -> String:
	return "slash" if _combo_step in [0, 2, 3] else "swish"


func _start_attack(move: AttackData, combo_step: int) -> void:
	super(move, combo_step)
	if move == _throw_move:
		velocity = Vector2(THROW_HOP.x * facing, THROW_HOP.y)
	elif move == _spear_kick_move:
		_attack_anim = "spear_kick"


## 丟苦無這一段:出手的那一刻把苦無丟出去,不畫揮擊的軌跡。
func _show_slash() -> void:
	if _move == _throw_move:
		_throw_kunai()
		return
	super()


func _check_hits() -> void:
	if _move != _throw_move:
		super()


## 踢完那一腳接著放雷槍,不回到待機。
func _end_attack() -> void:
	if _move == _spear_kick_move and state == State.ATTACK:
		_set_hitbox(false)
		_start_spear()
		return
	super()


## 往斜下方丟苦無。對手在前方時會稍微瞄準他的身體。
func _throw_kunai() -> void:
	Sfx.play("kunai")
	var hand := global_position + Vector2(KUNAI_HAND.x * facing, KUNAI_HAND.y)
	var angle := KUNAI_ANGLE
	if opponent != null:
		var to := opponent.global_position + CHEST - hand
		if to.x * facing > 20.0:
			angle = clampf(atan2(to.y, to.x * facing), KUNAI_ANGLE_MIN, KUNAI_ANGLE_MAX)
	var direction := Vector2(facing * cos(angle), sin(angle))
	var node := _sheet_prop(KUNAI_FX_DIR, "kunai", Vector2(44, 10), BLADE_COLOR)
	node.global_position = hand
	node.rotation = direction.angle()
	_kunai.append({"node": node, "velocity": direction * KUNAI_SPEED, "time": KUNAI_LIFETIME})


func _tick_kunai(delta: float) -> void:
	for kunai: Dictionary in _kunai.duplicate():
		var node: Node2D = kunai.node
		kunai.time -= delta
		node.position += kunai.velocity * delta
		if _rect_hits_opponent(node.global_position, KUNAI_SIZE):
			opponent.take_hit(_kunai_move, self)
			_remove_kunai(kunai)
		elif kunai.time <= 0.0 or node.global_position.y >= _floor_y - 4.0:
			_remove_kunai(kunai)  # 插進地面


func _remove_kunai(kunai: Dictionary) -> void:
	if is_instance_valid(kunai.node):
		kunai.node.queue_free()
	_kunai.erase(kunai)


func _clear_kunai() -> void:
	for kunai: Dictionary in _kunai:
		if is_instance_valid(kunai.node):
			kunai.node.queue_free()
	_kunai.clear()


# ---------- 千鳥 ----------

func _start_chidori() -> void:
	_clear_chidori()
	_chidori = Chidori.CHARGE
	_chidori_node = _sheet_prop(FX_DIR, "chidori", Vector2(40, 40), LIGHTNING_COLOR)
	_callout("千鳥", LIGHTNING_COLOR, "chidori")
	# 整招的長度要看衝出去有沒有打到人,先給一個夠長的時間,各階段再自己訂結束的時刻
	_start_cast(10.0, CHIDORI_CHARGE, _release_chidori, "chidori_charge")
	_place_chidori()


## 雷電聚好了:轉向對手,衝出去。
func _release_chidori() -> void:
	if _chidori != Chidori.CHARGE:
		return
	_face_opponent()
	_chidori = Chidori.RUSH
	_chidori_time = CHIDORI_RUSH_TIME
	_cast_anim = "chidori_rush"
	_cast_duration = _state_time + CHIDORI_RUSH_TIME + CHIDORI_RECOVERY
	Sfx.play("dash")


func _tick_chidori(delta: float) -> void:
	if _chidori == Chidori.NONE:
		return
	if state != State.CAST:
		_clear_chidori()  # 被打斷,或整招結束
		return
	match _chidori:
		Chidori.CHARGE:
			# 手上的雷電越聚越大
			_chidori_node.scale = Vector2.ONE * lerpf(0.25, CHIDORI_ART_SCALE, clampf(_state_time / CHIDORI_CHARGE, 0.0, 1.0))
		Chidori.RUSH:
			velocity.x = facing * CHIDORI_RUSH_SPEED
			_chidori_time -= delta
			if _rect_hits_opponent(_chidori_point(), CHIDORI_SIZE):
				_chidori_strike()
			elif _chidori_time <= 0.0:
				_end_chidori()
	_place_chidori()


## 千鳥打在對手身上(被防禦住也算碰到,衝刺到此為止)。
func _chidori_strike() -> void:
	var at := opponent.global_position + CHEST
	opponent.take_hit(_chidori_move, self)
	_spawn_sheet_effect(FX_DIR, "zap", at)
	Sfx.play("thunder")
	screen_shake.emit(12.0)
	_end_chidori()


func _end_chidori() -> void:
	velocity.x = 0.0
	_free_chidori_node()
	_chidori = Chidori.RECOVER
	_cast_duration = _state_time + CHIDORI_RECOVERY


func _chidori_point() -> Vector2:
	var hand := CHIDORI_LOW if _chidori == Chidori.CHARGE else CHIDORI_HAND
	return global_position + Vector2(hand.x * facing, hand.y)


func _place_chidori() -> void:
	if is_instance_valid(_chidori_node):
		_chidori_node.global_position = _chidori_point()


func _free_chidori_node() -> void:
	if is_instance_valid(_chidori_node):
		_chidori_node.queue_free()
	_chidori_node = null


func _clear_chidori() -> void:
	_chidori = Chidori.NONE
	_free_chidori_node()


# ---------- 千鳥雷槍 ----------

func _start_spear_kick() -> void:
	_clear_spear()
	_callout("千鳥雷槍", LIGHTNING_COLOR)
	_start_attack(_spear_kick_move, SPECIAL_STEP)


## 踢完之後:手指向斜上方,雷電聚在手上。
func _start_spear() -> void:
	_clear_spear()
	_spear = Spear.CHARGE
	_spear_node = _sheet_prop(FX_DIR, "chidori", Vector2(30, 30), LIGHTNING_COLOR)
	_spear_node.scale = Vector2.ONE * 0.3
	_spear_node.global_position = _spear_hand()
	_start_cast(SPEAR_CHARGE + SPEAR_TIME + SPEAR_RECOVERY, SPEAR_CHARGE, _fire_spear, "spear")


## 射出雷槍。對手被踢到空中的話就瞄準他,否則往固定的斜上方射。
func _fire_spear() -> void:
	if _spear != Spear.CHARGE:
		return
	var hand := _spear_hand()
	var angle := SPEAR_ANGLE
	if opponent != null and not opponent.is_on_floor():
		var to := opponent.global_position + CHEST - hand
		if to.x * facing > -30.0:
			angle = clampf(atan2(-to.y, maxf(to.x * facing, 1.0)), SPEAR_ANGLE_MIN, SPEAR_ANGLE_MAX)
	var direction := Vector2(facing * cos(angle), -sin(angle))
	if is_instance_valid(_spear_node):
		_spear_node.queue_free()
	_spear_node = _sheet_prop(FX_DIR, "spear", Vector2(SPEAR_ART_LENGTH, 12), LIGHTNING_COLOR)
	_spear_node.global_position = hand
	_spear_node.rotation = direction.angle()
	_spear_node.scale.x = SPEAR_LENGTH / SPEAR_ART_LENGTH
	_spear = Spear.FIRE
	_spear_time = SPEAR_TIME
	_spear_hit = false
	_spear_from = hand
	_spear_to = hand + direction * SPEAR_LENGTH
	Sfx.play("thunder")
	screen_shake.emit(6.0)


func _tick_spear(delta: float) -> void:
	if _spear == Spear.NONE:
		return
	if state != State.CAST and not (state == State.ATTACK and _move == _spear_kick_move):
		_clear_spear()
		return
	if _spear == Spear.CHARGE:
		if is_instance_valid(_spear_node):
			_spear_node.global_position = _spear_hand()
			_spear_node.scale = Vector2.ONE * lerpf(0.3, 0.55, clampf(_state_time / SPEAR_CHARGE, 0.0, 1.0))
		return
	# 雷槍停留的這段時間裡碰到對手就算刺中(只算一次)
	if not _spear_hit and opponent != null and not opponent.is_invulnerable():
		var chest := opponent.global_position + CHEST
		if chest.distance_to(Geometry2D.get_closest_point_to_segment(chest, _spear_from, _spear_to)) <= SPEAR_REACH:
			_spear_hit = true
			opponent.take_hit(_spear_move, self)
			_spawn_sheet_effect(FX_DIR, "zap", chest)
	_spear_time -= delta
	if _spear_time <= 0.0:
		_clear_spear()


func _spear_hand() -> Vector2:
	return global_position + Vector2(SPEAR_HAND.x * facing, SPEAR_HAND.y)


func _clear_spear() -> void:
	_spear = Spear.NONE
	if is_instance_valid(_spear_node):
		_spear_node.queue_free()
	_spear_node = null


# ---------- 豪火球之術 ----------

func _start_fire() -> void:
	_callout("豪火球之術", FIRE_COLOR)
	_start_cast(FIRE_CAST, FIRE_RELEASE, _release_fire, "fire")


func _release_fire() -> void:
	Sfx.play("fireball")
	var node := _sheet_prop(FX_DIR, "fireball", Vector2(FIRE_SIZE.x, FIRE_SIZE.x), FIRE_COLOR)
	node.global_position = global_position + Vector2(FIRE_MOUTH.x * facing, FIRE_MOUTH.y)
	node.scale = Vector2(facing, 1.0) * FIRE_ART_SCALE
	_fires.append({"node": node, "direction": facing, "time": FIRE_LIFETIME})


func _tick_fires(delta: float) -> void:
	for fire: Dictionary in _fires.duplicate():
		var node: Node2D = fire.node
		fire.time -= delta
		node.position.x += fire.direction * FIRE_SPEED * delta
		if _rect_hits_opponent(node.global_position, FIRE_SIZE):
			# 火球在對手身上炸開;確實打中(沒被防住)才會燒起來
			_spawn_effect("blast", node.global_position, _bright(FIRE_COLOR, 1.5), 0.5)
			if _land(_fire_move):
				_ignite()
			_remove_fire(fire)
		elif fire.time <= 0.0:
			_remove_fire(fire)


func _remove_fire(fire: Dictionary) -> void:
	if is_instance_valid(fire.node):
		fire.node.queue_free()
	_fires.erase(fire)


func _clear_fires() -> void:
	for fire: Dictionary in _fires:
		if is_instance_valid(fire.node):
			fire.node.queue_free()
	_fires.clear()


## 對手陷入燃燒狀態(已經在燒的話重新算 5 秒)。
func _ignite() -> void:
	if opponent == null or opponent.state == State.KO:
		return
	_burn_time = BURN_DURATION
	_burn_timer = BURN_TICK
	if not is_instance_valid(_burn_node):
		_burn_node = _sheet_prop(FX_DIR, "burning", Vector2(40, 60), FIRE_COLOR)


func burning() -> bool:
	return _burn_time > 0.0


## 燃燒:每隔一段時間扣一次血,火跟著對手走。不會造成硬直,也不會把人燒倒。
func _tick_burn(delta: float) -> void:
	if not burning():
		return
	if opponent == null or opponent.state == State.KO:
		_clear_burn()
		return
	_burn_time -= delta
	_burn_timer -= delta
	if _burn_timer <= 0.0:
		_burn_timer += BURN_TICK
		opponent.chip(BURN_TICK_DAMAGE)
	if is_instance_valid(_burn_node):
		_burn_node.global_position = opponent.global_position
	if _burn_time <= 0.0:
		_clear_burn()


func _clear_burn() -> void:
	_burn_time = 0.0
	if is_instance_valid(_burn_node):
		_burn_node.queue_free()
	_burn_node = null


# ---------- 麒麟 ----------

func _start_super() -> void:
	_clear_kirin()
	_kirin = Kirin.CHARGE
	_kirin_locked = false
	_kirin_falling = false
	_kirin_x = opponent.global_position.x if opponent != null else global_position.x + facing * 300.0
	# 頭頂的雷雲:畫在角色後面,跟著對手移動
	_kirin_cloud = _sheet_prop(FX_DIR, "cloud", Vector2(300, 90), Color(0.2, 0.2, 0.35, 0.8))
	_kirin_cloud.z_index = -1
	_kirin_cloud.scale = Vector2.ONE * 1.5
	_kirin_cloud.modulate = Color(1.7, 1.7, 2.0, 0.0)
	_kirin_cloud.create_tween().tween_property(_kirin_cloud, "modulate:a", 1.0, 0.4)
	_kirin_hand = _sheet_prop(FX_DIR, "chidori", Vector2(30, 30), LIGHTNING_COLOR)
	_kirin_hand.scale = Vector2.ONE * 0.25
	_callout("麒麟", LIGHTNING_COLOR, "kirin_charge")
	_start_cast(KIRIN_CHARGE + KIRIN_AFTER, KIRIN_CHARGE, _strike_kirin, "kirin")
	_place_kirin()


func _tick_kirin(delta: float) -> void:
	if _kirin == Kirin.NONE:
		return
	if state != State.CAST:
		_clear_kirin()  # 被打斷,或整招結束
		return
	if _kirin != Kirin.CHARGE:
		return
	if not _kirin_locked:
		# 雷雲追著對手;落雷前才定住,並在地上亮出預兆
		if opponent != null:
			_kirin_x = move_toward(_kirin_x, opponent.global_position.x, KIRIN_TRACK_SPEED * delta)
		if _state_time >= KIRIN_CHARGE - KIRIN_LOCK:
			_kirin_locked = true
			_kirin_warning = _spawn_rect(Vector2(KIRIN_WIDTH, KIRIN_HEIGHT), Color(LIGHTNING_COLOR, 0.2), _kirin_center(), -1)
	if not _kirin_falling and _state_time >= KIRIN_CHARGE - KIRIN_DROP:
		# 龍頭先從天上落下來,咬到地面的那一刻才算打中
		_kirin_falling = true
		_drop_kirin()
	if is_instance_valid(_kirin_hand):
		_kirin_hand.scale = Vector2.ONE * lerpf(0.25, 0.6, clampf(_state_time / KIRIN_CHARGE, 0.0, 1.0))
	if is_instance_valid(_kirin_warning):
		_kirin_warning.color.a = 0.16 + 0.1 * sin(_state_time * 40.0)
	_place_kirin()


## 龍形的雷電開始落下(只是畫面;打中是在 _strike_kirin)。
func _drop_kirin() -> void:
	_cast_anim = "kirin_down"
	Sfx.play("kirin")
	if _spawn_sheet_effect(FX_DIR, "kirin", Vector2(_kirin_x, _floor_y)) != null:
		return
	# 沒有點陣圖時:一道白色的光柱
	var bolt := _spawn_rect(Vector2(60, KIRIN_HEIGHT), Color.WHITE, _kirin_center(), 3)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.4)
	tween.tween_callback(bolt.queue_free)


## 龍頭咬到地面。防禦擋不住;被打中的對手受到傷害並麻痺。
func _strike_kirin() -> void:
	if _kirin != Kirin.CHARGE:
		return
	_kirin = Kirin.AFTER
	_free_kirin_props(true)
	screen_shake.emit(20.0)
	if not _rect_hits_opponent(_kirin_center(), Vector2(KIRIN_WIDTH, KIRIN_HEIGHT)):
		return
	opponent.stun(KIRIN_STUN, KIRIN_DAMAGE)
	if opponent.state == State.STUNNED:
		_shock_time = KIRIN_STUN
		if not is_instance_valid(_shock_node):
			_shock_node = _sheet_prop(FX_DIR, "chidori", Vector2(40, 40), LIGHTNING_COLOR)
			_shock_node.modulate.a = 0.85
			_shock_node.scale = Vector2.ONE * 0.6


## 落雷範圍的中心(一根從地面往上的柱子)。
func _kirin_center() -> Vector2:
	return Vector2(_kirin_x, _floor_y - KIRIN_HEIGHT / 2.0)


func _place_kirin() -> void:
	if is_instance_valid(_kirin_cloud):
		_kirin_cloud.global_position = Vector2(_kirin_x, _floor_y - KIRIN_CLOUD_HEIGHT)
	if is_instance_valid(_kirin_hand):
		_kirin_hand.global_position = global_position + Vector2(KIRIN_HAND.x * facing, KIRIN_HAND.y)


## 收掉雷雲、預兆和手上的雷電。fade 為 true 時雷雲慢慢散掉,否則馬上消失。
func _free_kirin_props(fade: bool) -> void:
	if is_instance_valid(_kirin_cloud):
		if fade:
			var cloud := _kirin_cloud
			var tween := cloud.create_tween()
			tween.tween_property(cloud, "modulate:a", 0.0, 0.5)
			tween.tween_callback(cloud.queue_free)
		else:
			_kirin_cloud.queue_free()
	_kirin_cloud = null
	if is_instance_valid(_kirin_warning):
		_kirin_warning.queue_free()
	_kirin_warning = null
	if is_instance_valid(_kirin_hand):
		_kirin_hand.queue_free()
	_kirin_hand = null


func _clear_kirin() -> void:
	_kirin = Kirin.NONE
	_kirin_locked = false
	_kirin_falling = false
	_free_kirin_props(false)


## 麻痺的特效:電流在對手身上亂竄,直到麻痺結束。
func _tick_shock(delta: float) -> void:
	if _shock_time <= 0.0:
		return
	_shock_time -= delta
	if _shock_time <= 0.0 or opponent == null or opponent.state != State.STUNNED:
		_clear_shock()
		return
	if is_instance_valid(_shock_node):
		_shock_node.global_position = opponent.global_position + CHEST


func _clear_shock() -> void:
	_shock_time = 0.0
	if is_instance_valid(_shock_node):
		_shock_node.queue_free()
	_shock_node = null


# ---------- 電腦操作 ----------

## 千鳥要蓄 1 秒:氣夠、對手在衝刺打得到的距離內,而且不會馬上被打斷才放。
func ai_skill_range() -> float:
	if energy < CHIDORI_COST or opponent == null:
		return 0.0
	if not _ai_opponent_cannot_interrupt(CHIDORI_SAFE_GAP):
		return 0.0
	return CHIDORI_RUSH_SPEED * CHIDORI_RUSH_TIME + CHIDORI_HAND.x


## 普通攻擊打到一半、還有氣:接千鳥雷槍。
func ai_combo_skill() -> bool:
	return energy >= SPEAR_COST and _can_spear()


func ai_skill2_ready() -> bool:
	return energy >= FIRE_COST


## 豪火球出手要 0.3 秒:對手貼在身邊又能動的時候不放。
func ai_skill2_range() -> float:
	if not _ai_opponent_cannot_interrupt(FIRE_SAFE_GAP):
		return 0.0
	return FIRE_SPEED * FIRE_LIFETIME


## 對手剛被打飛或剛倒地、離得不遠:趁這個空檔蓄千鳥,等他起身時衝過去。
func ai_charges_on_knockdown() -> bool:
	if energy < CHIDORI_COST or opponent == null or _chidori != Chidori.NONE:
		return false
	var gap := absf(opponent.global_position.x - global_position.x)
	if gap < CHIDORI_WAKEUP_MIN or gap > CHIDORI_RUSH_SPEED * CHIDORI_RUSH_TIME:
		return false
	return opponent.state == State.LAUNCHED or (opponent.state == State.DOWN and opponent._state_time < 0.15)


## 決定存氣的回合先不放招式,存到滿氣:用 1 格千鳥把對手轟飛,剩下 4 格剛好接麒麟。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and energy < max_energy


## 存氣的代價很高(麒麟不容易放出來),所以只有少數回合會存。
func _ai_save_chance() -> float:
	return 0.3


## 只有在放得出來的時機才想放麒麟;否則照常打,不會為了找機會一直後退。
func ai_wants_super() -> bool:
	return energy >= KIRIN_COST and _kirin == Kirin.NONE and ai_super_is_safe()


## 麒麟要站著蓄 2 秒,被打斷就白費 4 格氣:電腦只在對手被定身、或被千鳥轟飛正往場邊滾的時候放。
## 一般的倒地或單純離得遠都不算,對手 2 秒內衝得過來打斷。
func ai_super_is_safe() -> bool:
	if opponent == null:
		return true
	var gap := absf(opponent.global_position.x - global_position.x)
	if opponent.state == State.STUNNED:
		return true
	# 被千鳥轟飛、正在往場邊滾
	return opponent.state == State.LAUNCHED and opponent._tumbling and gap > KIRIN_SAFE_GAP


## 已經定住位置、即將落下的麒麟,讓電腦對手知道要閃。
func ai_hazards() -> Array[Dictionary]:
	var hazards: Array[Dictionary] = []
	if _kirin == Kirin.CHARGE and _kirin_locked:
		hazards.append({"x": _kirin_x, "half_width": KIRIN_WIDTH / 2.0, "time": maxf(KIRIN_CHARGE - _state_time, 0.0)})
	return hazards


# ---------- 顯示 ----------

func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
