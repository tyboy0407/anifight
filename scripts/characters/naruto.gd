class_name NarutoFighter
extends Fighter
## 以漩渦鳴人為藍本的角色。氣量上限是 5 格(在 naruto.tscn 設定 max_energy = 500)。
##
## 普通攻擊(按四下)
##   第一下:一拳接一腳(按一下就會打完兩下)。 第二下:另一隻手再一拳。 第三下:上踢,把對手踢到空中。
##   第四下:結印,影分身出現在對手上方把人往下打,落到身前時本體一拳揍飛。
## 招式一「影分身之術」(2 格):叫出一個分身。分身的血量是本體的 10%,會自己走到對手身邊出拳;場上最多兩個。
## 招式二「螺旋丸」(1 格):原地凝聚後往前推出去。場上有分身時,分身會瞬身到身後幫忙,變成傷害更高的大型螺旋丸。
## 大招「鳴人連擊」(3 格):八個分身圍住對手輪流毆打、一起把人踢上天,本體踩著分身跳上去,用螺旋丸把人砸回地面。
##   整套不受連段上限限制。
## 尾獸爆走(被動,每回合一次):會讓血量掉到 5% 以下的那一下(包含原本會被打倒的)打不死他,
##   血量回到 30% 並進入尾獸爆走 30 秒:長出四條查克拉尾巴,出手、傷害、移動都快 30%,招式也換一組:
##     招式一(1 格):往前撲出去的爪擊,打中的對手會浮空。
##     招式二(1 格):尾獸螺旋丸,凝聚紅色的螺旋丸後快速推出,打中的對手飛出去;
##       對手落地前按普通攻擊:衝過去抓住對手往上拋,再跳上去用爪子連抓。
##     大招不能用。
##   時間到了之後陷入虛脫,到這一回合結束都放不出任何招式(只剩普通攻擊)。

const CHAKRA_COLOR := Color(0.45, 0.8, 1.0)
const CLONE_COLOR := Color(1.0, 0.72, 0.3)
const FOX_COLOR := Color(1.0, 0.34, 0.16)
const FX_DIR := "res://assets/naruto_fx"  # 螺旋丸、影分身的白煙(和波風湊共用)
const FOX_SPRITES := "res://assets/characters/naruto_kyuubi"
const CHEST := Vector2(0, -62)

# 普通攻擊的第四下
const FINISH_REACH := 330.0             # 浮空的對手在身前這麼遠以內,影分身才追得到
const FINISH_NEAR := 150.0              # 對手還站在地上的話,要在這麼近以內
const FINISH_HEIGHT := 480.0            # 對手離地這麼高以內
const FINISH_DROP := Vector2(76, -26)   # 影分身把浮空的對手打到身前的這個位置(對手的腳底)
const FINISH_PUNCH_SIZE := Vector2(190, 210)
const SPIKE_DAMAGE := 40
const FINAL_DAMAGE := 80
# 影分身之術
const CLONE_COST := 200
const CLONE_MAX := 2
const CLONE_HEALTH_RATIO := 0.1
const CLONE_CAST := 0.42
const CLONE_RELEASE := 0.24
const CLONE_SPEED := 270.0
const CLONE_SLOT := 74.0                # 站在對手身旁多遠
const CLONE_REACH := 92.0               # 離對手這麼近就出拳
const CLONE_WINDUP := 0.26
const CLONE_RECOVER := 0.28
const CLONE_INTERVAL := 1.4             # 兩拳之間至少隔多久
const CLONE_FIRST := 0.6                # 剛出現、剛幫忙完之後,過多久才會出第一拳
const CLONE_DAMAGE := 26
const CLONE_HIT_SIZE := Vector2(100, 76)
const CLONE_HURT := 0.32
# 螺旋丸
const BALL_COST := 100
const BALL_CHARGE := 0.4
const BALL_RUSH_SPEED := 780.0
const BALL_RUSH_TIME := 0.26
const BALL_RECOVERY := 0.34
const BALL_DAMAGE := 175
const BIG_BALL_DAMAGE := 260
const BALL_SIZE := 66.0
const BIG_BALL_SIZE := 150.0
const BIG_BALL_SCALE := 0.82            # 大型螺旋丸的圖要縮到多大
const BALL_SIDE := Vector2(24, -58)     # 凝聚時球心的位置(腰前)
const BALL_HAND := Vector2(74, -74)     # 推出時球心的位置
# 鳴人連擊
const BARRAGE_COST := 300
const BARRAGE_SEAL := 0.34
const BARRAGE_RANGE := 340.0
const BARRAGE_BEATS := 8
const BARRAGE_INTERVAL := 0.12
const BARRAGE_HOLD := 1.5               # 對手被圍住多久(要撐到被踢上天)
const BARRAGE_DAMAGE := 34
const BARRAGE_KICK_DAMAGE := 90
const BARRAGE_SLAM_DAMAGE := 560
const BARRAGE_RISE := 0.28              # 踢上去之後,過多久本體才起跳
const BARRAGE_LEAP := 0.26              # 本體從地面跳到對手上方花多久
const BARRAGE_DIVE := 0.7
const BARRAGE_RECOVERY := 0.4
const BARRAGE_ABOVE := Vector2(46, -92) # 起跳後停在對手的哪裡(背後、上方)
const RAISE_HAND := Vector2(22, -138)   # 舉在頭頂的螺旋丸
const DIVE_HAND := Vector2(58, -30)     # 往下砸時的螺旋丸
# 尾獸爆走
const RAGE_TRIGGER := 0.05
const RAGE_HEAL := 0.3
const RAGE_TIME := 30.0
const RAGE_SCALE := 1.3
const CLAW_COST := 100
const CLAW_WINDUP := 0.13
const CLAW_SPEED := 1250.0
const CLAW_TIME := 0.2
const CLAW_DAMAGE := 130
const CLAW_SIZE := Vector2(120, 124)
const BEAST_BALL_COST := 100
const BEAST_BALL_CHARGE := 0.36
const BEAST_BALL_SPEED := 1150.0
const BEAST_BALL_TIME := 0.2
const BEAST_BALL_DAMAGE := 190
const BEAST_BALL_SIZE := 78.0
const CHASE_WINDOW := 1.2               # 尾獸螺旋丸打中後,最多這麼久以內可以按普攻追擊
const CHASE_DASH := 0.1
const CHASE_TOSS := 0.22
const CHASE_SWIPES := 3
const CHASE_INTERVAL := 0.11
const CHASE_GRAB_DAMAGE := 70
const CHASE_SWIPE_DAMAGE := 46
const CHASE_FINAL_DAMAGE := 100
const AI_CLONE_CHANCE := 0.5            # 電腦:每次判斷有多少機率願意叫分身(不然氣全花在這上面)

enum CloneMode { APPEAR, MOVE, PUNCH, HURT, ASSIST }
enum Ball { NONE, CHARGE, RUSH, RECOVER }
enum Barrage { NONE, SEAL, BEAT, RISE, LEAP, DIVE, RECOVER }
enum Beast { NONE, CLAW_WINDUP, CLAW_RUSH, BALL_CHARGE, BALL_RUSH, CHASE_DASH, CHASE_TOSS, CHASE_SWIPE, RECOVER }


## 場上的一個影分身。
class Clone:
	var node: Node2D
	var slot := 0            # 0:繞到對手背後;1:站在本體這一側
	var facing := 1
	var health := 0
	var mode := 0            # CloneMode
	var time := 0.0          # 進入這個狀態多久了
	var cooldown := 0.0      # 還要多久才能再出拳
	var fired := false       # 這一拳打出去了沒
	var struck := false      # 對手這一次揮擊已經打過它了


var _plain_chain: Array[AttackData] = []
var _rage_chain: Array[AttackData] = []
var _plain_air: AttackData
var _rage_air: AttackData
var _spike_move: AttackData        # 影分身把浮空的對手往下打
var _stomp_move: AttackData        # 對手站在地上時的那一下(不打飛)
var _final_move: AttackData
var _next_queued := false          # 第一拳還沒打完就又按了一下:踢完直接接第二下
var _finish_struck := false
var _finish_punched := false

var _clones: Array[Clone] = []
var _clone_move: AttackData
var _floor_y := 0.0

var _ball := Ball.NONE
var _ball_big := false
var _ball_node: Node2D
var _ball_time := 0.0
var _ball_move: AttackData
var _big_ball_move: AttackData
var _helper: Clone                 # 正在幫忙凝聚螺旋丸的分身

var _barrage := Barrage.NONE
var _barrage_time := 0.0
var _barrage_timer := 0.0
var _barrage_left := 0
var _barrage_doubles: Array[Node2D] = []
var _barrage_from := Vector2.ZERO
var _barrage_hold := Vector2.ZERO  # 本體起跳後,對手被定在半空的位置
var _beat_move: AttackData
var _kick_up_move: AttackData
var _slam_move: AttackData

var _rage_time := 0.0
var _rage_used := false            # 這一回合已經爆走過了
var _rage_pending := false         # 剛被打到見底,下一格開始爆走
var _exhausted := false
## 故事模式的關卡可以指定:"auto" 照一般規則;"never" 這一場不會爆走;"always" 整場都是尾獸型態(沒有時間限制、不會虛脫)。
var _story_rampage := "auto"
var _plain_damage_scale := 1.0
var _plain_frames: SpriteFrames
var _fox_frames: SpriteFrames
var _tails: KaguneTails

var _beast := Beast.NONE
var _beast_time := 0.0
var _beast_timer := 0.0
var _beast_left := 0
var _beast_orb: ColorRect
var _beast_from := Vector2.ZERO
var _beast_hold := Vector2.ZERO
var _beast_victim := Vector2.ZERO
var _ghost_timer := 0.0
var _chase_time := 0.0             # 尾獸螺旋丸打中後,還有多久可以按普攻追擊
var _claw_move: AttackData
var _beast_ball_move: AttackData
var _grab_move: AttackData
var _swipe_move: AttackData
var _swipe_final_move: AttackData

## 時間很長、由自己推進節奏的施法,動畫幾乎不會往下播:要擺哪一格由這裡指定(-1 是照動畫自己播)。
var _pose_frame := -1
var _status_label: Label


func _ready() -> void:
	super()
	_preload_sheet(FX_DIR)
	_floor_y = global_position.y
	if _has_sprite:
		_plain_frames = _sprite.sprite_frames
		var fox := SpriteSheetLoader.load_character(FOX_SPRITES)
		_fox_frames = fox.frames if not fox.is_empty() else _plain_frames
	# 查克拉尾巴:和金木研的赫子用同一種畫法,換成尾獸的顏色
	_tails = KaguneTails.new()
	_tails.count = KaguneTails.MAX_TAILS
	_tails.outline = Color(0.42, 0.06, 0.03)
	_tails.body = Color(0.95, 0.3, 0.1)
	_tails.shade = Color(0.72, 0.14, 0.06)
	_tails.shine = Color(1.0, 0.66, 0.3)
	_tails.root = Vector2(-10, -50)
	_tails.visible = false
	add_child(_tails)
	move_child(_tails, 0)
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", FOX_COLOR.lightened(0.35))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	_plain_chain = [
		AttackData.make(28, 0.05, 0.08, 0.10, Vector2(62, -70), Vector2(74, 38), Vector2(140, 0), 0.30, false, 110.0),
		AttackData.make(34, 0.06, 0.09, 0.16, Vector2(72, -56), Vector2(96, 46), Vector2(170, 0), 0.34, false, 110.0),
		AttackData.make(38, 0.06, 0.09, 0.18, Vector2(66, -68), Vector2(80, 40), Vector2(180, 0), 0.36, false, 110.0),
		# 上踢:把人踢到空中,高度剛好讓第四下的影分身接得到
		AttackData.make(50, 0.09, 0.10, 0.20, Vector2(60, -100), Vector2(88, 140), Vector2(30, -860), 0.0, true, 100.0),
		# 第四下只管動作的時間;命中由 _tick_finisher 自己算
		AttackData.make(0, 0.36, 0.08, 0.30, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, false, 0.0),
	]
	_plain_air = _air_move
	for move in _plain_chain:
		_rage_chain.append(_hasted(move))
	_rage_air = _hasted(_air_move)
	_ground_moves = _plain_chain

	_spike_move = _remote(SPIKE_DAMAGE, Vector2(0, 300), 0.0, true)
	_spike_move.builds_energy = true
	_stomp_move = _remote(SPIKE_DAMAGE, Vector2(40, 0), 0.5, false)
	_stomp_move.builds_energy = true
	_final_move = _remote(FINAL_DAMAGE, Vector2(720, -330), 0.0, true)
	_final_move.builds_energy = true
	_final_move.tumbles = true
	_clone_move = _remote(CLONE_DAMAGE, Vector2(70, 0), 0.22, false)

	_ball_move = _remote(BALL_DAMAGE, Vector2(680, -320), 0.0, true)
	_ball_move.tumbles = true
	_big_ball_move = _remote(BIG_BALL_DAMAGE, Vector2(840, -380), 0.0, true)
	_big_ball_move.tumbles = true

	# 鳴人連擊:對手被分身圍住,擋不了;整套不受連段上限限制
	_beat_move = _remote(BARRAGE_DAMAGE, Vector2.ZERO, 0.3, false)
	_kick_up_move = _remote(BARRAGE_KICK_DAMAGE, Vector2(0, -1050), 0.0, true)
	_slam_move = _remote(BARRAGE_SLAM_DAMAGE, Vector2(60, 1500), 0.0, true)
	for move: AttackData in [_beat_move, _kick_up_move, _slam_move]:
		move.unblockable = true
		move.ignores_combo_limit = true

	_claw_move = _remote(CLAW_DAMAGE, Vector2(60, -800), 0.0, true)
	_beast_ball_move = _remote(BEAST_BALL_DAMAGE, Vector2(760, -440), 0.0, true)
	_grab_move = _remote(CHASE_GRAB_DAMAGE, Vector2(0, -860), 0.0, true)
	_swipe_move = _remote(CHASE_SWIPE_DAMAGE, Vector2.ZERO, 0.3, false)
	_swipe_final_move = _remote(CHASE_FINAL_DAMAGE, Vector2(520, 900), 0.0, true)
	for move: AttackData in [_grab_move, _swipe_move, _swipe_final_move]:
		move.unblockable = true


## 不經過攻擊框、由招式自己判定命中的攻擊。預設是耗氣招式,打中不回氣。
func _remote(damage: int, knockback: Vector2, hitstun: float, launches: bool) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	return move


## 尾獸爆走時的普通攻擊:前搖與收招都縮短。
func _hasted(move: AttackData) -> AttackData:
	var fast: AttackData = move.duplicate()
	fast.startup = move.startup / RAGE_SCALE
	fast.recovery = move.recovery / RAGE_SCALE
	return fast


## 故事模式:這一關的鳴人會不會爆走({"rampage": "never"} 或 {"rampage": "always"})。
func apply_story(setup: Dictionary) -> void:
	super(setup)
	_story_rampage = str(setup.get("rampage", "auto"))


func action_available(key: String) -> bool:
	return key != "super" or _story_rampage != "always"


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_dismiss_clones(false)
	_clear_ball()
	_clear_barrage()
	_clear_beast()
	_leave_rage(false)
	_rage_used = false
	_rage_pending = false
	_exhausted = false
	_chase_time = 0.0
	_next_queued = false
	super(spawn_position, spawn_facing)
	_floor_y = spawn_position.y
	if puppet_of == null and _story_rampage != "auto":
		_rage_used = true  # 不會因為血量見底而爆走
		if _story_rampage == "always":
			_begin_rage()


func _exit_tree() -> void:
	_dismiss_clones(false)
	_clear_ball()
	_clear_barrage()
	_clear_beast()


func _physics_process(delta: float) -> void:
	if _rage_pending and state != State.KO:
		_rage_pending = false
		_enter_rage()
	if _chase_time > 0.0 and _can_chase() and _pressed("attack"):
		_start_chase()
	super(delta)
	if is_on_floor():
		_floor_y = global_position.y
	_tick_ball(delta)
	_tick_barrage(delta)
	_tick_beast(delta)
	_tick_clones(delta)
	_tick_rage(delta)
	_update_status()


## 每次開始施法都回到「照動畫自己播」;要指定某一格的招式在呼叫之後再設 _pose_frame。
func _start_cast(duration: float, release_at: float, callback: Callable, animation: String = "cast") -> void:
	_pose_frame = -1
	super(duration, release_at, callback, animation)


# ---------- 招式的入口 ----------

func _try_character_actions() -> bool:
	if (_exhausted or in_rampage()) and _raw_super_pressed():
		# 大招放不出來:把這一下按鍵丟掉,免得放開「下」之後被當成通用大招
		_buffer.erase("special")
		_buffer.erase("super")
	if _exhausted:
		_buffer.erase("skill")
		_buffer.erase("skill2")
		return false
	var which := 2 if _skill2_pressed() else (1 if _skill1_pressed() else 0)
	if which == 0:
		return false
	if in_rampage():
		if which == 1 and _spend_energy(CLAW_COST):
			_start_claw()
			return true
		if which == 2 and _spend_energy(BEAST_BALL_COST):
			_start_beast_ball()
			return true
	elif which == 1:
		if _clones.size() < CLONE_MAX and _spend_energy(CLONE_COST):
			_start_clone_jutsu()
			return true
	elif _spend_energy(BALL_COST):
		_start_ball()
		return true
	if which == 2:
		# 氣不夠:把這一下按鍵丟掉,免得放開「上」之後被當成招式一
		_buffer.erase("skill")
		_buffer.erase("skill2")
	return false


func _raw_super_pressed() -> bool:
	return _pressed("super") or (direction_combos and _pressed("special") and _held("down"))


## 虛脫時連通用的大招也放不出來;尾獸爆走時不能用鳴人連擊。
func _special_pressed() -> bool:
	return not _exhausted and super()


func _super_pressed() -> bool:
	return not _exhausted and not in_rampage() and super()


func super_cost() -> int:
	return max_energy + 1 if _exhausted or in_rampage() else BARRAGE_COST


func _start_super() -> void:
	_start_barrage()


func move_speed() -> float:
	return MOVE_SPEED * (RAGE_SCALE if in_rampage() else 1.0)


# ---------- 普通攻擊 ----------

func _start_attack(move: AttackData, combo_step: int) -> void:
	if combo_step != 1:
		_next_queued = false
	if combo_step == 4:
		_finish_struck = false
		_finish_punched = false
	super(move, combo_step)


func _tick_attack(delta: float) -> void:
	match _combo_step:
		0:
			# 按一下就會打完一拳一腳;出拳途中又按的那一下留給第二下
			if _pressed("attack"):
				_next_queued = true
			_combo_queued = true
		1:
			if _next_queued:
				_combo_queued = true
		4:
			_tick_finisher()
			if state != State.ATTACK:
				return
	super(delta)


## 第四下沒有揮擊的軌跡(影分身與最後一拳各自有特效)。
func _show_slash() -> void:
	if _combo_step != 4:
		super()


## 第四下:結印到一半影分身打下來,結印完本體揮出最後一拳。
func _tick_finisher() -> void:
	if not _finish_struck and _state_time >= _move.startup * 0.5:
		_finish_struck = true
		_finisher_strike()
	if not _finish_punched and _state_time >= _move.startup:
		_finish_punched = true
		_finisher_punch()


## 影分身(尾獸爆走時是自己的查克拉爪子)出現在對手上方往下打:浮空的對手被打到自己身前。
func _finisher_strike() -> void:
	var foe := opponent
	var caught := false
	var at := global_position + Vector2(facing * 150.0, -190.0)
	if foe != null and not foe.is_invulnerable():
		var ahead := (foe.global_position.x - global_position.x) * facing
		var airborne := foe.state == State.LAUNCHED or not foe.is_on_floor()
		if ahead >= -50.0 and ahead <= (FINISH_REACH if airborne else FINISH_NEAR) and _floor_y - foe.global_position.y <= FINISH_HEIGHT:
			caught = true
			at = foe.global_position + Vector2(0, -BODY_SIZE.y - 20.0)
	if in_rampage():
		_spawn_effect("claw", at + Vector2(0, 70), _bright(FOX_COLOR, 1.6), 1.5, facing < 0, PI / 2.0)
		Sfx.play("rika_claw")
	else:
		_flash_double(at, -facing if caught else facing, "air_attack", 0.22, Vector2(0, 54))
		Sfx.play("poof")
	if not caught:
		return
	if foe.state != State.LAUNCHED and foe.is_on_floor():
		# 對手還站在地上:被踩得動彈不得,最後一拳照樣打得到
		foe.take_hit(_stomp_move, self)
		return
	if not _land(_spike_move) or foe.state != State.LAUNCHED:
		return
	# 往下打到身前:算好速度,讓人剛好在最後一拳揮出去的時候落到拳頭前面
	var target := Vector2(global_position.x + facing * FINISH_DROP.x, _floor_y + FINISH_DROP.y)
	target.x = clampf(target.x, arena_min_x, arena_max_x)
	var time := maxf(_move.startup - _state_time, 0.06)
	foe.velocity = (target - foe.global_position) / time - Vector2(0, GRAVITY * time * 0.5)


func _finisher_punch() -> void:
	var center := global_position + Vector2(facing * 86.0, -82.0)
	velocity.x = facing * 160.0
	Sfx.play("swing")
	_spawn_effect("swish", center, Color(1.0, 0.97, 0.75), 1.5, facing < 0, 0.0, true)
	if _rect_hits_opponent(center, FINISH_PUNCH_SIZE) and _land(_final_move):
		screen_shake.emit(8.0)


# ---------- 分身的樣子 ----------

## 一個和自己長得一樣、會播動畫的分身,放在場景裡;回傳裝著它的節點,原點在腳底。
func _make_double(at: Vector2, face: int, animation: String = "idle") -> Node2D:
	var holder := Node2D.new()
	holder.z_index = -1
	if _has_sprite:
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.sprite_frames = _plain_frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.scale = _sprite.scale
		sprite.offset = _sprite_offset
		holder.add_child(sprite)
	else:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = body_color.lightened(0.2)
		rect.size = BODY_SIZE
		rect.position = Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y)
		holder.add_child(rect)
	get_parent().add_child(holder)
	holder.global_position = at
	_double_play(holder, animation, face)
	return holder


## 換分身正在播的動畫。duration 大於 0 時調整速度,讓動畫剛好在這段時間內播完;restart 是從頭再播一次。
func _double_play(holder: Node2D, animation: String, face: int, duration: float = 0.0, restart: bool = false) -> void:
	if not is_instance_valid(holder):
		return
	var sprite := holder.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		return
	sprite.flip_h = face < 0
	var frames := sprite.sprite_frames
	var resolved := animation
	for attempt in 8:
		if frames.has_animation(resolved):
			break
		resolved = ANIM_FALLBACKS.get(resolved, "idle")
	if not frames.has_animation(resolved):
		return
	if sprite.animation == resolved and sprite.is_playing() and not restart:
		return
	var natural := frames.get_frame_count(resolved) / maxf(frames.get_animation_speed(resolved), 0.01)
	sprite.speed_scale = natural / duration if duration > 0.0 else 1.0
	sprite.stop()
	sprite.play(resolved)


## 影分身「砰」一聲的白煙。at 是分身的腳底。
func _poof(at: Vector2, sound: bool = true) -> void:
	_spawn_sheet_effect(FX_DIR, "poof", at)
	if sound:
		Sfx.play("poof")


## 只出現一下子的分身:擺個姿勢、往 drift 移動,時間到就變成白煙。
func _flash_double(at: Vector2, face: int, animation: String, life: float, drift: Vector2 = Vector2.ZERO) -> void:
	var holder := _make_double(at, face, animation)
	holder.z_index = 1
	var tween := holder.create_tween()
	tween.tween_property(holder, "position", holder.position + drift, life).set_ease(Tween.EASE_IN)
	tween.tween_callback(_poof_and_free.bind(holder))


func _poof_and_free(holder: Node2D) -> void:
	if not is_instance_valid(holder):
		return
	if is_inside_tree():
		_poof(holder.global_position + Vector2(0, -8), false)
	holder.queue_free()


# ---------- 招式一:影分身之術 ----------

func _start_clone_jutsu() -> void:
	_face_opponent()
	_callout("影分身之術", CLONE_COLOR)
	_start_cast(CLONE_CAST, CLONE_RELEASE, _summon_clone, "seal")


func _summon_clone() -> void:
	if _clones.size() >= CLONE_MAX:
		return
	var clone := Clone.new()
	clone.slot = 0
	for other in _clones:
		if other.slot == 0:
			clone.slot = 1
	clone.facing = facing
	clone.health = maxi(int(round(max_health * CLONE_HEALTH_RATIO)), 1)
	clone.mode = CloneMode.APPEAR
	clone.cooldown = CLONE_FIRST
	var x := clampf(global_position.x + facing * (70.0 if clone.slot == 0 else -60.0), arena_min_x, arena_max_x)
	clone.node = _make_double(Vector2(x, _floor_y), facing)
	_clones.append(clone)
	_poof(clone.node.global_position)


func clone_count() -> int:
	return _clones.size()


## 分身要走到哪裡:第一個繞到對手背後(和本體一前一後夾住),第二個站在本體這一側。
func _clone_target(clone: Clone) -> float:
	var foe_x := opponent.global_position.x
	var side := signf(foe_x - global_position.x)
	if side == 0.0:
		side = float(facing)
	var direction := side if clone.slot == 0 else -side
	var x := foe_x + direction * CLONE_SLOT
	if x < arena_min_x + 8.0 or x > arena_max_x - 8.0:
		# 對手貼著場邊,背後沒有空間:改站另一邊,離遠一點才不會和另一個分身疊在一起
		x = foe_x - direction * (CLONE_SLOT + 44.0)
	return clampf(x, arena_min_x, arena_max_x)


func _tick_clones(delta: float) -> void:
	if _clones.is_empty():
		return
	if state == State.KO or opponent == null:
		_dismiss_clones(true)
		return
	_check_clone_swings()
	var foe := opponent
	for clone: Clone in _clones.duplicate():
		if not _clones.has(clone) or not is_instance_valid(clone.node):
			continue
		clone.time += delta
		clone.cooldown = maxf(clone.cooldown - delta, 0.0)
		var at := clone.node.global_position
		at.y = _floor_y
		match clone.mode:
			CloneMode.APPEAR:
				if clone.time >= 0.2:
					_set_clone_mode(clone, CloneMode.MOVE)
			CloneMode.HURT:
				_double_play(clone.node, "hit", clone.facing)
				if clone.time >= CLONE_HURT:
					_set_clone_mode(clone, CloneMode.MOVE)
			CloneMode.ASSIST:
				# 站在本體身後幫忙凝聚螺旋丸(什麼時候放開由 _tick_ball 決定)
				clone.facing = facing
				at.x = clampf(global_position.x - facing * 34.0, arena_min_x, arena_max_x)
				_double_play(clone.node, "rasengan_charge", clone.facing)
			CloneMode.MOVE:
				var target := _clone_target(clone)
				var gap := target - at.x
				if absf(foe.global_position.x - at.x) > 1.0:
					clone.facing = int(signf(foe.global_position.x - at.x))
				if absf(gap) > 6.0:
					at.x += signf(gap) * minf(CLONE_SPEED * delta, absf(gap))
					_double_play(clone.node, "walk", clone.facing)
				else:
					_double_play(clone.node, "idle", clone.facing)
				if clone.cooldown <= 0.0 and input_enabled and not foe.is_invulnerable() \
						and absf(foe.global_position.x - at.x) <= CLONE_REACH and foe.global_position.y >= _floor_y - 70.0:
					_set_clone_mode(clone, CloneMode.PUNCH)
					clone.fired = false
					_double_play(clone.node, "attack1", clone.facing, CLONE_WINDUP + CLONE_RECOVER, true)
			CloneMode.PUNCH:
				if not clone.fired and clone.time >= CLONE_WINDUP:
					clone.fired = true
					_clone_punch(clone)
				if clone.time >= CLONE_WINDUP + CLONE_RECOVER:
					_set_clone_mode(clone, CloneMode.MOVE)
					clone.cooldown = CLONE_INTERVAL
		if is_instance_valid(clone.node):
			clone.node.global_position = at


func _set_clone_mode(clone: Clone, mode: int) -> void:
	clone.mode = mode
	clone.time = 0.0


## 分身的一拳。挨打的方向、擋不擋得住都要照分身站的位置算,所以出手的那一刻先把自己「借放」到分身那裡。
func _clone_punch(clone: Clone) -> void:
	var from := clone.node.global_position
	var center := from + Vector2(clone.facing * 54.0, -66.0)
	_spawn_effect("swish", center, Color(1.0, 0.97, 0.75), 0.8, clone.facing < 0)
	if not _rect_hits_opponent(center, CLONE_HIT_SIZE):
		return
	var own_position := global_position
	var own_facing := facing
	global_position = from
	facing = clone.facing
	opponent.take_hit(_clone_move, self)
	global_position = own_position
	facing = own_facing


func _clone_rect(clone: Clone) -> Rect2:
	var at := clone.node.global_position
	return Rect2(at.x - BODY_SIZE.x / 2.0, at.y - BODY_SIZE.y, BODY_SIZE.x, BODY_SIZE.y)


## 對手的普通攻擊掃到分身:同一下揮擊只算一次。
func _check_clone_swings() -> void:
	var swing := opponent.swing_rect()
	if not swing.has_area():
		for clone in _clones:
			clone.struck = false
		return
	for clone: Clone in _clones.duplicate():
		if not clone.struck and swing.intersects(_clone_rect(clone)):
			clone.struck = true
			_hurt_clone(clone, opponent.swing_damage())


## 對手的招式(飛行道具、範圍技)掃過場上:碰到的分身直接消失。
func swept_by(center: Vector2, rect_size: Vector2) -> void:
	if _clones.is_empty():
		return
	var area := Rect2(center - rect_size / 2.0, rect_size)
	for clone: Clone in _clones.duplicate():
		if area.intersects(_clone_rect(clone)):
			_hurt_clone(clone, clone.health)


func _hurt_clone(clone: Clone, damage: int) -> void:
	clone.health -= maxi(damage, 1)
	var chest := clone.node.global_position + CHEST
	_spawn_effect("spark", chest, SPARK_COLOR, 1.0)
	if clone.health <= 0:
		_remove_clone(clone, true)
		return
	Sfx.play("hit_light")
	if clone == _helper:
		return  # 正在幫忙凝聚螺旋丸:挨打也不放手
	_set_clone_mode(clone, CloneMode.HURT)
	_double_play(clone.node, "hit", clone.facing, 0.0, true)


func _remove_clone(clone: Clone, announce: bool) -> void:
	_clones.erase(clone)
	if clone == _helper:
		_helper = null
		_ball_big = false
	if is_instance_valid(clone.node):
		if announce and is_inside_tree():
			_poof(clone.node.global_position)
		clone.node.queue_free()


func _dismiss_clones(announce: bool) -> void:
	for clone: Clone in _clones.duplicate():
		_remove_clone(clone, announce)


# ---------- 招式二:螺旋丸 ----------

func _start_ball() -> void:
	_clear_ball()
	_face_opponent()
	_ball = Ball.CHARGE
	# 場上有分身:叫一個瞬身到身後幫忙,凝聚成大型螺旋丸
	_helper = null
	for clone in _clones:
		if clone.mode != CloneMode.APPEAR:
			_helper = clone
			break
	_ball_big = _helper != null
	if _ball_big:
		_poof(_helper.node.global_position)
		_helper.node.global_position.x = clampf(global_position.x - facing * 34.0, arena_min_x, arena_max_x)
		_set_clone_mode(_helper, CloneMode.ASSIST)
		_poof(_helper.node.global_position, false)
	_ball_node = _sheet_prop(FX_DIR, "rasengan_big" if _ball_big else "rasengan",
			Vector2.ONE * (BIG_BALL_SIZE if _ball_big else BALL_SIZE), CHAKRA_COLOR)
	_callout("大玉螺旋丸" if _ball_big else "螺旋丸", CHAKRA_COLOR, "rasengan")
	# 整招的長度要看有沒有打中,先給一個夠長的時間,各階段再自己訂結束的時刻
	_start_cast(10.0, BALL_CHARGE, _release_ball, "rasengan_charge")
	_place_ball()


## 凝聚完成:整個人往前衝,把螺旋丸推出去。
func _release_ball() -> void:
	if _ball != Ball.CHARGE:
		return
	_ball = Ball.RUSH
	_ball_time = BALL_RUSH_TIME
	_cast_anim = "rasengan_push"
	_cast_duration = _state_time + BALL_RUSH_TIME + BALL_RECOVERY
	_release_helper()
	Sfx.play("dash")


func _release_helper() -> void:
	if _helper != null and _clones.has(_helper):
		_set_clone_mode(_helper, CloneMode.MOVE)
		_helper.cooldown = CLONE_FIRST
	_helper = null


func _tick_ball(delta: float) -> void:
	if _ball == Ball.NONE:
		return
	if state != State.CAST:
		_clear_ball()  # 被打斷,或整招結束
		return
	match _ball:
		Ball.CHARGE:
			var grown := clampf(_state_time / BALL_CHARGE, 0.0, 1.0)
			if is_instance_valid(_ball_node):
				_ball_node.scale = Vector2.ONE * lerpf(0.25, 1.0, grown) * (BIG_BALL_SCALE if _ball_big else 1.0)
		Ball.RUSH:
			velocity.x = facing * BALL_RUSH_SPEED
			_ball_time -= delta
			var reach := Vector2(BIG_BALL_SIZE + 20.0, BIG_BALL_SIZE + 30.0) if _ball_big else Vector2(BALL_SIZE + 24.0, BALL_SIZE + 40.0)
			if _rect_hits_opponent(_ball_point(), reach):
				velocity.x = 0.0
				_burst_ball(_land(_big_ball_move if _ball_big else _ball_move))
			elif _ball_time <= 0.0:
				# 沒打到人:螺旋丸散掉
				velocity.x = 0.0
				_spawn_effect("flash", _ball_point(), _bright(CHAKRA_COLOR), 0.7)
				_free_ball_node()
				_ball = Ball.RECOVER
	_place_ball()


## 螺旋丸炸開。hit 是有沒有確實打中(被擋住也會炸開,只是小一點)。
func _burst_ball(hit: bool) -> void:
	var size := (1.0 if _ball_big else 0.6) * (1.0 if hit else 0.7)
	_spawn_effect("blast", _ball_point(), _bright(CHAKRA_COLOR, 1.6), size)
	Sfx.play("rasengan_burst")
	screen_shake.emit((16.0 if _ball_big else 11.0) if hit else 5.0)
	_free_ball_node()
	_ball = Ball.RECOVER
	_cast_duration = _state_time + BALL_RECOVERY


func _ball_point() -> Vector2:
	var hand := BALL_SIDE if _ball == Ball.CHARGE else BALL_HAND
	if _ball_big:
		# 大的那顆托在身前遠一點、高一點的地方,才不會把人整個蓋住
		hand += Vector2(34, -22) if _ball == Ball.CHARGE else Vector2(50, -12)
	return global_position + Vector2(hand.x * facing, hand.y)


func _place_ball() -> void:
	if is_instance_valid(_ball_node) and _barrage == Barrage.NONE:
		_ball_node.global_position = _ball_point()


func _free_ball_node() -> void:
	if is_instance_valid(_ball_node):
		_ball_node.queue_free()
	_ball_node = null


func _clear_ball() -> void:
	_ball = Ball.NONE
	_ball_big = false
	_release_helper()
	if _barrage == Barrage.NONE:
		_free_ball_node()


# ---------- 大招:鳴人連擊 ----------

func _start_barrage() -> void:
	_clear_barrage()
	_face_opponent()
	_barrage = Barrage.SEAL
	_callout("多重影分身之術", CLONE_COLOR)
	# 節奏由 _tick_barrage 自己推進,施法時間先設成放不完
	_start_cast(10.0, BARRAGE_SEAL, _release_barrage, "seal")


## 結印完成:對手在範圍內就被八個分身圍住,動彈不得。
func _release_barrage() -> void:
	if _barrage != Barrage.SEAL:
		return
	var foe := opponent
	var caught := foe != null and not foe.is_invulnerable() \
			and absf(foe.global_position.x - global_position.x) <= BARRAGE_RANGE
	if caught:
		foe.stun(BARRAGE_HOLD)
		caught = foe.state == State.STUNNED
	if not caught:
		# 沒圍到人:分身在身邊冒出來又消失
		for side: int in [-1, 1]:
			_flash_double(global_position + Vector2(side * 70.0, 0), facing, "idle", 0.2)
		Sfx.play("poof")
		_barrage = Barrage.RECOVER
		_cast_duration = _state_time + BARRAGE_RECOVERY
		return
	Sfx.play("poof")
	var floor_y := maxf(foe.global_position.y, _floor_y)
	for index in BARRAGE_BEATS:
		var side := -1 if index % 2 == 0 else 1
		@warning_ignore("integer_division")
		var x := clampf(foe.global_position.x + side * (58.0 + (index / 2) * 30.0), arena_min_x, arena_max_x)
		var double := _make_double(Vector2(x, floor_y), -side)
		double.z_index = 1 if index < 2 else -1
		_poof(double.global_position, false)
		_barrage_doubles.append(double)
	_barrage = Barrage.BEAT
	_barrage_left = BARRAGE_BEATS
	_barrage_timer = 0.14


func _tick_barrage(delta: float) -> void:
	if _barrage == Barrage.NONE:
		return
	if state != State.CAST:
		_clear_barrage()  # 被打斷,或整招結束
		return
	var foe := opponent
	match _barrage:
		Barrage.BEAT:
			velocity.x = 0.0
			if foe == null or foe.state != State.STUNNED:
				_end_barrage()
				return
			foe.velocity.x = 0.0
			_barrage_timer -= delta
			if _barrage_timer > 0.0:
				return
			_barrage_timer = BARRAGE_INTERVAL
			if _barrage_left > 0:
				_barrage_beat(BARRAGE_BEATS - _barrage_left)
				_barrage_left -= 1
			else:
				_barrage_kick()
		Barrage.RISE:
			velocity.x = 0.0
			_barrage_time -= delta
			if foe == null or foe.is_invulnerable():
				_end_barrage()
			elif _barrage_time <= 0.0:
				_barrage_leap()
		Barrage.LEAP:
			_barrage_time -= delta
			if foe == null or foe.is_invulnerable():
				_end_barrage()
				return
			if not foe.is_immovable():
				foe.velocity = Vector2.ZERO
				foe.global_position = _barrage_hold
			var progress := 1.0 - clampf(_barrage_time / BARRAGE_LEAP, 0.0, 1.0)
			var target := _barrage_hold + Vector2(-facing * BARRAGE_ABOVE.x, BARRAGE_ABOVE.y)
			target.x = clampf(target.x, arena_min_x, arena_max_x)
			velocity = Vector2.ZERO
			global_position = _barrage_from.lerp(target, progress) + Vector2(0, -sin(progress * PI) * 46.0)
			if is_instance_valid(_ball_node):
				_ball_node.scale = Vector2.ONE * lerpf(0.25, 1.15, progress)
				_ball_node.global_position = global_position + Vector2(RAISE_HAND.x * facing, RAISE_HAND.y)
			if _barrage_time <= 0.0:
				_barrage_slam()
		Barrage.DIVE:
			_barrage_time -= delta
			if is_instance_valid(_ball_node):
				_ball_node.global_position = global_position + Vector2(DIVE_HAND.x * facing, DIVE_HAND.y)
			var falling := foe != null and foe.state in [State.LAUNCHED, State.KO] and not foe.is_on_floor()
			if not falling or is_on_floor() or _barrage_time <= 0.0:
				_barrage_impact()


## 分身輪流上前打一下。
func _barrage_beat(index: int) -> void:
	var foe := opponent
	if index < _barrage_doubles.size() and is_instance_valid(_barrage_doubles[index]):
		var double := _barrage_doubles[index]
		var toward := signf(foe.global_position.x - double.global_position.x)
		_double_play(double, "attack1" if index % 2 == 0 else "attack2", int(toward) if toward != 0.0 else 1, 0.22, true)
		var home := double.position
		var tween := double.create_tween()
		tween.tween_property(double, "position:x", home.x + toward * 26.0, 0.05)
		tween.tween_property(double, "position:x", home.x, 0.12)
	foe.take_hit(_beat_move, self)


## 所有分身一起把人踢上天。
func _barrage_kick() -> void:
	var foe := opponent
	for double in _barrage_doubles:
		if is_instance_valid(double):
			var toward := signf(foe.global_position.x - double.global_position.x)
			_double_play(double, "attack4", int(toward) if toward != 0.0 else 1, 0.3, true)
	foe.take_hit(_kick_up_move, self)
	_callout("鳴人連擊", CLONE_COLOR)
	screen_shake.emit(7.0)
	if foe.state != State.LAUNCHED:
		_end_barrage()
		return
	_barrage = Barrage.RISE
	_barrage_time = BARRAGE_RISE


## 本體踩著分身跳上去:分身留下最後一個當墊腳石,其餘的消失。
func _barrage_leap() -> void:
	_free_barrage_doubles(true)
	_face_opponent()
	_flash_double(global_position + Vector2(facing * 30.0, 0), facing, "guard", 0.12)
	_spawn_dust(global_position, 4, 0.8)
	Sfx.play("jump")
	_barrage = Barrage.LEAP
	_barrage_time = BARRAGE_LEAP
	_barrage_from = global_position
	_barrage_hold = opponent.global_position
	_cast_anim = "raise"
	_anim_restart = true
	_pose_frame = 0
	_free_ball_node()
	_ball_node = _sheet_prop(FX_DIR, "rasengan", Vector2(BALL_SIZE, BALL_SIZE), CHAKRA_COLOR)
	_ball_node.scale = Vector2.ONE * 0.25
	Sfx.play("rasengan")


## 螺旋丸砸在對手身上,把人往地面砸下去,自己跟著往下衝。
func _barrage_slam() -> void:
	_cast_anim = "dive"
	_anim_restart = true
	_pose_frame = 0
	opponent.take_hit(_slam_move, self)
	if opponent.state == State.KO:
		# 這一下把人打倒了:一樣要往地面砸下去(被打倒的人預設是往上彈)
		opponent.velocity = Vector2(facing * 60.0, 1500.0)
	velocity = Vector2(facing * 60.0, 1100.0)
	_barrage = Barrage.DIVE
	_barrage_time = BARRAGE_DIVE
	Sfx.play("special")


## 對手砸在地上:螺旋丸炸開。
func _barrage_impact() -> void:
	var at := opponent.global_position if opponent != null else global_position
	_spawn_effect("blast", at + Vector2(0, -40), _bright(CHAKRA_COLOR, 1.7), 1.0)
	_spawn_effect("landing", at)
	Sfx.play("rasengan_burst")
	screen_shake.emit(18.0)
	_free_ball_node()
	_barrage = Barrage.RECOVER
	_cast_duration = _state_time + BARRAGE_RECOVERY


## 中途接不下去了(對手脫出、被打倒):分身消失,自己收招。
func _end_barrage() -> void:
	_free_barrage_doubles(true)
	_free_ball_node()
	_barrage = Barrage.RECOVER
	_cast_duration = _state_time + BARRAGE_RECOVERY * 0.6


func _free_barrage_doubles(announce: bool) -> void:
	for double in _barrage_doubles:
		if is_instance_valid(double):
			if announce and is_inside_tree():
				_poof(double.global_position, false)
			double.queue_free()
	if announce and not _barrage_doubles.is_empty():
		Sfx.play("poof")
	_barrage_doubles.clear()


func _clear_barrage() -> void:
	if _barrage != Barrage.NONE:
		_free_ball_node()
	_barrage = Barrage.NONE
	_free_barrage_doubles(false)


# ---------- 尾獸爆走 ----------

func in_rampage() -> bool:
	return _rage_time > 0.0


func is_exhausted() -> bool:
	return _exhausted


## 每回合一次:會讓血量掉到 5% 以下的那一下(包含會被打倒的)打不死他,血量回到 30%,下一格開始爆走。
func _set_health(value: int) -> void:
	if puppet_of == null and not _rage_used and state != State.KO and value < health \
			and value < int(ceil(max_health * RAGE_TRIGGER)):
		_rage_used = true
		_rage_pending = true
		value = int(round(max_health * RAGE_HEAL))
	super(value)


func _enter_rage() -> void:
	_dismiss_clones(true)
	_clear_ball()
	_clear_barrage()
	_clear_beast()
	_end_hitstop()
	_begin_rage()
	velocity = Vector2.ZERO
	# 查克拉爆發:短暫無敵,把身邊的對手彈開
	_start_burst()
	_callout("尾獸爆走", FOX_COLOR, "powerup")
	_power_burst(FOX_COLOR, 1.3)
	screen_shake.emit(12.0)


## 換成尾獸型態(不含變身那一刻的演出)。
func _begin_rage() -> void:
	_rage_time = RAGE_TIME
	_plain_damage_scale = damage_scale
	damage_scale = _plain_damage_scale * RAGE_SCALE
	_ground_moves = _rage_chain
	_air_move = _rage_air
	_swap_frames(_fox_frames)
	_tails.relax()


## 結束爆走。exhausts 為 true 時陷入虛脫(時間到了);回合重置時是 false。
func _leave_rage(exhausts: bool) -> void:
	if _rage_time <= 0.0 and _ground_moves == _plain_chain:
		return
	_rage_time = 0.0
	damage_scale = _plain_damage_scale
	_ground_moves = _plain_chain
	_air_move = _plain_air
	_swap_frames(_plain_frames)
	_chase_time = 0.0
	if exhausts:
		_exhausted = true
		_callout("虛脫", Color(0.7, 0.72, 0.85), "weapon_swap")


func _tick_rage(delta: float) -> void:
	if not in_rampage() and _ground_moves == _plain_chain:
		return
	if state == State.KO or _story_rampage == "always":
		return
	_rage_time = maxf(_rage_time - delta, 0.0)
	# 時間到了:等手上的招式放完才退出
	if _rage_time <= 0.0:
		if _beast == Beast.NONE:
			_leave_rage(true)
		else:
			_rage_time = 0.001


func _swap_frames(frames: SpriteFrames) -> void:
	if _has_sprite and frames != null and _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
		_current_anim = ""
		_anim_restart = true


## 尾獸爆走時招式出手的速度。
func _haste() -> float:
	return RAGE_SCALE


# ---------- 尾獸爆走的招式一:爪擊 ----------

func _start_claw() -> void:
	_clear_beast()
	_face_opponent()
	_beast = Beast.CLAW_WINDUP
	_callout("爪擊", FOX_COLOR, "rika_claw")
	var windup := CLAW_WINDUP / _haste()
	_start_cast(windup + CLAW_TIME + 0.26, windup, _release_claw, "claw_dash")


func _release_claw() -> void:
	if _beast != Beast.CLAW_WINDUP:
		return
	_beast = Beast.CLAW_RUSH
	_beast_time = CLAW_TIME
	_cast_duration = _state_time + CLAW_TIME + 0.26
	Sfx.play("dash")


# ---------- 尾獸爆走的招式二:尾獸螺旋丸 ----------

func _start_beast_ball() -> void:
	_clear_beast()
	_face_opponent()
	_beast = Beast.BALL_CHARGE
	_beast_orb = _spawn_rect(Vector2(20, 20), FOX_COLOR, global_position + Vector2(BALL_SIDE.x * facing, BALL_SIDE.y), 3)
	_callout("尾獸螺旋丸", FOX_COLOR, "rasengan")
	_start_cast(10.0, BEAST_BALL_CHARGE / _haste(), _release_beast_ball, "rasengan_charge")


func _release_beast_ball() -> void:
	if _beast != Beast.BALL_CHARGE:
		return
	_beast = Beast.BALL_RUSH
	_beast_time = BEAST_BALL_TIME
	_cast_anim = "rasengan_push"
	_cast_duration = _state_time + BEAST_BALL_TIME + 0.3
	Sfx.play("dash")


## 把紅色的光球放到 center,大小是 size(色塊的 size 一變,貼在上面的圖會跟著縮放)。
func _place_orb(center: Vector2, size: float) -> void:
	if not is_instance_valid(_beast_orb):
		return
	_beast_orb.size = Vector2(size, size)
	_beast_orb.pivot_offset = _beast_orb.size / 2.0
	_beast_orb.position = center - _beast_orb.size / 2.0


func _free_orb() -> void:
	if is_instance_valid(_beast_orb):
		_beast_orb.queue_free()
	_beast_orb = null


# ---------- 尾獸螺旋丸之後的追擊 ----------

## 現在能不能追擊:對手還在半空(還沒倒地),自己能動、或正在收尾獸螺旋丸的招。
func _can_chase() -> bool:
	if not in_rampage() or opponent == null or opponent.state != State.LAUNCHED or opponent.is_invulnerable():
		return false
	if not input_enabled or _hitstop > 0.0:
		return false
	return state in [State.IDLE, State.MOVE, State.JUMP] or (state == State.CAST and _beast == Beast.RECOVER)


## 衝到對手那裡一把抓住。
func _start_chase() -> void:
	_chase_time = 0.0
	_clear_beast()
	_buffer.clear()
	_face_opponent()
	_beast = Beast.CHASE_DASH
	_beast_time = CHASE_DASH
	_beast_from = global_position
	_ghost_timer = 0.0
	Sfx.play("dash")
	# 節奏由 _tick_beast 自己推進
	_start_cast(10.0, INF, Callable(), "claw_dash")
	_pose_frame = 1


func _tick_beast(delta: float) -> void:
	_chase_time = maxf(_chase_time - delta, 0.0)
	if _chase_time > 0.0 and (opponent == null or opponent.state != State.LAUNCHED):
		_chase_time = 0.0  # 對手已經落地了
	if _beast == Beast.NONE:
		return
	if state != State.CAST:
		_clear_beast()  # 被打斷,或整招結束
		return
	var foe := opponent
	match _beast:
		Beast.CLAW_RUSH:
			velocity.x = facing * CLAW_SPEED
			_beast_time -= delta
			_leave_trail(delta)
			var center := global_position + Vector2(facing * 62.0, -58.0)
			if _rect_hits_opponent(center, CLAW_SIZE):
				velocity.x = 0.0
				_spawn_effect("claw", foe.global_position + CHEST, _bright(FOX_COLOR, 1.6), 1.5, facing < 0)
				if _land(_claw_move):
					screen_shake.emit(7.0)
				# 打中了收招很短,來得及追打浮空的對手
				_finish_beast(0.14)
			elif _beast_time <= 0.0:
				velocity.x = 0.0
				_finish_beast(0.26)
		Beast.BALL_CHARGE:
			var grown := clampf(_state_time / maxf(_cast_release, 0.01), 0.0, 1.0)
			_place_orb(global_position + Vector2(BALL_SIDE.x * facing, BALL_SIDE.y), lerpf(20.0, BEAST_BALL_SIZE, grown))
		Beast.BALL_RUSH:
			velocity.x = facing * BEAST_BALL_SPEED
			_beast_time -= delta
			var point := global_position + Vector2(BALL_HAND.x * facing, BALL_HAND.y)
			_place_orb(point, BEAST_BALL_SIZE)
			if _rect_hits_opponent(point, Vector2(BEAST_BALL_SIZE + 26.0, BEAST_BALL_SIZE + 44.0)):
				velocity.x = 0.0
				var hit := _land(_beast_ball_move)
				_spawn_effect("blast", point, _bright(FOX_COLOR, 1.7), 0.75 if hit else 0.5)
				Sfx.play("rasengan_burst")
				screen_shake.emit(13.0 if hit else 5.0)
				_free_orb()
				if hit and foe.state == State.LAUNCHED:
					_chase_time = CHASE_WINDOW
				_finish_beast(0.12 if hit else 0.3)
			elif _beast_time <= 0.0:
				velocity.x = 0.0
				_spawn_effect("flash", point, _bright(FOX_COLOR), 0.7)
				_free_orb()
				_finish_beast(0.3)
		Beast.CHASE_DASH:
			if foe == null or foe.is_invulnerable():
				_finish_beast(0.2)
				return
			_beast_time -= delta
			_leave_trail(delta)
			var progress := 1.0 - clampf(_beast_time / CHASE_DASH, 0.0, 1.0)
			var target := foe.global_position + Vector2(-facing * 58.0, 0)
			target.x = clampf(target.x, arena_min_x, arena_max_x)
			target.y = minf(target.y, _floor_y)
			velocity = Vector2.ZERO
			global_position = _beast_from.lerp(target, progress)
			if _beast_time <= 0.0:
				_chase_grab()
		Beast.CHASE_TOSS:
			velocity = Vector2.ZERO
			global_position = _beast_hold
			_beast_time -= delta
			if foe == null or foe.is_invulnerable():
				_finish_beast(0.2)
			elif _beast_time <= 0.0:
				_chase_pounce()
		Beast.CHASE_SWIPE:
			velocity = Vector2.ZERO
			global_position = _beast_hold
			if foe == null or foe.is_invulnerable():
				_finish_beast(0.2)
				return
			if not foe.is_immovable():
				foe.velocity = Vector2.ZERO
				foe.global_position = _beast_victim
			_beast_timer -= delta
			if _beast_timer <= 0.0:
				_beast_timer = CHASE_INTERVAL
				_chase_swipe()


## 抓住對手往上拋。
func _chase_grab() -> void:
	var foe := opponent
	_spawn_effect("claw", foe.global_position + CHEST, _bright(FOX_COLOR, 1.6), 1.3, facing < 0, -PI / 2.0)
	Sfx.play("rika_claw")
	if not _land(_grab_move) or foe.state != State.LAUNCHED:
		_finish_beast(0.2)
		return
	_callout("追擊", FOX_COLOR)
	_beast = Beast.CHASE_TOSS
	_beast_time = CHASE_TOSS
	_beast_hold = global_position
	_cast_anim = "attack4"
	_anim_restart = true
	_pose_frame = 1


## 跳到被拋上去的對手身邊,開始用爪子連抓。
func _chase_pounce() -> void:
	var foe := opponent
	_leave_ghost()
	_face_opponent()
	global_position = foe.global_position + Vector2(-facing * 54.0, 12.0)
	global_position.x = clampf(global_position.x, arena_min_x, arena_max_x)
	velocity = Vector2.ZERO
	_beast = Beast.CHASE_SWIPE
	_beast_hold = global_position
	_beast_victim = foe.global_position
	_beast_left = CHASE_SWIPES
	_beast_timer = 0.05
	_cast_anim = "air_claw"
	_anim_restart = true
	_pose_frame = 0
	Sfx.play("teleport")


func _chase_swipe() -> void:
	var foe := opponent
	var last := _beast_left <= 0
	_spawn_effect("claw", foe.global_position + CHEST, _bright(FOX_COLOR, 1.6), 1.7 if last else 1.2, _beast_left % 2 == 0,
			0.5 if last else randf_range(-0.6, 0.6))
	Sfx.play("rika_claw")
	foe.take_hit(_swipe_final_move if last else _swipe_move, self)
	_pose_frame = 1 - _pose_frame if _pose_frame >= 0 else 0  # 兩隻手輪流
	_beast_left -= 1
	if last:
		screen_shake.emit(10.0)
		_finish_beast(0.3)


## 這一招接下來只剩收招:after 秒後恢復行動。
func _finish_beast(after: float) -> void:
	_free_orb()
	_pose_frame = -1
	_beast = Beast.RECOVER
	_cast_duration = _state_time + after


func _clear_beast() -> void:
	_beast = Beast.NONE
	_free_orb()


## 衝刺時每隔一小段時間留下一個紅色的殘影。
func _leave_trail(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.035
		_leave_ghost()


func _leave_ghost() -> void:
	var ghost := _copy_of_self(_sprite.animation, _sprite.frame) if _has_sprite else null
	if ghost == null:
		return
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(2.2, 0.8, 0.5, 0.5)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


# ---------- 電腦操作 ----------

## 影分身:哪裡都能叫,但有氣、分身還沒滿、對手又不在身邊才叫。爪擊:要在撲得到的距離內。
func ai_skill_range() -> float:
	if _exhausted:
		return 0.0
	if in_rampage():
		return CLAW_SPEED * CLAW_TIME + 60.0 if energy >= CLAW_COST else 0.0
	if ai_saving_energy() or energy < CLONE_COST or _clones.size() >= CLONE_MAX or not _ai_opponent_cannot_interrupt(230.0):
		return 0.0
	return INF if randf() < AI_CLONE_CHANCE else 0.0


func ai_skill2_ready() -> bool:
	if _exhausted:
		return false
	return energy >= BALL_COST and (in_rampage() or not ai_saving_energy())


func ai_skill2_range() -> float:
	if in_rampage():
		return BEAST_BALL_SPEED * BEAST_BALL_TIME + BALL_HAND.x
	return BALL_RUSH_SPEED * BALL_RUSH_TIME + BALL_HAND.x


## 尾獸螺旋丸打中了:馬上按普攻追擊。
func ai_wants_attack() -> bool:
	return _chase_time > 0.0 and _can_chase()


## 存氣的回合先不放招式,留給鳴人連擊。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and not in_rampage() and not _exhausted and energy < BARRAGE_COST


func _ai_save_chance() -> float:
	return 0.45


func ai_wants_super() -> bool:
	if _exhausted or in_rampage() or energy < BARRAGE_COST or opponent == null or opponent.is_invulnerable():
		return false
	return absf(opponent.global_position.x - global_position.x) <= BARRAGE_RANGE * 0.9


func ai_super_is_safe() -> bool:
	if opponent == null:
		return false
	var distance := absf(opponent.global_position.x - global_position.x)
	return distance <= BARRAGE_RANGE * 0.9 and (distance > 200.0 or opponent.state in [State.HITSTUN, State.STUNNED, State.LAUNCHED])


## 虛脫時連通用的大招也放不出來,不必白按。
func ai_energy_reserve() -> int:
	return max_energy + 1 if _exhausted else 0


# ---------- 顯示 ----------

## 觸控按鈕的提示:尾獸爆走時招式換了一組,招式的按鈕會發光。
func skill1_empowered() -> bool:
	return in_rampage()


func _update_status() -> void:
	if in_rampage():
		_status_label.text = "尾獸爆走" if _story_rampage == "always" else "尾獸爆走 %d" % ceili(_rage_time)
	elif _exhausted:
		_status_label.text = "虛脫"
	else:
		_status_label.text = ""


func _update_visual() -> void:
	super()
	if _tails == null:
		return
	_tails.facing = facing
	# 被打飛、倒在地上的時候尾巴收起來
	_tails.visible = in_rampage() and state not in [State.LAUNCHED, State.DOWN, State.GETUP, State.KO]
	if _pose_frame >= 0 and state == State.CAST and _has_sprite:
		_sprite.frame = mini(_pose_frame, _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1)
	if _exhausted and _has_sprite and state != State.KO:
		_sprite.modulate = _sprite.modulate * Color(0.68, 0.7, 0.86)
