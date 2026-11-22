class_name SasukeFighter
extends Fighter
## 以宇智波佐助為藍本的角色(火影忍者)。氣量上限是 5 格(在 sasuke.tscn 設定 max_energy = 500)。
##
## 普通攻擊(六段)
##   拔出腰後的草薙劍往前揮、往前踢、轉身橫掃、由下往上挑,
##   往後跳起在空中往斜下方丟苦無、落地收刀,
##   最後再拔刀衝過對手(停在對手身後),收刀的那一刻斬擊才發作,把對手打倒。
## 招式
##   千鳥(skill,1 格):凝聚雷電 0.3 秒(期間被打會中斷),接著衝向前方把雷推到對手身上。
##     普通攻擊打到一半時按下去會變成「千鳥雷槍」(1 格):一腳把對手踢上空中,
##     再從手上射出一道長長的雷電刺向空中。
##   豪火球之術(上 + skill,1 格):往前吐出一顆巨大的火球。確實打中的話對手會燃燒 5 秒,持續扣血。
##     火球碰到對手後 1 秒內按普通攻擊,會瞬身到對手面前,從普通攻擊的第四段接下去。
##   麒麟(下 + special,5 格):先一拳把對手打飛到遠處,立刻射出雷槍刺中他,使他麻痺 2 秒;
##     接著蓄力 1 秒,龍形的雷電從天而降,再麻痺 2 秒。
##     那一拳沒打中(揮空、被防禦、被打斷)就收招,只扣 1 格氣,退回 4 格。
## 大蛇之力
##   血條下方的計量條。隨時間慢慢累積,普通攻擊打中對手時也會累積,被對手打中會減少。
##   滿了之後招式一變成「蛇咬」、招式二變成「蛇籠」,都不耗氣;用了任何一招計量條就歸零。
##   蛇咬:手變成一條白蛇往前咬。咬中(沒被防住)就把自己拉到對手面前,一刀砍倒對手。
##   蛇籠:一群小白蛇在腳邊的地面散開,停留 5 秒後融化。對手踩到就被白蛇纏住,3 秒無法動彈。

const LIGHTNING_COLOR := Color(0.62, 0.85, 1.0)
const FIRE_COLOR := Color(1.0, 0.55, 0.2)
const BLADE_COLOR := Color(0.88, 0.92, 1.0)
const SNAKE_COLOR := Color(0.72, 0.52, 0.96)   # 大蛇之力的計量條
const SNAKE_WHITE := Color(0.93, 0.94, 1.0)
const FX_DIR := "res://assets/sasuke_fx"        # 千鳥、雷槍、火球、燃燒、雷雲、麒麟、白蛇
const KUNAI_FX_DIR := "res://assets/naruto_fx"  # 苦無和波風湊共用同一張圖
const FX_SCALE := 3.0                           # 特效點陣圖的顯示倍率(一個像素畫成幾個像素)
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
const KUNAI_HITSTUN := 0.75           # 被苦無釘住的時間(夠久,第六段的斬擊才接得上)
# 普攻第六段:拔刀衝過對手,收刀時斬擊才發作
const IAI_DASH_START := 0.06          # 這一段開始後多久衝出去
const IAI_DASH_TIME := 0.10
const IAI_CUT_TIME := 0.42            # 收刀、斬擊發作的時刻
const IAI_RECOVERY := 0.15
const IAI_RANGE := 560.0              # 對手在前方這個距離內才衝得過去
const IAI_PASS := 90.0                # 停在對手身後這麼遠
const IAI_WHIFF_DISTANCE := 320.0     # 前面沒有對手時往前衝的距離
const IAI_DAMAGE := 70
# 千鳥
const CHIDORI_COST := 100
const CHIDORI_CHARGE := 0.3           # 凝聚雷電的時間,期間被打會中斷
const CHIDORI_RUSH_TIME := 0.42
const CHIDORI_RUSH_SPEED := 1150.0
const CHIDORI_RECOVERY := 0.32
const CHIDORI_DAMAGE := 240
const CHIDORI_LOW := Vector2(22, -28)   # 凝聚時雷電的位置(朝下的手掌)
const CHIDORI_HAND := Vector2(62, -68)  # 衝刺時雷電的位置(往前推的手)
const CHIDORI_SIZE := Vector2(90, 100)
const CHIDORI_ART_SCALE := 0.7        # 手上那團雷電的圖縮小到這個比例,才不會把人蓋住
# 千鳥雷槍
const SPEAR_COST := 100
const SPEAR_KICK_DAMAGE := 50
const SPEAR_CHARGE := 0.24            # 踢完後在手上聚雷的時間
const SPEAR_TIME := 0.22              # 雷槍停留的時間
const SPEAR_RECOVERY := 0.26
const SPEAR_HAND := Vector2(38, -112) # 指向斜上方的那隻手
const SPEAR_LENGTH := 560.0
const SPEAR_ART_LENGTH := 440.0 * FX_SCALE  # 雷槍的圖在畫面上的長度,見 tools/pixelfx_custom/anifight/lightning-spear.js
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
const FIRE_SAFE_GAP := 230.0          # 電腦:對手在這個距離內又能動,就不放火球
const FOLLOWUP_WINDOW := 1.0          # 火球碰到對手後多久內按普攻可以瞬身追擊
const FOLLOWUP_GAP := 78.0            # 瞬身後離對手多遠
const FOLLOWUP_STEP := 3              # 從普通攻擊的第幾段接下去(編號從 0 算,3 是第四段)
const BURN_DURATION := 5.0
const BURN_TICK := 0.5
const BURN_TICK_DAMAGE := 12          # 5 秒共 10 下
# 麒麟
const KIRIN_COST := 500
const KIRIN_REFUND := 400             # 第一拳沒打中時退回的氣
const KIRIN_PUNCH_DAMAGE := 60
const KIRIN_SPEAR_CAST := 0.10        # 拳打中後多久射出雷槍
const KIRIN_SPEAR_TIME := 0.25        # 雷槍停留的時間,之後開始蓄力
const KIRIN_SPEAR_DAMAGE := 110
const KIRIN_REACH_HAND := Vector2(56, -80)  # 往前伸直的手
const KIRIN_CHARGE := 1.0
const KIRIN_LOCK := 0.4               # 落雷前這麼久定住位置
const KIRIN_DROP := 0.16              # 龍頭從天上落到地面的時間(點陣圖動畫的前段);傷害在落地那一刻
const KIRIN_AFTER := 0.5              # 落雷後收招的時間
const KIRIN_TRACK_SPEED := 1100.0     # 雷雲追著對手移動的速度
const KIRIN_WIDTH := 180.0
const KIRIN_HEIGHT := 760.0
const KIRIN_DAMAGE := 340
const KIRIN_STUN := 2.0               # 雷槍、落雷各麻痺這麼久
const KIRIN_CLOUD_HEIGHT := 455.0     # 雷雲在地面上方多高
const KIRIN_HAND := Vector2(9, -130)  # 高舉的手
const KIRIN_PUNCH_RANGE := 150.0      # 電腦:對手在這個距離內才出拳
# 大蛇之力
const SNAKE_MAX := 100.0
const SNAKE_PER_SECOND := 2.0         # 光靠時間要 50 秒才滿
const SNAKE_PER_HIT := 7.0            # 普通攻擊每打中一下
const SNAKE_LOSS_PER_HIT := 6.0       # 每被打中一下
# 蛇咬
const BITE_REACH := 0.12              # 伸手的時間,之後白蛇射出去
const BITE_HAND := Vector2(56, -80)
const BITE_SPEED := 1900.0
const BITE_RANGE := 540.0             # 白蛇最遠伸到這裡(蛇身的圖長 180 像素)
const BITE_SIZE := Vector2(60, 76)
const BITE_DAMAGE := 30
const BITE_HITSTUN := 0.7             # 被咬住的時間(夠他拉過去砍一刀)
const BITE_PULL_TIME := 0.12
const BITE_GAP := 78.0                # 拉到對手面前這麼遠
const BITE_SLASH_DELAY := 0.08
const BITE_SLASH_DAMAGE := 190
const BITE_RECOVERY := 0.30
# 蛇籠
const CAGE_CAST := 0.45
const CAGE_RELEASE := 0.25
const CAGE_DURATION := 5.0
const CAGE_HALF_WIDTH := 240.0        # 小白蛇散開後左右各佔這麼寬
const CAGE_SPREAD_TIME := 0.5         # 散開到全寬的時間
const CAGE_HOLD := 3.0                # 被纏住多久
const CAGE_MELT := 0.4                # 融化消失的時間
const CAGE_TILE := 160.0              # 每隔這麼遠鋪一塊小白蛇的圖

enum Chidori { NONE, CHARGE, RUSH, RECOVER }
enum Spear { NONE, CHARGE, FIRE }
enum Kirin { NONE, PUNCH, SPEAR, CHARGE, AFTER }
enum Bite { NONE, REACH, STRIKE, PULL, SLASH, RETRACT }

var _throw_move: AttackData
var _kunai_move: AttackData
var _iai_move: AttackData
var _iai_cut_move: AttackData
var _chidori_move: AttackData
var _spear_kick_move: AttackData
var _spear_move: AttackData
var _fire_move: AttackData
var _kirin_punch_move: AttackData
var _bite_move: AttackData
var _bite_slash_move: AttackData

var _kunai: Array[Dictionary] = []   # 飛行中的苦無:{node, velocity, time}
var _floor_y := 0.0                  # 最近一次站在地上時的高度(苦無飛到這裡就落地)

var _iai_from := 0.0
var _iai_to := 0.0
var _iai_started := false            # 已經衝出去了
var _iai_dashed := false             # 已經衝到定點
var _iai_cuts := false               # 衝刺有沒有穿過對手
var _iai_cut_done := false           # 收刀的那一下已經算過了

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
var _followup_time := 0.0            # 火球碰到對手後,還剩幾秒可以按普攻瞬身追擊
var _burn_time := 0.0
var _burn_timer := 0.0
var _burn_node: Node2D

var _kirin := Kirin.NONE
var _kirin_time := 0.0
var _kirin_punch_hit := false
var _kirin_x := 0.0
var _kirin_locked := false
var _kirin_falling := false          # 龍形的雷電已經開始往下落
var _kirin_beam: Node2D
var _kirin_cloud: Node2D
var _kirin_warning: ColorRect
var _kirin_hand: Node2D
var _shock_time := 0.0               # 對手麻痺還剩幾秒(只管特效;動不了是定身狀態)
var _shock_node: Node2D

var _snake := 0.0                    # 大蛇之力,0 到 SNAKE_MAX
var _bite := Bite.NONE
var _bite_time := 0.0
var _bite_length := 0.0              # 白蛇目前伸出去多長
var _bite_from := 0.0                # 被拉過去之前站的位置
var _bite_to := 0.0
var _bite_clip: Control              # 只露出伸出去那一段蛇身
var _bite_head: Node2D
var _cage_time := 0.0
var _cage_age := 0.0
var _cage_position := Vector2.ZERO   # 小白蛇散開的中心(地面上)
var _cage_node: Node2D
var _wrap_time := 0.0                # 對手被白蛇纏住還剩幾秒(只管特效)
var _wrap_node: Node2D

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
	# 拔刀、踢、轉身橫掃、由下往上挑(都不擊飛,後面的苦無才丟得中)。
	# 連段比別人長,所以每一下的傷害比一般角色高一點
	var kick := AttackData.make(40, 0.07, 0.10, 0.17, Vector2(72, -58), Vector2(104, 52), Vector2(190, 0), 0.34, false, 150.0)
	# 丟苦無這一段本身沒有攻擊判定,傷害在飛出去的苦無上。「判定時間」一直算到落地:
	# 落地後才能接第六段;不接的話剩下的收招時間就是收刀
	_throw_move = AttackData.make(0, 0.20, 0.34, 0.14, KUNAI_HAND, Vector2(10, 10), Vector2.ZERO, 0.0, false, 0.0)
	# 第六段也沒有攻擊框:人衝過去,收刀時才由程式判定(見 _tick_iai)
	_iai_move = AttackData.make(0, IAI_DASH_START, IAI_DASH_TIME, IAI_CUT_TIME - IAI_DASH_START - IAI_DASH_TIME + IAI_RECOVERY,
			Vector2(40, -60), Vector2(10, 10), Vector2.ZERO, 0.0, false, 0.0)
	_ground_moves = [
		_blade(38, 0.06, 0.16, Vector2(66, -64), Vector2(100, 54), 170.0, 0.32, 130.0),
		kick,
		_blade(46, 0.07, 0.17, Vector2(70, -62), Vector2(120, 60), 190.0, 0.36, 150.0),
		_blade(52, 0.07, 0.19, Vector2(62, -84), Vector2(96, 120), 150.0, 0.60, 120.0),
		_throw_move,
		_iai_move,
	]
	# 苦無:把對手釘在原地一段時間,第六段才接得上
	_kunai_move = AttackData.make(KUNAI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(110, 0), KUNAI_HITSTUN, false, 0.0)
	# 收刀時發作的斬擊:連段的收尾,把對手打倒
	_iai_cut_move = AttackData.make(IAI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(150, -430), 0.0, true, 0.0)

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
	# 麒麟的第一拳:把對手打飛到遠處。可以防禦(被防住就收招退氣)
	_kirin_punch_move = AttackData.make(KIRIN_PUNCH_DAMAGE, 0.09, 0.10, 0.08, Vector2(72, -66), Vector2(124, 72), Vector2(1000, -360), 0.0, true, 220.0)
	_kirin_punch_move.builds_energy = false
	_kirin_punch_move.color = Color(LIGHTNING_COLOR, 0.8)
	# 蛇咬:咬住之後對手動不了,接著一刀砍倒
	_bite_move = _remote(BITE_DAMAGE, Vector2.ZERO, BITE_HITSTUN)
	_bite_slash_move = _remote(BITE_SLASH_DAMAGE, Vector2(170, -450), 0.0, true)


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
	_clear_bite()
	_clear_cage(false)
	_clear_wrap()
	_followup_time = 0.0
	_snake = 0.0
	super(spawn_position, spawn_facing)
	_floor_y = spawn_position.y
	_emit_snake()


func _physics_process(delta: float) -> void:
	super(delta)
	if is_on_floor():
		_floor_y = global_position.y
	_followup_time = maxf(_followup_time - delta, 0.0)
	_tick_iai()
	_tick_kunai(delta)
	_tick_chidori(delta)
	_tick_spear(delta)
	_tick_fires(delta)
	_tick_burn(delta)
	_tick_kirin(delta)
	_tick_shock(delta)
	_tick_bite(delta)
	_tick_cage(delta)
	_tick_wrap(delta)
	_tick_snake(delta)
	_update_status()


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if snake_full():
			_start_cage()
			return true
		if _spend_energy(FIRE_COST):
			_start_fire()
			return true
		return false
	if _skill1_pressed():
		if snake_full():
			_start_bite()
			return true
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


## 觸控按鈕的提示:大蛇之力滿了,招式一的按鈕會發光。
func skill1_empowered() -> bool:
	return snake_full()


# ---------- 普通攻擊 ----------

func _in_normal_chain() -> bool:
	return state == State.ATTACK and _combo_step >= 0 and _combo_step < _ground_moves.size()


## 千鳥雷槍(或蛇咬)要站在地上、還在前四段的時候才接得出來。
func _can_spear() -> bool:
	return _in_normal_chain() and _combo_step < THROW_STEP and is_on_floor()


## 普通攻擊的前四段任何時候都可以按招式一(千鳥雷槍;大蛇之力滿了是蛇咬),不必等打中。
func _tick_attack(delta: float) -> void:
	if _can_spear() and _skill1_pressed():
		if snake_full():
			_buffer.clear()
			_start_bite()
			return
		if _spend_energy(SPEAR_COST):
			_buffer.clear()
			_start_spear_kick()
			return
	super(delta)


## 待機、走路時:火球剛打到人的話,按普攻是瞬身追擊。
func _tick_ground() -> void:
	if _try_fire_followup():
		return
	super()


## 放完火球還在收招時也可以直接按普攻瞬身追擊。
func _tick_cast(delta: float) -> void:
	if _cast_anim == "fire" and _cast_fired and _try_fire_followup():
		return
	super(delta)


## 揮劍的幾段是刀光,踢擊是拳腳的弧線。
func _slash_effect() -> String:
	return "slash" if _combo_step in [0, 2, 3] else "swish"


func _start_attack(move: AttackData, combo_step: int) -> void:
	super(move, combo_step)
	if move == _throw_move:
		velocity = Vector2(THROW_HOP.x * facing, THROW_HOP.y)
	elif move == _iai_move:
		_begin_iai()
	elif move == _spear_kick_move:
		_attack_anim = "spear_kick"
	elif move == _kirin_punch_move:
		_attack_anim = "punch"


## 丟苦無與第六段都不畫揮擊的軌跡:苦無在出手的那一刻丟出去,第六段由 _tick_iai 處理。
func _show_slash() -> void:
	if _move == _throw_move:
		_throw_kunai()
	elif _move != _iai_move:
		super()


func _check_hits() -> void:
	if _move != _throw_move and _move != _iai_move:
		super()


## 普通攻擊打中(沒被防住)會累積大蛇之力;麒麟的那一拳要記下有沒有把人打飛。
func _on_attack_hit(target: Fighter, move: AttackData) -> void:
	if move == _kirin_punch_move:
		_kirin_punch_hit = target == opponent and target.state == State.LAUNCHED
	elif (move in _ground_moves or move == _air_move) and target.state != State.GUARD:
		_add_snake(SNAKE_PER_HIT)


## 千鳥雷槍踢完接著放雷槍;麒麟的那一拳打完,看有沒有打中再決定接不接。
func _end_attack() -> void:
	if state == State.ATTACK and _move == _spear_kick_move:
		_set_hitbox(false)
		_start_spear()
		return
	if state == State.ATTACK and _move == _kirin_punch_move and _kirin == Kirin.PUNCH:
		_set_hitbox(false)
		if _kirin_punch_hit:
			_start_kirin_spear()
			return
		_refund_kirin()
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
			if _land(_kunai_move):
				_add_snake(SNAKE_PER_HIT)
			_remove_kunai(kunai)
		elif kunai.time <= 0.0 or node.global_position.y >= _floor_y - 4.0:
			_remove_kunai(kunai)  # 插進地面


func _remove_kunai(kunai: Dictionary) -> void:
	_drop(kunai.node)
	_kunai.erase(kunai)


func _clear_kunai() -> void:
	for kunai: Dictionary in _kunai:
		_drop(kunai.node)
	_kunai.clear()


## 第六段開始:決定要衝到哪裡。對手在前方不遠就衝到他身後,否則往前衝一段固定的距離。
func _begin_iai() -> void:
	_iai_started = false
	_iai_dashed = false
	_iai_cuts = false
	_iai_cut_done = false
	_iai_from = global_position.x
	_iai_to = _iai_from + facing * IAI_WHIFF_DISTANCE
	if opponent != null:
		var ahead := (opponent.global_position.x - _iai_from) * facing
		if ahead > 0.0 and ahead < IAI_RANGE:
			_iai_to = opponent.global_position.x + facing * IAI_PASS
	_iai_to = clampf(_iai_to, arena_min_x, arena_max_x)
	velocity.x = 0.0


## 第六段:拔刀衝過去(位置直接算,不靠速度),收刀的那一刻斬擊才發作。
func _tick_iai() -> void:
	if state != State.ATTACK or _move != _iai_move or _state_time < IAI_DASH_START:
		return
	if not _iai_dashed:
		if not _iai_started:
			_iai_started = true
			Sfx.play("slash")
			_iai_streak()
		var progress := clampf((_state_time - IAI_DASH_START) / IAI_DASH_TIME, 0.0, 1.0)
		global_position.x = lerpf(_iai_from, _iai_to, progress)
		velocity.x = 0.0
		if progress >= 1.0:
			_iai_dashed = true
			_iai_cuts = _iai_passed_opponent()
	elif not _iai_cut_done and _state_time >= IAI_CUT_TIME:
		_iai_cut_done = true
		Sfx.play("weapon_swap")  # 收刀入鞘的一聲
		if _iai_cuts and opponent != null and not opponent.is_invulnerable():
			_spawn_effect("cut", opponent.global_position + CHEST, _bright(BLADE_COLOR, 1.6), 1.3, facing < 0)
			Sfx.play("slash")
			if _land(_iai_cut_move):
				_add_snake(SNAKE_PER_HIT)


## 衝刺的路線有沒有穿過對手的身體。
func _iai_passed_opponent() -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	var x := opponent.global_position.x
	return x >= minf(_iai_from, _iai_to) - 20.0 and x <= maxf(_iai_from, _iai_to) + 20.0 \
			and absf(opponent.global_position.y - global_position.y) < 130.0


## 衝刺留下的一道刀光。
func _iai_streak() -> void:
	var length := absf(_iai_to - _iai_from)
	if length < 30.0:
		return
	var center := Vector2((_iai_from + _iai_to) / 2.0, global_position.y - 62.0)
	var streak := _spawn_rect(Vector2(length, 5), Color(_bright(BLADE_COLOR, 1.3), 0.95), center, 2)
	var tween := streak.create_tween()
	tween.tween_interval(0.08)
	tween.tween_property(streak, "scale:y", 0.2, 0.25)
	tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.25)
	tween.tween_callback(streak.queue_free)


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
	_drop(_chidori_node)
	_chidori_node = null
	_chidori = Chidori.RECOVER
	_cast_duration = _state_time + CHIDORI_RECOVERY


func _chidori_point() -> Vector2:
	var hand := CHIDORI_LOW if _chidori == Chidori.CHARGE else CHIDORI_HAND
	return global_position + Vector2(hand.x * facing, hand.y)


func _place_chidori() -> void:
	if is_instance_valid(_chidori_node):
		_chidori_node.global_position = _chidori_point()


func _clear_chidori() -> void:
	_chidori = Chidori.NONE
	_drop(_chidori_node)
	_chidori_node = null


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
	_drop(_spear_node)
	_spear_node = _make_beam(hand, direction, SPEAR_LENGTH)
	_spear = Spear.FIRE
	_spear_time = SPEAR_TIME
	_spear_hit = false
	_spear_from = hand
	_spear_to = hand + direction * SPEAR_LENGTH
	Sfx.play("thunder")
	screen_shake.emit(6.0)


## 一道從 from 朝 direction 射出去、長 length 的雷槍。
func _make_beam(from: Vector2, direction: Vector2, length: float) -> Node2D:
	var beam := _sheet_prop(FX_DIR, "spear", Vector2(SPEAR_ART_LENGTH, 12), LIGHTNING_COLOR)
	beam.global_position = from
	beam.rotation = direction.angle()
	beam.scale.x = length / SPEAR_ART_LENGTH
	return beam


func _tick_spear(delta: float) -> void:
	if _spear == Spear.NONE:
		return
	if state != State.CAST:
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
	_drop(_spear_node)
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
			# 火球在對手身上炸開;確實打中(沒被防住)才會燒起來。碰到就可以瞬身追擊
			_spawn_effect("blast", node.global_position, _bright(FIRE_COLOR, 1.5), 0.5)
			if _land(_fire_move):
				_ignite()
			_followup_time = FOLLOWUP_WINDOW
			_remove_fire(fire)
		elif fire.time <= 0.0:
			_remove_fire(fire)


func _remove_fire(fire: Dictionary) -> void:
	_drop(fire.node)
	_fires.erase(fire)


func _clear_fires() -> void:
	for fire: Dictionary in _fires:
		_drop(fire.node)
	_fires.clear()


## 火球剛碰到對手、又按了普攻:瞬身到對手面前,從普通攻擊的第四段接下去。有發動就回傳 true。
func _try_fire_followup() -> bool:
	if _followup_time <= 0.0 or opponent == null or opponent.state == State.KO or not _pressed("attack"):
		return false
	_followup_time = 0.0
	_buffer.clear()
	_vanish_effect(LIGHTNING_COLOR)
	var side := int(signf(opponent.global_position.x - global_position.x))
	if side == 0:
		side = facing
	global_position = Vector2(clampf(opponent.global_position.x - side * FOLLOWUP_GAP, arena_min_x, arena_max_x), _floor_y)
	velocity = Vector2.ZERO
	facing = side
	_appear_effect(LIGHTNING_COLOR)
	Sfx.play("teleport")
	_start_attack(_ground_moves[FOLLOWUP_STEP], FOLLOWUP_STEP)
	return true


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
	_drop(_burn_node)
	_burn_node = null


# ---------- 麒麟 ----------

## 第一步:一拳把對手打飛。氣量已在呼叫前扣除;沒打中會退回大部分。
func _start_super() -> void:
	_clear_kirin()
	_kirin = Kirin.PUNCH
	_kirin_punch_hit = false
	_callout("麒麟", LIGHTNING_COLOR)
	_start_attack(_kirin_punch_move, SPECIAL_STEP)


## 那一拳沒打中(揮空、被防禦、被打斷):收招,退回 4 格氣。
func _refund_kirin() -> void:
	_kirin = Kirin.NONE
	_set_energy(energy + KIRIN_REFUND)


## 第二步:手往前伸,立刻朝飛出去的對手射出雷槍。
func _start_kirin_spear() -> void:
	_kirin = Kirin.SPEAR
	# 後面還有蓄力與落雷,先給一個夠長的時間,落雷後再訂結束的時刻
	_start_cast(60.0, KIRIN_SPEAR_CAST, _fire_kirin_spear, "reach")


## 雷槍刺中飛在半空的對手,使他麻痺。
func _fire_kirin_spear() -> void:
	if _kirin != Kirin.SPEAR:
		return
	var hand := global_position + Vector2(KIRIN_REACH_HAND.x * facing, KIRIN_REACH_HAND.y)
	var target := hand + Vector2(facing * 500.0, -60.0)
	if opponent != null:
		target = opponent.global_position + CHEST
	var direction := (target - hand).normalized() if hand.distance_to(target) > 1.0 else Vector2(facing, 0)
	_kirin_beam = _make_beam(hand, direction, clampf(hand.distance_to(target) + 70.0, 260.0, 1200.0))
	_kirin_time = KIRIN_SPEAR_TIME
	Sfx.play("thunder")
	screen_shake.emit(8.0)
	if opponent != null and not opponent.is_invulnerable():
		_spawn_sheet_effect(FX_DIR, "zap", target)
		_paralyse(KIRIN_SPEAR_DAMAGE)


## 第三步:舉手蓄力,雷雲聚在對手頭上。
func _begin_kirin_charge() -> void:
	_drop(_kirin_beam)
	_kirin_beam = null
	_kirin = Kirin.CHARGE
	_kirin_time = KIRIN_CHARGE
	_kirin_locked = false
	_kirin_falling = false
	_kirin_x = opponent.global_position.x if opponent != null else global_position.x + facing * 300.0
	_cast_anim = "kirin"
	# 頭頂的雷雲:畫在角色後面,跟著對手移動
	_kirin_cloud = _sheet_prop(FX_DIR, "cloud", Vector2(300, 90), Color(0.2, 0.2, 0.35, 0.8))
	_kirin_cloud.z_index = -1
	_kirin_cloud.scale = Vector2.ONE * 1.5
	_kirin_cloud.modulate = Color(1.7, 1.7, 2.0, 0.0)
	_kirin_cloud.create_tween().tween_property(_kirin_cloud, "modulate:a", 1.0, 0.3)
	_kirin_hand = _sheet_prop(FX_DIR, "chidori", Vector2(30, 30), LIGHTNING_COLOR)
	_kirin_hand.scale = Vector2.ONE * 0.25
	Sfx.play("kirin_charge")
	_place_kirin()


func _tick_kirin(delta: float) -> void:
	if _kirin == Kirin.NONE:
		return
	if _kirin == Kirin.PUNCH:
		if state != State.ATTACK or _move != _kirin_punch_move:
			_refund_kirin()  # 拳還沒打到人就被打斷:當作沒打中
		return
	if state != State.CAST:
		_clear_kirin()  # 被打斷,或整招結束
		return
	match _kirin:
		Kirin.SPEAR:
			if _cast_fired:
				_kirin_time -= delta
				if _kirin_time <= 0.0:
					_begin_kirin_charge()
		Kirin.CHARGE:
			_kirin_time -= delta
			if not _kirin_locked:
				# 雷雲追著對手;落雷前才定住,並在地上亮出預兆
				if opponent != null:
					_kirin_x = move_toward(_kirin_x, opponent.global_position.x, KIRIN_TRACK_SPEED * delta)
				if _kirin_time <= KIRIN_LOCK:
					_kirin_locked = true
					_kirin_warning = _spawn_rect(Vector2(KIRIN_WIDTH, KIRIN_HEIGHT), Color(LIGHTNING_COLOR, 0.2), _kirin_center(), -1)
			if not _kirin_falling and _kirin_time <= KIRIN_DROP:
				# 龍頭先從天上落下來,咬到地面的那一刻才算打中
				_kirin_falling = true
				_drop_kirin()
			if is_instance_valid(_kirin_hand):
				_kirin_hand.scale = Vector2.ONE * lerpf(0.25, 0.6, clampf(1.0 - _kirin_time / KIRIN_CHARGE, 0.0, 1.0))
			if is_instance_valid(_kirin_warning):
				_kirin_warning.color.a = 0.16 + 0.1 * sin(_state_time * 40.0)
			_place_kirin()
			if _kirin_time <= 0.0:
				_strike_kirin()


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


## 龍頭咬到地面。防禦擋不住;被打中的對手受到傷害並再麻痺一次。
func _strike_kirin() -> void:
	_kirin = Kirin.AFTER
	_cast_duration = _state_time + KIRIN_AFTER
	_free_kirin_props(true)
	screen_shake.emit(20.0)
	if _rect_hits_opponent(_kirin_center(), Vector2(KIRIN_WIDTH, KIRIN_HEIGHT)):
		_paralyse(KIRIN_DAMAGE)


## 用雷電打中對手並使他麻痺(定身)。對手有無下限這類效果擋下來的話就沒有麻痺。
func _paralyse(damage: int) -> void:
	opponent.stun(KIRIN_STUN, damage)
	if opponent.state != State.STUNNED:
		return
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


## 收掉雷槍、雷雲、預兆和手上的雷電。fade 為 true 時雷雲慢慢散掉,否則馬上消失。
func _free_kirin_props(fade: bool) -> void:
	_drop(_kirin_beam)
	_kirin_beam = null
	if is_instance_valid(_kirin_cloud):
		if fade:
			var cloud := _kirin_cloud
			var tween := cloud.create_tween()
			tween.tween_property(cloud, "modulate:a", 0.0, 0.5)
			tween.tween_callback(cloud.queue_free)
		else:
			_kirin_cloud.queue_free()
	_kirin_cloud = null
	_drop(_kirin_warning)
	_kirin_warning = null
	_drop(_kirin_hand)
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
	_drop(_shock_node)
	_shock_node = null


# ---------- 大蛇之力 ----------

func meter_info() -> Dictionary:
	return {"name": "大蛇之力", "color": SNAKE_COLOR}


func snake_full() -> bool:
	return _snake >= SNAKE_MAX


func _add_snake(amount: float) -> void:
	_snake = clampf(_snake + amount, 0.0, SNAKE_MAX)


func _emit_snake() -> void:
	meter_changed.emit(_snake / SNAKE_MAX, snake_full())


## 隨時間慢慢累積(回合進行中才算)。每一格都通知介面,滿了之後計量條才會閃。
func _tick_snake(delta: float) -> void:
	if input_enabled and state != State.KO:
		_add_snake(SNAKE_PER_SECOND * delta)
	_emit_snake()


## 被打中(沒防住)會減少大蛇之力。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	var before := health
	super(move, attacker)
	if health < before and state != State.GUARD:
		_add_snake(-SNAKE_LOSS_PER_HIT)


func stun(duration: float, damage: int = 0, damage_scale: float = 1.0) -> void:
	var before := health
	super(duration, damage, damage_scale)
	if health < before:
		_add_snake(-SNAKE_LOSS_PER_HIT)


# ---------- 蛇咬 ----------

func _start_bite() -> void:
	_clear_bite()
	_snake = 0.0
	_bite = Bite.REACH
	_callout("蛇咬", SNAKE_WHITE, "snake_bite")
	# 整招的長度要看有沒有咬中,先給一個夠長的時間,各階段再自己訂結束的時刻
	_start_cast(10.0, BITE_REACH, _release_bite, "reach")


## 手變成白蛇射出去。
func _release_bite() -> void:
	if _bite != Bite.REACH:
		return
	_bite = Bite.STRIKE
	_bite_length = 0.0
	# 蛇身的圖放在一個會裁切的框裡,只露出目前伸出去的那一段;蛇頭另外接在末端
	_bite_clip = Control.new()
	_bite_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bite_clip.clip_contents = true
	_bite_clip.z_index = 3
	var body := _sheet_sprite(FX_DIR, "snake_body")
	if body != null:
		body.position = Vector2(0, 30)
		_bite_clip.add_child(body)
	else:
		var strip := ColorRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.color = SNAKE_WHITE
		strip.size = Vector2(BITE_RANGE, 12)
		strip.position = Vector2(0, 24)
		_bite_clip.add_child(strip)
	get_parent().add_child(_bite_clip)
	_bite_head = _sheet_prop(FX_DIR, "snake_head", Vector2(40, 30), SNAKE_WHITE)
	_place_bite()


func _tick_bite(delta: float) -> void:
	if _bite == Bite.NONE:
		return
	if state != State.CAST:
		_clear_bite()  # 被打斷,或整招結束
		return
	match _bite:
		Bite.STRIKE:
			_bite_length = minf(_bite_length + BITE_SPEED * delta, BITE_RANGE)
			if _rect_hits_opponent(_bite_point(), BITE_SIZE):
				if _land(_bite_move):
					# 咬住了:把自己拉過去
					_bite = Bite.PULL
					_bite_time = 0.0
					_bite_from = global_position.x
					_bite_to = clampf(opponent.global_position.x - facing * BITE_GAP, arena_min_x, arena_max_x)
				else:
					_bite = Bite.RETRACT  # 被防住:白蛇縮回來
			elif _bite_length >= BITE_RANGE:
				_bite = Bite.RETRACT
		Bite.PULL:
			_bite_time += delta
			var progress := clampf(_bite_time / BITE_PULL_TIME, 0.0, 1.0)
			global_position.x = lerpf(_bite_from, _bite_to, progress)
			velocity.x = 0.0
			if opponent != null:
				_bite_length = maxf((opponent.global_position.x - _bite_hand().x) * facing, 0.0)
			if progress >= 1.0:
				_free_bite_snake()
				_bite = Bite.SLASH
				_bite_time = BITE_SLASH_DELAY
				_cast_anim = "slash_pose"
		Bite.SLASH:
			_bite_time -= delta
			if _bite_time <= 0.0:
				_bite_slash()
		Bite.RETRACT:
			_bite_length -= BITE_SPEED * 1.6 * delta
			if _bite_length <= 0.0:
				_end_bite(0.2)
	_place_bite()


## 拉到對手面前後的那一刀:砍倒對手。
func _bite_slash() -> void:
	_spawn_effect("slash", global_position, _bright(BLADE_COLOR, 1.2), 1.1, facing < 0, 0.0, true)
	Sfx.play("slash")
	if opponent != null and not opponent.is_invulnerable() and absf(opponent.global_position.x - global_position.x) < 170.0:
		opponent.take_hit(_bite_slash_move, self)
	_end_bite(BITE_RECOVERY)


func _end_bite(recovery: float) -> void:
	_free_bite_snake()
	_bite = Bite.NONE
	_cast_duration = _state_time + recovery


func _bite_hand() -> Vector2:
	return global_position + Vector2(BITE_HAND.x * facing, BITE_HAND.y)


## 蛇頭現在的位置。
func _bite_point() -> Vector2:
	return _bite_hand() + Vector2(facing * _bite_length, 0)


func _place_bite() -> void:
	if is_instance_valid(_bite_clip):
		_bite_clip.size = Vector2(maxf(_bite_length, 0.0), 60)
		_bite_clip.scale.x = facing  # 面向左邊時整段往左伸
		_bite_clip.position = _bite_hand() + Vector2(0, -30)
	if is_instance_valid(_bite_head):
		_bite_head.global_position = _bite_point()
		_bite_head.scale.x = facing


func _free_bite_snake() -> void:
	_drop(_bite_clip)
	_bite_clip = null
	_drop(_bite_head)
	_bite_head = null


func _clear_bite() -> void:
	_bite = Bite.NONE
	_free_bite_snake()


# ---------- 蛇籠 ----------

func _start_cage() -> void:
	_snake = 0.0
	_callout("蛇籠", SNAKE_WHITE, "snake_cage")
	_start_cast(CAGE_CAST, CAGE_RELEASE, _release_cage)


## 小白蛇從腳邊往兩側的地面散開。放出去之後就算佐助被打也會留在場上。
func _release_cage() -> void:
	_clear_cage(false)
	_cage_time = CAGE_DURATION
	_cage_age = 0.0
	_cage_position = Vector2(global_position.x, _floor_y)
	_cage_node = Node2D.new()
	_cage_node.z_index = 1
	get_parent().add_child(_cage_node)
	_cage_node.global_position = _cage_position
	var tiles := int(ceil(CAGE_HALF_WIDTH / CAGE_TILE))
	for index in range(-tiles + 1, tiles):
		var tile := _sheet_sprite(FX_DIR, "snakelets")
		if tile == null:
			break
		tile.position = Vector2(index * CAGE_TILE, 0)
		tile.flip_h = index % 2 != 0
		_cage_node.add_child(tile)
	if _cage_node.get_child_count() == 0:
		# 沒有點陣圖時:地上一條淡淡的白色
		var strip := ColorRect.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.color = Color(SNAKE_WHITE, 0.6)
		strip.size = Vector2(CAGE_HALF_WIDTH * 2.0, 10)
		strip.position = Vector2(-CAGE_HALF_WIDTH, -10)
		_cage_node.add_child(strip)
	_cage_node.scale.x = 0.1


func cage_active() -> bool:
	return _cage_time > 0.0


func _tick_cage(delta: float) -> void:
	if not cage_active():
		return
	_cage_time -= delta
	_cage_age += delta
	var spread := clampf(_cage_age / CAGE_SPREAD_TIME, 0.1, 1.0)
	if is_instance_valid(_cage_node):
		_cage_node.scale.x = spread
	if _cage_catches_opponent(CAGE_HALF_WIDTH * spread):
		opponent.stun(CAGE_HOLD)
		if opponent.state == State.STUNNED:
			# 白蛇迅速聚過來纏住對手,地上的蛇跟著散掉
			Sfx.play("snake_bite")
			_clear_wrap()
			_wrap_time = CAGE_HOLD
			_wrap_node = _sheet_prop(FX_DIR, "snake_wrap", Vector2(60, 100), SNAKE_WHITE)
			_clear_cage(true)
			return
	if _cage_time <= 0.0:
		_clear_cage(true)  # 時間到:小白蛇融化


## 對手是不是踩在小白蛇上(站在地上、在範圍內、不是無敵)。
func _cage_catches_opponent(half_width: float) -> bool:
	if opponent == null or opponent.is_invulnerable() or not opponent.is_on_floor():
		return false
	return absf(opponent.global_position.x - _cage_position.x) <= half_width + BODY_SIZE.x / 2.0 \
			and absf(opponent.global_position.y - _cage_position.y) < 24.0


## 收掉地上的小白蛇。melt 為 true 時慢慢融化,否則馬上消失。
func _clear_cage(melt: bool) -> void:
	_cage_time = 0.0
	if is_instance_valid(_cage_node):
		if melt:
			var node := _cage_node
			var tween := node.create_tween()
			tween.tween_property(node, "modulate:a", 0.0, CAGE_MELT)
			tween.parallel().tween_property(node, "scale:y", 0.3, CAGE_MELT)
			tween.tween_callback(node.queue_free)
		else:
			_cage_node.queue_free()
	_cage_node = null


## 纏住對手的白蛇跟著他,直到他能動為止。
func _tick_wrap(delta: float) -> void:
	if _wrap_time <= 0.0:
		return
	_wrap_time -= delta
	if _wrap_time <= 0.0 or opponent == null or opponent.state != State.STUNNED:
		_clear_wrap()
		return
	if is_instance_valid(_wrap_node):
		_wrap_node.global_position = opponent.global_position


func _clear_wrap() -> void:
	_wrap_time = 0.0
	_drop(_wrap_node)
	_wrap_node = null


# ---------- 共用 ----------

func _drop(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


# ---------- 電腦操作 ----------

## 招式一:大蛇之力滿了是蛇咬(白蛇伸得到的距離內);否則是千鳥(氣夠、衝刺打得到的距離內)。
func ai_skill_range() -> float:
	if snake_full():
		return BITE_RANGE
	if energy < CHIDORI_COST:
		return 0.0
	return CHIDORI_RUSH_SPEED * CHIDORI_RUSH_TIME + CHIDORI_HAND.x


## 普通攻擊打到一半:有氣就接千鳥雷槍,大蛇之力滿了就接蛇咬。
func ai_combo_skill() -> bool:
	return (snake_full() or energy >= SPEAR_COST) and _can_spear()


func ai_skill2_ready() -> bool:
	return snake_full() or energy >= FIRE_COST


## 招式二:大蛇之力滿了是蛇籠(對手在附近才放,等他走進來);否則是豪火球,
## 出手要 0.3 秒,對手貼在身邊又能動的時候不放。
func ai_skill2_range() -> float:
	if snake_full():
		return CAGE_HALF_WIDTH * 2.0
	if not _ai_opponent_cannot_interrupt(FIRE_SAFE_GAP):
		return 0.0
	return FIRE_SPEED * FIRE_LIFETIME


## 火球剛打到人:按普攻瞬身追擊。
func ai_wants_attack() -> bool:
	return _followup_time > 0.0 and state in [State.IDLE, State.MOVE, State.CAST]


## 決定存氣的回合先不放招式,存滿 5 格放麒麟。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and energy < KIRIN_COST


func _ai_save_chance() -> float:
	return 0.4


## 氣滿了、對手就在拳頭打得到的地方(站著、沒在防禦)才放麒麟。
func ai_wants_super() -> bool:
	if energy < KIRIN_COST or _kirin != Kirin.NONE or opponent == null or opponent.is_invulnerable():
		return false
	var ahead := (opponent.global_position.x - global_position.x) * facing
	return ahead > 0.0 and ahead < KIRIN_PUNCH_RANGE and opponent.is_on_floor() and opponent.state != State.GUARD


## 已經定住位置、即將落下的麒麟,讓電腦對手知道要閃。
func ai_hazards() -> Array[Dictionary]:
	var hazards: Array[Dictionary] = []
	if _kirin == Kirin.CHARGE and _kirin_locked:
		hazards.append({"x": _kirin_x, "half_width": KIRIN_WIDTH / 2.0, "time": maxf(_kirin_time, 0.0)})
	return hazards


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = []
	if burning():
		parts.append("燃燒 %d" % ceili(_burn_time))
	if cage_active():
		parts.append("蛇籠 %d" % ceili(_cage_time))
	_status_label.text = "   ".join(parts)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
