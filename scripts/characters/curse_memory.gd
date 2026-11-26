class_name CurseMemoryFighter
extends Fighter
## 追憶咒靈(只在故事模式出現的對手):會讓人想起不好的回憶。用低級咒靈的圖染成蒼白的顏色。
##
## 招式一「追憶」(不耗氣,有冷卻):吐出一團黑霧往前飄。被打中的人陷入回憶(Fighter.haunt):
##   幾秒內放不出任何招式,畫面變暗,耳邊浮出不想記起的話。防禦或閃開就沒事。

const TINT := Color(0.72, 0.9, 1.2)     # 把灰紫色的咒靈染得蒼白偏藍
const FOG_COLOR := Color(0.36, 0.22, 0.6)
const FOG_CAST := 0.66
const FOG_RELEASE := 0.42
const FOG_SPEED := 430.0
const FOG_RANGE := 780.0
const FOG_SIZE := 96.0
const FOG_DAMAGE := 45
const FOG_COOLDOWN := 6.5
const FOG_FIRST := 2.5                  # 回合開始後多久才會第一次吐霧
const HAUNT_TIME := 5.0
const DIM_ALPHA := 0.5                  # 對手陷入回憶時畫面變多暗
const WHISPERS: Array[String] = ["……不要想起來", "對不起", "都是我的錯", "不要走", "……為什麼是你"]
const WHISPER_INTERVAL := 0.7

var _fog_move: AttackData
var _fog: ColorRect
var _fog_at := Vector2.ZERO
var _fog_dir := 1
var _fog_left := 0.0                    # 還能飄多遠;0 以下就是場上沒有黑霧
var _fog_cooldown := 0.0
var _dim: ColorRect
var _whisper_timer := 0.0
var _whisper_index := 0


func _ready() -> void:
	super()
	if _has_sprite:
		_sprite.self_modulate = TINT


func _build_moves() -> void:
	super()
	_fog_move = AttackData.make(FOG_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(60, 0), 0.4, false, 0.0)
	_fog_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_fog()
	super(spawn_position, spawn_facing)
	_fog_cooldown = FOG_FIRST


func _exit_tree() -> void:
	_clear_fog()
	if is_instance_valid(_dim):
		_dim.queue_free()


func _physics_process(delta: float) -> void:
	super(delta)
	if input_enabled:
		_fog_cooldown = maxf(_fog_cooldown - delta, 0.0)
	_tick_fog(delta)
	_tick_haunting(delta)


func _try_character_actions() -> bool:
	if not _skill1_pressed() or _fog_cooldown > 0.0:
		return false
	_fog_cooldown = FOG_COOLDOWN
	_face_opponent()
	_callout("追憶", FOG_COLOR, "domain_void")
	_start_cast(FOG_CAST, FOG_RELEASE, _release_fog)
	return true


func _release_fog() -> void:
	_clear_fog()
	_fog_dir = facing
	_fog_at = global_position + Vector2(facing * 60.0, -64.0)
	_fog_left = FOG_RANGE
	_fog = _spawn_rect(Vector2(FOG_SIZE, FOG_SIZE), FOG_COLOR, _fog_at, 3, "void")


## 黑霧放出去之後自己往前飄(咒靈被打也不會消失),碰到人只算一次。
func _tick_fog(delta: float) -> void:
	if _fog_left <= 0.0:
		return
	var step := FOG_SPEED * delta
	_fog_at.x += _fog_dir * step
	_fog_left -= step
	if is_instance_valid(_fog):
		_fog.position = _fog_at - _fog.size / 2.0
	if _rect_hits_opponent(_fog_at, Vector2(FOG_SIZE, FOG_SIZE) * 0.8):
		if _land(_fog_move):
			opponent.haunt(HAUNT_TIME)
			_whisper_timer = 0.0
		_spawn_effect("flash", _fog_at, _bright(FOG_COLOR), 0.9)
		_clear_fog()
	elif _fog_left <= 0.0:
		_clear_fog()


func _clear_fog() -> void:
	_fog_left = 0.0
	if is_instance_valid(_fog):
		_fog.queue_free()
	_fog = null


## 對手陷入回憶的期間:整個畫面暗下來,他身邊浮出一句一句不想記起的話。
func _tick_haunting(delta: float) -> void:
	var haunting := opponent != null and opponent.haunted() and opponent.state != State.KO
	if not haunting and not is_instance_valid(_dim):
		return
	if not is_instance_valid(_dim):
		_dim = ColorRect.new()
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.color = Color(0.05, 0.0, 0.12, 0.0)
		_dim.size = Vector2(6000, 4000)
		_dim.z_index = 40
		get_parent().add_child(_dim)
	_dim.position = _screen_center() - _dim.size / 2.0
	_dim.color.a = move_toward(_dim.color.a, DIM_ALPHA if haunting else 0.0, delta * 2.5)
	if not haunting:
		if _dim.color.a <= 0.0:
			_dim.queue_free()
			_dim = null
		return
	_whisper_timer -= delta
	if _whisper_timer <= 0.0:
		_whisper_timer = WHISPER_INTERVAL
		_whisper()


func _whisper() -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = WHISPERS[_whisper_index % WHISPERS.size()]
	_whisper_index += 1
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.8, 0.74, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	# 左右交錯地浮在他身邊
	var side := -1.0 if _whisper_index % 2 == 0 else 1.0
	label.position = opponent.global_position + Vector2(side * 90.0 - 60.0, -150.0 - (_whisper_index % 3) * 26.0)
	label.z_index = 41
	label.modulate.a = 0.0
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "modulate:a", 0.9, 0.25)
	tween.parallel().tween_property(label, "position:y", label.position.y - 36.0, 1.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


## 給電腦對手的提示:黑霧放得出來的時候,對手在飄得到的距離內才放。
func ai_skill_range() -> float:
	return FOG_RANGE * 0.8 if _fog_cooldown <= 0.0 else 0.0


func ai_skill2_ready() -> bool:
	return false
