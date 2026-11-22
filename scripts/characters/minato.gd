class_name MinatoFighter
extends Fighter
## 以波風湊為藍本的角色(火影忍者)。氣量上限是 5 格(在 minato.tscn 設定 max_energy = 500)。
##
## 「飛雷神」狀態
##   苦無或大招的斬擊確實打中對手(被防禦住不算)時,對手身上會留下飛雷神的術式。
##   術式不會自己消失,要等被下面的招式用掉,或是回合重新開始。
##   對手身上有術式時,招式一、招式二會變成強化版;對手倒地或無敵時放的是一般版,術式會留著。
## 普通攻擊
##   單手持苦無揮兩刀、踢一腳,接著往後轉身跳開,同時把苦無往前丟。
## 招式
##   瞬身踢(skill,1 格):瞬身到前方一段距離,抬腳往上踢。
##     對手有術式:改為瞬身到對手背後往上踢。
##   螺旋丸(上 + skill,2 格):在手中凝聚螺旋丸往前衝,命中後連續傷害再擊飛,破防。
##     對手有術式:改為瞬身到對手上方,把螺旋丸往下砸。
##   飛光連擊閃身二式(下 + special,4 格):往前丟出數枚苦無,接著連續瞬身到每一枚苦無上,
##     沿途經過的對手會被砍中並留下術式。結束時對手身上有術式的話,立刻叫出影分身架住對手,
##     在對手面前凝聚大型螺旋丸推出去,造成大範圍的連續傷害。

const FLASH_COLOR := Color(1.0, 0.86, 0.32)   # 飛雷神:金色的閃光
const CHAKRA_COLOR := Color(0.45, 0.8, 1.0)   # 螺旋丸
const BLADE_COLOR := Color(0.85, 0.9, 1.0)
const FX_DIR := "res://assets/naruto_fx"      # 苦無、螺旋丸、術式印記、影分身的白煙
const CHEST := Vector2(0, -55)                # 身體中心相對腳底的位置
const MARK_OFFSET := Vector2(0, -58)          # 術式印記浮在對手身上的位置

# 普攻第四段:往後跳開並丟出苦無
const THROW_HOP := Vector2(-300, -250)        # 跳開的速度(x 是相對面向)
const KUNAI_HAND := Vector2(58, -82)          # 苦無離手的位置
const KUNAI_SPEED := 1500.0
const KUNAI_LIFETIME := 0.5
const KUNAI_SIZE := Vector2(62, 30)
const KUNAI_DAMAGE := 30
# 招式一:瞬身踢
const KICK_COST := 100
const KICK_BLINK := 260.0                     # 往前瞬身的距離
const KICK_REACH := 64.0                      # 對手擋在路上時,停在他面前這麼遠
const KICK_BEHIND := 64.0                     # 強化版:出現在對手背後這麼遠
const KICK_DAMAGE := 120
const KICK_MARKED_DAMAGE := 150
# 招式二:螺旋丸
const BALL_COST := 200
const BALL_CHARGE := 0.32                     # 凝聚的時間,結束的瞬間衝出去
const BALL_RUSH_TIME := 0.34
const BALL_RUSH_SPEED := 820.0
const BALL_RECOVERY := 0.28
const BALL_SIZE := 66.0                       # 螺旋丸的直徑
const BALL_SIDE := Vector2(32, -62)           # 凝聚時球心的位置(腰側)
const BALL_HAND := Vector2(76, -74)           # 推出時球心的位置
const BALL_TICKS := 4                         # 連續傷害幾下(之後再加最後一擊)
const BALL_TICK_INTERVAL := 0.09
const BALL_TICK_DAMAGE := 30
const BALL_FINAL_DAMAGE := 220
const SLAM_HAND := Vector2(34, -30)           # 往下砸時球心的位置
const SLAM_HEIGHT := 75.0                     # 強化版:出現在對手上方這麼高(球剛好壓在對手頭上)
const SLAM_TICK_DAMAGE := 36
const SLAM_FINAL_DAMAGE := 300
# 大招:飛光連擊閃身二式
const FLASH_COST := 400
const FLASH_THROW := 0.18                     # 出手丟苦無的時間
const FLASH_FLY := 0.16                       # 苦無飛到定點的時間
const FLASH_STEP := 0.10                      # 每次瞬身的間隔
const FLASH_REACH := 85.0                     # 對手離瞬身的路徑多近算被砍中
const FLASH_DAMAGE := 70
const FLASH_RECOVERY := 0.30
## 苦無落點(相對出招位置,x 是相對面向;高度是苦無的高度,也是瞬身後身體中心的位置)。
## 前四枚一低一高往前排開,最後一枚在中間:最後一次瞬身會從遠處斜著穿回來。
const FLASH_POINTS: Array[Vector2] = [
	Vector2(190, -55), Vector2(380, -200), Vector2(570, -55), Vector2(700, -200), Vector2(330, -55),
]
# 大招收尾:影分身架住對手,推出大型螺旋丸
const FINISH_HOLD := 1.5                      # 對手被架住多久(要撐到螺旋丸打完)
const FINISH_DAMAGE_SCALE := 1.5              # 被架住期間受到的傷害倍率
const FINISH_DISTANCE := 240.0                # 本尊出現在對手面前這麼遠(凝聚時球還碰不到對手,看得到影分身)
const FINISH_CHARGE := 0.5
const FINISH_TICKS := 4
const FINISH_TICK_INTERVAL := 0.12
const FINISH_TICK_DAMAGE := 40
const FINISH_FINAL_DAMAGE := 420
const FINISH_HAND := Vector2(100, -80)        # 大型螺旋丸凝聚完成時球心的位置
const FINISH_PUSH := 150.0                    # 推出去的距離
const FINISH_SIZE := Vector2(230, 230)        # 大型螺旋丸的判定範圍
const BIG_BALL_SIZE := 180.0
const CLONE_OFFSET := 30.0                    # 影分身站在對手背後這麼遠

enum Ball { NONE, CHARGE, RUSH, GRIND, RECOVER }
enum Flash { NONE, THROW, FLY, STEPS, CHARGE, PUSH, RECOVER }

var _throw_move: AttackData
var _kunai_move: AttackData
var _kick_move: AttackData
var _kick_marked_move: AttackData
var _ball_tick_move: AttackData
var _ball_final_move: AttackData
var _slam_tick_move: AttackData
var _slam_bounce_move: AttackData   # 對手站在地上:砸進地面再彈起來
var _slam_spike_move: AttackData    # 對手在空中:直接往下砸到地上
var _flash_move: AttackData
var _finish_tick_move: AttackData
var _finish_final_move: AttackData

var _marked := false                # 對手身上有沒有飛雷神的術式
var _mark_node: Node2D
var _kunai: Array[Dictionary] = []  # 飛行中的苦無:{node, direction, time}

var _ball := Ball.NONE
var _ball_slam := false             # 這一發是不是強化版(從上方砸下)
var _ball_time := 0.0
var _ball_timer := 0.0
var _ball_hits_left := 0
var _ball_node: Node2D
var _ball_hold := Vector2.ZERO      # 連續傷害期間自己停住的位置
var _victim_hold := Vector2.ZERO    # 連續傷害期間對手被壓住的位置

var _flash := Flash.NONE
var _flash_time := 0.0
var _flash_index := 0
var _flash_from := Vector2.ZERO
var _flash_floor_y := 0.0
var _flash_hold := Vector2.ZERO
var _flash_holding := false         # 瞬身到空中的苦無上時,要自己停在半空
var _flash_targets: Array[Vector2] = []
var _flash_kunai: Array[Node2D] = []
var _finish_side := 1               # 收尾時本尊站在對手的哪一側
var _finish_hits_left := 0
var _finish_timer := 0.0
var _big_ball: Node2D
var _clone: Node2D

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_preload_sheet(FX_DIR)
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", FLASH_COLOR.lightened(0.3))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 苦無兩刀、一腳(把對手踢開一點,但不擊飛,苦無才丟得中),最後往後跳開丟苦無
	var kick := AttackData.make(56, 0.08, 0.10, 0.20, Vector2(72, -58), Vector2(104, 52), Vector2(300, 0), 0.46, false, 170.0)
	# 丟苦無這一段本身沒有攻擊判定,傷害在飛出去的苦無上
	_throw_move = AttackData.make(0, 0.12, 0.06, 0.22, KUNAI_HAND, Vector2(10, 10), Vector2.ZERO, 0.0, false, 0.0)
	_ground_moves = [
		_blade(36, 0.05, 0.16, Vector2(64, -66), Vector2(92, 52), 170.0, 0.32, 130.0),
		_blade(40, 0.06, 0.17, Vector2(66, -62), Vector2(96, 58), 180.0, 0.34, 140.0),
		kick,
		_throw_move,
	]
	_kunai_move = AttackData.make(KUNAI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(110, 0), 0.50, false, 0.0)

	# 瞬身踢:往正上方踢,對手被踢高,可以跳起來追打
	_kick_move = AttackData.make(KICK_DAMAGE, 0.09, 0.12, 0.26, Vector2(50, -96), Vector2(96, 130), Vector2(90, -820), 0.0, true, 0.0)
	_kick_move.builds_energy = false
	_kick_move.color = Color(FLASH_COLOR, 0.8)
	_kick_marked_move = _kick_move.duplicate()
	_kick_marked_move.damage = KICK_MARKED_DAMAGE

	# 螺旋丸:連續傷害的每一下都破防、不推開對手;最後一擊把人轟到場邊
	_ball_tick_move = _remote(BALL_TICK_DAMAGE, Vector2.ZERO, 0.30)
	_ball_final_move = _remote(BALL_FINAL_DAMAGE, Vector2(900, -360), 0.0, true)
	_ball_final_move.tumbles = true
	_slam_tick_move = _remote(SLAM_TICK_DAMAGE, Vector2.ZERO, 0.30)
	_slam_bounce_move = _remote(SLAM_FINAL_DAMAGE, Vector2(200, -620), 0.0, true)
	_slam_spike_move = _remote(SLAM_FINAL_DAMAGE, Vector2(120, 1100), 0.0, true)

	# 大招:路徑上的斬擊可以防禦;收尾時對手被影分身架住,擋不了
	_flash_move = _remote(FLASH_DAMAGE, Vector2.ZERO, 0.60)
	_flash_move.unblockable = false
	_finish_tick_move = _remote(FINISH_TICK_DAMAGE, Vector2.ZERO, 0.30)
	_finish_final_move = _remote(FINISH_FINAL_DAMAGE, Vector2(1000, -420), 0.0, true)
	_finish_final_move.tumbles = true


func _blade(damage: int, startup: float, recovery: float, offset: Vector2, hit_size: Vector2,
		push: float, hitstun: float, lunge: float) -> AttackData:
	var move := AttackData.make(damage, startup, 0.10, recovery, offset, hit_size, Vector2(push, 0), hitstun, false, lunge)
	move.color = Color(BLADE_COLOR, 0.75)
	return move


## 不經過攻擊框、由招式自己判定命中的攻擊(螺旋丸、大招)。耗氣招式,打中不回氣;預設破防。
func _remote(damage: int, knockback: Vector2, hitstun: float, launches: bool = false) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	move.unblockable = true
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_kunai()
	_clear_ball()
	_clear_flash()
	_clear_mark()
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_tick_kunai(delta)
	_tick_ball(delta)
	_tick_flash(delta)
	_tick_mark()
	_status_label.text = "飛雷神" if _marked else ""


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(BALL_COST):
			_start_ball()
			return true
		return false
	if _skill1_pressed() and _spend_energy(KICK_COST):
		_start_flash_kick()
		return true
	return false


func super_cost() -> int:
	return FLASH_COST


## 對手身上有術式、而且現在打得到:招式會是強化版。對手倒地或無敵時放一般版,術式留著。
func _can_use_mark() -> bool:
	return _marked and opponent != null and not opponent.is_invulnerable()


## 觸控按鈕的提示:對手身上有術式時,招式一的按鈕會發光。
func skill1_empowered() -> bool:
	return _marked


# ---------- 普通攻擊 ----------

## 兩刀是刀光,踢擊是拳腳的弧線。
func _slash_effect() -> String:
	return "slash" if _combo_step in [0, 1] else "swish"


func _start_attack(move: AttackData, combo_step: int) -> void:
	super(move, combo_step)
	if move == _throw_move:
		# 往後轉身跳開
		velocity = Vector2(THROW_HOP.x * facing, THROW_HOP.y)
	elif move == _kick_move or move == _kick_marked_move:
		_attack_anim = "upkick"


## 丟苦無這一段:出手的那一刻把苦無丟出去,不畫揮擊的軌跡。
func _show_slash() -> void:
	if _move == _throw_move:
		_throw_kunai()
		return
	if _move == _kick_move or _move == _kick_marked_move:
		# 瞬身踢:由下往上的一道弧光(一般的揮擊弧線太大,會把人整個蓋住)
		if _spawn_effect("uppercut", global_position, Color(FLASH_COLOR, 0.85), 1.1, facing < 0, 0.0, true) != null:
			return
	super()


func _check_hits() -> void:
	if _move != _throw_move:
		super()


func _throw_kunai() -> void:
	Sfx.play("kunai")
	var node := _prop("kunai", Vector2(44, 10), BLADE_COLOR)
	node.global_position = global_position + Vector2(KUNAI_HAND.x * facing, KUNAI_HAND.y)
	node.scale.x = facing
	_kunai.append({"node": node, "direction": facing, "time": KUNAI_LIFETIME})


func _tick_kunai(delta: float) -> void:
	for kunai: Dictionary in _kunai.duplicate():
		var node: Node2D = kunai.node
		kunai.time -= delta
		node.position.x += kunai.direction * KUNAI_SPEED * delta
		if _rect_hits_opponent(node.global_position, KUNAI_SIZE):
			# 確實打中才留下術式;被防禦住的話苦無只是彈開
			if _land(_kunai_move):
				_apply_mark()
			_remove_kunai(kunai)
		elif kunai.time <= 0.0:
			_remove_kunai(kunai)


func _remove_kunai(kunai: Dictionary) -> void:
	if is_instance_valid(kunai.node):
		kunai.node.queue_free()
	_kunai.erase(kunai)


func _clear_kunai() -> void:
	for kunai: Dictionary in _kunai:
		if is_instance_valid(kunai.node):
			kunai.node.queue_free()
	_kunai.clear()


# ---------- 飛雷神 ----------

func _apply_mark() -> void:
	if opponent == null or opponent.state == State.KO:
		return
	if not _marked:
		_marked = true
		_mark_node = _prop("mark", Vector2(26, 26), FLASH_COLOR)
		Sfx.play("mark")
	_spawn_effect("flash", opponent.global_position + MARK_OFFSET, _bright(FLASH_COLOR), 0.8)
	_tick_mark()


func _clear_mark() -> void:
	_marked = false
	if is_instance_valid(_mark_node):
		_mark_node.queue_free()
	_mark_node = null


## 術式印記跟著對手走,一明一滅。
func _tick_mark() -> void:
	if not _marked or not is_instance_valid(_mark_node):
		return
	if opponent == null:
		_clear_mark()
		return
	_mark_node.global_position = opponent.global_position + MARK_OFFSET
	_mark_node.modulate.a = 0.72 + 0.2 * sin(Time.get_ticks_msec() / 130.0)


# ---------- 招式一:瞬身踢 ----------

func _start_flash_kick() -> void:
	var empowered := _can_use_mark()
	_vanish_effect(FLASH_COLOR)
	if empowered:
		# 飛雷神:直接出現在對手背後(對手在空中就出現在同樣的高度)
		_clear_mark()
		_move_behind_opponent(KICK_BEHIND)
		global_position.y = opponent.global_position.y
		_callout("飛雷神", FLASH_COLOR)
	else:
		var target_x := global_position.x + facing * KICK_BLINK
		if opponent != null:
			# 對手擋在路上:停在他面前,不穿過去
			var ahead := (opponent.global_position.x - global_position.x) * facing
			if ahead > 0.0 and ahead < KICK_BLINK + KICK_REACH:
				target_x = global_position.x + facing * maxf(ahead - KICK_REACH, 0.0)
		global_position.x = clampf(target_x, arena_min_x, arena_max_x)
		velocity = Vector2.ZERO
	_appear_effect(FLASH_COLOR)
	Sfx.play("teleport")
	_start_attack(_kick_marked_move if empowered else _kick_move, SPECIAL_STEP)


# ---------- 招式二:螺旋丸 ----------

func _start_ball() -> void:
	_clear_ball()
	_ball = Ball.CHARGE
	_ball_slam = false
	_ball_node = _prop("rasengan", Vector2(BALL_SIZE, BALL_SIZE), CHAKRA_COLOR)
	_callout("螺旋丸", CHAKRA_COLOR, "rasengan")
	# 整招的長度要看有沒有打中,先給一個夠長的時間,各階段再自己訂結束的時刻
	_start_cast(10.0, BALL_CHARGE, _release_ball, "rasengan_charge")
	_place_ball()


## 凝聚完成:對手身上有術式就瞬身到他上方往下砸,否則往前衝。
func _release_ball() -> void:
	if _ball != Ball.CHARGE:
		return
	if not _can_use_mark():
		_ball = Ball.RUSH
		_ball_time = BALL_RUSH_TIME
		_cast_anim = "rasengan_push"
		_cast_duration = _state_time + BALL_RUSH_TIME + BALL_RECOVERY
		Sfx.play("dash")
		return
	_clear_mark()
	_ball_slam = true
	_vanish_effect(FLASH_COLOR)
	_face_opponent()
	global_position = opponent.global_position + Vector2(-facing * SLAM_HAND.x, -SLAM_HEIGHT)
	global_position.x = clampf(global_position.x, arena_min_x, arena_max_x)
	_appear_effect(FLASH_COLOR)
	Sfx.play("teleport")
	_callout("飛雷神", FLASH_COLOR)
	_cast_anim = "slam"
	_begin_grind()


## 螺旋丸壓在對手身上:雙方停在原地,開始連續傷害。
func _begin_grind() -> void:
	_ball = Ball.GRIND
	_ball_hits_left = BALL_TICKS + 1
	_ball_timer = 0.0
	velocity = Vector2.ZERO
	_ball_hold = global_position
	_victim_hold = opponent.global_position
	_cast_duration = _state_time + 10.0


func _tick_ball(delta: float) -> void:
	if _ball == Ball.NONE:
		return
	if state != State.CAST:
		_clear_ball()  # 被打斷,或整招結束
		return
	match _ball:
		Ball.CHARGE:
			# 腰側的螺旋丸越轉越大
			_ball_node.scale = Vector2.ONE * lerpf(0.25, 1.0, clampf(_state_time / BALL_CHARGE, 0.0, 1.0))
		Ball.RUSH:
			velocity.x = facing * BALL_RUSH_SPEED
			_ball_time -= delta
			if _rect_hits_opponent(_ball_point(), Vector2(BALL_SIZE + 24.0, BALL_SIZE + 40.0)):
				_begin_grind()
			elif _ball_time <= 0.0:
				# 沒打到人:螺旋丸散掉
				velocity.x = 0.0
				_spawn_effect("flash", _ball_point(), _bright(CHAKRA_COLOR), 0.7)
				_free_ball_node()
				_ball = Ball.RECOVER
		Ball.GRIND:
			_hold_grind()
			_ball_timer -= delta
			if _ball_timer <= 0.0:
				_ball_timer = BALL_TICK_INTERVAL
				_grind_hit()
	_place_ball()


## 連續傷害期間:自己停住(強化版是停在半空),對手被壓在原地。
func _hold_grind() -> void:
	velocity = Vector2.ZERO
	if _ball_slam:
		global_position = _ball_hold
	if opponent != null and not opponent.is_immovable():
		opponent.velocity = Vector2.ZERO
		opponent.global_position = _victim_hold


func _grind_hit() -> void:
	_ball_hits_left -= 1
	if opponent == null or opponent.is_invulnerable():
		_finish_ball(false)
	elif _ball_hits_left > 0:
		opponent.take_hit(_slam_tick_move if _ball_slam else _ball_tick_move, self)
		if opponent.is_invulnerable():
			_finish_ball(false)  # 對手被打倒,或連段到達上限被強制擊飛
	else:
		_finish_ball(true)


## 螺旋丸炸開。hit 為 true 時最後一擊打在對手身上。
func _finish_ball(hit: bool) -> void:
	var at := _ball_point()
	if hit and _ball_slam:
		if opponent.is_on_floor():
			# 把人砸進地面再彈起來
			_spawn_effect("landing", opponent.global_position)
			opponent.take_hit(_slam_bounce_move, self)
		else:
			opponent.take_hit(_slam_spike_move, self)
	elif hit:
		opponent.take_hit(_ball_final_move, self)
	_spawn_effect("blast", at, _bright(CHAKRA_COLOR, 1.6), 0.7 if _ball_slam else 0.6)
	Sfx.play("rasengan_burst")
	screen_shake.emit(13.0 if hit else 5.0)
	_free_ball_node()
	_ball = Ball.RECOVER
	_cast_duration = _state_time + BALL_RECOVERY


## 螺旋丸球心現在的位置。
func _ball_point() -> Vector2:
	var hand := BALL_SIDE if _ball == Ball.CHARGE else (SLAM_HAND if _ball_slam else BALL_HAND)
	return global_position + Vector2(hand.x * facing, hand.y)


func _place_ball() -> void:
	if is_instance_valid(_ball_node):
		_ball_node.global_position = _ball_point()


func _free_ball_node() -> void:
	if is_instance_valid(_ball_node):
		_ball_node.queue_free()
	_ball_node = null


func _clear_ball() -> void:
	_ball = Ball.NONE
	_ball_slam = false
	_free_ball_node()


# ---------- 大招:飛光連擊閃身二式 ----------

func _start_super() -> void:
	_clear_flash()
	_flash = Flash.THROW
	_callout("飛光連擊閃身二式", FLASH_COLOR, "special")
	_start_cast(10.0, FLASH_THROW, _release_flash, "throw")


## 把苦無一口氣丟出去,各自飛向自己的落點。
func _release_flash() -> void:
	if _flash != Flash.THROW:
		return
	_flash = Flash.FLY
	_flash_time = FLASH_FLY
	_flash_index = 0
	_flash_holding = false
	_flash_floor_y = global_position.y
	_flash_from = global_position + Vector2(KUNAI_HAND.x * facing, KUNAI_HAND.y)
	Sfx.play("kunai")
	for offset in FLASH_POINTS:
		var target := global_position + Vector2(offset.x * facing, offset.y)
		target.x = clampf(target.x, arena_min_x + 10.0, arena_max_x - 10.0)
		_flash_targets.append(target)
		var node := _prop("kunai", Vector2(44, 10), BLADE_COLOR)
		node.global_position = _flash_from
		node.rotation = (target - _flash_from).angle()
		_flash_kunai.append(node)


func _tick_flash(delta: float) -> void:
	if _flash == Flash.NONE:
		return
	if state != State.CAST:
		_clear_flash()  # 被打斷,或整招結束
		return
	if _flash_holding:
		velocity = Vector2.ZERO
		global_position = _flash_hold
	_flash_time -= delta
	match _flash:
		Flash.FLY:
			# 苦無先快後慢地飛到落點,停在那裡等他過去
			var progress := 1.0 - clampf(_flash_time / FLASH_FLY, 0.0, 1.0)
			for index in _flash_kunai.size():
				_flash_kunai[index].global_position = _flash_from.lerp(_flash_targets[index], 1.0 - pow(1.0 - progress, 2.0))
			if _flash_time <= 0.0:
				for node in _flash_kunai:
					_summon_play(node, "kunai_still")
				_flash = Flash.STEPS
		Flash.STEPS:
			if _flash_time > 0.0:
				return
			if _flash_index < _flash_targets.size():
				_flash_time = FLASH_STEP
				_flash_step()
			else:
				_end_flash_steps()
		Flash.CHARGE:
			_tick_finish_charge()
		Flash.PUSH:
			_tick_finish_push(delta)
	_tick_clone()


## 瞬身到下一枚苦無上,沿途砍中擋在路上的對手。
func _flash_step() -> void:
	var from := global_position + CHEST
	var to := _flash_targets[_flash_index]
	# 斬擊在出發的那一刻就算打出去:對手面向他防禦就擋得住,不會因為他穿到背後而變成從背後砍
	if _path_hits_opponent(from, to):
		_spawn_effect("cut", opponent.global_position + CHEST, _bright(FLASH_COLOR, 1.6), 1.2, to.x < from.x)
		Sfx.play("slash")
		if _land(_flash_move):
			_apply_mark()
	_leave_ghost()
	if is_instance_valid(_flash_kunai[_flash_index]):
		_flash_kunai[_flash_index].queue_free()
	_flash_index += 1
	global_position = Vector2(to.x, minf(to.y - CHEST.y, _flash_floor_y))
	velocity = Vector2.ZERO
	_flash_hold = global_position
	_flash_holding = true
	if absf(to.x - from.x) > 1.0:
		facing = int(signf(to.x - from.x))
	_cast_anim = "strike1" if _flash_index % 2 == 1 else "strike2"
	_anim_restart = true
	_flash_streak(from, to)
	_spawn_effect("flash", to, _bright(FLASH_COLOR), 0.6)
	Sfx.play("teleport")


## 對手的身體中心是不是在 from 到 to 這段路徑附近。
func _path_hits_opponent(from: Vector2, to: Vector2) -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	var chest := opponent.global_position + CHEST
	return chest.distance_to(Geometry2D.get_closest_point_to_segment(chest, from, to)) <= FLASH_REACH


## 瞬身留下的一道金色光痕。
func _flash_streak(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	if length < 30.0:
		return
	var streak := _spawn_rect(Vector2(length, 6), Color(_bright(FLASH_COLOR, 1.3), 0.95), (from + to) / 2.0, 2)
	streak.rotation = (to - from).angle()
	var tween := streak.create_tween()
	tween.tween_property(streak, "scale:y", 0.2, 0.22)
	tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.22)
	tween.tween_callback(streak.queue_free)


## 在原地留下一個淡掉的金色殘影(目前這一格的樣子)。
func _leave_ghost() -> void:
	var ghost := _copy_of_self(_sprite.animation, _sprite.frame) if _has_sprite else null
	if ghost == null:
		return
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(2.4, 2.0, 0.9, 0.55)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


## 用角色素材的某一格做一個不會動的分身圖,放在場景裡(殘影、影分身用)。沒有素材時回傳 null。
func _copy_of_self(animation: StringName, frame: int) -> Sprite2D:
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_animation(animation):
		return null
	var copy := Sprite2D.new()
	copy.texture = frames.get_frame_texture(animation, mini(frame, frames.get_frame_count(animation) - 1))
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	copy.centered = false
	copy.scale = _sprite.scale
	copy.offset = _sprite_offset
	get_parent().add_child(copy)
	return copy


## 所有苦無都瞬身過了:對手身上有術式就接收尾,否則收招。
func _end_flash_steps() -> void:
	_free_flash_kunai()
	if _marked and opponent != null and opponent.state != State.KO:
		opponent.stun(FINISH_HOLD, 0, FINISH_DAMAGE_SCALE)
		if opponent.state == State.STUNNED:
			_begin_finish()
			return
	_recover_flash()


func _recover_flash() -> void:
	_flash = Flash.RECOVER
	_flash_holding = false
	_cast_anim = "cast"
	_cast_duration = _state_time + FLASH_RECOVERY


## 收尾:影分身從背後架住對手,本尊出現在對手面前開始凝聚大型螺旋丸。
func _begin_finish() -> void:
	_clear_mark()
	_leave_ghost()
	_finish_side = int(signf(global_position.x - opponent.global_position.x))
	if _finish_side == 0:
		_finish_side = -facing
	var front_x := opponent.global_position.x + _finish_side * FINISH_DISTANCE
	if front_x < arena_min_x or front_x > arena_max_x:
		# 這一側沒有空間:改站另一邊
		_finish_side = -_finish_side
		front_x = opponent.global_position.x + _finish_side * FINISH_DISTANCE
	global_position = Vector2(front_x, _flash_floor_y)
	velocity = Vector2.ZERO
	facing = -_finish_side
	_flash_hold = global_position
	_flash_holding = true
	_appear_effect(FLASH_COLOR)
	Sfx.play("teleport")
	_spawn_clone()
	_flash = Flash.CHARGE
	_flash_time = FINISH_CHARGE
	_cast_anim = "rasengan_charge"
	_big_ball = _prop("rasengan_big", Vector2(BIG_BALL_SIZE, BIG_BALL_SIZE), CHAKRA_COLOR)
	_callout("螺旋丸", CHAKRA_COLOR, "rasengan")
	_tick_finish_charge()


func _spawn_clone() -> void:
	var at := _clone_point()
	_spawn_sheet_effect(FX_DIR, "poof", at)
	Sfx.play("poof")
	if not _has_sprite:
		return
	_clone = _copy_of_self("guard", 0)
	if _clone == null:
		return
	_clone.flip_h = _finish_side < 0  # 面向對手(本尊在另一邊)
	_clone.z_index = -1               # 畫在對手後面
	_clone.global_position = at


func _clone_point() -> Vector2:
	return opponent.global_position + Vector2(-_finish_side * CLONE_OFFSET, 0)


## 影分身跟著被架住的對手;對手不再被架住(打飛、被打倒)就「砰」一聲消失。
func _tick_clone() -> void:
	if not is_instance_valid(_clone):
		return
	if opponent == null or opponent.state != State.STUNNED:
		_dismiss_clone()
		return
	_clone.global_position = _clone_point()


func _dismiss_clone() -> void:
	if not is_instance_valid(_clone):
		return
	_spawn_sheet_effect(FX_DIR, "poof", _clone.global_position)
	Sfx.play("poof")
	_clone.queue_free()
	_clone = null


## 大型螺旋丸在身前越聚越大。
func _tick_finish_charge() -> void:
	var progress := 1.0 - clampf(_flash_time / FINISH_CHARGE, 0.0, 1.0)
	_place_big_ball(BALL_SIDE.lerp(FINISH_HAND, progress), lerpf(0.2, 1.0, progress))
	if _flash_time > 0.0:
		return
	_flash = Flash.PUSH
	_flash_time = FINISH_TICK_INTERVAL * (FINISH_TICKS + 1)
	_finish_hits_left = FINISH_TICKS + 1
	_finish_timer = FINISH_TICK_INTERVAL
	_cast_anim = "rasengan_push"
	Sfx.play("rasengan")
	if is_instance_valid(_big_ball):
		_big_ball.modulate.a = 0.85  # 稍微透明:看得到被捲在裡面的對手


## 把大型螺旋丸推出去:球壓過對手,範圍內連續傷害,最後炸開。
func _tick_finish_push(delta: float) -> void:
	var total := FINISH_TICK_INTERVAL * (FINISH_TICKS + 1)
	var progress := 1.0 - clampf(_flash_time / total, 0.0, 1.0)
	_place_big_ball(FINISH_HAND + Vector2(FINISH_PUSH * progress, 0), 1.0 + 0.05 * sin(_state_time * 40.0))
	_finish_timer -= delta
	if _finish_timer > 0.0:
		return
	_finish_timer = FINISH_TICK_INTERVAL
	_finish_hits_left -= 1
	var center := _big_ball_point(FINISH_HAND + Vector2(FINISH_PUSH * progress, 0))
	var hit := _rect_hits_opponent(center, FINISH_SIZE)
	if _finish_hits_left > 0:
		if hit:
			opponent.take_hit(_finish_tick_move, self)
		return
	# 最後一擊:螺旋丸炸開,把人轟到場邊
	if hit:
		opponent.take_hit(_finish_final_move, self)
	_spawn_effect("blast", center, _bright(CHAKRA_COLOR, 1.7), 1.1)
	Sfx.play("rasengan_burst")
	screen_shake.emit(18.0 if hit else 8.0)
	_dismiss_clone()
	_free_big_ball()
	_recover_flash()


func _big_ball_point(hand: Vector2) -> Vector2:
	return global_position + Vector2(hand.x * facing, hand.y)


func _place_big_ball(hand: Vector2, size: float) -> void:
	if is_instance_valid(_big_ball):
		_big_ball.global_position = _big_ball_point(hand)
		_big_ball.scale = Vector2.ONE * size


func _free_big_ball() -> void:
	if is_instance_valid(_big_ball):
		_big_ball.queue_free()
	_big_ball = null


func _free_flash_kunai() -> void:
	for node in _flash_kunai:
		if is_instance_valid(node):
			node.queue_free()
	_flash_kunai.clear()


func _clear_flash() -> void:
	_flash = Flash.NONE
	_flash_holding = false
	_flash_targets.clear()
	_free_flash_kunai()
	_free_big_ball()
	_dismiss_clone()


# ---------- 共用 ----------

## 從火影系列的特效圖拿一個循環播放的小道具(苦無、螺旋丸、印記)放進場景;原點是圖的對齊點。
func _prop(animation: String, fallback_size: Vector2, color: Color) -> Node2D:
	return _sheet_prop(FX_DIR, animation, fallback_size, color)


# ---------- 電腦操作 ----------

## 瞬身踢:對手有術式時從哪裡都踢得到;否則要在瞬身的距離內。
func ai_skill_range() -> float:
	if energy < KICK_COST:
		return 0.0
	return INF if _can_use_mark() else KICK_BLINK + KICK_REACH


func ai_skill2_ready() -> bool:
	return energy >= BALL_COST


## 螺旋丸:對手有術式時直接砸得到;否則要在衝刺的距離內。
func ai_skill2_range() -> float:
	return INF if _can_use_mark() else BALL_RUSH_SPEED * BALL_RUSH_TIME + BALL_HAND.x


## 決定存氣的回合先不放招式,存滿 4 格放大招。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and energy < FLASH_COST


## 氣夠了、對手在苦無飛得到的範圍內就想放大招;對手身上已經有術式更好(收尾一定接得上)。
func ai_wants_super() -> bool:
	if energy < FLASH_COST or opponent == null or _flash != Flash.NONE:
		return false
	var ahead := (opponent.global_position.x - global_position.x) * facing
	return ahead > 0.0 and ahead < FLASH_POINTS[3].x and (_marked or opponent.state != State.GUARD)


## 出手丟苦無的那一下會被打斷:對手貼在身邊出招時先不放。
func ai_super_is_safe() -> bool:
	return _marked or _ai_opponent_cannot_interrupt(150.0) or opponent.state != State.ATTACK


# ---------- 顯示 ----------

func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
