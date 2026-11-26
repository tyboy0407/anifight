class_name CurseGiantFighter
extends Fighter
## 巨型咒靈(只在故事模式出現的對手)。用低級咒靈的圖放大來畫,身體也比一般角色大。
##
## 動作慢、打得重:普攻是一記橫掃接一記把人打飛的重砸。
## 招式一「震地」(不耗氣,有冷卻):高舉雙手再砸向地面,衝擊沿著地面往兩邊傳出去,
##   站在地上的人會被震飛;跳起來或防禦就躲得掉。

const SIZE := 1.7                       # 比一般角色大幾倍
const TINT := Color(1.0, 0.74, 0.76)    # 把灰紫色的咒靈染得偏暗紅
const HURT_SIZE := Vector2(90, 184)
const SLOW := 0.72                      # 移動速度的倍率
const QUAKE_COLOR := Color(0.8, 0.45, 0.4)
const QUAKE_CAST := 1.05
const QUAKE_RELEASE := 0.7
const QUAKE_REACH := 400.0              # 往左右各傳多遠
const QUAKE_HEIGHT := 70.0              # 離地這麼高以內才會被震到
const QUAKE_DAMAGE := 110
const QUAKE_COOLDOWN := 7.0
const QUAKE_FIRST := 3.0                # 回合開始後多久才會第一次震地

var _quake_move: AttackData
var _quake_cooldown := 0.0


func _ready() -> void:
	super()
	var hurt := $Hurtbox/CollisionShape2D as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = HURT_SIZE
	hurt.shape = shape
	hurt.position = Vector2(0, -HURT_SIZE.y / 2.0)
	if _has_sprite:
		_sprite.scale *= SIZE
		_sprite.self_modulate = TINT
	# 頭上的玩家標籤移到變大的頭頂上
	for child in get_children():
		if child is Label and (child as Label).text.ends_with("P"):
			(child as Label).position.y = -BODY_SIZE.y * SIZE - 30.0


func _build_moves() -> void:
	super()
	_ground_moves = [
		# 橫掃:範圍很大,但舉手的時間很長
		AttackData.make(75, 0.26, 0.12, 0.36, Vector2(110, -96), Vector2(180, 150), Vector2(280, 0), 0.4, false, 90.0),
		# 重砸:把人打飛
		AttackData.make(125, 0.34, 0.12, 0.48, Vector2(118, -74), Vector2(200, 170), Vector2(440, -640), 0.0, true, 110.0),
	]
	_air_move = AttackData.make(80, 0.12, 0.22, 0.14, Vector2(70, -70), Vector2(150, 130), Vector2(300, 0), 0.34, false, 0.0)
	_special_move.hitbox_offset = Vector2(130, -90)
	_special_move.hitbox_size = Vector2(230, 170)
	_special_move.startup = 0.3
	_super_move.hitbox_offset = Vector2(170, -110)
	_super_move.hitbox_size = Vector2(360, 230)
	_super_move.startup = 0.4
	_quake_move = AttackData.make(QUAKE_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(300, -720), 0.0, true, 0.0)
	_quake_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	super(spawn_position, spawn_facing)
	_quake_cooldown = QUAKE_FIRST


func _physics_process(delta: float) -> void:
	super(delta)
	if input_enabled:
		_quake_cooldown = maxf(_quake_cooldown - delta, 0.0)


func move_speed() -> float:
	return MOVE_SPEED * SLOW


func _try_character_actions() -> bool:
	if not _skill1_pressed() or _quake_cooldown > 0.0:
		return false
	_quake_cooldown = QUAKE_COOLDOWN
	_callout("震地", QUAKE_COLOR)
	Sfx.play("cannon_charge")
	_start_cast(QUAKE_CAST, QUAKE_RELEASE, _release_quake, "burst")
	return true


## 雙手砸在地上:衝擊沿著地面往兩邊傳。
func _release_quake() -> void:
	var floor_y := global_position.y
	screen_shake.emit(16.0)
	Sfx.play("wall_crash")
	_spawn_effect("landing", global_position, Color.WHITE, 1.6)
	# 沿著地面一路揚起的沙土:離得越遠越晚冒出來
	for step in range(1, 6):
		var offset := QUAKE_REACH * step / 5.0
		var timer := get_tree().create_timer(0.04 * step, false, true)
		timer.timeout.connect(_quake_dust.bind(floor_y, offset))
	if opponent == null or opponent.global_position.y < floor_y - QUAKE_HEIGHT:
		return  # 跳起來躲掉了
	if _rect_hits_opponent(Vector2(global_position.x, floor_y - QUAKE_HEIGHT / 2.0), Vector2(QUAKE_REACH * 2.0, QUAKE_HEIGHT)):
		_land(_quake_move)


func _quake_dust(floor_y: float, offset: float) -> void:
	if not is_inside_tree():
		return
	for side: float in [-1.0, 1.0]:
		var x := global_position.x + side * offset
		if x >= arena_min_x - 40.0 and x <= arena_max_x + 40.0:
			_spawn_dust(Vector2(x, floor_y), 6, 1.3)


## 給電腦對手的提示:震地放得出來的時候,對手在範圍內才放。
func ai_skill_range() -> float:
	return QUAKE_REACH * 0.85 if _quake_cooldown <= 0.0 else 0.0


func ai_skill2_ready() -> bool:
	return false
