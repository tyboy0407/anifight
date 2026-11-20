class_name TojiFighter
extends Fighter
## 以伏黑甚爾為藍本的角色。沒有咒力,靠肉體與咒具戰鬥。
##
## 被動「天與咒縛」
##   沒有氣格(在 toji.tscn 設定 max_energy = 0),所有招式都不耗氣,改用冷卻時間限制。
##   移動速度是一般角色的 150%,並且會緩慢回復生命。
##   幽步冷卻 3 秒、受擊脫出冷卻 10 秒;沒有通用大招(special)。
## 武器
##   手上拿的武器決定普通攻擊的連段,開場拿狼牙刀。
##   狼牙刀:大砍刀。揮砍兩刀後迴身踢,把對手踢向遠方。
##   天逆牟:短刀。連砍四刀後下旋踢,並瞬間閃到對手身後(可以接著追打)。
## 招式
##   招式一(skill):換成狼牙刀;已經拿著狼牙刀就向前旋轉揮砍。
##   招式二(上 + skill):換成天逆牟;已經拿著天逆牟就瞬身到對手身後揮出一刀,這一刀破防。
##   大招(下 + special)「咒縛狀態」:10 秒內所有攻擊都破防、傷害 2 倍、
##   移動速度提升到 200%、受到的傷害減半。結束後冷卻 30 秒。

enum Weapon { CLEAVER, DAGGER }  # 狼牙刀、天逆牟

const WEAPON_NAMES: Array[String] = ["狼牙刀", "天逆牟"]
const CLEAVER_COLOR := Color(0.75, 0.8, 0.9)
const DAGGER_COLOR := Color(0.95, 0.85, 0.5)
const BIND_COLOR := Color(1.0, 0.35, 0.3)
const AFTERIMAGE_COLOR := Color(0.7, 0.72, 0.8)  # 瞬身殘影:沒有咒力,只是快到留下的灰白人影
const DAGGER_SPRITES := "res://assets/characters/toji_dagger"

# 天與咒縛
const SPEED_SCALE := 1.5
const REGEN_PER_SECOND := 1.5     # 每秒回復的生命(些微:150 秒約回 225)
const TELEPORT_COOLDOWN := 3.0
const ESCAPE_COOLDOWN := 10.0
# 換武器、武器招式
const SWAP_TIME := 0.16           # 換武器的動作時間
const SPIN_COOLDOWN := 3.5        # 狼牙刀旋轉揮砍
const SPIN_RANGE := 260.0         # 電腦:對手在這個距離內才用旋轉揮砍
const BACKSTAB_COOLDOWN := 6.0    # 天逆牟瞬身背刺
const BACKSTAB_OFFSET := 70.0     # 瞬身後離對手多遠
const BACKSTAB_RANGE := 700.0     # 電腦:對手在這個距離內才用背刺
# 咒縛狀態
const BIND_CAST := 0.40
const BIND_RELEASE := 0.20
const BIND_DURATION := 10.0
const BIND_COOLDOWN := 30.0       # 狀態結束後才開始算
const BIND_DAMAGE_SCALE := 2.0
const BIND_SPEED_SCALE := 2.0
const BIND_DAMAGE_TAKEN := 0.5
# 電腦:每隔一段時間重新決定想拿哪把武器
const AI_WEAPON_TIME_MIN := 5.0
const AI_WEAPON_TIME_MAX := 10.0

var weapon := Weapon.CLEAVER

var _chains: Array = [[], []]            # 各武器的地面連段
var _air_moves: Array[AttackData] = []   # 各武器的空中攻擊
var _spin_move: AttackData
var _backstab_move: AttackData
var _sweep_move: AttackData              # 天逆牟連段最後的下旋踢
var _weapon_frames: Array = [null, null] # 各武器的角色素材

var _teleport_cooldown := 0.0
var _escape_cooldown := 0.0
var _spin_cooldown := 0.0
var _backstab_cooldown := 0.0
var _bind_time := 0.0
var _bind_cooldown := 0.0
var _bound_moves: Dictionary = {}  # 原招式 -> 咒縛狀態用的複本(傷害 2 倍、破防)
var _regen_bank := 0.0             # 回血還沒滿 1 點的零頭
var _ai_weapon := Weapon.CLEAVER
var _ai_weapon_time := 0.0

var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	if _has_sprite:
		_weapon_frames[Weapon.CLEAVER] = _sprite.sprite_frames
		var dagger := SpriteSheetLoader.load_character(DAGGER_SPRITES)
		_weapon_frames[Weapon.DAGGER] = dagger.frames if not dagger.is_empty() else _sprite.sprite_frames
	_status_label = Label.new()
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.size = Vector2(360, 20)
	_status_label.position = Vector2(-180, -BODY_SIZE.y - 66)
	add_child(_status_label)


func _build_moves() -> void:
	super()
	# 狼牙刀:又重又遠的兩刀,接迴身踢把對手踢遠
	# (傷害數值經過電腦對戰統計調整過:他不耗氣、跑得快又會回血,單下傷害要比別人低)
	var kick := AttackData.make(66, 0.12, 0.12, 0.32, Vector2(78, -60), Vector2(116, 60), Vector2(1050, -520), 0.0, true, 240.0)
	_chains[Weapon.CLEAVER] = [
		_blade(38, 0.09, 0.22, Vector2(88, -62), Vector2(136, 66), 190.0, 0.34, 140.0, CLEAVER_COLOR),
		_blade(44, 0.10, 0.24, Vector2(90, -60), Vector2(140, 70), 210.0, 0.36, 150.0, CLEAVER_COLOR),
		kick,
	]
	# 天逆牟:又快又短的四刀,接下旋踢並閃到對手身後
	_sweep_move = AttackData.make(38, 0.08, 0.10, 0.22, Vector2(62, -24), Vector2(104, 44), Vector2(40, -430), 0.0, true, 130.0)
	_chains[Weapon.DAGGER] = [
		_blade(18, 0.04, 0.14, Vector2(62, -64), Vector2(86, 44), 120.0, 0.30, 110.0, DAGGER_COLOR),
		_blade(18, 0.04, 0.14, Vector2(64, -58), Vector2(86, 44), 120.0, 0.30, 110.0, DAGGER_COLOR),
		_blade(21, 0.05, 0.14, Vector2(64, -66), Vector2(88, 46), 130.0, 0.30, 110.0, DAGGER_COLOR),
		_blade(21, 0.05, 0.16, Vector2(66, -60), Vector2(90, 46), 130.0, 0.32, 120.0, DAGGER_COLOR),
		_sweep_move,
	]
	_air_moves = [
		AttackData.make(55, 0.06, 0.20, 0.10, Vector2(62, -40), Vector2(124, 74), Vector2(280, 0), 0.32, false, 0.0),
		AttackData.make(38, 0.04, 0.20, 0.10, Vector2(52, -40), Vector2(90, 60), Vector2(220, 0), 0.30, false, 0.0),
	]
	_air_moves[Weapon.CLEAVER].color = CLEAVER_COLOR
	_air_moves[Weapon.DAGGER].color = DAGGER_COLOR

	# 狼牙刀旋轉揮砍:邊前衝邊轉,前後都掃得到
	_spin_move = AttackData.make(70, 0.10, 0.18, 0.30, Vector2(40, -60), Vector2(240, 96), Vector2(420, -520), 0.0, true, 560.0)
	_spin_move.color = CLEAVER_COLOR
	# 天逆牟背刺:破防,打出硬直讓自己接連段
	_backstab_move = AttackData.make(52, 0.07, 0.10, 0.26, Vector2(62, -62), Vector2(112, 56), Vector2(240, 0), 0.36, false, 0.0)
	_backstab_move.unblockable = true
	_backstab_move.color = DAGGER_COLOR
	_equip(weapon)


## 拿刀的角色:揮擊畫成刀光。
func _slash_effect() -> String:
	return "slash"


func _blade(damage: int, startup: float, recovery: float, offset: Vector2, hit_size: Vector2,
		push: float, hitstun: float, lunge: float, color: Color) -> AttackData:
	var move := AttackData.make(damage, startup, 0.10, recovery, offset, hit_size, Vector2(push, 0), hitstun, false, lunge)
	move.color = Color(color, 0.75)
	return move


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_teleport_cooldown = 0.0
	_escape_cooldown = 0.0
	_spin_cooldown = 0.0
	_backstab_cooldown = 0.0
	_bind_time = 0.0
	_bind_cooldown = 0.0
	_regen_bank = 0.0
	_ai_weapon_time = 0.0
	_equip(Weapon.CLEAVER)
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_teleport_cooldown = maxf(_teleport_cooldown - delta, 0.0)
	_escape_cooldown = maxf(_escape_cooldown - delta, 0.0)
	_spin_cooldown = maxf(_spin_cooldown - delta, 0.0)
	_backstab_cooldown = maxf(_backstab_cooldown - delta, 0.0)
	_tick_bind(delta)
	_tick_regen(delta)
	_tick_ai_weapon(delta)
	_update_status()


# ---------- 天與咒縛 ----------

func move_speed() -> float:
	return MOVE_SPEED * (BIND_SPEED_SCALE if bound() else SPEED_SCALE)


## 幽步與脫出不耗氣,冷卻好了才放得出來。
func teleport_cost() -> int:
	return 0 if _teleport_cooldown <= 0.0 else max_energy + 1


func escape_cost() -> int:
	return 0 if _escape_cooldown <= 0.0 else max_energy + 1


func _start_teleport() -> void:
	super()
	_teleport_cooldown = TELEPORT_COOLDOWN


func _start_burst() -> void:
	super()
	_escape_cooldown = ESCAPE_COOLDOWN


## 緩慢回血。回合結束後(不能操作時)與被打倒時不回。
func _tick_regen(delta: float) -> void:
	if state == State.KO or not input_enabled or health >= max_health:
		_regen_bank = 0.0
		return
	_regen_bank += REGEN_PER_SECOND * delta
	var whole := int(_regen_bank)
	if whole > 0:
		_regen_bank -= whole
		_set_health(health + whole)


# ---------- 武器 ----------

## 換上指定武器的連段、空中攻擊與外觀(不含換武器的動作)。
func _equip(new_weapon: Weapon) -> void:
	weapon = new_weapon
	if _air_moves.is_empty():
		return  # 招式還沒建立
	_ground_moves.assign(_chains[weapon])
	_air_move = _air_moves[weapon]
	if _has_sprite and _weapon_frames[weapon] != null and _sprite.sprite_frames != _weapon_frames[weapon]:
		_sprite.sprite_frames = _weapon_frames[weapon]
		_current_anim = ""
		_anim_restart = true


func _swap_weapon(new_weapon: Weapon) -> void:
	_equip(new_weapon)
	var weapon_color := CLEAVER_COLOR if new_weapon == Weapon.CLEAVER else DAGGER_COLOR
	_callout(WEAPON_NAMES[new_weapon], weapon_color, "weapon_swap")
	# 手上一閃:新武器出鞘
	_spawn_effect("flash", global_position + Vector2(facing * 34.0, -62.0), _bright(weapon_color), 1.4, false, 0.0, true)
	# 只是一個短暫的換武器動作,沒有要在途中觸發的事
	_start_cast(SWAP_TIME, SWAP_TIME + 1.0, func() -> void: pass, "guard")


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if weapon != Weapon.DAGGER:
			_swap_weapon(Weapon.DAGGER)
			return true
		if _backstab_cooldown <= 0.0 and opponent != null:
			_start_backstab()
			return true
		return false
	if _skill1_pressed():
		if weapon != Weapon.CLEAVER:
			_swap_weapon(Weapon.CLEAVER)
			return true
		if _spin_cooldown <= 0.0:
			_spin_cooldown = SPIN_COOLDOWN
			_start_attack(_spin_move, SPECIAL_STEP)
			return true
	return false


## 天逆牟:瞬身到對手身後揮出破防的一刀。
func _start_backstab() -> void:
	_backstab_cooldown = BACKSTAB_COOLDOWN
	_afterimage()
	_move_behind_opponent(BACKSTAB_OFFSET)
	_appear_effect(AFTERIMAGE_COLOR)
	Sfx.play("teleport")
	_start_attack(_backstab_move, SPECIAL_STEP)


## 天逆牟連段的每一刀輪流用兩種揮砍動作,最後的下旋踢用踢擊動作。
func _start_attack(move: AttackData, combo_step: int) -> void:
	super(move, combo_step)
	if weapon == Weapon.DAGGER and combo_step >= 0 and combo_step < _ground_moves.size():
		_attack_anim = "attack3" if move == _sweep_move else ("attack1" if combo_step % 2 == 0 else "attack2")


## 下旋踢踢到對手(被防禦住也算)就閃到對手身後。
func _on_attack_hit(target: Fighter, move: AttackData) -> void:
	if move != _sweep_move or target != opponent:
		return
	_afterimage()
	_move_behind_opponent(TELEPORT_OFFSET)
	_appear_effect(AFTERIMAGE_COLOR)
	Sfx.play("teleport")
	# 人換邊了,攻擊框也要跟著翻到新的正面
	var offset := Vector2(move.hitbox_offset.x * facing, move.hitbox_offset.y)
	_hit_shape.position = offset
	_hit_visual.position = offset - move.hitbox_size / 2.0


## 瞬身前留在原地的殘影:一道散成光點的人影。沒有點陣特效時是一塊深色的色塊。
func _afterimage() -> void:
	if _vanish_effect(AFTERIMAGE_COLOR):
		return
	var ghost := _spawn_rect(BODY_SIZE, Color(0.1, 0.1, 0.14, 0.6), global_position + Vector2(0, -BODY_SIZE.y / 2.0), 0)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)


# ---------- 咒縛狀態 ----------

func bound() -> bool:
	return _bind_time > 0.0


## 不耗氣;狀態中或冷卻中放不出來。
func super_cost() -> int:
	return 0 if _bind_cooldown <= 0.0 and not bound() else max_energy + 1


func _start_super() -> void:
	_start_cast(BIND_CAST, BIND_RELEASE, _enter_bind)


func _enter_bind() -> void:
	_bind_time = BIND_DURATION
	_callout("咒縛狀態", BIND_COLOR, "bind")
	_power_burst(BIND_COLOR)
	screen_shake.emit(8.0)


func _tick_bind(delta: float) -> void:
	if bound():
		_bind_time = maxf(_bind_time - delta, 0.0)
		if not bound():
			_bind_cooldown = BIND_COOLDOWN
	else:
		_bind_cooldown = maxf(_bind_cooldown - delta, 0.0)


## 咒縛狀態中:所有攻擊傷害 2 倍,而且破防。
func _effective_move(move: AttackData) -> AttackData:
	if not bound():
		return move
	if not _bound_moves.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * BIND_DAMAGE_SCALE))
		copy.unblockable = true
		_bound_moves[move] = copy
	return _bound_moves[move]


func _damage_taken_scale() -> float:
	return BIND_DAMAGE_TAKEN if bound() else 1.0


# ---------- 電腦操作 ----------

## 電腦每隔幾秒重新決定想拿哪把武器,不然會一直換來換去。
func _tick_ai_weapon(delta: float) -> void:
	_ai_weapon_time -= delta
	if _ai_weapon_time <= 0.0:
		_ai_weapon_time = randf_range(AI_WEAPON_TIME_MIN, AI_WEAPON_TIME_MAX)
		_ai_weapon = Weapon.CLEAVER if randf() < 0.5 else Weapon.DAGGER


## 招式一:拿著狼牙刀時是旋轉揮砍(要夠近、冷卻好);拿著天逆牟時是換回狼牙刀(想換才按)。
func ai_skill_range() -> float:
	if weapon == Weapon.CLEAVER:
		return SPIN_RANGE if _spin_cooldown <= 0.0 else 0.0
	return INF if _ai_weapon == Weapon.CLEAVER else 0.0


## 招式二:拿著天逆牟時是瞬身背刺;拿著狼牙刀時是換成天逆牟(想換才按)。
func ai_skill2_range() -> float:
	if weapon == Weapon.DAGGER:
		return BACKSTAB_RANGE if _backstab_cooldown <= 0.0 else 0.0
	return INF if _ai_weapon == Weapon.DAGGER else 0.0


func ai_skill2_ready() -> bool:
	return true


## 冷卻好了就想進入咒縛狀態;施法會被打斷,所以挑對手打不到的時候。
func ai_wants_super() -> bool:
	return super_cost() == 0


func ai_super_is_safe() -> bool:
	return _ai_opponent_cannot_interrupt(300.0)


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = [WEAPON_NAMES[weapon]]
	if bound():
		parts.append("咒縛 %d" % ceili(_bind_time))
	elif _bind_cooldown > 0.0:
		parts.append("咒縛冷卻 %d" % ceili(_bind_cooldown))
	_status_label.text = "   ".join(parts)
	var color := BIND_COLOR if bound() else (CLEAVER_COLOR if weapon == Weapon.CLEAVER else DAGGER_COLOR)
	_status_label.add_theme_color_override("font_color", color.lightened(0.3))


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	if _has_sprite and bound() and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH, State.CAST]:
		_sprite.modulate = Color(1.45, 0.8, 0.75)
