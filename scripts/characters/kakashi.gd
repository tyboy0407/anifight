class_name KakashiFighter
extends Fighter
## 以旗木卡卡西為藍本的角色。氣量上限是 5 格(在 kakashi.tscn 設定 max_energy = 500)。
##
## 普通攻擊(按三下)
##   第一段:向前連揮兩拳(按一下就會打完兩拳)。
##   第二段:俯身下踢,把對手踢得短暫離地。
##   第三段:土遁.土流壁。雙手按地,在對手腳下升起土牆把人往上頂飛。
## 招式一「雷切」(1 格):短暫蓄力後往前刺出雷電。
## 招式二「水遁.水龍波」(2 格):原地結印 0.5 秒,身後凝聚的水龍往前撲去。
##   打中後的短時間內按普通攻擊:直接接第三段的土流壁把人頂飛,再用「雷流引」電擊浮空的對手。
## 大招「寫輪眼」(氣量滿 3 格才能開,開的時候不扣氣):開著的時候氣量持續流失,
##   再按一次或氣量歸零就關閉。期間招式出手快 50%、傷害多 20%,而且對手每用一次招式就能拷貝(不耗氣)。
## 拷貝(計量條)
##   對手每用一次招式(招式一、招式二、超必殺)累積一格,滿 5 格後,卡卡西的招式一、招式二
##   變成對手的招式一、招式二;用掉其中一個(耗 1 格氣)計量條就清空。
##   做法:場上另外放一個對手那個角色的「替身」(Fighter.puppet_of),外觀套卡卡西的圖、平常藏著不動。
##   拷貝出手時由替身實際施放那一招,卡卡西本人躲起來跟著替身移動,放完再換回來;
##   之後替身留在卡卡西身上繼續跑一小段時間,讓那一招留下的東西(式神、強化狀態…)照常運作。

const LIGHTNING_COLOR := Color(0.62, 0.86, 1.0)
const WATER_COLOR := Color(0.35, 0.68, 1.0)
const EARTH_COLORS: Array[Color] = [Color(0.5, 0.38, 0.26), Color(0.4, 0.3, 0.2), Color(0.62, 0.5, 0.34)]
const SHARINGAN_COLOR := Color(1.0, 0.25, 0.28)
const FX_DIR := "res://assets/sasuke_fx"  # 雷電的點陣圖和佐助共用
const SHARINGAN_SPRITES := "res://assets/characters/kakashi_sharingan"
const CHEST := Vector2(0, -62)

# 普通攻擊
const WALL_DAMAGE := 95
const WALL_REACH := 340.0          # 連段裡的土流壁:對手在身前這個距離內才會長在他腳下
const WALL_NEAR := 150.0           # 對手不在範圍內時,土牆長在身前這麼遠的地方
const WALL_HALF_WIDTH := 72.0
const WALL_HEIGHT := 230.0         # 土牆頂得到多高(對手離地這麼高以內都會被頂飛)
const WALL_KNOCKBACK := Vector2(40, -900)
# 雷切
const RAIKIRI_COST := 100
const RAIKIRI_CHARGE := 0.32
const RAIKIRI_RECOVERY := 0.42
const RAIKIRI_DAMAGE := 185
const RAIKIRI_LUNGE := 880.0
const RAIKIRI_WINDOW := 0.14       # 刺出去之後判定持續多久
const RAIKIRI_SIZE := Vector2(250, 84)
const SPEAR_ART_LENGTH := 440.0 * 3.0  # 雷光的圖在畫面上的長度(和佐助的雷槍同一張圖)
# 水遁.水龍波
const DRAGON_COST := 200
const DRAGON_SEAL := 0.5
const DRAGON_RECOVERY := 0.36
const DRAGON_DAMAGE := 150
const DRAGON_SPEED := 1250.0
const DRAGON_RANGE := 900.0
const DRAGON_BACK := 110.0         # 水龍在身後多遠的地方凝聚
const DRAGON_SIZE := Vector2(120, 120)
const DRAGON_FOLLOW := 0.9         # 水龍打中後,多久以內按普通攻擊可以接土流壁
# 雷流引
const RAITON_HITS := 6
const RAITON_INTERVAL := 0.13
const RAITON_DAMAGE := 24
const RAITON_FINAL_DAMAGE := 60
const RAITON_RECOVERY := 0.3
# 寫輪眼
const SHARINGAN_NEED := 300        # 要有這麼多氣才能開(不會扣)
const SHARINGAN_DRAIN := 25.0      # 開著的時候每秒流失的氣量(4 秒一格)
const SHARINGAN_HASTE := 1.5
const SHARINGAN_DAMAGE := 1.2
const SHARINGAN_CAST := 0.36
# 拷貝
const COPY_NEED := 5               # 對手用幾次招式才拷貝得到
const COPY_COST := 100
const COPY_PUPPET_ENERGY := 300    # 替身出手前補到多少氣(夠放任何一招,又不會讓「氣量很多才變化」的招式變化)
const COPY_FAIL_TIME := 0.25       # 這麼久了替身還沒放出招式(距離不對、冷卻中…)就當作沒放成,氣量退回
const COPY_FOLLOW_MAX := 0.6       # 招式放完後還有「接著按普攻」的追擊時,最多再等這麼久
const COPY_MAX_TIME := 9.0
const COPY_LINGER := 12.0          # 招式放完後,替身繼續留在身上跑多久
const COPY_COLOR := Color(0.95, 0.3, 0.34)
const AI_RAIKIRI_CHANCE := 0.45    # 電腦:距離夠的時候,每次判斷有多少機率放雷切(不然氣全花在這一招上)

var _jab_move: AttackData
var _cross_move: AttackData
var _low_kick_move: AttackData
var _wall_move: AttackData         # 只管動作的時間;命中由 _raise_wall 自己算
var _wall_hit_move: AttackData
var _kick_queued := false          # 第一拳還沒打完就又按了一下:第二拳打完直接接下踢
var _wall_raised := false
var _wall_follow := false          # 這一次的土流壁是水龍波之後的追擊:不限距離,頂飛後接雷流引

var _raikiri_move: AttackData
var _raikiri_node: Node2D
var _raikiri_time := 0.0           # 雷切刺出去之後,判定還剩幾秒

var _dragon_move: AttackData
var _dragon_node: WaterDragon      # 正在飛的水龍
var _dragon_forming: WaterDragon   # 結印時在身後凝聚的水龍
var _dragon_x := 0.0
var _dragon_y := 0.0
var _dragon_dir := 1
var _dragon_left := 0.0            # 還能飛多遠;0 以下就是沒有水龍在飛
var _dragon_hit := false
var _follow_time := 0.0

var _raiton_move: AttackData
var _raiton_final_move: AttackData
var _raiton_active := false
var _raiton_left := 0
var _raiton_time := 0.0

var _sharingan := false
var _drain_bank := 0.0
var _plain_damage_scale := 1.0
var _plain_frames: SpriteFrames
var _sharingan_frames: SpriteFrames

var _puppet: Fighter
var _copy_count := 0
var _copy_ready := false
var _seen_uses := 0                # 上一格看到對手用過幾次招式
var _copying := false              # 替身正在替自己出招
var _copy_which := 0               # 這次拷貝的是招式一(1)還是招式二(2)
var _copy_time := 0.0
var _copy_paid := 0
var _copy_fired := false
var _copy_follow := 0.0
var _puppet_uses := 0
var _linger := 0.0                 # 替身還要在身上留多久
var _routing := false              # 正在把挨的這一下交給替身先處理
var _boosted: Dictionary = {}      # 普攻招式 -> 套用替身的強化後的複本
var _boost_scale := 1.0

var _foe_skills: Array[String] = []  # 對手招式一、招式二的名字(顯示用)
var _sharingan_allowed := true     # 故事模式的某些關卡不讓他開寫輪眼
var _status_label: Label


func _ready() -> void:
	super()
	_preload_sheet(FX_DIR)
	if _has_sprite:
		_plain_frames = _sprite.sprite_frames
		var red := SpriteSheetLoader.load_character(SHARINGAN_SPRITES)
		_sharingan_frames = red.frames if not red.is_empty() else _plain_frames
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COPY_COLOR.lightened(0.35))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(360, 20)
	_status_label.position = Vector2(-180, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	_jab_move = AttackData.make(34, 0.05, 0.08, 0.10, Vector2(62, -70), Vector2(74, 38), Vector2(140, 0), 0.30, false, 110.0)
	_cross_move = AttackData.make(40, 0.05, 0.08, 0.16, Vector2(66, -66), Vector2(80, 40), Vector2(170, 0), 0.34, false, 110.0)
	# 下踢:把人踢得稍微離地(算擊飛,但飛得很低,馬上就落地)
	_low_kick_move = AttackData.make(58, 0.09, 0.10, 0.22, Vector2(74, -24), Vector2(124, 48), Vector2(70, -470), 0.0, true, 120.0)
	_wall_move = AttackData.make(0, 0.18, 0.06, 0.34, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, false, 0.0)
	_wall_hit_move = AttackData.make(WALL_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, WALL_KNOCKBACK, 0.0, true, 0.0)
	_ground_moves = [_jab_move, _cross_move, _low_kick_move, _wall_move]

	_raikiri_move = AttackData.make(RAIKIRI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(680, -360), 0.0, true, 0.0)
	_raikiri_move.builds_energy = false
	_dragon_move = AttackData.make(DRAGON_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(90, 0), 0.75, false, 0.0)
	_dragon_move.builds_energy = false
	# 雷流引:電的是浮在空中的人,擋不了
	_raiton_move = AttackData.make(RAITON_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.30, false, 0.0)
	_raiton_move.builds_energy = false
	_raiton_move.unblockable = true
	_raiton_final_move = AttackData.make(RAITON_FINAL_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(420, -520), 0.0, true, 0.0)
	_raiton_final_move.builds_energy = false
	_raiton_final_move.unblockable = true


## 故事模式:這一關可以指定他不開寫輪眼({"sharingan": false})。
func apply_story(setup: Dictionary) -> void:
	super(setup)
	_sharingan_allowed = bool(setup.get("sharingan", true))


func action_available(key: String) -> bool:
	return _sharingan_allowed or key != "super"


## 一場新的對戰:準備好對手那個角色的替身。
func new_match() -> void:
	_make_puppet()


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_raikiri()
	_clear_dragon()
	_clear_raiton()
	_follow_time = 0.0
	_kick_queued = false
	_close_sharingan(false)
	_copying = false
	_linger = 0.0
	_copy_count = 0
	_copy_ready = false
	if _has_sprite:
		_sprite.visible = true
	super(spawn_position, spawn_facing)
	_make_puppet()
	if _puppet != null:
		_puppet.reset(spawn_position, spawn_facing)
		_puppet.input_enabled = false
		_puppet.visible = false
	_seen_uses = opponent.skill_uses if opponent != null else 0
	_emit_copy()


func _exit_tree() -> void:
	for node: Node in [_raikiri_node, _dragon_node, _dragon_forming]:
		if is_instance_valid(node):
			node.queue_free()


func _physics_process(delta: float) -> void:
	_watch_opponent()
	if _copying:
		# 替身正在出招:自己不動,整個人跟著替身
		_tick_energy_seal(delta)
		_tick_copy(delta)
	else:
		super(delta)
		_tick_linger(delta)
	_follow_time = maxf(_follow_time - delta, 0.0)
	_tick_raikiri(delta)
	_tick_dragon(delta)
	_tick_raiton(delta)
	_tick_sharingan(delta)
	_update_status()


# ---------- 招式的入口 ----------

func _try_character_actions() -> bool:
	if _super_pressed():
		if _sharingan:
			_start_cast(SHARINGAN_CAST * 0.6, SHARINGAN_CAST * 0.3, _close_sharingan.bind(true), "sharingan")
			return true
		if energy >= SHARINGAN_NEED and _sharingan_allowed:
			_start_cast(SHARINGAN_CAST, SHARINGAN_CAST * 0.55, _open_sharingan, "sharingan")
			return true
		# 氣不夠:把這一下按鍵丟掉,免得放開「下」之後被當成通用大招
		_buffer.erase("special")
		_buffer.erase("super")
		return false
	var which := 2 if _skill2_pressed() else (1 if _skill1_pressed() else 0)
	if which == 0:
		return false
	if _copy_ready and _puppet != null:
		# 拷貝好了:兩個招式都換成對手的,用掉一個計量條就清空
		var cost := _copy_cost()
		if energy < cost:
			return false
		_start_copy(which, cost)
		return true
	if which == 2:
		if _spend_energy(DRAGON_COST):
			_start_dragon()
			return true
		# 氣不夠:把這一下按鍵丟掉,免得放開「上」之後被當成招式一
		_buffer.erase("skill")
		_buffer.erase("skill2")
		return false
	if _spend_energy(RAIKIRI_COST):
		_start_raikiri()
		return true
	return false


## 寫輪眼不是用「耗氣」的方式放的(見 _try_character_actions);這個數字只給電腦對手判斷用:
## 沒開的時候氣量到 3 格可以開,開著的時候不要再按(會關掉)。
func super_cost() -> int:
	return max_energy + 1 if _sharingan or not _sharingan_allowed else SHARINGAN_NEED


## 招式出手的速度:寫輪眼期間快 50%。
func _haste() -> float:
	return SHARINGAN_HASTE if _sharingan else 1.0


# ---------- 普通攻擊 ----------

func _start_attack(move: AttackData, combo_step: int) -> void:
	if move == _jab_move or move == _low_kick_move:
		_kick_queued = false
	if move == _wall_move:
		_wall_raised = false
	super(move, combo_step)
	if move == _wall_move:
		Sfx.play("land")


func _tick_attack(delta: float) -> void:
	if _move == _jab_move:
		# 按一下就會打完兩拳;第一拳途中又按的那一下留給下踢
		if _pressed("attack"):
			_kick_queued = true
		_combo_queued = true
	elif _move == _cross_move and _kick_queued:
		_combo_queued = true
	elif _move == _wall_move and not _wall_raised and _state_time >= _move.startup:
		_wall_raised = true
		_raise_wall()
		if state != State.ATTACK:
			return  # 頂飛之後直接接了雷流引
	super(delta)


## 兩拳和下踢是拳腳的弧線;土流壁沒有揮擊的軌跡。
func _show_slash() -> void:
	if _move != _wall_move:
		super()


## 土遁.土流壁:土牆從對手腳下升起,把人往上頂飛。
func _raise_wall() -> void:
	var follow := _wall_follow
	_wall_follow = false
	var wall_x := global_position.x + facing * WALL_NEAR
	if opponent != null:
		var ahead := (opponent.global_position.x - global_position.x) * facing
		if follow or (ahead >= 0.0 and ahead <= WALL_REACH):
			wall_x = opponent.global_position.x
	wall_x = clampf(wall_x, arena_min_x, arena_max_x)
	var floor_y := global_position.y
	_spawn_wall(Vector2(wall_x, floor_y))
	screen_shake.emit(5.0)
	Sfx.play("wall_crash")
	if not _rect_hits_opponent(Vector2(wall_x, floor_y - WALL_HEIGHT / 2.0), Vector2(WALL_HALF_WIDTH * 2.0, WALL_HEIGHT)):
		return
	var launched := _land(_boost(_wall_hit_move))
	if launched and follow and opponent.state == State.LAUNCHED:
		_start_raiton()


## 土牆的樣子:幾根高低不一的石柱從地面竄出來,停一下再碎掉沉回地裡。
func _spawn_wall(at: Vector2) -> void:
	var wall := Node2D.new()
	wall.z_index = 1
	get_parent().add_child(wall)
	wall.global_position = at
	var columns := [[-58.0, 120.0], [-30.0, 180.0], [-4.0, 215.0], [24.0, 170.0], [48.0, 110.0]]
	for index in columns.size():
		var column: Array = columns[index]
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = EARTH_COLORS[index % EARTH_COLORS.size()]
		rect.size = Vector2(30, column[1])
		rect.position = Vector2(column[0], -column[1])
		wall.add_child(rect)
		# 石柱頂端的受光面,和側面的一道陰影
		var top := ColorRect.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.color = EARTH_COLORS[2].lightened(0.18)
		top.size = Vector2(30, 8)
		rect.add_child(top)
		var shade := ColorRect.new()
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.color = Color(0, 0, 0, 0.22)
		shade.size = Vector2(8, column[1])
		shade.position = Vector2(22, 0)
		rect.add_child(shade)
	wall.scale = Vector2(1.0, 0.05)
	var tween := wall.create_tween()
	tween.tween_property(wall, "scale:y", 1.0, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.3)
	tween.tween_property(wall, "scale:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(wall, "modulate:a", 0.0, 0.25)
	tween.tween_callback(wall.queue_free)
	_spawn_dust(at + Vector2(-40, 0), 6, 1.2)
	_spawn_dust(at + Vector2(40, 0), 6, 1.2)


## 替身身上有「強化普攻」的狀態時(例如拷貝了「我也可以!」),自己的普攻套用它。
func _effective_move(move: AttackData) -> AttackData:
	return _boost(move) if _ground_moves.has(move) or move == _air_move else move


func _boost(move: AttackData) -> AttackData:
	var scale_factor := _puppet.normal_attack_scale() if _puppet != null and _linger > 0.0 else 1.0
	if is_equal_approx(scale_factor, 1.0):
		return move
	if not is_equal_approx(scale_factor, _boost_scale):
		_boost_scale = scale_factor
		_boosted.clear()
	if not _boosted.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * scale_factor))
		_boosted[move] = copy
	return _boosted[move]


## 水龍波打中後的短時間內按普通攻擊:直接接土流壁(不限距離),頂飛後接雷流引。
func _tick_ground() -> void:
	if _follow_time > 0.0 and is_on_floor() and _pressed("attack"):
		_follow_time = 0.0
		_face_opponent()
		_wall_follow = true
		_start_attack(_wall_move, 3)
		return
	super()


# ---------- 招式一:雷切 ----------

func _start_raikiri() -> void:
	_clear_raikiri()
	_face_opponent()
	_raikiri_node = _sheet_prop(FX_DIR, "chidori", Vector2(36, 36), LIGHTNING_COLOR)
	_callout("雷切", LIGHTNING_COLOR, "chidori")
	var haste := _haste()
	_start_cast((RAIKIRI_CHARGE + RAIKIRI_RECOVERY) / haste, RAIKIRI_CHARGE / haste, _release_raikiri, "raikiri")
	_place_raikiri()


## 蓄好了:整個人往前刺出去,雷電貫穿身前的一段距離。
func _release_raikiri() -> void:
	velocity.x = facing * RAIKIRI_LUNGE
	_raikiri_time = RAIKIRI_WINDOW
	Sfx.play("thunder")
	screen_shake.emit(5.0)
	# 從手上往前射出去的一道雷光,長度就是判定的範圍
	var from := global_position + Vector2(facing * 40.0, CHEST.y - 6.0)
	_spawn_bolt(from, from + Vector2(facing * (RAIKIRI_SIZE.x + 20.0), 0.0), 0.2)


func _tick_raikiri(delta: float) -> void:
	if not is_instance_valid(_raikiri_node) and _raikiri_time <= 0.0:
		return
	if state != State.CAST or _copying:
		_clear_raikiri()  # 被打斷,或整招結束
		return
	_place_raikiri()
	if _raikiri_time <= 0.0:
		return
	_raikiri_time -= delta
	var center := global_position + Vector2(facing * (RAIKIRI_SIZE.x / 2.0 + 10.0), CHEST.y)
	if _rect_hits_opponent(center, RAIKIRI_SIZE):
		_raikiri_time = 0.0
		velocity.x = 0.0
		if _land(_raikiri_move):
			_spawn_sheet_effect(FX_DIR, "zap", opponent.global_position + CHEST)
			screen_shake.emit(9.0)


## 手上的雷電:蓄力時在腰側越聚越大,刺出去之後在伸直的手上。
func _place_raikiri() -> void:
	if not is_instance_valid(_raikiri_node):
		return
	var charging := not _cast_fired
	var hand := Vector2(-6.0, -34.0) if charging else Vector2(58.0, -70.0)
	_raikiri_node.global_position = global_position + Vector2(hand.x * facing, hand.y)
	var grown := clampf(_state_time / maxf(_cast_release, 0.01), 0.0, 1.0)
	_raikiri_node.scale = Vector2.ONE * (lerpf(0.3, 0.9, grown) if charging else 1.1)


func _clear_raikiri() -> void:
	_raikiri_time = 0.0
	if is_instance_valid(_raikiri_node):
		_raikiri_node.queue_free()
	_raikiri_node = null


# ---------- 招式二:水遁.水龍波 ----------

func _start_dragon() -> void:
	_face_opponent()
	_callout("水遁.水龍波", WATER_COLOR)
	Sfx.play("blue")
	var haste := _haste()
	_start_cast((DRAGON_SEAL + DRAGON_RECOVERY) / haste, DRAGON_SEAL / haste, _release_dragon, "water")
	# 結印的時候,水在身後慢慢凝聚成龍
	if is_instance_valid(_dragon_forming):
		_dragon_forming.queue_free()
	_dragon_forming = WaterDragon.new()
	_dragon_forming.facing = facing
	_dragon_forming.grown = 0.0
	_dragon_forming.fade = 0.75
	get_parent().add_child(_dragon_forming)
	_dragon_forming.global_position = global_position + Vector2(-facing * DRAGON_BACK, CHEST.y - 30.0)


func _release_dragon() -> void:
	if is_instance_valid(_dragon_node):
		_dragon_node.queue_free()
	_dragon_node = _dragon_forming if is_instance_valid(_dragon_forming) else WaterDragon.new()
	if _dragon_node.get_parent() == null:
		get_parent().add_child(_dragon_node)
	_dragon_forming = null
	_dragon_node.grown = 1.0
	_dragon_node.fade = 1.0
	_dragon_node.scale = Vector2.ONE * 1.4
	_dragon_node.facing = facing
	_dragon_dir = facing
	_dragon_x = global_position.x - facing * DRAGON_BACK
	_dragon_y = global_position.y + CHEST.y
	_dragon_left = DRAGON_RANGE + DRAGON_BACK
	_dragon_hit = false
	_dragon_node.global_position = Vector2(_dragon_x, _dragon_y)
	Sfx.play("cannon_fire")
	screen_shake.emit(4.0)


## 水龍放出去之後自己往前飛(卡卡西被打也不會消失),打到人只算一次。
func _tick_dragon(delta: float) -> void:
	if is_instance_valid(_dragon_forming):
		if state != State.CAST or _cast_anim != "water":
			# 結印被打斷:還沒成形的水散掉
			_dragon_forming.queue_free()
			_dragon_forming = null
		else:
			_dragon_forming.grown = clampf(_state_time / maxf(_cast_release, 0.01), 0.0, 1.0)
	if _dragon_left <= 0.0:
		return
	var step := DRAGON_SPEED * delta
	_dragon_x += _dragon_dir * step
	_dragon_left -= step
	if is_instance_valid(_dragon_node):
		_dragon_node.global_position = Vector2(_dragon_x, _dragon_y)
	if not _dragon_hit and _rect_hits_opponent(Vector2(_dragon_x, _dragon_y), DRAGON_SIZE):
		_dragon_hit = true
		if _land(_dragon_move):
			_follow_time = DRAGON_FOLLOW
			# 打中了:自己的收招馬上結束,才來得及追擊
			if state == State.CAST and _cast_anim == "water" and _cast_fired:
				_cast_duration = minf(_cast_duration, _state_time + 0.05)
	if _dragon_left <= 0.0:
		_fade_dragon()


func _fade_dragon() -> void:
	_dragon_left = 0.0
	if not is_instance_valid(_dragon_node):
		return
	var node := _dragon_node
	_dragon_node = null
	var tween := node.create_tween()
	tween.tween_property(node, "fade", 0.0, 0.2)
	tween.tween_callback(node.queue_free)


func _clear_dragon() -> void:
	_dragon_left = 0.0
	for node: Node in [_dragon_node, _dragon_forming]:
		if is_instance_valid(node):
			node.queue_free()
	_dragon_node = null
	_dragon_forming = null


# ---------- 雷流引 ----------

## 對手被土流壁頂到空中:舉手放電,一下一下電他,最後一下把人打飛。
func _start_raiton() -> void:
	_raiton_active = true
	_raiton_left = RAITON_HITS
	_raiton_time = 0.16
	_callout("雷流引", LIGHTNING_COLOR, "thunder")
	# 節奏由 _tick_raiton 自己推進,施法時間先設成放不完
	_start_cast(10.0, INF, Callable(), "raiton")


func _tick_raiton(delta: float) -> void:
	if not _raiton_active:
		return
	if state != State.CAST:
		_clear_raiton()  # 被打斷,或整招結束
		return
	velocity.x = 0.0
	if opponent == null or opponent.is_invulnerable():
		_finish_raiton()
		return
	_raiton_time -= delta
	if _raiton_time > 0.0:
		return
	_raiton_time = RAITON_INTERVAL
	_raiton_left -= 1
	var target := opponent.global_position + CHEST
	_spawn_bolt(global_position + Vector2(facing * 46.0, -112.0), target)
	_spawn_sheet_effect(FX_DIR, "zap", target)
	Sfx.play("chidori" if _raiton_left % 2 == 0 else "hit_light")
	opponent.take_hit(_raiton_final_move if _raiton_left <= 0 else _raiton_move, self)
	if _raiton_left <= 0:
		screen_shake.emit(8.0)
		_finish_raiton()


func _finish_raiton() -> void:
	_raiton_active = false
	_cast_duration = _state_time + RAITON_RECOVERY


func _clear_raiton() -> void:
	_raiton_active = false


## 一道從 from 射到 to 的雷光,亮一下就淡掉。
func _spawn_bolt(from: Vector2, to: Vector2, time: float = 0.12) -> void:
	var bolt := _sheet_prop(FX_DIR, "spear", Vector2(from.distance_to(to), 10), LIGHTNING_COLOR)
	bolt.global_position = from
	bolt.rotation = (to - from).angle()
	if bolt.get_child(0) is AnimatedSprite2D:
		bolt.scale = Vector2(from.distance_to(to) / SPEAR_ART_LENGTH, 0.8)
	else:
		bolt.get_child(0).position.x = 0.0  # 沒有圖的時候是一條色塊:從起點往前畫
	var tween := bolt.create_tween()
	tween.tween_interval(time * 0.4)
	tween.tween_property(bolt, "modulate:a", 0.0, time * 0.6)
	tween.tween_callback(bolt.queue_free)


# ---------- 大招:寫輪眼 ----------

func in_sharingan() -> bool:
	return _sharingan


func _open_sharingan() -> void:
	if _sharingan:
		return
	_sharingan = true
	_drain_bank = 0.0
	_plain_damage_scale = damage_scale
	damage_scale = _plain_damage_scale * SHARINGAN_DAMAGE
	_callout("寫輪眼", SHARINGAN_COLOR, "powerup")
	_power_burst(SHARINGAN_COLOR)
	_swap_frames(_sharingan_frames)
	_check_copy()


## announce 為 false 時不演出(回合重置時用)。
func _close_sharingan(announce: bool) -> void:
	if not _sharingan:
		return
	_sharingan = false
	damage_scale = _plain_damage_scale
	_swap_frames(_plain_frames)
	if announce:
		Sfx.play("weapon_swap")
	# 沒開寫輪眼的話,要累積滿 5 次才算拷貝完成
	_copy_ready = _copy_count >= _copy_need()
	_emit_copy()


func _swap_frames(frames: SpriteFrames) -> void:
	if _has_sprite and frames != null and _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames
		_current_anim = ""
		_anim_restart = true


## 寫輪眼開著的時候氣量持續流失,歸零就自動關閉。
func _tick_sharingan(delta: float) -> void:
	if not _sharingan or state == State.KO:
		return
	_drain_bank += SHARINGAN_DRAIN * delta
	var whole := int(_drain_bank)
	if whole > 0:
		_drain_bank -= whole
		_set_energy(energy - whole)
	if energy <= 0:
		_close_sharingan(true)


# ---------- 拷貝 ----------

func _copy_need() -> int:
	return 1 if _sharingan else COPY_NEED


func _copy_cost() -> int:
	return 0 if _sharingan else COPY_COST


func meter_info() -> Dictionary:
	if puppet_of != null:
		return {}
	return {"name": "拷貝", "color": COPY_COLOR, "segments": COPY_NEED}


func _emit_copy() -> void:
	if puppet_of == null:
		meter_changed.emit(1.0 if _copy_ready else float(_copy_count) / COPY_NEED, _copy_ready)


## 每一格看看對手有沒有又用了招式;累積夠了就拷貝完成。
func _watch_opponent() -> void:
	if opponent == null or puppet_of != null:
		return
	var uses := opponent.skill_uses
	if uses > _seen_uses and not _copy_ready and state != State.KO:
		_copy_count = mini(_copy_count + uses - _seen_uses, COPY_NEED)
		_check_copy()
		_emit_copy()
	_seen_uses = uses


func _check_copy() -> void:
	if _copy_ready or _copy_count < _copy_need() or _puppet == null:
		return
	_copy_ready = true
	_callout("拷貝完成", COPY_COLOR, "parry")
	_emit_copy()


## 觸控按鈕的提示:拷貝好了,招式的按鈕會發光。
func skill1_empowered() -> bool:
	return _copy_ready


## 對手那個角色的替身:和對手同一個場景,外觀套自己的圖,平常藏著不動。替身自己不會再有替身。
func _make_puppet() -> void:
	if is_instance_valid(_puppet) or puppet_of != null or opponent == null or not is_inside_tree():
		return
	var path := opponent.scene_file_path
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var puppet := (load(path) as PackedScene).instantiate() as Fighter
	if puppet == null:
		return
	puppet.name = "%sPuppet" % name
	puppet.puppet_of = self
	puppet.player_id = player_id
	puppet.body_color = body_color
	puppet.sprite_dir = sprite_dir
	puppet.pad_driven = true
	puppet.direction_combos = false
	get_parent().add_child(puppet)
	# 故事模式:對手還沒領悟的招式,替身也不會(拷貝不到對手自己都還不會的東西)
	if GameState.in_story():
		var setups: Array = GameState.story_fight.get("setups", [])
		var index := opponent.player_id - 1
		if index >= 0 and index < setups.size():
			puppet.apply_story(setups[index])
	puppet.opponent = opponent
	puppet.set_physics_process(false)  # 由 _tick_copy / _tick_linger 推進
	puppet.visible = false
	puppet.input_enabled = false
	puppet.screen_shake.connect(func(strength: float) -> void: screen_shake.emit(strength))
	puppet.new_match()
	puppet.reset(global_position, facing)
	_puppet = puppet
	_read_foe_skills()


## 對手的招式一 / 招式二叫什麼(選角資料裡的名字,去掉後面括號裡的說明)。
func _foe_skill_name(which: int) -> String:
	return _foe_skills[which - 1] if _foe_skills.size() >= which else ""


func _read_foe_skills() -> void:
	_foe_skills.clear()
	var path := opponent.scene_file_path if opponent != null else ""
	for index in GameState.CHARACTERS.size():
		for form in GameState.form_count(index):
			var info := GameState.form_info(index, form)
			if str(info.scene) != path:
				continue
			for text: String in (info.skills as Array).slice(0, 2):
				_foe_skills.append(text.get_slice("(", 0).get_slice("/", 0))
			return


## 用拷貝來的招式:換成替身上場,由它放對手的招式一(which 是 1)或招式二(2)。
func _start_copy(which: int, cost: int) -> void:
	_spend_energy(cost)
	_clear_raikiri()
	_set_hitbox(false)
	var puppet := _puppet
	if puppet.state not in [State.IDLE, State.MOVE]:
		puppet.reset(global_position, facing)  # 上一次拷貝留下的東西還沒結束:清掉重來
	_copying = true
	_copy_which = which
	_copy_paid = cost
	_copy_time = 0.0
	_copy_fired = false
	_copy_follow = 0.0
	_linger = 0.0
	_face_opponent()
	puppet.global_position = global_position
	# 先讓替身踩穩地面:它還不知道自己站在地上的話,第一格會被當成在空中,出招的按鍵就丟了
	puppet.velocity = Vector2(0.0, 60.0)
	puppet.move_and_slide()
	puppet.velocity = Vector2.ZERO
	puppet.facing = facing
	puppet.input_enabled = true
	puppet.set_pad(0)
	puppet._set_energy(mini(COPY_PUPPET_ENERGY, puppet.max_energy))
	puppet.prepare_copy(which)
	_puppet_uses = puppet.skill_uses
	puppet.visible = true
	if _has_sprite:
		_sprite.visible = false
	# 自己在旁人眼中是「正在施法」;實際的動作都在替身身上
	_start_cast(COPY_MAX_TIME + 1.0, INF, Callable(), "seal")
	velocity = Vector2.ZERO
	_copy_callout()


## 「拷貝」的浮字:比招式名稱的浮字小、位置高一點,才不會和替身喊的招式名稱疊在一起。
func _copy_callout() -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "拷貝"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", COPY_COLOR.lightened(0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.size = Vector2(200, 40)
	label.position = global_position + Vector2(-100, -250)
	label.z_index = 2
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)


## 這一格要交給替身的按鍵:一開始替它按下那一招;之後玩家還按著就繼續按著(要蓄力的招式),
## 普通攻擊和左右也照樣轉過去(有些招式放完可以接著按普攻追擊)。
func _copy_pad() -> int:
	if not input_enabled:
		return 0
	var mask := 0
	var up := direction_combos and _down("up")
	var held := (_down("skill") and not up) if _copy_which == 1 else (_down("skill2") or (_down("skill") and up))
	if _copy_time < 0.05 or held:
		mask |= GameState.net_bit("skill" if _copy_which == 1 else "skill2")
	for action_name: String in ["attack", "left", "right"]:
		if _down(action_name):
			mask |= GameState.net_bit(action_name)
	return mask


func _tick_copy(delta: float) -> void:
	var puppet := _puppet
	puppet.arena_min_x = arena_min_x
	puppet.arena_max_x = arena_max_x
	puppet.input_enabled = input_enabled
	puppet.set_pad(_copy_pad())
	puppet._physics_process(delta)
	if not _copying:
		return  # 替身這一格害自己被打斷了(例如打在格檔上被反擊),見 _break_copy
	puppet.global_position.x = clampf(puppet.global_position.x, arena_min_x, arena_max_x)
	global_position = puppet.global_position
	facing = puppet.facing
	velocity = Vector2.ZERO
	_state_time += delta
	_copy_time += delta
	if not _copy_fired:
		if puppet.skill_uses > _puppet_uses:
			# 招式放出來了:計量條清空,重新累積
			_copy_fired = true
			_copy_count = 0
			_copy_ready = false
			_emit_copy()
		elif _copy_time >= COPY_FAIL_TIME:
			# 沒放成(距離不對、對方的招式還在冷卻…):氣量退回,拷貝留著
			_set_energy(energy + _copy_paid)
			_end_copy(false)
		return
	var neutral := puppet.state in [State.IDLE, State.MOVE, State.GUARD]
	if neutral and puppet.ai_wants_attack() and _copy_follow < COPY_FOLLOW_MAX:
		_copy_follow += delta  # 這一招放完可以接著按普攻追擊:再等一下
	elif neutral or _copy_time >= COPY_MAX_TIME:
		_end_copy(true)


## 換回自己。lingers 為 true 時替身留在身上繼續跑一段時間,那一招留下的東西才會照常運作。
func _end_copy(lingers: bool) -> void:
	_copying = false
	var puppet := _puppet
	puppet.input_enabled = false
	puppet.set_pad(0)
	puppet.visible = false
	if _has_sprite:
		_sprite.visible = true
	velocity = Vector2.ZERO
	if lingers:
		_linger = COPY_LINGER
	else:
		_linger = 0.0
		puppet.reset(global_position, facing)
		puppet.input_enabled = false
	if state == State.CAST:
		_set_state(State.IDLE if puppet.is_on_floor() else State.JUMP, true)


## 拷貝的招式放到一半被打斷:替身收掉。
func _break_copy() -> void:
	if _copying:
		_end_copy(false)


## 替身留在身上的期間:跟著自己走,不出招,只讓它身上還在進行的東西繼續跑。
func _tick_linger(delta: float) -> void:
	if _linger <= 0.0 or _puppet == null:
		return
	var puppet := _puppet
	_linger -= delta
	if _linger <= 0.0 or state == State.KO:
		_linger = 0.0
		puppet.reset(global_position, facing)
		puppet.input_enabled = false
		return
	puppet.arena_min_x = arena_min_x
	puppet.arena_max_x = arena_max_x
	puppet.global_position = global_position
	puppet.velocity = Vector2.ZERO
	# 不替它按任何鍵;input_enabled 跟著自己,是因為有些角色用它判斷「回合是不是在進行中」(式神會不會出手…)
	puppet.input_enabled = input_enabled
	puppet.set_pad(0)
	puppet._physics_process(delta)


func _puppet_live() -> bool:
	return _puppet != null and (_copying or _linger > 0.0)


# ---------- 挨打 ----------
# 替身在場的時候,打到自己的攻擊先交給替身:它有自己的防禦手段(格檔、無下限…)就照它的規則擋;
# 它擋不下來,才會經由 puppet_was_hit / puppet_was_stunned 回到自己身上。

func take_hit(move: AttackData, attacker: Fighter) -> void:
	if _puppet_live() and not _routing:
		_routing = true
		_puppet.take_hit(move, attacker)
		_routing = false
		return
	_real_hit(move, attacker)


func puppet_was_hit(move: AttackData, attacker: Fighter) -> void:
	_real_hit(move, attacker)


func _real_hit(move: AttackData, attacker: Fighter) -> void:
	if is_invulnerable():
		return
	_break_copy()
	super.take_hit(move, attacker)


func stun(duration: float, damage: int = 0, damage_scale_taken: float = 1.0) -> void:
	if _puppet_live() and not _routing:
		_routing = true
		_puppet.stun(duration, damage, damage_scale_taken)
		_routing = false
		return
	puppet_was_stunned(duration, damage, damage_scale_taken)


func puppet_was_stunned(duration: float, damage: int, damage_scale_taken: float) -> void:
	if state in [State.KO, State.TELEPORT, State.BURST]:
		return
	_break_copy()
	super.stun(duration, damage, damage_scale_taken)


func pin(duration: float, sink: float = 0.0) -> void:
	if not is_invulnerable():
		_break_copy()
	super(duration, sink)


func stagger(duration: float) -> void:
	if not is_invulnerable() and state != State.LAUNCHED:
		_break_copy()
	super(duration)


func blown_away(source: Fighter) -> void:
	_break_copy()
	super(source)


## 替身出招的時候,無不無敵看替身(例如它正在瞬身)。
func is_invulnerable() -> bool:
	if _copying:
		return _puppet.is_invulnerable()
	return super()


func is_immovable() -> bool:
	if _puppet_live() and _puppet.is_immovable():
		return true
	return super()


# ---------- 電腦操作 ----------

## 拷貝好了就用對手招式的距離來判斷;否則是雷切的距離。
func ai_skill_range() -> float:
	if _copy_ready and _puppet != null:
		return _puppet.ai_skill_range() if energy >= _copy_cost() else 0.0
	if ai_saving_energy() or energy < RAIKIRI_COST or (_sharingan and energy < RAIKIRI_COST * 2):
		return 0.0
	return RAIKIRI_SIZE.x if randf() < AI_RAIKIRI_CHANCE else 0.0


func ai_skill2_ready() -> bool:
	if _copy_ready and _puppet != null:
		return energy >= _copy_cost()
	# 寫輪眼開著的時候氣就是時間,不拿兩格去換一條水龍
	return energy >= DRAGON_COST and not _sharingan and not ai_saving_energy()


func ai_skill2_range() -> float:
	if _copy_ready and _puppet != null:
		return _puppet.ai_skill2_range()
	return DRAGON_RANGE * 0.7


func ai_skill2_hold() -> float:
	if _copy_ready and _puppet != null:
		return _puppet.ai_skill2_hold()
	return 0.0


## 水龍波打中了:馬上按普攻接土流壁。替身出招時則看替身要不要追擊。
func ai_wants_attack() -> bool:
	if _copying:
		return _puppet.ai_wants_attack()
	return _follow_time > 0.0 and opponent != null and not opponent.is_invulnerable()


## 電腦操作時:決定存氣的回合先不放招式,存到 3 格開寫輪眼;開了之後才又開始用招式。
func ai_saving_energy() -> bool:
	return _sharingan_allowed and ai_saves_this_round and not _sharingan and energy < SHARINGAN_NEED


func ai_wants_super() -> bool:
	return _sharingan_allowed and not _sharingan and energy >= SHARINGAN_NEED


func ai_super_is_safe() -> bool:
	return _ai_opponent_cannot_interrupt(260.0)


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = []
	if _sharingan:
		parts.append("寫輪眼 %d" % ceili(energy / SHARINGAN_DRAIN))
	if _copy_ready:
		parts.append("拷貝:%s / %s" % [_foe_skill_name(1), _foe_skill_name(2)])
	_status_label.text = "   ".join(parts)


func _update_visual() -> void:
	super()
	# 寫輪眼開著:身上帶一點紅光
	if _has_sprite and _sharingan and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH, State.CAST]:
		_sprite.modulate = Color(1.18, 1.0, 1.0)
