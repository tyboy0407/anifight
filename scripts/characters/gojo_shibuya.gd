class_name GojoShibuyaFighter
extends GojoFighter
## 五條悟的第三個型態:澀谷事變時的五條悟。在選角畫面長按五條悟的卡片可以選到。
## 氣量上限是 5 格(在 gojo_shibuya.tscn 設定 max_energy = 500)。
## 沿用五條悟的領域背景,蒼與赫則換成體術和近身的術式。
##
## 普通攻擊(四段)
##   一:對手在半個畫面內就瞬身到他面前,連打四拳。
##   二:一腳把人踢到遠處;被踢中的人滑出去的這段時間動彈不得。
##   三:抬手用「蒼」把對手吸回自己面前,吸過來的人短暫動彈不得,第四段一定接得上。
##     只吸得動正在挨打的對手(被踢出去、被蒼迫壓住、硬直或浮空中);行動自如的對手不受影響。
##   四:單手重拳,把人打得一路翻滾到場邊。
## 招式
##   蒼迫(skill,1 格):瞬身到對手上方,往四周壓下蒼的力量,把範圍內的對手壓進地面 2 秒。
##     可以防禦。收招後 0.5 秒內按普通攻擊,直接接第三段把人吸過來。
##   塵殺(上 + skill,1 格):往前衝一段再折回原位,路上的對手去程、回程各挨一下。
##     確實打中就讓對手「破防」10 秒:受到的傷害提高 50%。
##   0.2 秒領域展開・無量空處(下 + special,4 格):領域只展開 0.2 秒,對手僵直 2 秒、氣閉 15 秒;
##     接著衝到對手面前連打 15 下(不受連段上限限制),最後抓起來往前扔出去。

const FORCE_COLOR := Color(0.72, 0.9, 1.0)  # 瞬身、殘影、衝擊的顏色
const CHEST := Vector2(0, -55)

# 普通攻擊
const BLINK_RANGE := 580.0     # 對手在這個距離內,第一段才會瞬身過去(大約半個畫面)
const BLINK_MIN := 110.0       # 已經這麼近就不必瞬身
const BLINK_GAP := 78.0        # 瞬身後離對手多遠
const BLINK_HEIGHT := 150.0    # 對手比自己高出這麼多(跳在空中)就不追
const BLINK_STARTUP := 0.17    # 瞬身過去之後,第一拳要這麼久才打出來(對手來得及防禦)
const FLURRY_STARTUP := 0.05   # 原地出拳的前搖
const FLURRY_HITS := 4
const FLURRY_INTERVAL := 0.09
const FLURRY_DAMAGE := 16
const KICK_DAMAGE := 55
const KICK_DISTANCE := 430.0   # 把人踢出去多遠
const KICK_SLIDE := 0.32       # 滑出去花多久
const KICK_HOLD := 0.95        # 被踢中的人動彈不得多久(夠接第三段)
const PULL_RANGE := 760.0      # 「蒼」吸得到多遠的對手
const PULL_DAMAGE := 14
const PULL_TIME := 0.14        # 把人吸到面前花多久
const PULL_GAP := 84.0         # 吸過來後離自己多遠
const PULL_HOLD := 0.6         # 被吸過來的人動彈不得多久(夠接第四段)
const PULL_HAND := Vector2(52, -84)
const PULL_ORB := 46.0
const PUNCH_DAMAGE := 110
const DRAG_DUST := 0.04        # 被踢出去、吸回來時,每隔多久揚起一次沙土
# 蒼迫
const PRESS_COST := 100
const PRESS_HEIGHT := 210.0    # 出現在對手頭上多高
const PRESS_WINDUP := 0.30     # 瞬身後到壓下去的時間(對手可以趁這段防禦或跑開)
const PRESS_RADIUS := 170.0    # 往左右壓得到多遠
const PRESS_DAMAGE := 90
const PRESS_PIN := 2.0         # 被壓進地面幾秒
const PRESS_SINK := 18.0       # 人陷進地面幾個像素
const PRESS_AFTER := 0.22      # 壓下去之後還停在空中多久
const PRESS_LAND_GAP := 230.0  # 收招時落在對手面前多遠
const PRESS_RECOVERY := 0.12
const PRESS_FOLLOW := 0.5      # 收招後這段時間內按普通攻擊:直接接第三段
const PRESS_ORB_START := 60.0
const PRESS_ORB_SIZE := 250.0
const PIT_STONES := 10
# 塵殺
const DUST_COST := 100
const DUST_DISTANCE := 440.0
const DUST_START := 0.08       # 起手
const DUST_OUT := 0.11         # 衝出去花多久
const DUST_BACK := 0.13        # 折回來花多久
const DUST_RECOVERY := 0.16
const DUST_DAMAGE := 65
const DUST_REACH := 62.0       # 身體前後這麼遠以內的對手算在路徑上
const DUST_HEIGHT := 110.0     # 對手和自己的高度差在這之內才打得到
const BREAK_TIME := 10.0       # 「破防」幾秒
const BREAK_SCALE := 1.5       # 破防期間對手受到的傷害倍率
# 0.2 秒領域展開
const VOID_SIGN := 0.30        # 結印到領域展開
const VOID_TIME := 0.2         # 領域展開多久
const VOID_FADE := 0.05
const VOID_STUN := 2.0
const VOID_SEAL := 15.0
const VOID_MISS_RECOVERY := 0.3
const RUSH_TIME := 0.10        # 衝到對手面前花多久
const RUSH_GAP := 76.0
const BARRAGE_HITS := 15
const BARRAGE_INTERVAL := 0.065
const BARRAGE_DAMAGE := 50
const GRAB_TIME := 0.22        # 把人抓起來花多久
const GRAB_HAND := Vector2(58, -34)  # 抓起來時,對手的腳底相對於自己的位置
const TOSS_DAMAGE := 600
const TOSS_RECOVERY := 0.35
# 電腦操作
const AI_NEAR := 115.0         # 這個距離內算近身,用不著瞬身
const AI_BLINK_CHANCE := 0.08  # 半個畫面內,每次判斷有這個機率直接瞬身過去開打
const AI_PRESS_CHANCE := 0.5   # 每次判斷有這個機率考慮用蒼迫

enum Press { NONE, GATHER, HOLD, LAND }
enum Dust { NONE, READY, OUT, BACK, RECOVER }
enum Void { NONE, SIGN, DOMAIN, RUSH, BARRAGE, GRAB, RECOVER }

var _flurry_move: AttackData
var _kick_move: AttackData
var _pull_move: AttackData
var _pull_hit_move: AttackData
var _punch_move: AttackData
var _flurry_beat := -1
var _health_before_hit := 0

# 被踢出去、吸回來的對手:由這裡帶著滑到定點
var _drag_time := 0.0
var _drag_duration := 0.0
var _drag_from := 0.0
var _drag_to := 0.0
var _drag_dust := 0.0

var _press := Press.NONE
var _press_time := 0.0
var _press_hold := Vector2.ZERO
var _press_side := -1      # 出招前自己在對手的哪一邊(-1 是左邊)
var _press_floor_y := 0.0
var _press_node: ColorRect
var _press_move: AttackData
var _follow_time := 0.0    # 蒼迫收招後,還能接第三段的時間
var _pit_node: Node2D      # 對手陷進去的坑
var _pit_pending := false  # 對手還在空中,落地才砸出坑

var _dust := Dust.NONE
var _dust_time := 0.0
var _dust_origin := Vector2.ZERO
var _dust_target_x := 0.0
var _dust_hit_done := false
var _dust_move: AttackData

var _void := Void.NONE
var _void_time := 0.0
var _void_from := Vector2.ZERO
var _void_to := Vector2.ZERO
var _void_hold := Vector2.ZERO
var _victim_hold := Vector2.ZERO
var _barrage_left := 0
var _barrage_move: AttackData
var _toss_move: AttackData


func _build_moves() -> void:
	super()
	# 一:連打四拳(判定期間每隔一小段時間重新算一次命中,見 _tick_attack)
	_flurry_move = AttackData.make(FLURRY_DAMAGE, FLURRY_STARTUP, FLURRY_INTERVAL * FLURRY_HITS, 0.18,
			Vector2(58, -68), Vector2(84, 44), Vector2(30, 0), 0.34, false, 60.0)
	# 二:踢擊。打中後對手由 _kick_away 帶著滑出去
	_kick_move = AttackData.make(KICK_DAMAGE, 0.08, 0.10, 0.24, Vector2(70, -58), Vector2(110, 56), Vector2(200, 0), 0.50, false, 150.0)
	# 三:抬手的動作本身沒有攻擊判定,效果在 _release_pull
	_pull_move = AttackData.make(0, 0.12, 0.05, 0.22, PULL_HAND, Vector2(10, 10), Vector2.ZERO, 0.0, false, 0.0)
	_pull_move.color = Color(BLUE_COLOR, 0.75)
	_pull_hit_move = AttackData.make(PULL_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.40, false, 0.0)
	# 四:重拳,把人打得一路翻滾到場邊
	_punch_move = AttackData.make(PUNCH_DAMAGE, 0.14, 0.12, 0.38, Vector2(74, -64), Vector2(116, 64), Vector2(880, -340), 0.0, true, 220.0)
	_punch_move.tumbles = true
	_ground_moves = [_flurry_move, _kick_move, _pull_move, _punch_move]

	# 蒼迫、塵殺都可以防禦;大招的連打打在僵直的對手身上,擋不了
	_press_move = _technique(PRESS_DAMAGE, Vector2.ZERO, 0.50)
	_dust_move = _technique(DUST_DAMAGE, Vector2.ZERO, 0.55)
	_barrage_move = _technique(BARRAGE_DAMAGE, Vector2.ZERO, 0.30)
	_barrage_move.unblockable = true
	_barrage_move.ignores_combo_limit = true
	_toss_move = _technique(TOSS_DAMAGE, Vector2(1150, -280), 0.0, true)
	_toss_move.unblockable = true
	_toss_move.tumbles = true


## 不經過攻擊框、由招式自己判定命中的攻擊。耗氣招式,打中不回氣。
func _technique(damage: int, knockback: Vector2, hitstun: float, launches: bool = false) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_press()
	_clear_dust()
	_clear_void()
	_clear_pit()
	_drag_time = 0.0
	_follow_time = 0.0
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	if _hitstop <= 0.0:
		_follow_time = maxf(_follow_time - delta, 0.0)
	if state not in [State.CAST, State.IDLE, State.MOVE, State.GUARD]:
		_follow_time = 0.0
	_tick_drag(delta)
	_tick_press(delta)
	_tick_dust(delta)
	_tick_void(delta)
	_tick_pit()


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(DUST_COST):
			_start_dust()
			return true
		return false
	if _skill1_pressed() and opponent != null and _spend_energy(PRESS_COST):
		_start_press()
		return true
	return false


# ---------- 普通攻擊 ----------

## 蒼迫收招後的短暫時間內按普通攻擊:跳過前兩段,直接抬手把人吸過來。
func _tick_ground() -> void:
	if _follow_time > 0.0 and is_on_floor() and _pressed("attack"):
		_follow_time = 0.0
		_face_opponent()
		_start_attack(_pull_move, 2)
		return
	super()


func _start_attack(move: AttackData, combo_step: int) -> void:
	var blinked := false
	if move == _flurry_move:
		_flurry_beat = -1
		blinked = combo_step == 0 and _blink_in()
		# 瞬身過去的那一次出手比較慢:人先出現在面前,才開始出拳
		_flurry_move.startup = BLINK_STARTUP if blinked else FLURRY_STARTUP
	super(move, combo_step)
	if blinked:
		_attack_anim = "blink_flurry"


## 第一段:對手在半個畫面內就瞬身到他面前,回傳有沒有瞬身。
## 太近、太遠、對手倒地或跳在高處時原地出拳。
func _blink_in() -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	var gap := opponent.global_position.x - global_position.x
	if absf(gap) <= BLINK_MIN or absf(gap) > BLINK_RANGE:
		return false
	if global_position.y - opponent.global_position.y > BLINK_HEIGHT:
		return false
	var side := signf(gap)
	_vanish_effect(FORCE_COLOR)
	global_position.x = clampf(opponent.global_position.x - side * BLINK_GAP, arena_min_x, arena_max_x)
	velocity = Vector2.ZERO
	facing = int(side)
	_appear_effect(FORCE_COLOR)
	Sfx.play("teleport")
	return true


func _tick_attack(delta: float) -> void:
	if _move == _flurry_move:
		# 連打:每一拳各算一次命中,各有自己的揮擊弧線
		var beat := floori((_state_time - _move.startup) / FLURRY_INTERVAL)
		if beat != _flurry_beat and beat >= 0 and beat < FLURRY_HITS:
			_flurry_beat = beat
			_hit_targets.clear()
			if beat > 0:
				_slash_shown = false
				Sfx.play("swing")
	super(delta)


## 第三段抬手的那一刻:放出「蒼」。
func _show_slash() -> void:
	if _move == _pull_move:
		_release_pull()
		return
	super()


func _check_hits() -> void:
	if _move == _pull_move:
		return  # 這一段的效果不走攻擊框
	if opponent != null:
		_health_before_hit = opponent.health
	super()


func _on_attack_hit(target: Fighter, move: AttackData) -> void:
	if move != _kick_move or target != opponent:
		return
	# 確實踢中(沒被防禦、沒被無下限擋下):把人踢到遠處,這段時間他動彈不得
	if target.health < _health_before_hit and target.state != State.GUARD:
		_kick_away()


func _kick_away() -> void:
	opponent.pin(KICK_HOLD)
	if opponent.state != State.STUNNED:
		return
	_start_drag(opponent.global_position.x + facing * KICK_DISTANCE, KICK_SLIDE)


## 讓動彈不得的對手滑到 to_x:先快後慢。途中對手脫離定身(被打飛、被打倒)就停。
func _start_drag(to_x: float, duration: float) -> void:
	_drag_from = opponent.global_position.x
	_drag_to = clampf(to_x, arena_min_x, arena_max_x)
	_drag_duration = duration
	_drag_time = duration
	_drag_dust = 0.0


func _tick_drag(delta: float) -> void:
	if _drag_time <= 0.0:
		return
	if opponent == null or opponent.state != State.STUNNED:
		_drag_time = 0.0
		return
	if opponent._hitstop > 0.0:
		return  # 命中定格的那一下先不動
	_drag_time = maxf(_drag_time - delta, 0.0)
	var progress := 1.0 - _drag_time / _drag_duration
	opponent.global_position.x = lerpf(_drag_from, _drag_to, 1.0 - pow(1.0 - progress, 2.0))
	opponent.velocity.x = 0.0
	_drag_dust -= delta
	if _drag_dust <= 0.0 and opponent.is_on_floor():
		_drag_dust = DRAG_DUST
		_spawn_dust(opponent.global_position, 2, 0.55)


## 「蒼」:把前方正在挨打的對手吸到自己面前。背後的、太遠的吸不到。
func _release_pull() -> void:
	Sfx.play("blue")
	var hand := global_position + Vector2(PULL_HAND.x * facing, PULL_HAND.y)
	var orb := _make_orb(PULL_ORB, Color(BLUE_COLOR, 0.85), hand, "void")
	var fade := orb.create_tween()
	fade.tween_property(orb, "scale", Vector2(1.5, 1.5), PULL_TIME + 0.14)
	fade.parallel().tween_property(orb, "modulate:a", 0.0, PULL_TIME + 0.14)
	fade.tween_callback(orb.queue_free)
	if opponent == null or opponent.is_immovable():
		return
	var ahead := (opponent.global_position.x - global_position.x) * facing
	if ahead < 0.0 or ahead > PULL_RANGE:
		return
	var from := opponent.global_position + CHEST
	# 只吸得動正在挨打、動彈不得的對手(被踢出去、被蒼迫壓住、硬直或浮空中);行動自如的對手不受影響
	if opponent.state not in [State.STUNNED, State.HITSTUN, State.LAUNCHED]:
		return
	if not _land(_pull_hit_move) or opponent.state == State.KO:
		return
	opponent.pin(PULL_HOLD)
	if opponent.state != State.STUNNED:
		return
	_start_drag(global_position.x + facing * PULL_GAP, PULL_TIME)
	# 被吸過來的軌跡:幾道往手心收的藍線
	for i in 3:
		var start := from + Vector2(0, (i - 1) * 26.0)
		var streak := _spawn_rect(Vector2(start.distance_to(hand), 4), Color(_bright(BLUE_COLOR, 1.4), 0.9), (start + hand) / 2.0, 2)
		streak.rotation = (hand - start).angle()
		var tween := streak.create_tween()
		tween.tween_property(streak, "scale:y", 0.2, 0.2)
		tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.2)
		tween.tween_callback(streak.queue_free)


# ---------- 招式一:蒼迫 ----------

## 瞬身到對手正上方,在身邊凝聚蒼的力量;凝聚完就往四周壓下去。
func _start_press() -> void:
	_clear_press()
	_set_hitbox(false)
	_press = Press.GATHER
	_press_time = PRESS_WINDUP
	_press_floor_y = global_position.y
	var gap := global_position.x - opponent.global_position.x
	_press_side = int(signf(gap)) if absf(gap) > 1.0 else -facing
	_vanish_effect(FORCE_COLOR)
	_face_opponent()
	global_position = Vector2(clampf(opponent.global_position.x, arena_min_x, arena_max_x),
			minf(opponent.global_position.y, _press_floor_y) - PRESS_HEIGHT)
	velocity = Vector2.ZERO
	_press_hold = global_position
	_appear_effect(FORCE_COLOR)
	Sfx.play("teleport")
	_callout("蒼迫", BLUE_COLOR, "blue")
	_press_node = _make_orb(PRESS_ORB_START, Color(BLUE_COLOR, 0.55), global_position + CHEST, "void")
	# 階段由 _tick_press 自己推進,施法時間先設成放不完
	_start_cast(10.0, PRESS_WINDUP, _release_press, "press")


func _tick_press(delta: float) -> void:
	if _press == Press.NONE:
		return
	if state != State.CAST:
		_clear_press()  # 被打斷,或整招結束
		return
	if _press == Press.LAND:
		return
	velocity = Vector2.ZERO
	global_position = _press_hold
	_press_time -= delta
	if _press == Press.GATHER:
		var progress := 1.0 - clampf(_press_time / PRESS_WINDUP, 0.0, 1.0)
		_resize_orb(_press_node, lerpf(PRESS_ORB_START, PRESS_ORB_SIZE, progress))
	else:
		# 壓下去之後:球體往外擴散、淡掉
		var progress := 1.0 - clampf(_press_time / PRESS_AFTER, 0.0, 1.0)
		_resize_orb(_press_node, lerpf(PRESS_ORB_SIZE, PRESS_ORB_SIZE * 1.5, progress))
		_press_node.modulate.a = 1.0 - progress
		if _press_time <= 0.0:
			_land_press()


func _resize_orb(orb: ColorRect, orb_size: float) -> void:
	if not is_instance_valid(orb):
		return
	orb.size = Vector2(orb_size, orb_size)
	orb.pivot_offset = orb.size / 2.0
	orb.position = global_position + CHEST - orb.size / 2.0


## 往四周壓下去:範圍內、在自己下方的對手被壓進地面。
func _release_press() -> void:
	if _press != Press.GATHER:
		return
	_press = Press.HOLD
	_press_time = PRESS_AFTER
	Sfx.play("burst")
	screen_shake.emit(8.0)
	var floor_point := Vector2(global_position.x, _press_floor_y)
	_spawn_effect("ring", floor_point + Vector2(0, -12), _bright(BLUE_COLOR, 1.5), PRESS_RADIUS / (22.5 * _effect_scale))
	# 從上方一路壓到地面的力道
	for i in 7:
		var x := lerpf(-PRESS_RADIUS, PRESS_RADIUS, i / 6.0) * 0.9
		var top := global_position.y - 30.0 + absf(x) * 0.5
		var line := _spawn_rect(Vector2(5, _press_floor_y - top), Color(_bright(BLUE_COLOR, 1.5), 0.8), Vector2(floor_point.x + x, (top + _press_floor_y) / 2.0), 2)
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.26)
		tween.tween_callback(line.queue_free)
	_spawn_dust(floor_point, 10, 1.3)
	if not _press_reaches() or not _land(_press_move) or opponent.state == State.KO:
		return
	opponent.pin(PRESS_PIN, PRESS_SINK)
	if opponent.state != State.STUNNED:
		return
	opponent.velocity = Vector2(0, 1400.0)  # 人在空中就直接砸到地上
	_pit_pending = true


func _press_reaches() -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	return absf(opponent.global_position.x - global_position.x) <= PRESS_RADIUS \
			and opponent.global_position.y >= global_position.y


## 收招:落回對手面前一段距離外(出招前自己在哪一邊就落在哪一邊)。
func _land_press() -> void:
	_press = Press.LAND
	_free_press_node()
	_vanish_effect(FORCE_COLOR)
	var anchor := opponent.global_position.x if opponent != null else global_position.x
	var x := clampf(anchor + _press_side * PRESS_LAND_GAP, arena_min_x, arena_max_x)
	if absf(x - anchor) < PRESS_LAND_GAP * 0.5:
		# 那一邊緊貼著場邊:改落在另一邊
		x = clampf(anchor - _press_side * PRESS_LAND_GAP, arena_min_x, arena_max_x)
	global_position = Vector2(x, _press_floor_y)
	velocity = Vector2.ZERO
	_face_opponent()
	_appear_effect(FORCE_COLOR)
	Sfx.play("teleport")
	_cast_anim = "idle"
	_anim_restart = true
	_cast_duration = _state_time + PRESS_RECOVERY
	_follow_time = PRESS_RECOVERY + PRESS_FOLLOW


func _free_press_node() -> void:
	if is_instance_valid(_press_node):
		_press_node.queue_free()
	_press_node = null


func _clear_press() -> void:
	_press = Press.NONE
	_free_press_node()


## 對手被壓進去的坑:一道裂開的地面,周圍翻起來的碎石蓋住陷下去的腳。
func _make_pit(at: Vector2) -> void:
	_clear_pit()
	_pit_node = Node2D.new()
	_pit_node.z_index = 3
	get_parent().add_child(_pit_node)
	_pit_node.global_position = at
	var hole := ColorRect.new()
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.color = Color(0.07, 0.06, 0.09, 0.92)
	hole.size = Vector2(96, PRESS_SINK + 10.0)  # 往下蓋住陷進去的腳
	hole.position = Vector2(-48, -5)
	_pit_node.add_child(hole)
	for i in PIT_STONES:
		var stone_size := randf_range(9.0, 19.0)
		var stone := ColorRect.new()
		stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stone.color = DEBRIS_COLORS[i % DEBRIS_COLORS.size()].darkened(randf_range(0.0, 0.25))
		stone.size = Vector2(stone_size, stone_size)
		stone.pivot_offset = stone.size / 2.0
		stone.position = Vector2(lerpf(-54.0, 54.0, i / float(PIT_STONES - 1)) + randf_range(-4.0, 4.0) - stone_size / 2.0,
				-stone_size * randf_range(0.6, 0.95))
		stone.rotation = randf_range(-0.6, 0.6)
		_pit_node.add_child(stone)
	if _spawn_effect("landing", at, Color.WHITE, 1.0, randf() < 0.5) == null:
		_spawn_dust(at, 8, 1.0)
	screen_shake.emit(10.0)
	Sfx.play("bounce")


func _tick_pit() -> void:
	if _pit_pending:
		if opponent == null or opponent.state != State.STUNNED:
			_pit_pending = false
		elif opponent.is_on_floor():
			_pit_pending = false
			_make_pit(opponent.global_position)
		return
	if not is_instance_valid(_pit_node):
		return
	# 對手脫離定身,或還在定身中就被吸走:人回到地面上,坑慢慢淡掉
	if opponent == null or opponent.state != State.STUNNED or absf(opponent.global_position.x - _pit_node.global_position.x) > 10.0:
		if opponent != null:
			opponent.set_sink(0.0)
		var pit := _pit_node
		_pit_node = null
		var tween := pit.create_tween()
		tween.tween_property(pit, "modulate:a", 0.0, 0.3)
		tween.tween_callback(pit.queue_free)


func _clear_pit() -> void:
	_pit_pending = false
	if is_instance_valid(_pit_node):
		_pit_node.queue_free()
	_pit_node = null


# ---------- 招式二:塵殺 ----------

func _start_dust() -> void:
	_clear_dust()
	_dust = Dust.READY
	_dust_origin = global_position
	_dust_target_x = clampf(global_position.x + facing * DUST_DISTANCE, arena_min_x, arena_max_x)
	_callout("塵殺", FORCE_COLOR, "special")
	_start_cast(10.0, DUST_START, _release_dust, "dust_ready")


func _release_dust() -> void:
	if _dust == Dust.READY:
		_begin_dust_leg(Dust.OUT)


func _begin_dust_leg(leg: Dust) -> void:
	_dust = leg
	_dust_time = DUST_OUT if leg == Dust.OUT else DUST_BACK
	_dust_hit_done = false
	var to_x := _dust_target_x if leg == Dust.OUT else _dust_origin.x
	if absf(to_x - global_position.x) > 1.0:
		facing = int(signf(to_x - global_position.x))
	_cast_anim = "dust"
	_anim_restart = true
	Sfx.play("dash")
	_streak(global_position + CHEST, Vector2(to_x, global_position.y) + CHEST)


func _tick_dust(delta: float) -> void:
	if _dust == Dust.NONE:
		return
	if state != State.CAST:
		_clear_dust()  # 被打斷,或整招結束
		return
	if _dust == Dust.READY or _dust == Dust.RECOVER:
		return
	_dust_time -= delta
	var out := _dust == Dust.OUT
	var progress := 1.0 - clampf(_dust_time / (DUST_OUT if out else DUST_BACK), 0.0, 1.0)
	var next_x := lerpf(_dust_origin.x, _dust_target_x, progress) if out else lerpf(_dust_target_x, _dust_origin.x, progress)
	# 先判定、再移動:打中的那一刻人還沒越過對手,對手面向他防禦就擋得住
	if not _dust_hit_done and _dust_sweeps_opponent(global_position.x, next_x):
		_dust_hit_done = true
		_dust_strike()
	_leave_ghost()
	_spawn_dust(Vector2(global_position.x, _dust_origin.y), 2, 0.6)
	global_position = Vector2(next_x, _dust_origin.y)
	velocity = Vector2.ZERO
	if _dust_time > 0.0:
		return
	if out:
		_begin_dust_leg(Dust.BACK)
		return
	# 回到原位,收招
	_dust = Dust.RECOVER
	global_position = _dust_origin
	_face_opponent()
	_cast_anim = "idle"
	_anim_restart = true
	_cast_duration = _state_time + DUST_RECOVERY


## 這一格要經過的路段(from_x 到 to_x)上有沒有對手。
func _dust_sweeps_opponent(from_x: float, to_x: float) -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	if absf(opponent.global_position.y - global_position.y) > DUST_HEIGHT:
		return false
	var x := opponent.global_position.x
	return x >= minf(from_x, to_x) - DUST_REACH and x <= maxf(from_x, to_x) + DUST_REACH


func _dust_strike() -> void:
	_spawn_effect("cut", opponent.global_position + CHEST, _bright(FORCE_COLOR, 1.6), 1.2, facing < 0)
	Sfx.play("slash")
	if _land(_dust_move) and opponent.state != State.KO:
		opponent.break_guard(BREAK_TIME, BREAK_SCALE)


func _clear_dust() -> void:
	_dust = Dust.NONE


# ---------- 大招:0.2 秒領域展開・無量空處 ----------

func _start_super() -> void:
	_clear_void()
	_void = Void.SIGN
	_start_cast(10.0, VOID_SIGN, _release_void, "domain")


## 領域展開:只維持一瞬間,但已經足夠讓對手僵直。沒定住對手(無下限、幽步閃過)就直接收招。
func _release_void() -> void:
	if _void != Void.SIGN:
		return
	Sfx.play("domain_void")
	_clear_domain()
	_domain_node = _make_domain_effect(VOID_TIME + VOID_FADE * 2.0, VOID_FADE)
	if opponent != null:
		opponent.stun(VOID_STUN, 0)
		if opponent.state == State.STUNNED:
			opponent.seal_energy(VOID_SEAL)
			_void = Void.DOMAIN
			_void_time = VOID_TIME
			return
	_recover_void(VOID_MISS_RECOVERY)


func _tick_void(delta: float) -> void:
	if _void == Void.NONE:
		return
	if state != State.CAST:
		_clear_void()  # 被打斷,或整招結束
		return
	if _void == Void.SIGN or _void == Void.RECOVER:
		return
	if opponent == null or opponent.is_invulnerable():
		_recover_void(VOID_MISS_RECOVERY)  # 對手被打倒了
		return
	_void_time -= delta
	match _void:
		Void.DOMAIN:
			if _void_time <= 0.0:
				_begin_rush()
		Void.RUSH:
			var progress := 1.0 - clampf(_void_time / RUSH_TIME, 0.0, 1.0)
			_leave_ghost()
			global_position = _void_from.lerp(_void_to, progress)
			velocity = Vector2.ZERO
			if _void_time <= 0.0:
				_begin_barrage()
		Void.BARRAGE:
			_hold_both(_victim_hold)
			if _void_time > 0.0:
				return
			if _barrage_left > 0:
				_barrage_left -= 1
				_void_time = BARRAGE_INTERVAL
				_barrage_hit()
			else:
				_void = Void.GRAB
				_void_time = GRAB_TIME
				_cast_anim = "grab"
				_anim_restart = true
		Void.GRAB:
			# 抓著對手提起來
			var progress := 1.0 - clampf(_void_time / GRAB_TIME, 0.0, 1.0)
			var lifted := _void_hold + Vector2(GRAB_HAND.x * facing, GRAB_HAND.y)
			_hold_both(_victim_hold.lerp(lifted, 1.0 - pow(1.0 - progress, 2.0)))
			if _void_time <= 0.0:
				_toss()


## 領域收起後:一瞬間衝到對手面前(對手在空中就衝到同樣的高度)。
func _begin_rush() -> void:
	var gap := opponent.global_position.x - global_position.x
	var side := int(signf(gap)) if absf(gap) > 1.0 else facing
	facing = side
	_void = Void.RUSH
	_void_time = RUSH_TIME
	_void_from = global_position
	_void_to = Vector2(clampf(opponent.global_position.x - side * RUSH_GAP, arena_min_x, arena_max_x), opponent.global_position.y)
	_cast_anim = "dust"
	_anim_restart = true
	Sfx.play("dash")
	_streak(_void_from + CHEST, _void_to + CHEST)


func _begin_barrage() -> void:
	_void = Void.BARRAGE
	_void_time = 0.0
	_barrage_left = BARRAGE_HITS
	_void_hold = global_position
	_victim_hold = opponent.global_position


## 連打期間雙方停在原地(在空中也一樣)。
func _hold_both(victim_at: Vector2) -> void:
	velocity = Vector2.ZERO
	global_position = _void_hold
	opponent.velocity = Vector2.ZERO
	opponent.global_position = victim_at


func _barrage_hit() -> void:
	_cast_anim = "jab1" if _barrage_left % 2 == 0 else "jab2"
	_anim_restart = true
	Sfx.play("swing")
	opponent.take_hit(_barrage_move, self)


## 把抓起來的對手往前用力扔出去,一路翻滾到場邊。
func _toss() -> void:
	_cast_anim = "toss"
	_anim_restart = true
	Sfx.play("special")
	screen_shake.emit(10.0)
	opponent.take_hit(_toss_move, self)
	_recover_void(TOSS_RECOVERY)


func _recover_void(time: float) -> void:
	_void = Void.RECOVER
	_cast_duration = _state_time + time


func _clear_void() -> void:
	_void = Void.NONE


# ---------- 共用 ----------

## 在原地留下一個淡掉的淺藍色殘影(目前這一格的樣子)。
func _leave_ghost() -> void:
	var ghost := _copy_of_self(_sprite.animation, _sprite.frame) if _has_sprite else null
	if ghost == null:
		return
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(1.2, 1.7, 2.4, 0.5)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


## 高速移動留下的一道光痕。
func _streak(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	if length < 30.0:
		return
	var streak := _spawn_rect(Vector2(length, 6), Color(_bright(FORCE_COLOR, 1.3), 0.9), (from + to) / 2.0, 2)
	streak.rotation = (to - from).angle()
	var tween := streak.create_tween()
	tween.tween_property(streak, "scale:y", 0.2, 0.22)
	tween.parallel().tween_property(streak, "modulate:a", 0.0, 0.22)
	tween.tween_callback(streak.queue_free)


# ---------- 電腦操作 ----------

## 蒼迫凝聚的那一小段時間:讓對面的電腦知道要防禦或跑開。
func ai_hazards() -> Array[Dictionary]:
	if _press != Press.GATHER:
		return []
	return [{"x": global_position.x, "half_width": PRESS_RADIUS, "time": maxf(_press_time, 0.0)}]


## 蒼迫:對手在哪裡都壓得到。存氣中、對手已經動彈不得時不用;也不是每次都用。
func ai_skill_range() -> float:
	if energy < PRESS_COST or ai_saving_energy() or opponent == null or opponent.state == State.STUNNED:
		return 0.0
	return INF if randf() < AI_PRESS_CHANCE else 0.0


func ai_skill2_ready() -> bool:
	return energy >= DUST_COST


## 塵殺:對手要在衝得到的距離內。
func ai_skill2_range() -> float:
	return DUST_DISTANCE - 30.0


## 塵殺不用蓄力(五條悟的赫才要)。
func ai_skill2_hold() -> float:
	return 0.0


## 該按普通攻擊的時機:蒼迫剛收招、對手動彈不得;半個畫面內偶爾也直接瞬身過去。
func ai_wants_attack() -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	if _follow_time > 0.0:
		return true
	var distance := absf(opponent.global_position.x - global_position.x)
	if distance > BLINK_RANGE or global_position.y - opponent.global_position.y > BLINK_HEIGHT:
		return false
	if opponent.state == State.STUNNED:
		return true
	return distance > AI_NEAR and randf() < AI_BLINK_CHANCE


## 氣夠了就想開領域:對手擋不了,定住之後整套一定打得完。
func ai_wants_super() -> bool:
	return energy >= super_cost() and _void == Void.NONE and opponent != null and opponent.state != State.KO


## 結印的那一下會被打斷:對手貼在身邊、又不是動彈不得的時候先不放。
func ai_super_is_safe() -> bool:
	return opponent.state == State.HITSTUN or _ai_opponent_cannot_interrupt(240.0)
