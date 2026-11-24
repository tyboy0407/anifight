class_name KanekiFighter
extends Fighter
## 金木研(東京喰種)。氣量上限是 5 格(在 kaneki.tscn 設定 max_energy = 500)。
##
## 赫胞計量條(血條下方,共三層)
##   打中對手、自己挨打都會累積。每累積滿一層,背後的赫子尾巴多一條:開場一條,最多四條。
##   尾巴整場對戰都保留,換回合不會歸零;新的一場對戰才從一條開始。
## 普通攻擊
##   一:出拳。二:尾巴追擊,有幾條尾巴就刺幾下。三:再出拳。四:往前踢一腳,接著自己往後跳開。
##   有四條尾巴時多出第五段:四條尾巴一起往前伸出去穿刺,把人打飛到場邊。
## 招式
##   跳擊(skill,1 格):往前撲過去;打中就短暫壓制對手,有幾條尾巴就追擊幾下,最後一下把人挑飛。
##   尾殺(上 + skill,2 格):尾巴往身前大範圍橫掃,尾巴越多傷害越高。
##   獵殺本能(下 + special,3 格):往前高速衝刺;抓到對手就瘋狂撕咬,把造成傷害的一半回復成自己的血量,
##     咬完進入「亢奮」15 秒:移動速度與傷害提升 30%。

const KAGUNE_COLOR := Color(0.9, 0.12, 0.16)
const CHEST := Vector2(0, -60)

# 赫胞
const CELLS_PER_LAYER := 100.0
const CELL_LAYERS := 3
const CELLS_PER_DAMAGE_DEALT := 0.07   # 每打出 1 點傷害累積多少
const CELLS_PER_DAMAGE_TAKEN := 0.06   # 每受到 1 點傷害累積多少
# 普通攻擊
const TAIL_INTERVAL := 0.11            # 第二段:尾巴一下接一下的間隔
const TAIL_DAMAGE := 28
const TAIL_REACH := Vector2(168, -62)  # 尾巴刺到哪裡(以腳底為原點、面向為正)
const KICK_DAMAGE := 66
const KICK_ACTIVE := 0.10              # 第四段:腳踢出去的判定時間,之後是往後跳
const HOP_TIME := 0.15
const HOP_SPEED := 620.0
const PIERCE_DAMAGE := 140
const PIERCE_REACH := Vector2(350, -62)
# 跳擊
const LEAP_COST := 100
const LEAP_SPEED := Vector2(620, -520)
const LEAP_DAMAGE := 80
const LEAP_PIN := 0.30                 # 壓制多久之後第一條尾巴才刺下去
const LEAP_TAIL_INTERVAL := 0.13
const LEAP_TAIL_DAMAGE := 40
const LEAP_RECOVERY := 0.22
const LEAP_RANGE := 330.0              # 大約撲得到多遠(電腦用)
# 尾殺
const SWEEP_COST := 200
const SWEEP_DAMAGE := 150
const SWEEP_DAMAGE_PER_TAIL := 50
# 獵殺本能
const HUNT_START := 0.12
const HUNT_DISTANCE := 540.0
const HUNT_TIME := 0.20
const HUNT_REACH := 66.0               # 身體前後這麼遠以內的對手算抓到
const HUNT_HEIGHT := 110.0
const HUNT_GAP := 58.0                 # 撕咬時貼在對手面前多近
const HUNT_DAMAGE := 80
const BITE_COUNT := 6
const BITE_INTERVAL := 0.12
const BITE_DAMAGE := 76
const BITE_FINAL_DAMAGE := 150
const HUNT_HEAL := 0.5                 # 造成的傷害有多少比例回復成血量
const HUNT_MISS_RECOVERY := 0.42
const HUNT_RECOVERY := 0.30
const FRENZY_TIME := 15.0
const FRENZY_SCALE := 1.3              # 亢奮:移動速度與傷害的倍率

enum Hunt { NONE, READY, DASH, BITE, RECOVER }

var _cells := 0.0            # 赫胞,0 到 CELLS_PER_LAYER * CELL_LAYERS
var _seen_health := 0        # 上一格自己與對手的血量:用來算這一格打出、受到多少傷害
var _seen_foe_health := 0
var _tails: KaguneTails
var _status_label: Label

var _punch_move: AttackData
var _tail_move: AttackData
var _second_punch_move: AttackData
var _kick_move: AttackData        # 第四段是最後一段時:把人踢飛
var _kick_link_move: AttackData   # 有四條尾巴時:只把人踢退,第五段才接得上
var _pierce_move: AttackData
var _tail_hits := 1               # 這一次第二段要刺幾下(出招當下的尾巴數)
var _tail_beat := -1
var _health_before_hit := 0

var _leap_move: AttackData
var _leap_tail_move: AttackData
var _leap_end_move: AttackData
var _leap_hit := false            # 跳擊剛剛確實打中了
var _leap_active := false         # 正在用尾巴追擊
var _leap_left := 0
var _leap_time := 0.0

var _sweep_move: AttackData

var _hunt := Hunt.NONE
var _hunt_time := 0.0
var _hunt_from := 0.0
var _hunt_to := 0.0
var _hunt_hold := Vector2.ZERO
var _victim_hold := Vector2.ZERO
var _bites_left := 0
var _hunt_move: AttackData
var _bite_move: AttackData
var _bite_end_move: AttackData
var _frenzy_time := 0.0


func _ready() -> void:
	# 尾巴畫在角色後面。要在 super() 之前建立,因為它會呼叫 _update_visual()
	_tails = KaguneTails.new()
	add_child(_tails)
	move_child(_tails, 0)
	super()
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", KAGUNE_COLOR.lightened(0.45))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(240, 20)
	_status_label.position = Vector2(-120, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	_punch_move = AttackData.make(42, 0.06, 0.10, 0.17, Vector2(60, -70), Vector2(72, 38), Vector2(170, 0), 0.32, false, 120.0)
	# 尾巴追擊:判定時間依尾巴數量決定,每隔一小段時間重新算一次命中(見 _tick_attack)
	_tail_move = AttackData.make(TAIL_DAMAGE, 0.08, TAIL_INTERVAL, 0.16, Vector2(104, -62), Vector2(156, 52), Vector2(60, 0), 0.36, false, 30.0)
	_tail_move.color = Color(KAGUNE_COLOR, 0.75)
	_second_punch_move = AttackData.make(48, 0.07, 0.10, 0.19, Vector2(64, -64), Vector2(80, 42), Vector2(190, 0), 0.36, false, 130.0)
	# 踢擊:判定只在前 KICK_ACTIVE 秒,後面那段是往後跳(跳完才能接下一段)
	_kick_move = AttackData.make(KICK_DAMAGE, 0.09, KICK_ACTIVE + HOP_TIME, 0.20, Vector2(72, -58), Vector2(108, 56), Vector2(520, -380), 0.0, true, 150.0)
	_kick_link_move = AttackData.make(KICK_DAMAGE, 0.09, KICK_ACTIVE + HOP_TIME, 0.20, Vector2(72, -58), Vector2(108, 56), Vector2(260, 0), 0.60, false, 150.0)
	_pierce_move = AttackData.make(PIERCE_DAMAGE, 0.12, 0.10, 0.34, Vector2(190, -62), Vector2(330, 64), Vector2(760, -400), 0.0, true, 0.0)
	_pierce_move.tumbles = true
	_pierce_move.color = Color(KAGUNE_COLOR, 0.75)
	_refresh_chain()

	# 跳擊:撲過去的那一下可以防禦;壓制之後的尾巴擋不了
	_leap_move = AttackData.make(LEAP_DAMAGE, 0.07, 0.39, 0.16, Vector2(46, -46), Vector2(96, 96), Vector2(120, 0), 0.40, false, LEAP_SPEED.x)
	_leap_move.builds_energy = false
	_leap_move.color = Color(KAGUNE_COLOR, 0.75)
	_leap_tail_move = _technique(LEAP_TAIL_DAMAGE, Vector2.ZERO, 0.30)
	_leap_end_move = _technique(LEAP_TAIL_DAMAGE, Vector2(360, -560), 0.0, true)

	# 尾殺:傷害在出招時依尾巴數量決定
	_sweep_move = AttackData.make(SWEEP_DAMAGE, 0.18, 0.14, 0.38, Vector2(140, -78), Vector2(290, 170), Vector2(640, -520), 0.0, true, 60.0)
	_sweep_move.builds_energy = false
	_sweep_move.color = Color(KAGUNE_COLOR, 0.75)

	# 獵殺本能:衝過去抓人的那一下可以防禦;咬住之後擋不了,也不受連段上限限制
	_hunt_move = _technique(HUNT_DAMAGE, Vector2.ZERO, 0.40)
	_hunt_move.unblockable = false
	_bite_move = _technique(BITE_DAMAGE, Vector2.ZERO, 0.30)
	_bite_move.ignores_combo_limit = true
	_bite_end_move = _technique(BITE_FINAL_DAMAGE, Vector2(520, -480), 0.0, true)


## 不經過攻擊框、由招式自己判定命中的攻擊。耗氣招式,打中不回氣;預設擋不了。
func _technique(damage: int, knockback: Vector2, hitstun: float, launches: bool = false) -> AttackData:
	var move := AttackData.make(damage, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, knockback, hitstun, launches, 0.0)
	move.builds_energy = false
	move.unblockable = true
	return move


## 一場新的對戰:尾巴回到一條。(換回合不會歸零。)
func new_match() -> void:
	_cells = 0.0
	_refresh_chain()
	_emit_cells()


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_leap()
	_clear_hunt()
	_frenzy_time = 0.0
	_tails.relax()
	super(spawn_position, spawn_facing)
	_seen_health = health
	_seen_foe_health = opponent.health if opponent != null else 0
	_emit_cells()


func _physics_process(delta: float) -> void:
	super(delta)
	_track_damage()
	_frenzy_time = maxf(_frenzy_time - delta, 0.0)
	_tick_leap(delta)
	_tick_hunt(delta)
	if state != State.ATTACK:
		_tails.sweep(-1.0)
	_status_label.text = "亢奮 %d" % ceili(_frenzy_time) if in_frenzy() else ""


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(SWEEP_COST):
			_start_sweep()
			return true
		# 氣不夠:把這一下按鍵丟掉,免得放開「上」之後被當成招式一撲出去
		_buffer.erase("skill")
		_buffer.erase("skill2")
		return false
	if _skill1_pressed() and _spend_energy(LEAP_COST):
		_start_leap()
		return true
	return false


# ---------- 赫胞與尾巴 ----------

## 現在有幾條尾巴:開場一條,赫胞每滿一層多一條。
func tails() -> int:
	return 1 + mini(floori(_cells / CELLS_PER_LAYER), CELL_LAYERS)


func meter_info() -> Dictionary:
	return {"name": "赫胞", "color": KAGUNE_COLOR, "segments": CELL_LAYERS, "text": "赫子 ×%d" % tails()}


func _emit_cells() -> void:
	var limit := CELLS_PER_LAYER * CELL_LAYERS
	meter_changed.emit(_cells / limit, _cells >= limit)


## 打中對手、自己挨打都會累積赫胞:比較這一格和上一格雙方的血量。
func _track_damage() -> void:
	var gained := 0.0
	if opponent != null:
		gained += maxi(_seen_foe_health - opponent.health, 0) * CELLS_PER_DAMAGE_DEALT
		_seen_foe_health = opponent.health
	gained += maxi(_seen_health - health, 0) * CELLS_PER_DAMAGE_TAKEN
	_seen_health = health
	if gained > 0.0:
		_add_cells(gained)


func _add_cells(amount: float) -> void:
	var before := tails()
	_cells = clampf(_cells + amount, 0.0, CELLS_PER_LAYER * CELL_LAYERS)
	if tails() != before:
		_refresh_chain()
		if tails() > before and state != State.KO:
			# 多長出一條尾巴
			_power_burst(KAGUNE_COLOR)
			Sfx.play("powerup")
	_emit_cells()


## 依尾巴數量排出普通攻擊:四條尾巴時第四段只把人踢退,後面多一段穿刺。
func _refresh_chain() -> void:
	var full := tails() > CELL_LAYERS
	_ground_moves = [_punch_move, _tail_move, _second_punch_move, _kick_link_move if full else _kick_move]
	if full:
		_ground_moves.append(_pierce_move)


## 對手的胸口在哪裡(以自己的腳底為原點、面向為正):尾巴要刺向那裡。
func _foe_point() -> Vector2:
	if opponent == null:
		return TAIL_REACH
	var offset := opponent.global_position - global_position
	return Vector2(offset.x * facing, offset.y) + CHEST


# ---------- 亢奮 ----------

func in_frenzy() -> bool:
	return _frenzy_time > 0.0


func move_speed() -> float:
	return MOVE_SPEED * (FRENZY_SCALE if in_frenzy() else 1.0)


## 亢奮期間所有攻擊的傷害提升。
func _effective_move(move: AttackData) -> AttackData:
	if not in_frenzy() or move.damage <= 0:
		return move
	var boosted: AttackData = move.duplicate()
	boosted.damage = int(round(move.damage * FRENZY_SCALE))
	return boosted


## 用不走攻擊框的招式打對手(套用亢奮的加成),回傳實際造成多少傷害。
func _strike(move: AttackData) -> int:
	var before := opponent.health
	opponent.take_hit(_effective_move(move), self)
	return maxi(before - opponent.health, 0)


# ---------- 普通攻擊 ----------

func _start_attack(move: AttackData, combo_step: int) -> void:
	if move == _tail_move:
		_tail_hits = tails()
		_tail_beat = -1
		_tail_move.active = TAIL_INTERVAL * _tail_hits
	super(move, combo_step)


func _tick_attack(delta: float) -> void:
	if _move == _tail_move:
		# 尾巴一條接一條刺出去,每一下各算一次命中
		var beat := floori((_state_time - _move.startup) / TAIL_INTERVAL)
		if beat != _tail_beat and beat >= 0 and beat < _tail_hits:
			_tail_beat = beat
			_hit_targets.clear()
			_tails.stab(beat, TAIL_REACH + Vector2(0, (beat % 2) * 22.0 - 11.0), 0.03)
			Sfx.play("slash")
	elif _move == _kick_move or _move == _kick_link_move:
		# 踢完之後往後跳開
		var hop_from := _move.startup + KICK_ACTIVE
		if _state_time >= hop_from and _state_time < hop_from + HOP_TIME:
			velocity.x = -facing * HOP_SPEED
	elif _move == _sweep_move:
		# 尾巴從背後甩到身前,甩到最前面的時候正好是判定的時間
		var from := _move.startup * 0.5
		var until := _move.startup + _move.active
		if _state_time < from or _state_time > until + 0.12:
			_tails.sweep(-1.0)  # 還沒甩出去,或已經掃完收回背後
		else:
			_tails.sweep(clampf((_state_time - from) / (until - from), 0.0, 1.0))
	super(delta)
	if _leap_hit and state == State.ATTACK and _move == _leap_move:
		_begin_leap_tails()


func _show_slash() -> void:
	if _move == _tail_move:
		return  # 尾巴自己就是軌跡
	if _move == _pierce_move:
		_tails.stab_all(PIERCE_REACH, 0.12)
		Sfx.play("slash")
		return
	if _move == _sweep_move:
		# 一大片紅色的弧光
		_spawn_effect("slash", global_position, _bright(KAGUNE_COLOR, 1.5), 1.35, facing < 0, 0.0, true)
		Sfx.play("slash")
		return
	super()


func _check_hits() -> void:
	# 踢擊的後半段是往後跳,沒有判定
	if (_move == _kick_move or _move == _kick_link_move) and _state_time > _move.startup + KICK_ACTIVE:
		return
	if opponent != null:
		_health_before_hit = opponent.health
	super()


func _on_attack_hit(target: Fighter, move: AttackData) -> void:
	if move == _leap_move and target == opponent and target.health < _health_before_hit and target.state != State.GUARD:
		_leap_hit = true


# ---------- 招式一:跳擊 ----------

func _start_leap() -> void:
	_clear_leap()
	_start_attack(_leap_move, SPECIAL_STEP)
	velocity.y = LEAP_SPEED.y
	_attack_anim = "leap"
	_callout("跳擊", KAGUNE_COLOR)


## 撲中了:壓住對手,自己落到地上,接著尾巴一條一條刺下去。
func _begin_leap_tails() -> void:
	_leap_hit = false
	if opponent == null or opponent.state == State.KO:
		return
	var count := tails()
	opponent.pin(LEAP_PIN + LEAP_TAIL_INTERVAL * count)
	if opponent.state != State.STUNNED:
		return
	_set_hitbox(false)
	velocity = Vector2(0.0, 700.0)
	_leap_active = true
	_leap_left = count
	_leap_time = LEAP_PIN * 0.6
	# 追擊的節奏由 _tick_leap 自己推進,施法時間先設成放不完
	_start_cast(10.0, INF, Callable(), "leap_tails")


func _tick_leap(delta: float) -> void:
	if not _leap_active:
		return
	if state != State.CAST:
		_clear_leap()  # 被打斷,或整招結束
		return
	velocity.x = 0.0
	if opponent == null or opponent.is_invulnerable():
		_finish_leap()
		return
	_leap_time -= delta
	if _leap_time > 0.0:
		return
	var index := tails() - _leap_left
	_leap_left -= 1
	_leap_time = LEAP_TAIL_INTERVAL
	_tails.stab(clampi(index, 0, KaguneTails.MAX_TAILS - 1), _foe_point(), 0.04)
	Sfx.play("slash")
	# 最後一條尾巴把人挑飛
	_strike(_leap_end_move if _leap_left <= 0 else _leap_tail_move)
	if _leap_left <= 0:
		_finish_leap()


func _finish_leap() -> void:
	_leap_active = false
	_cast_duration = _state_time + LEAP_RECOVERY


func _clear_leap() -> void:
	_leap_hit = false
	_leap_active = false


# ---------- 招式二:尾殺 ----------

func _start_sweep() -> void:
	_sweep_move.damage = SWEEP_DAMAGE + SWEEP_DAMAGE_PER_TAIL * tails()
	_start_attack(_sweep_move, SPECIAL_STEP)
	_attack_anim = "sweep"
	_callout("尾殺", KAGUNE_COLOR)


# ---------- 大招:獵殺本能 ----------

func _start_super() -> void:
	_clear_hunt()
	_hunt = Hunt.READY
	_callout("獵殺本能", KAGUNE_COLOR, "special")
	_start_cast(10.0, HUNT_START, _release_hunt, "hunt_ready")


func _release_hunt() -> void:
	if _hunt != Hunt.READY:
		return
	_hunt = Hunt.DASH
	_hunt_time = HUNT_TIME
	_hunt_from = global_position.x
	_hunt_to = clampf(global_position.x + facing * HUNT_DISTANCE, arena_min_x, arena_max_x)
	_cast_anim = "hunt"
	_anim_restart = true
	Sfx.play("dash")


func _tick_hunt(delta: float) -> void:
	if _hunt == Hunt.NONE:
		return
	if state != State.CAST:
		_clear_hunt()  # 被打斷,或整招結束
		return
	match _hunt:
		Hunt.DASH:
			_hunt_time -= delta
			var progress := 1.0 - clampf(_hunt_time / HUNT_TIME, 0.0, 1.0)
			var next_x := lerpf(_hunt_from, _hunt_to, progress)
			velocity = Vector2.ZERO
			# 先判定、再移動:抓到的那一刻人還在對手面前,對手面向他防禦就擋得住
			if _hunt_catches(global_position.x, next_x):
				_hunt_grab()
				return
			_leave_ghost()
			_spawn_dust(global_position, 2, 0.6)
			global_position.x = next_x
			if _hunt_time <= 0.0:
				_recover_hunt(HUNT_MISS_RECOVERY)
		Hunt.BITE:
			velocity = Vector2.ZERO
			global_position = _hunt_hold
			if opponent == null or opponent.is_invulnerable():
				_end_bite()  # 咬到一半對手就倒了
				return
			opponent.velocity = Vector2.ZERO
			opponent.global_position = _victim_hold
			_hunt_time -= delta
			if _hunt_time > 0.0:
				return
			_hunt_time = BITE_INTERVAL
			_bites_left -= 1
			_bite(_bite_end_move if _bites_left <= 0 else _bite_move)
			if _bites_left <= 0:
				_end_bite()


## 這一格要經過的路段(from_x 到 to_x)上有沒有對手。
func _hunt_catches(from_x: float, to_x: float) -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	if absf(opponent.global_position.y - global_position.y) > HUNT_HEIGHT:
		return false
	var x := opponent.global_position.x
	return x >= minf(from_x, to_x) - HUNT_REACH and x <= maxf(from_x, to_x) + HUNT_REACH


## 衝到對手面前:沒被防住就撲上去咬住,被防住就停在他面前。
func _hunt_grab() -> void:
	var dealt := _strike(_hunt_move)
	var landed := dealt > 0 and opponent.state != State.GUARD
	var side := signf(opponent.global_position.x - global_position.x)
	if side == 0.0:
		side = facing
	global_position.x = clampf(opponent.global_position.x - side * HUNT_GAP, arena_min_x, arena_max_x)
	facing = int(side)
	if not landed or opponent.state == State.KO:
		_recover_hunt(HUNT_MISS_RECOVERY)
		return
	_feed(dealt)
	opponent.pin(BITE_INTERVAL * (BITE_COUNT + 2))
	if opponent.state != State.STUNNED:
		_recover_hunt(HUNT_MISS_RECOVERY)
		return
	_hunt = Hunt.BITE
	_hunt_time = BITE_INTERVAL
	_bites_left = BITE_COUNT + 1  # 最後一口把人甩出去
	_hunt_hold = global_position
	_victim_hold = opponent.global_position
	_cast_anim = "bite1"
	_anim_restart = true
	screen_shake.emit(6.0)


func _bite(move: AttackData) -> void:
	_cast_anim = "bite2" if _bites_left % 2 == 0 else "bite1"
	_anim_restart = true
	Sfx.play("rika_claw")
	var neck := opponent.global_position + Vector2(-facing * 8.0, -82.0)
	_spawn_effect("cut", neck, _bright(KAGUNE_COLOR, 1.6), 0.8, randf() < 0.5, randf_range(-0.6, 0.6))
	_feed(_strike(move))


## 把造成的傷害的一部分回復成自己的血量。
func _feed(dealt: int) -> void:
	if dealt > 0 and state != State.KO:
		_set_health(health + int(round(dealt * HUNT_HEAL)))


## 咬完:進入亢奮。
func _end_bite() -> void:
	_frenzy_time = FRENZY_TIME
	_power_burst(KAGUNE_COLOR, 1.0)
	_callout("亢奮", KAGUNE_COLOR, "powerup")
	_cast_anim = "cast"
	_anim_restart = true
	_recover_hunt(HUNT_RECOVERY)


func _recover_hunt(time: float) -> void:
	_hunt = Hunt.RECOVER
	_cast_duration = _state_time + time


func _clear_hunt() -> void:
	_hunt = Hunt.NONE


## 在原地留下一個淡掉的紅色殘影(目前這一格的樣子)。
func _leave_ghost() -> void:
	var ghost := _copy_of_self(_sprite.animation, _sprite.frame) if _has_sprite else null
	if ghost == null:
		return
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(2.2, 0.6, 0.7, 0.5)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


# ---------- 電腦操作 ----------

## 跳擊:對手要在撲得到的距離內。
func ai_skill_range() -> float:
	return LEAP_RANGE if energy >= LEAP_COST and not ai_saving_energy() else 0.0


func ai_skill2_ready() -> bool:
	return energy >= SWEEP_COST


## 尾殺:對手要在尾巴掃得到的範圍內。
func ai_skill2_range() -> float:
	return 270.0


## 平常有氣就用在跳擊與尾殺上,只有少數回合會存氣。
func _ai_save_chance() -> float:
	return 0.3


## 決定存氣的回合先不放招式,存到 3 格放獵殺本能。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and energy < super_cost()


## 氣夠了、對手在衝得到的地方、又沒在防禦,就想撲上去。
func ai_wants_super() -> bool:
	if energy < super_cost() or _hunt != Hunt.NONE or opponent == null or opponent.is_invulnerable():
		return false
	var ahead := (opponent.global_position.x - global_position.x) * facing
	return ahead > 0.0 and ahead < HUNT_DISTANCE - 40.0 and opponent.state != State.GUARD \
			and absf(opponent.global_position.y - global_position.y) < HUNT_HEIGHT


# ---------- 顯示 ----------

func _update_visual() -> void:
	super()
	_tails.count = tails()
	_tails.facing = facing
	_tails.glow = 1.0 if in_frenzy() else 0.0
	# 被打飛、倒在地上的時候尾巴收起來
	_tails.visible = state not in [State.LAUNCHED, State.DOWN, State.GETUP, State.KO]
	_tails.modulate.a = 0.5 if state == State.TELEPORT else 1.0
	if in_frenzy() and _has_sprite and state != State.KO:
		_sprite.modulate = _sprite.modulate * Color(1.3, 0.82, 0.82)
