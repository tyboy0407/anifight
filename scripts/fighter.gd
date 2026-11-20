class_name Fighter
extends CharacterBody2D
## 原型用格鬥角色:狀態機 + 攻擊框 / 受擊框。目前用色塊代替美術。

signal health_changed(current: int, maximum: int)
signal energy_changed(current: int, maximum: int)
signal defeated(fighter: Fighter)
## 自己「被」連段的狀況:hits 為連續受擊數,damage 為這段連段的累計傷害。歸零代表連段結束。
signal combo_changed(hits: int, damage: int)
## 要求畫面震動(重擊命中、摔在地上、撞到場邊)。strength 是震動的最大位移(像素)。
signal screen_shake(strength: float)

enum State { IDLE, MOVE, JUMP, DASH, ATTACK, GUARD, HITSTUN, LAUNCHED, DOWN, GETUP, KO, TELEPORT, BURST, CAST, STUNNED }

# 氣量:一格 100,預設最多三格(實際上限看 max_energy)。
const MAX_ENERGY := 300
const START_ENERGY := 100
const SPECIAL_COST := 100
const SUPER_COST := 300
const TELEPORT_COST := 100
const ESCAPE_COST := 100
const ENERGY_PER_DAMAGE_DEALT := 0.3
const ENERGY_PER_DAMAGE_TAKEN := 0.2
const ENERGY_PER_DAMAGE_BLOCKED := 0.1
const TELEPORT_OFFSET := 75.0
const TELEPORT_TIME := 0.1
const BURST_TIME := 0.3
const BURST_RADIUS := 170.0
# 連段保護:每多一段傷害少 10%,最低 30%;到達上限的那一擊強制擊飛倒地。
const COMBO_DAMAGE_STEP := 0.1
const COMBO_DAMAGE_FLOOR := 0.3
const COMBO_HIT_LIMIT := 10
# 浮空中被普通招式打到時:往上彈的速度,以及水平擊退的縮小比例。
const AIR_HIT_POP := -300.0
const AIR_HIT_PUSH_SCALE := 0.3
## 普攻連段最後一擊的擊飛方向:打高、不打遠,衝刺追上去還來得及在空中接著打。
const CHAIN_LAUNCH := Vector2(250, -700)
## 耗氣招式用的連段編號:視為地面招式,但不能再接下一段。
const SPECIAL_STEP := 99
## 黑閃:傷害倍率與演出用的顏色(虎杖的被動、乙骨的「不准欺負我的朋友!」共用)。
const BLACK_FLASH_DAMAGE_SCALE := 2.0
const BLACK_FLASH_COLOR := Color(0.85, 0.08, 0.12)
## 電腦操作時,每回合有這個機率選擇存氣放超必殺(只對超必殺很貴的角色有意義)。
const AI_SAVE_CHANCE := 0.6
# 打擊手感
const HITSTOP_LIGHT := 0.05   # 命中的瞬間雙方定格多久:輕攻擊
const HITSTOP_HEAVY := 0.10   # 擊飛的重攻擊
const HITSTOP_GUARD := 0.04   # 打在防禦上
const HITSTOP_KO := 0.22      # 打倒對手的最後一擊
const HITSTOP_SHAKE := 3.0    # 定格期間,挨打的一方左右抖動的幅度(像素)
const INPUT_BUFFER := 0.12    # 按鍵提早這麼久按下也算數(收招、定格、落地前先按好)
const BUFFERED_ACTIONS: Array[String] = ["attack", "jump", "dash", "skill", "skill2", "special", "super", "teleport", "escape"]
const EFFECTS_DIR := "res://assets/effects"
const EFFECTS_FX_DIR := "res://assets/effects_fx"
const EFFECTS_FX2_DIR := "res://assets/effects2_fx"  # 第一張排不下的特效;用名字找,不必管在哪一張
const SUMMONS_FX_DIR := "res://assets/summons_fx"  # 召喚物的點陣圖(式神、里香)
const TELEPORT_FX_COLOR := Color(0.75, 0.88, 1.0)   # 瞬身特效預設的顏色
# pixelfx 的光球與漩渦在圖上的直徑(像素):用來把圖縮放到招式指定的大小
const ORB_ART_DIAMETER := {"orb": 44.0, "void": 46.0}
const SPARK_COLOR := Color(1.0, 0.95, 0.7)
const GUARD_SPARK_COLOR := Color(0.7, 0.86, 1.0)
# 翻滾擊飛(AttackData.tumbles):落地後彈跳幾次,彈不起來就貼地翻滾,撞到場邊或停下來才倒地。
const TUMBLE_BOUNCES: Array[float] = [-400.0, -310.0, -220.0]  # 每次著地彈起的速度
const TUMBLE_BOUNCE_KEEP := 0.85       # 每次著地保留的水平速度比例
const TUMBLE_ROLL_FRICTION := 1500.0   # 貼地翻滾時的減速
const TUMBLE_STOP_SPEED := 140.0       # 慢到這個速度就停下來倒地
const TUMBLE_SPIN := 15.0              # 翻滾的旋轉速度(弧度 / 秒)
const TUMBLE_WALL_REBOUND := Vector2(170, -330)  # 撞到場邊後彈回來的速度
const TUMBLE_DUST_INTERVAL := 0.04     # 貼近地面時每隔多久揚起一次沙土
const TUMBLE_DUST_HEIGHT := 70.0       # 離地多高以內算貼近地面
const DUST_COLORS: Array[Color] = [Color(0.80, 0.68, 0.46), Color(0.62, 0.50, 0.33), Color(0.90, 0.82, 0.62)]
const DEBRIS_COLORS: Array[Color] = [Color(0.55, 0.55, 0.6), Color(0.38, 0.38, 0.43), Color(0.80, 0.68, 0.46)]

const MOVE_SPEED := 320.0
const JUMP_VELOCITY := -720.0
const GRAVITY := 2000.0
const DASH_SPEED := 950.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.35
const DOWN_TIME := 0.7
const QUICK_GETUP_AFTER := 0.15
const GETUP_TIME := 0.25
const GUARD_DAMAGE_SCALE := 0.1
const GROUND_FRICTION := 3000.0
const BODY_SIZE := Vector2(50, 110)
const LYING_SIZE := Vector2(110, 36)

@export var player_id: int = 1
@export var body_color: Color = Color(0.9, 0.35, 0.3)
@export var max_health: int = 2500
## 氣量上限(每格 100)。預設三格,個別角色可以在場景裡調整。
@export var max_energy: int = MAX_ENERGY
## 電腦操作時,這一回合要不要存氣放超必殺。每回合開始時隨機決定,
## 所以電腦有的回合會存氣開領域,有的回合有氣就用。
var ai_saves_this_round := false
## 角色素材資料夾(內含 sheet.png 與 sheet.json)。留空或沒有素材時以色塊顯示。
@export_dir var sprite_dir: String = ""

## 缺少某個動畫時改播的替代動畫。不在表內的名稱(角色專屬動作)會先試 "cast"。
const ANIM_FALLBACKS := {
	"walk": "idle", "jump": "idle", "dash": "walk", "teleport": "dash", "guard": "idle",
	"attack1": "idle", "attack2": "attack1", "attack3": "attack1", "air_attack": "attack1",
	"attack4": "attack2", "attack5": "attack3",
	"special": "attack3", "super": "special", "cast": "special", "burst": "cast",
	"hit": "idle", "stunned": "hit", "launched": "hit", "down": "launched", "ko": "down",
	"getup": "idle",
}

var opponent: Fighter
var state: State = State.IDLE
var facing: int = 1
var health: int = 0
var energy: int = 0
var input_enabled: bool = true
## 是否接受「方向 + 按鍵」的組合招式(鍵盤)。觸控操作時關閉,改用專用按鈕。
var direction_combos: bool = true
## 目前可活動的水平範圍,由主場景依鏡頭位置更新。
var arena_min_x: float = -INF
var arena_max_x: float = INF

var _state_time := 0.0
var _dash_cooldown := 0.0
var _dash_dir := 1
var _stun_time := 0.0
var _stun_damage_scale := 1.0
var _energy_seal_time := 0.0
var _seal_label: Label
var _move: AttackData
var _combo_step := 0  # 地面連段的第幾段;-1 代表空中攻擊
var _combo_queued := false
var _hit_targets: Array[Fighter] = []
var _ground_moves: Array[AttackData] = []
var _air_move: AttackData
var _special_move: AttackData
var _super_move: AttackData
# 施法(CAST)狀態:到 release 時間點呼叫一次 callback,到 duration 結束。
var _cast_duration := 0.0
var _cast_release := 0.0
var _cast_callback: Callable
var _cast_fired := false
var _combo_hits := 0
var _combo_damage := 0
## 連段到達上限後的那次擊飛:落地前不能再被追打。一般的擊飛則可以在空中被連擊。
var _launch_protected := false
# 打擊手感
var _hitstop := 0.0            # 命中定格還剩幾秒;定格中不移動、不計時
var _hitstop_shakes := false   # 定格中要不要左右抖(挨打的一方)
var _hitstop_paused_sprite := false  # 定格時有沒有把動畫停住(結束時要接著播)
var _buffer: Dictionary = {}   # 按鍵緩衝:動作名稱 -> 還記得幾秒
var _slash_shown := false      # 這一招的刀光放過了沒
var _effect_frames: SpriteFrames  # 自己畫的特效(tools/make_effects.py)
var _effect_scale := 3.0
var _fx_frames: SpriteFrames      # pixelfx 匯出的特效(tools/import_pixelfx.py);有同名的優先用這套
var _fx_scale := 3.0
var _fx2_frames: SpriteFrames     # pixelfx 匯出的第二張(倍率和第一張相同)
var _sheets: Dictionary = {}      # 其他幾組點陣圖(召喚物、領域背景):資料夾 -> 載入的結果;第一次用到才載入
# 翻滾擊飛中
var _tumbling := false
var _tumble_dir := 1          # 飛出去的方向
var _tumble_bounces := 0      # 已經在地上彈了幾次
var _tumble_angle := 0.0      # 目前轉到的角度
var _tumble_floor_y := INF    # 地面高度;還沒著地過就不知道
var _tumble_dust_timer := 0.0
var _sprite_offset := Vector2.ZERO  # 素材原本的位移,翻滾時要暫時改成以身體中心為軸
var _has_sprite := false
var _current_anim := ""
var _anim_restart := false
var _attack_anim := "attack1"
var _cast_anim := "cast"

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body: ColorRect = $Body
@onready var _eye: ColorRect = $Eye
@onready var _hitbox: Area2D = $Hitbox
@onready var _hit_shape: CollisionShape2D = $Hitbox/Shape
@onready var _hit_visual: ColorRect = $Hitbox/Visual


func _ready() -> void:
	# 場景內的子資源會被所有實例共用,所以攻擊框形狀在這裡各自建立。
	_hit_shape.shape = RectangleShape2D.new()
	_load_sprite()
	var effects := SpriteSheetLoader.load_character(EFFECTS_DIR)
	if not effects.is_empty():
		_effect_frames = effects.frames
		_effect_scale = effects.scale
	var fx := SpriteSheetLoader.load_character(EFFECTS_FX_DIR)
	if not fx.is_empty():
		_fx_frames = fx.frames
		_fx_scale = fx.scale
	var fx2 := SpriteSheetLoader.load_character(EFFECTS_FX2_DIR)
	if not fx2.is_empty():
		_fx2_frames = fx2.frames
	_build_moves()
	health = max_health
	_set_hitbox(false)
	_update_visual()


func _build_moves() -> void:
	# 地面三連擊:輕、輕、重(第三段擊飛倒地)
	_ground_moves = [
		AttackData.make(40, 0.06, 0.10, 0.18, Vector2(60, -70), Vector2(70, 36), Vector2(180, 0), 0.32),
		AttackData.make(50, 0.07, 0.10, 0.20, Vector2(65, -60), Vector2(80, 40), Vector2(200, 0), 0.34),
		AttackData.make(90, 0.10, 0.12, 0.30, Vector2(70, -65), Vector2(95, 60), CHAIN_LAUNCH, 0.0, true, 220.0),
	]
	_air_move = AttackData.make(60, 0.05, 0.20, 0.10, Vector2(45, -40), Vector2(80, 60), Vector2(260, 0), 0.30, false, 0.0)
	# 大招(耗 1 格):前衝的大範圍擊飛,可以從連段第一、二段取消接上。
	_special_move = AttackData.make(160, 0.14, 0.14, 0.34, Vector2(95, -60), Vector2(170, 90), Vector2(520, -560), 0.0, true, 380.0)
	_special_move.builds_energy = false
	_special_move.color = Color(0.3, 0.95, 1.0, 0.8)
	# 超必殺(耗 3 格)
	_super_move = AttackData.make(380, 0.22, 0.20, 0.50, Vector2(140, -75), Vector2(300, 150), Vector2(700, -700), 0.0, true, 500.0)
	_super_move.builds_energy = false
	_super_move.color = Color(1.0, 0.35, 0.9, 0.8)


## 回合開始時重置角色。
func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = spawn_facing
	health = max_health
	_dash_cooldown = 0.0
	_end_hitstop()
	_buffer.clear()
	ai_saves_this_round = randf() < _ai_save_chance()
	_energy_seal_time = 0.0
	_update_seal_label()
	_set_hitbox(false)
	_end_combo()
	_set_state(State.IDLE, true)
	health_changed.emit(health, max_health)
	_set_energy(START_ENERGY)
	_update_visual()


func _physics_process(delta: float) -> void:
	_tick_input_buffer(delta)
	if _hitstop > 0.0:
		_tick_hitstop(delta)
		return
	_state_time += delta
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_tick_energy_seal(delta)
	if state != State.DASH:
		velocity.y += GRAVITY * delta

	match state:
		State.IDLE, State.MOVE: _tick_ground()
		State.JUMP: _tick_air()
		State.DASH: _tick_dash()
		State.ATTACK: _tick_attack(delta)
		State.GUARD: _tick_guard(delta)
		State.HITSTUN: _tick_hitstun(delta)
		State.LAUNCHED: _tick_launched(delta)
		State.DOWN: _tick_down(delta)
		State.GETUP: _tick_getup()
		State.KO: _tick_ko(delta)
		State.TELEPORT: _tick_teleport()
		State.BURST: _tick_burst()
		State.CAST: _tick_cast(delta)
		State.STUNNED: _tick_stunned(delta)

	move_and_slide()
	_update_visual()
	_apply_spin()


# ---------- 打擊手感 ----------

## 命中定格:這段時間內整個人停住不動,打擊才有「打到東西」的重量。
## shakes 為 true 時(挨打的一方)會在原地左右抖。
func hitstop(duration: float, shakes: bool = false) -> void:
	if duration <= 0.0:
		return
	if _hitstop <= 0.0:
		# 先把這一下造成的姿勢與顏色換上去,再停住畫面
		_update_visual()
		_apply_spin()
		if _has_sprite and _sprite.is_playing():
			_sprite.pause()
			_hitstop_paused_sprite = true
	_hitstop = maxf(_hitstop, duration)
	_hitstop_shakes = _hitstop_shakes or shakes


func _tick_hitstop(delta: float) -> void:
	_hitstop -= delta
	if _hitstop <= 0.0:
		_end_hitstop()
	elif _hitstop_shakes and _has_sprite:
		_sprite.position.x = randf_range(-HITSTOP_SHAKE, HITSTOP_SHAKE)


func _end_hitstop() -> void:
	if _hitstop_shakes and _has_sprite:
		_sprite.position.x = 0.0
	if _hitstop_paused_sprite:
		_sprite.play()  # 不指定動畫:從剛才停住的地方繼續播
	_hitstop = 0.0
	_hitstop_shakes = false
	_hitstop_paused_sprite = false


## 記住剛按下的按鍵一小段時間。這樣在收招、定格或落地前先按好,能動的那一刻就會出招。
func _tick_input_buffer(delta: float) -> void:
	for action_name: String in _buffer.keys():
		_buffer[action_name] -= delta
		if _buffer[action_name] <= 0.0:
			_buffer.erase(action_name)
	if not input_enabled:
		_buffer.clear()
		return
	for action_name in BUFFERED_ACTIONS:
		if Input.is_action_just_pressed(_action(action_name)):
			_buffer[action_name] = INPUT_BUFFER


## 被打中(或擋下)時的回饋:火花、定格、重擊時畫面震動。
func _hit_feedback(attacker: Fighter, heavy: bool, guarded: bool = false) -> void:
	var toward := signf(attacker.global_position.x - global_position.x)
	if toward == 0.0:
		toward = -float(attacker.facing)
	var at := global_position + Vector2(toward * 18.0, -BODY_SIZE.y * 0.58)
	var knocked_out := state == State.KO
	var duration := HITSTOP_GUARD
	if _fx_frames != null:
		# pixelfx 的命中特效以挨打的人腳底為原點:火花在胸口炸開、掉到地上。
		# 圖面朝右(攻擊由左往右打);攻擊從右邊來就左右翻轉。
		var feet := global_position + Vector2(toward * 10.0, 0.0)
		if guarded:
			_spawn_effect("guard", global_position, Color.WHITE, 1.0, toward < 0.0)
		else:
			_spawn_effect("crit" if heavy else "spark", feet, Color.WHITE, 1.0, toward > 0.0)
	elif guarded:
		_spawn_effect("guard", at, GUARD_SPARK_COLOR, 1.0, toward < 0.0)
	else:
		_spawn_effect("spark", at, SPARK_COLOR, 1.5 if heavy else 1.0, false, randf_range(0.0, PI / 4.0))
		if heavy:
			_spawn_effect("ring", at, SPARK_COLOR, 1.3)
	if not guarded:
		duration = HITSTOP_KO if knocked_out else (HITSTOP_HEAVY if heavy else HITSTOP_LIGHT)
		if heavy:
			screen_shake.emit(12.0 if knocked_out else 4.0)
	# 近身打中:雙方一起定格。遠程招式打中:只有挨打的一方頓一下
	if attacker.state == State.ATTACK:
		attacker.hitstop(duration)
		hitstop(duration, not guarded)
	else:
		hitstop(duration * 0.5, not guarded)


## 播放一個特效(見 tools/make_effects.py)。圖是白色的,用 color 染色;size 是相對原始大小的倍率。
## attach 為 true 時跟著角色移動(例如刀光),否則留在原地。素材沒載到時回傳 null。
func _spawn_effect(animation: String, center: Vector2, color: Color = Color.WHITE, size: float = 1.0,
		flip: bool = false, angle: float = 0.0, attach: bool = false) -> AnimatedSprite2D:
	var frames := _effect_source(animation)
	if frames == null:
		return null
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = frames
	effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	effect.modulate = color
	effect.scale = Vector2(-1.0 if flip else 1.0, 1.0) * _effect_scale_of(frames) * size
	effect.rotation = angle
	effect.z_index = 2
	if attach:
		add_child(effect)
		effect.position = center - global_position
	else:
		get_parent().add_child(effect)
		effect.global_position = center
	effect.play(animation)
	if not frames.get_animation_loop(animation):
		effect.animation_finished.connect(effect.queue_free)
	return effect


## 建立一個正在播 animation 的特效 Sprite,但不放進場景:給要一直留在身上的循環特效用
## (例如罩住全身的光球),由呼叫的人自己加到節點底下並決定何時顯示。素材沒載到時回傳 null。
func _effect_sprite(animation: String) -> AnimatedSprite2D:
	var frames := _effect_source(animation)
	if frames == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * _effect_scale_of(frames)
	sprite.play(animation)
	return sprite


## 某個特效動畫在哪一套素材裡:先找 pixelfx 匯出的那套,沒有再找自己畫的。都沒有就回傳 null。
func _effect_source(animation: String) -> SpriteFrames:
	if _fx_frames != null and _fx_frames.has_animation(animation):
		return _fx_frames
	if _fx2_frames != null and _fx2_frames.has_animation(animation):
		return _fx2_frames
	if _effect_frames != null and _effect_frames.has_animation(animation):
		return _effect_frames
	return null


func _effect_scale_of(frames: SpriteFrames) -> float:
	return _fx_scale if frames == _fx_frames or frames == _fx2_frames else _effect_scale


## 這個角色揮擊時用哪一種軌跡:"slash" 是刀光(拿武器的角色覆寫成這個),
## "swish" 是拳腳揮動的弧線。
func _slash_effect() -> String:
	return "swish"


## 出招的那一刻畫出揮擊的軌跡。
func _show_slash() -> void:
	var reach := maxf(_move.hitbox_size.x, _move.hitbox_size.y * 1.3)
	var color := Color(_move.color, 1.0).lightened(0.25)
	# 通用大招:由下往上的一擊加上命中的星芒(對手會被往上打飛),取代一般的揮擊軌跡
	if _move == _special_move and _spawn_effect("uppercut", global_position, _bright(color, 1.3), 1.5, facing < 0, 0.0, true) != null:
		return
	# 超必殺:攻擊範圍裡炸開一團咒力,再加上原本的揮擊軌跡
	if _move == _super_move:
		_spawn_effect("blast", global_position + _hit_shape.position, _bright(color, 1.4), clampf(reach / 420.0, 0.6, 1.1))
	if _slash_effect() == "slash" and _effect_source("slash") != null:
		# 刀光的圖以持刀者的腳底為原點,弧線畫在身前
		_spawn_effect("slash", global_position, color, clampf(reach / 135.0, 0.7, 1.35), facing < 0, 0.0, true)
	else:
		_spawn_effect("swish", global_position + _hit_shape.position, color, clampf(reach / 130.0, 0.5, 1.9), facing < 0, 0.0, true)


# ---------- 各狀態 ----------

func _tick_ground() -> void:
	_face_opponent()
	if not is_on_floor():
		_set_state(State.JUMP)
		return
	if _try_energy_actions():
		return
	if _pressed("attack"):
		_start_attack(_ground_moves[0], 0)
		return
	if _pressed("jump"):
		Sfx.play("jump")
		_spawn_dust(global_position, 3, 0.45)
		velocity.y = JUMP_VELOCITY
		_set_state(State.JUMP)
		return
	if _pressed("dash") and _dash_cooldown <= 0.0:
		_start_dash()
		return
	if _held("down"):
		velocity.x = 0.0
		_set_state(State.GUARD)
		return
	var axis := _axis()
	velocity.x = axis * move_speed()
	_set_state(State.MOVE if axis != 0.0 else State.IDLE)


func _tick_air() -> void:
	velocity.x = _axis() * move_speed()
	if _pressed("attack"):
		_start_attack(_air_move, -1)
		return
	if _landed():
		Sfx.play("land")
		_spawn_dust(global_position, 3, 0.5)
		_set_state(State.IDLE)


func _tick_dash() -> void:
	velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)
	if _state_time >= DASH_TIME:
		velocity.x = 0.0
		_dash_cooldown = DASH_COOLDOWN
		_set_state(State.IDLE)


func _tick_attack(delta: float) -> void:
	var airborne := _combo_step < 0
	if airborne:
		if _landed():
			_end_attack()
			return
	else:
		_apply_friction(delta)
		# 普通招式命中後,可以取消接大招、超必殺或幽步。
		if _combo_step < _ground_moves.size() and not _hit_targets.is_empty() and _try_energy_actions():
			return

	var active_end := _move.startup + _move.active
	var active_now := _state_time >= _move.startup and _state_time < active_end
	_set_hitbox(active_now)
	if active_now:
		if not _slash_shown:
			_slash_shown = true
			_show_slash()
		_check_hits()

	if airborne:
		if _state_time >= active_end + _move.recovery:
			_end_attack()
		return

	if _pressed("attack"):
		_combo_queued = true
	# 判定結束後就能取消接下一段,手感比等收招結束更順。
	if _state_time >= active_end and _combo_queued and _combo_step + 1 < _ground_moves.size():
		_start_attack(_ground_moves[_combo_step + 1], _combo_step + 1)
	elif _state_time >= active_end + _move.recovery:
		_end_attack()


func _tick_guard(delta: float) -> void:
	_face_opponent()
	_apply_friction(delta)
	if not is_on_floor():
		_set_state(State.JUMP)
	elif _try_energy_actions():
		return
	elif not _held("down"):
		_set_state(State.IDLE)


func _tick_hitstun(delta: float) -> void:
	_apply_friction(delta)
	if _pressed("escape") and _spend_energy(escape_cost()):
		_start_burst()
	elif _state_time >= _stun_time:
		_set_state(State.IDLE)


func _tick_teleport() -> void:
	velocity.x = 0.0
	if _state_time >= TELEPORT_TIME:
		_set_state(State.IDLE)


func _tick_burst() -> void:
	velocity.x = 0.0
	if _state_time >= BURST_TIME:
		_set_hitbox(false)
		_set_state(State.IDLE)


func _tick_cast(delta: float) -> void:
	_apply_friction(delta)
	if not _cast_fired and _state_time >= _cast_release:
		_cast_fired = true
		_cast_callback.call()
	if state == State.CAST and _state_time >= _cast_duration:
		_set_state(State.IDLE)


func _tick_stunned(delta: float) -> void:
	_apply_friction(delta)
	if _state_time >= _stun_time:
		_set_state(State.IDLE)


func _tick_launched(delta: float) -> void:
	if can_escape() and _pressed("escape") and _spend_energy(escape_cost()):
		_start_burst()
	elif _tumbling:
		_tick_tumble(delta)
	elif _state_time > 0.05 and _landed():
		velocity.x = 0.0
		Sfx.play("down")
		_spawn_landing()
		_set_state(State.DOWN)


func _tick_ko(delta: float) -> void:
	if _tumbling:
		_tick_tumble(delta)
	else:
		_apply_friction(delta)


# ---------- 翻滾擊飛 ----------

func _begin_tumble(direction: int) -> void:
	_tumbling = true
	_tumble_dir = direction
	_tumble_bounces = 0
	_tumble_angle = 0.0
	_tumble_dust_timer = 0.0
	_tumble_floor_y = global_position.y if is_on_floor() else INF


func _stop_tumble() -> void:
	_tumbling = false
	_tumble_angle = 0.0


## 被翻滾擊飛的招式打中後:低空飛出、著地彈跳、貼地翻滾,撞到場邊或停下來為止。
func _tick_tumble(delta: float) -> void:
	_tumble_angle += _tumble_dir * TUMBLE_SPIN * delta
	var at_edge := global_position.x >= arena_max_x - 1.0 if _tumble_dir > 0 else global_position.x <= arena_min_x + 1.0
	if at_edge:
		_tumble_hit_wall()
		return
	if _state_time > 0.05 and _landed():
		_tumble_floor_y = global_position.y
		if _tumble_bounces < TUMBLE_BOUNCES.size():
			# 重重摔在地上再彈起來
			velocity.y = TUMBLE_BOUNCES[_tumble_bounces]
			velocity.x *= TUMBLE_BOUNCE_KEEP
			_tumble_bounces += 1
			_spawn_landing()
			screen_shake.emit(6.0)
			Sfx.play("bounce")
		else:
			# 彈不起來了:貼著地面滾到停
			velocity.x = move_toward(velocity.x, 0.0, TUMBLE_ROLL_FRICTION * delta)
			if absf(velocity.x) < TUMBLE_STOP_SPEED:
				_stop_tumble()
				if state == State.LAUNCHED:
					velocity.x = 0.0
					Sfx.play("down")
					_set_state(State.DOWN)
				return
	_tumble_dust_timer -= delta
	if _tumble_dust_timer <= 0.0 and global_position.y >= _tumble_floor_y - TUMBLE_DUST_HEIGHT:
		_tumble_dust_timer = TUMBLE_DUST_INTERVAL
		_spawn_dust(Vector2(global_position.x, _tumble_floor_y), 2, 0.55)


## 撞上場邊:碎石與沙塵炸開、畫面震動,人被彈回來後倒地。
func _tumble_hit_wall() -> void:
	var wall := Vector2(global_position.x + _tumble_dir * BODY_SIZE.x / 2.0, global_position.y - BODY_SIZE.y / 2.0)
	# 撞擊點一道閃光、往場內噴的火花與碎石(圖是撞上右邊的牆,撞左邊就翻轉);沒有點陣特效時用線條與方塊
	var crashed := _spawn_effect("wallhit", wall, Color.WHITE, 2.0, _tumble_dir < 0) != null
	for i in (0 if crashed else 5):
		var crack := _spawn_rect(Vector2(randf_range(70, 150), 5), Color(1, 1, 1, 0.9), wall, 3)
		crack.rotation = PI / 2.0 + randf_range(-1.0, 1.0)
		var crack_tween := crack.create_tween()
		crack_tween.tween_property(crack, "modulate:a", 0.0, 0.3)
		crack_tween.tween_callback(crack.queue_free)
	# 往場內噴的碎石
	for i in (0 if crashed else 16):
		var piece_size := randf_range(8, 22)
		var piece := _spawn_rect(Vector2(piece_size, piece_size), DEBRIS_COLORS[i % DEBRIS_COLORS.size()], wall + Vector2(0, randf_range(-50, 50)), 3)
		piece.rotation = randf_range(-PI, PI)
		var drift := Vector2(-_tumble_dir * randf_range(60, 300), randf_range(-190, 90))
		var time := randf_range(0.4, 0.7)
		var tween := piece.create_tween()
		tween.tween_property(piece, "position", piece.position + drift, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(piece, "rotation", piece.rotation + randf_range(-5.0, 5.0), time)
		tween.parallel().tween_property(piece, "modulate:a", 0.0, time)
		tween.tween_callback(piece.queue_free)
	if _tumble_floor_y < INF:
		_spawn_dust(Vector2(global_position.x, _tumble_floor_y), 14, 1.5)
	screen_shake.emit(18.0)
	Sfx.play("wall_crash")
	velocity = Vector2(-_tumble_dir * TUMBLE_WALL_REBOUND.x, TUMBLE_WALL_REBOUND.y)
	_stop_tumble()


## 重重摔在地上:腳下的地面裂開、兩圈煙塵往外滾。沒有這個特效時退回一般的沙土。
func _spawn_landing() -> void:
	if _spawn_effect("landing", global_position, Color.WHITE, 1.0, randf() < 0.5) == null:
		_spawn_dust(global_position, 6, 0.8)


## 揚起沙土:幾團點陣圖的煙塵,貼著地面冒出來。amount 越大團數越多,spread 是大小與散開的範圍。
## (沒有特效素材時退回用土色方塊。)
func _spawn_dust(at: Vector2, amount: int, spread: float) -> void:
	if _effect_frames != null:
		@warning_ignore("integer_division")
		for i in maxi((amount + 2) / 4, 1):
			var puff_size := randf_range(0.45, 0.7) * spread
			# 煙塵圖案的底部在格子中心下方約 20 像素處,往上移這麼多才會貼在地面
			var center := at + Vector2(randf_range(-26.0, 26.0) * spread, -20.0 * _effect_scale * puff_size)
			_spawn_effect("dust", center, DUST_COLORS[randi() % DUST_COLORS.size()], puff_size, randf() < 0.5)
		return
	for i in amount:
		var dust_size := randf_range(7, 17) * minf(spread + 0.4, 1.4)
		var dust := _spawn_rect(Vector2(dust_size, dust_size), Color(DUST_COLORS[randi() % DUST_COLORS.size()], 0.85), at + Vector2(randf_range(-22, 22) * spread, -dust_size / 2.0), 1)
		dust.rotation = randf_range(-PI, PI)
		var drift := Vector2(randf_range(-80, 80), randf_range(-95, -20)) * spread
		var time := randf_range(0.3, 0.55)
		var tween := dust.create_tween()
		tween.tween_property(dust, "position", dust.position + drift, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(dust, "scale", Vector2(1.7, 1.7), time)
		tween.parallel().tween_property(dust, "modulate:a", 0.0, time)
		tween.tween_callback(dust.queue_free)


## 翻滾時讓角色以身體中心為軸旋轉;平常角度是 0,等於沒有作用。
func _apply_spin() -> void:
	var pivot := BODY_SIZE.y / 2.0 if _tumbling else 0.0
	if _has_sprite:
		_sprite.rotation = _tumble_angle
		_sprite.position = Vector2(0, -pivot)
		_sprite.offset = _sprite_offset + Vector2(0, pivot / _sprite.scale.y)
	else:
		_body.pivot_offset = _body.size / 2.0
		_body.rotation = _tumble_angle
		if _tumbling:
			_eye.visible = false


func _tick_down(delta: float) -> void:
	_apply_friction(delta)
	var quick := _pressed("dash") and _state_time >= QUICK_GETUP_AFTER
	if quick or _state_time >= DOWN_TIME:
		_set_state(State.GETUP)


func _tick_getup() -> void:
	velocity.x = 0.0
	if _state_time >= GETUP_TIME:
		_set_state(State.IDLE)


# ---------- 動作 ----------

## 耗氣動作:大招(special)、超必殺(下 + special)、幽步(上或下 + dash)。
## 有放出任何一招就把按鍵緩衝清掉,免得同一下按鍵在接下來幾個影格又觸發一次。
func _try_energy_actions() -> bool:
	if _do_energy_actions():
		_buffer.clear()
		return true
	return false


func _do_energy_actions() -> bool:
	if _try_character_actions():
		return true
	if _super_pressed():
		if _spend_energy(super_cost()):
			_start_super()
			return true
	elif _special_pressed():
		if _spend_energy(SPECIAL_COST):
			_start_attack(_special_move, SPECIAL_STEP)
			return true
	if _teleport_pressed() and opponent != null:
		if _spend_energy(teleport_cost()):
			_start_teleport()
			return true
	return false


# 招式的輸入判斷。鍵盤用「方向 + 按鍵」的組合;觸控按鈕則直接送出
# skill2 / super / teleport 這幾個專用動作,不必同時按方向。
# direction_combos 關閉時(觸控),方向鍵不會改變按鍵的意思:
# 例如按住防禦再點衝刺,不會變成幽步。

func _skill1_pressed() -> bool:
	return _pressed("skill") and not (direction_combos and _held("up"))


func _skill2_pressed() -> bool:
	return _pressed("skill2") or (direction_combos and _pressed("skill") and _held("up"))


func _special_pressed() -> bool:
	return _pressed("special") and not (direction_combos and _held("down"))


func _super_pressed() -> bool:
	return _pressed("super") or (direction_combos and _pressed("special") and _held("down"))


func _teleport_pressed() -> bool:
	return _pressed("teleport") or (direction_combos and _pressed("dash") and (_held("down") or _held("up")))


## 角色專屬技能的掛勾。子類別覆寫;有發動就回傳 true。
func _try_character_actions() -> bool:
	return false


## 超必殺的內容。子類別可覆寫成自己的招式;氣量已在呼叫前扣除。
func _start_super() -> void:
	_start_attack(_super_move, SPECIAL_STEP)


## 進入施法狀態:release_at 秒時呼叫 callback,duration 秒後恢復行動。
## 施法途中被打會中斷,callback 不會觸發。
## animation 是施法時播放的動畫名稱;素材沒有這個動畫時會退回 "cast"。
func _start_cast(duration: float, release_at: float, callback: Callable, animation: String = "cast") -> void:
	_set_hitbox(false)
	_cast_anim = animation
	_cast_duration = duration
	_cast_release = release_at
	_cast_callback = callback
	_cast_fired = false
	_set_state(State.CAST, true)


## 被定身:期間無法行動,仍會受到攻擊。幽步、脫出與 KO 期間無效。
## damage_scale 是定身期間受到傷害的倍率(定身本身的 damage 不套用)。
func stun(duration: float, damage: int = 0, damage_scale: float = 1.0) -> void:
	if state in [State.KO, State.TELEPORT, State.BURST]:
		return
	_set_hitbox(false)
	_stun_damage_scale = 1.0
	_set_health(health - _register_hit(damage))
	_stun_damage_scale = damage_scale
	if health <= 0:
		velocity = Vector2(0.0, -300.0)
		_set_state(State.KO, true)
		defeated.emit(self)
		return
	velocity.x = 0.0
	_stun_time = duration
	_set_state(State.STUNNED, true)


## 被打出短暫硬直,不造成傷害、不計入連段。用於格檔反擊這類「打斷對手」的效果。
func stagger(duration: float) -> void:
	if is_invulnerable() or state == State.LAUNCHED:
		return  # 已經被打飛在空中的對手維持浮空,不會被拉回站立硬直
	_set_hitbox(false)
	velocity.x = 0.0
	_stun_time = duration
	_set_state(State.HITSTUN, true)


## 給觸控按鈕的提示:招式一現在是不是強化版(是的話按鈕周圍會冒出黑閃的光芒)。
func skill1_empowered() -> bool:
	return false


## 給電腦對手的提示:技能二要按住幾秒(可以蓄力的招式用)。預設點一下就好。
func ai_skill2_hold() -> float:
	return 0.0


## 給電腦對手的提示:這個角色放出、即將落在場上的範圍攻擊,讓電腦知道要閃。
## 每一項是 {x, half_width, time}:中心位置、半寬、離判定結束還有幾秒。
func ai_hazards() -> Array[Dictionary]:
	return []


## 給電腦對手的提示:技能一、技能二在離對手多遠以內才值得使用。預設不限距離。
func ai_skill_range() -> float:
	return INF


func ai_skill2_range() -> float:
	return INF


## 給電腦對手的提示:技能二現在放不放得出來。預設要有 1 格氣;不用氣的角色覆寫。
func ai_skill2_ready() -> bool:
	return energy >= SPECIAL_COST


## 給電腦對手的提示:要保留多少氣給角色專屬招式,不花在通用大招上。
func ai_energy_reserve() -> int:
	return 0


## 給電腦對手的提示:現在是不是在存氣(先不放耗氣的招式),準備放耗氣量大的超必殺。
## 超必殺很貴的角色覆寫這個函式,並參考 ai_saves_this_round。
func ai_saving_energy() -> bool:
	return false


## 電腦每回合選擇存氣的機率。超必殺特別貴、存氣代價很高的角色可以調低。
func _ai_save_chance() -> float:
	return AI_SAVE_CHANCE


## 給電腦對手的提示:現在放超必殺會不會被打斷。施法時間長、耗氣又多的角色覆寫。
func ai_super_is_safe() -> bool:
	return true


## 對手離得夠遠,或被擊飛、倒地、定身,來不及打斷自己施法。
func _ai_opponent_cannot_interrupt(room: float = 420.0) -> bool:
	if opponent == null:
		return true
	if opponent.state in [State.LAUNCHED, State.DOWN, State.STUNNED]:
		return true
	return absf(opponent.global_position.x - global_position.x) > room


## 給電腦對手的提示:現在是不是該優先放超必殺(例如條件難得湊齊的招式)。
func ai_wants_super() -> bool:
	return false


## 倒地、起身、幽步、脫出與 KO 期間無敵。被擊飛在空中時仍然可以被追打,
## 只有連段到達上限的那次擊飛例外。
func is_invulnerable() -> bool:
	if state == State.LAUNCHED:
		return _launch_protected
	return state in [State.KO, State.DOWN, State.GETUP, State.TELEPORT, State.BURST]


## 吸引類的招式(蒼、順轉「蒼」)能不能拉動這個角色。
func is_immovable() -> bool:
	return is_invulnerable()


## 現在能不能用受擊脫出:地面硬直中,或是在空中被追打時。
func can_escape() -> bool:
	return state == State.HITSTUN or (state == State.LAUNCHED and not _launch_protected)


## 幽步:瞬間移動到對手背後。
func _start_teleport() -> void:
	_set_hitbox(false)
	Sfx.play("teleport")
	_vanish_effect()
	_move_behind_opponent(TELEPORT_OFFSET)
	_appear_effect()
	_set_state(State.TELEPORT, true)


## 瞬間移到對手背後 offset 的位置,並轉身面向對手。
func _move_behind_opponent(offset: float) -> void:
	var side := int(signf(opponent.global_position.x - global_position.x))
	if side == 0:
		side = facing
	var target_x := opponent.global_position.x + side * offset
	if target_x < arena_min_x or target_x > arena_max_x:
		# 對手貼在畫面邊緣,背後沒有空間:改為瞬移到對手面前。
		side = -side
		target_x = opponent.global_position.x + side * offset
	global_position.x = target_x
	velocity = Vector2.ZERO
	facing = -side


## 受擊脫出:無敵並把附近的對手彈開,不造成傷害。
func _start_burst() -> void:
	velocity = Vector2.ZERO
	Sfx.play("burst")
	_set_state(State.BURST, true)
	# 往外擴散的衝擊波,最後擴到脫出的作用半徑
	var center := global_position + Vector2(0, -BODY_SIZE.y / 2.0)
	_spawn_effect("ring", center, Color(1.0, 1.0, 0.75), BURST_RADIUS / (22.5 * _effect_scale))
	_spawn_effect("spark", center, Color(1.0, 1.0, 0.75), 2.0)
	if opponent != null and global_position.distance_to(opponent.global_position) <= BURST_RADIUS:
		opponent.blown_away(self)


## 被對手的受擊脫出彈開。
func blown_away(source: Fighter) -> void:
	if state in [State.KO, State.DOWN, State.GETUP, State.LAUNCHED, State.TELEPORT, State.BURST]:
		return
	var away := int(signf(global_position.x - source.global_position.x))
	if away == 0:
		away = -source.facing
	_set_hitbox(false)
	velocity = Vector2(away * 500.0, -420.0)
	_set_state(State.LAUNCHED, true)

func _start_dash() -> void:
	var axis := _axis()
	_dash_dir = int(signf(axis)) if axis != 0.0 else facing
	Sfx.play("dash")
	if is_on_floor():
		_spawn_dust(global_position, 3, 0.5)
	_set_state(State.DASH)


func _start_attack(move: AttackData, combo_step: int) -> void:
	_move = move
	_combo_step = combo_step
	if combo_step < 0:
		_attack_anim = "air_attack"
	elif combo_step < _ground_moves.size():
		_attack_anim = "attack%d" % (combo_step + 1)
	else:
		_attack_anim = "super" if move == _super_move else "special"
	_combo_queued = false
	_slash_shown = false
	_hit_targets.clear()
	var shape := _hit_shape.shape as RectangleShape2D
	shape.size = move.hitbox_size
	var offset := Vector2(move.hitbox_offset.x * facing, move.hitbox_offset.y)
	_hit_shape.position = offset
	_hit_visual.color = move.color
	_hit_visual.size = move.hitbox_size
	_hit_visual.position = offset - move.hitbox_size / 2.0
	if combo_step >= 0:
		velocity.x = facing * move.lunge
	_set_state(State.ATTACK, true)
	Sfx.play("special" if combo_step == SPECIAL_STEP else "swing")


func _end_attack() -> void:
	_set_hitbox(false)
	_set_state(State.IDLE)


func _check_hits() -> void:
	for area in _hitbox.get_overlapping_areas():
		var target := area.get_parent() as Fighter
		if target == null or target == self or _hit_targets.has(target):
			continue
		_hit_targets.append(target)
		target.take_hit(_effective_move(_move), self)
		_on_attack_hit(target, _move)


## 實際套用到對手身上的招式數值。子類別可覆寫來做傷害強化等效果。
func _effective_move(move: AttackData) -> AttackData:
	return move


## 自己的招式命中對手後呼叫。子類別可覆寫來做追擊等效果。
func _on_attack_hit(_target: Fighter, _move: AttackData) -> void:
	pass


## 超必殺的耗氣量。子類別可依狀態改變。
func super_cost() -> int:
	return SUPER_COST


## 幽步、受擊脫出的耗氣量。不用氣的角色可以覆寫成 0,並改用冷卻時間限制
## (冷卻中回傳比氣量上限還大的數字,就等於放不出來)。
func teleport_cost() -> int:
	return TELEPORT_COST


func escape_cost() -> int:
	return ESCAPE_COST


## 移動速度。天生跑得快、或有加速狀態的角色覆寫。
func move_speed() -> float:
	return MOVE_SPEED


## 受到傷害的倍率。有減傷狀態的角色覆寫。
func _damage_taken_scale() -> float:
	return 1.0


## 被招式命中。倒地、起身、幽步、脫出與 KO 期間無敵;浮空時可以被連擊。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	if is_invulnerable():
		return
	var away := int(signf(global_position.x - attacker.global_position.x))
	if away == 0:
		away = attacker.facing

	if state == State.GUARD and facing == -away and not move.unblockable:
		# 防禦成功:只吃少量傷害,不會被防禦傷害打倒。(破防的招式擋不住,照常受擊。)
		_set_health(maxi(health - int(move.damage * GUARD_DAMAGE_SCALE * _damage_taken_scale()), 1))
		Sfx.play("guard")
		_hit_feedback(attacker, false, true)
		velocity.x = away * 160.0
		add_energy(int(move.damage * ENERGY_PER_DAMAGE_BLOCKED))
		if move.builds_energy:
			attacker.add_energy(int(move.damage * ENERGY_PER_DAMAGE_BLOCKED))
		return

	_set_hitbox(false)
	_stop_tumble()
	var tumbles := move.launches and move.tumbles
	var damage := _register_hit(move.damage)
	_set_health(health - damage)
	Sfx.play("ko" if health <= 0 else ("hit_heavy" if move.launches else "hit_light"))
	add_energy(int(damage * ENERGY_PER_DAMAGE_TAKEN))
	if move.builds_energy:
		attacker.add_energy(int(damage * ENERGY_PER_DAMAGE_DEALT))
	if health <= 0:
		# 被翻滾擊飛的招式打倒:一樣滾到場邊
		velocity = Vector2(away * move.knockback.x, move.knockback.y) if tumbles else Vector2(away * 350.0, -450.0)
		_set_state(State.KO, true)
		if tumbles:
			_begin_tumble(away)
		defeated.emit(self)
	elif _combo_hits >= COMBO_HIT_LIMIT:
		# 連段到達上限:強制擊飛倒地,落地前不能再被追打,結束這段連段。
		velocity = Vector2(away * move.knockback.x, move.knockback.y) if move.launches else Vector2(away * 320.0, -420.0)
		_set_state(State.LAUNCHED, true)
		_launch_protected = true
		if tumbles:
			_begin_tumble(away)
	elif move.launches:
		velocity = Vector2(away * move.knockback.x, move.knockback.y)
		_set_state(State.LAUNCHED, true)
		if tumbles:
			_begin_tumble(away)
	elif state == State.LAUNCHED or not is_on_floor():
		# 浮空中被打:再往上彈一下,落地前可以繼續被連擊。
		# 空中沒有地面摩擦,水平擊退要縮小,不然第二下就會被推出攻擊範圍。
		velocity = Vector2(away * move.knockback.x * AIR_HIT_PUSH_SCALE, AIR_HIT_POP)
		_set_state(State.LAUNCHED, true)
	elif state == State.STUNNED:
		# 定身中被普通招式打到:扣血但維持定身,不重置時間。
		velocity.x = 0.0
	else:
		velocity.x = away * move.knockback.x
		_stun_time = move.hitstun
		_set_state(State.HITSTUN, true)
	_hit_feedback(attacker, move.launches or health <= 0)


# ---------- 工具 ----------

func _set_state(new_state: State, force: bool = false) -> void:
	if new_state == state and not force:
		return
	state = new_state
	_state_time = 0.0
	# 開始一個新動作:之前緩衝的按鍵已經用掉了
	if new_state in [State.ATTACK, State.JUMP, State.DASH, State.CAST, State.TELEPORT, State.BURST, State.GETUP]:
		_buffer.clear()
	_anim_restart = true
	_launch_protected = false
	if new_state != State.LAUNCHED and new_state != State.KO:
		_stop_tumble()
	if new_state == State.IDLE:
		_end_combo()


## 記錄一次受擊,回傳套用連段衰減後的實際傷害。
func _register_hit(raw_damage: int) -> int:
	var scale_factor := maxf(1.0 - COMBO_DAMAGE_STEP * _combo_hits, COMBO_DAMAGE_FLOOR)
	if state == State.STUNNED:
		scale_factor *= _stun_damage_scale
	scale_factor *= _damage_taken_scale()
	var damage := maxi(int(round(raw_damage * scale_factor)), 1) if raw_damage > 0 else 0
	_combo_hits += 1
	_combo_damage += damage
	combo_changed.emit(_combo_hits, _combo_damage)
	return damage


func _end_combo() -> void:
	if _combo_hits == 0:
		return
	_combo_hits = 0
	_combo_damage = 0
	combo_changed.emit(0, 0)


func _set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)


func add_energy(amount: int) -> void:
	if amount > 0 and energy_sealed():
		return
	_set_energy(energy + amount)


## 氣閉:這段時間內無法以任何方式累積氣量;已經有的氣照常可以使用。
func seal_energy(duration: float) -> void:
	_energy_seal_time = maxf(_energy_seal_time, duration)
	if _seal_label == null:
		_seal_label = Label.new()
		_seal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_seal_label.add_theme_font_size_override("font_size", 14)
		_seal_label.add_theme_color_override("font_color", Color(0.78, 0.74, 0.92))
		_seal_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_seal_label.add_theme_constant_override("outline_size", 5)
		_seal_label.size = Vector2(240, 20)
		# 放在各角色自己的狀態文字上面一行
		_seal_label.position = Vector2(-120, -BODY_SIZE.y - 86)
		add_child(_seal_label)
	_update_seal_label()


func energy_sealed() -> bool:
	return _energy_seal_time > 0.0


func _tick_energy_seal(delta: float) -> void:
	if _energy_seal_time <= 0.0:
		return
	_energy_seal_time = maxf(_energy_seal_time - delta, 0.0)
	_update_seal_label()


func _update_seal_label() -> void:
	if _seal_label != null:
		_seal_label.text = "氣閉 %d" % ceili(_energy_seal_time) if energy_sealed() else ""


func _set_energy(value: int) -> void:
	energy = clampi(value, 0, max_energy)
	energy_changed.emit(energy, max_energy)


func _spend_energy(cost: int) -> bool:
	if energy < cost:
		return false
	_set_energy(energy - cost)
	return true


func _set_hitbox(enabled: bool) -> void:
	_hit_shape.disabled = not enabled
	# 攻擊範圍的色塊只在沒有特效素材時當後備;平常由 _show_slash 的刀光表示
	_hit_visual.visible = enabled and _effect_frames == null


func _apply_friction(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)


func _landed() -> bool:
	return is_on_floor() and velocity.y >= 0.0


func _face_opponent() -> void:
	if opponent == null:
		return
	var diff := opponent.global_position.x - global_position.x
	if absf(diff) > 1.0:
		facing = int(signf(diff))


## 在場景中放一個色塊。接近正方形的會自動畫成點陣的光球(orb_animation 可以改成 "void" 漩渦),
## 長條形的維持色塊(斬擊線、光束)。
func _spawn_rect(rect_size: Vector2, color: Color, center: Vector2, z: int = 1, orb_animation: String = "orb") -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	rect.size = rect_size
	rect.pivot_offset = rect_size / 2.0
	rect.position = center - rect_size / 2.0
	rect.z_index = z
	get_parent().add_child(rect)
	# 接近正方形的色塊都是「一團咒力」:改畫成點陣的光球,色塊本身隱藏
	if rect_size.x >= 14.0 and absf(rect_size.x - rect_size.y) <= rect_size.x * 0.2 and _effect_source(orb_animation) != null:
		_dress_as_orb(rect, color, orb_animation)
	return rect


## 在色塊上貼一顆光球的圖,大小跟著色塊變(招式會改色塊的 size 來表現蓄力變大)。
## animation 是 "orb"(光球)或 "void"(黑洞般的漩渦)。
func _dress_as_orb(rect: ColorRect, color: Color, animation: String) -> void:
	rect.color = Color(color, 0.0)
	var frames := _effect_source(animation)
	# 光球在圖上的直徑:pixelfx 的見 ORB_ART_DIAMETER,自己畫的約 30 像素
	var diameter: float = ORB_ART_DIAMETER.get(animation, 30.0) if frames == _fx_frames else 30.0
	var orb := AnimatedSprite2D.new()
	orb.sprite_frames = frames
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 灰階的圖染色後偏暗,把顏色提亮一點才有發光的感覺
	orb.modulate = Color(color.lightened(0.4), maxf(color.a, 0.9)) if frames == _fx_frames else color
	rect.add_child(orb)
	orb.play(animation)
	var fit := func() -> void:
		orb.position = rect.size / 2.0
		orb.scale = Vector2.ONE * rect.size.x / diameter
	fit.call()
	rect.resized.connect(fit)


## 把染色用的顏色調亮(分量可以超過 1)。灰階的特效圖染色後偏暗,斬擊、爪痕這類要「發亮」的用這個。
func _bright(color: Color, amount: float = 1.5) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, color.a)


## 在色塊上貼一張特效圖(色塊本身隱藏),圖跟著色塊移動、旋轉;判定仍然照色塊的大小算。
## 素材沒載到就維持色塊,回傳 null。
func _dress_rect(rect: ColorRect, animation: String, color: Color, size: float = 1.0, flip: bool = false) -> AnimatedSprite2D:
	var frames := _effect_source(animation)
	if frames == null:
		return null
	rect.color = Color(color, 0.0)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = color
	sprite.position = rect.size / 2.0
	sprite.scale = Vector2(-1.0 if flip else 1.0, 1.0) * _effect_scale_of(frames) * size
	rect.add_child(sprite)
	sprite.play(animation)
	return sprite


## 召喚物(式神、里香)的點陣圖:回傳一個已經在播 animation 的 Sprite,由呼叫的人放進場景。
## 圖都朝右;原點在圖的對齊點(鷲是身體中心,玉犬與里香是腳底)。素材沒載到時回傳 null。
func _summon_sprite(animation: String) -> AnimatedSprite2D:
	return _sheet_sprite(SUMMONS_FX_DIR, animation)


## 從某一組點陣圖(資料夾裡的 sheet.png + sheet.json)拿一個已經在播 animation 的 Sprite,
## 由呼叫的人放進場景。每一組第一次用到才載入,之後共用。素材沒載到時回傳 null。
func _sheet_sprite(dir: String, animation: String) -> AnimatedSprite2D:
	if not _sheets.has(dir):
		_sheets[dir] = SpriteSheetLoader.load_character(dir)
	var data: Dictionary = _sheets[dir]
	if data.is_empty() or not data.frames.has_animation(animation):
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = data.frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * data.scale
	sprite.play(animation)
	return sprite


## 先把某一組點陣圖載進來,免得招式第一次放出來的那一刻才載入而頓一下。
func _preload_sheet(dir: String) -> void:
	if not _sheets.has(dir):
		_sheets[dir] = SpriteSheetLoader.load_character(dir)


## 畫面正中央在場景裡的座標(鏡頭會跟著角色移動)。領域的背景用這個對齊,才會一直鋪滿畫面。
func _screen_center() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	return camera.get_screen_center_position() if camera != null else global_position + Vector2(0, -250)


## 換召喚物正在播的動畫(已經在播同一個就不動)。figure 是裝著 Sprite 的節點;用色塊暫代的沒有 Sprite,就什麼都不做。
func _summon_play(figure: Node2D, animation: String) -> void:
	if not is_instance_valid(figure):
		return
	var sprite := figure.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite != null and sprite.animation != animation and sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


## 招式名稱浮字。sound 是同時要播的音效名稱(見 Sfx.SOUNDS),留空就不播。
func _callout(text: String, color: Color, sound: String = "") -> void:
	if not sound.is_empty():
		Sfx.play(sound)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color.lightened(0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.size = Vector2(400, 60)
	label.position = global_position + Vector2(-200, -200)
	label.z_index = 2
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.7)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)


## 黑閃的演出:招式名稱浮字、整個畫面閃過黑白的集中線,接著命中點炸開黑紅色的閃電。
## 沒有點陣特效時,是黑色與紅色交錯的閃電狀線條。
func _black_flash_effect(center: Vector2) -> void:
	_callout("黑閃", BLACK_FLASH_COLOR, "black_flash")
	if _spawn_effect("blackflash", center, Color.WHITE, 1.3, randf() < 0.5) != null:
		_impact_frame()
		return
	for i in 7:
		var bolt := _spawn_rect(Vector2(randf_range(120, 210), 7), Color(0.05, 0.02, 0.04) if i % 2 == 0 else BLACK_FLASH_COLOR, center, 3)
		bolt.rotation = randf_range(-PI, PI)
		var tween := bolt.create_tween()
		tween.tween_property(bolt, "modulate:a", 0.0, 0.28)
		tween.tween_callback(bolt.queue_free)


## 全螢幕的衝擊畫面:黑白的集中線蓋滿整個畫面,閃幾格就散開(介面仍然看得到)。
func _impact_frame() -> void:
	var frame := _spawn_effect("impact", _screen_center())
	if frame == null:
		return
	# 圖是 320x180,放大到蓋得住整個畫面(寬螢幕手機會比 16:9 更寬)
	var view := get_viewport().get_visible_rect().size
	frame.scale = Vector2.ONE * maxf(view.x / 320.0, view.y / 180.0) * 1.06
	frame.z_index = 50


## 進入強化狀態的那一刻,從腳底湧出一陣咒力(之後的狀態只用身體變色表示)。
func _power_burst(color: Color, size: float = 0.85) -> void:
	_spawn_effect("powerup", global_position, _bright(color), size, false, 0.0, true)


## 瞬身:原地留下一道散成光點的人影,出現的位置則是光點聚成人影。
## 在移動之前呼叫 _vanish_effect(),移動之後呼叫 _appear_effect()。素材沒載到時 _vanish_effect() 回傳 false。
func _vanish_effect(color: Color = TELEPORT_FX_COLOR) -> bool:
	return _spawn_effect("vanish", global_position, _bright(color), 1.0, facing < 0) != null


func _appear_effect(color: Color = TELEPORT_FX_COLOR) -> void:
	_spawn_effect("appear", global_position, _bright(color), 1.0, facing < 0)


## 以 center、rect_size 描述的矩形是否碰到對手的身體(對手無敵時為 false)。
func _rect_hits_opponent(center: Vector2, rect_size: Vector2) -> bool:
	if opponent == null or opponent.is_invulnerable():
		return false
	var target_center := opponent.global_position + Vector2(0, -BODY_SIZE.y / 2.0)
	var reach := (rect_size + BODY_SIZE) / 2.0
	return absf(target_center.x - center.x) <= reach.x and absf(target_center.y - center.y) <= reach.y


func _action(action_name: String) -> String:
	return "p%d_%s" % [player_id, action_name]


func _axis() -> float:
	if not input_enabled:
		return 0.0
	return Input.get_axis(_action("left"), _action("right"))


func _pressed(action_name: String) -> bool:
	return input_enabled and (_buffer.has(action_name) or Input.is_action_just_pressed(_action(action_name)))


func _held(action_name: String) -> bool:
	return input_enabled and Input.is_action_pressed(_action(action_name))


## 載入角色素材。成功時改用動畫顯示並隱藏色塊。
func _load_sprite() -> void:
	var loaded := SpriteSheetLoader.load_character(sprite_dir)
	if loaded.is_empty():
		_sprite.visible = false
		return
	var canvas: Vector2 = loaded.canvas
	_sprite.sprite_frames = loaded.frames
	_sprite.scale = Vector2.ONE * float(loaded.scale)
	_sprite_offset = Vector2(-canvas.x / 2.0, -canvas.y + float(loaded.foot_offset))
	_sprite.offset = _sprite_offset
	_sprite.visible = true
	_has_sprite = true
	_body.visible = false
	_eye.visible = false

	# 同角色對戰時靠頭上的標籤分辨玩家。
	var tag := Label.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.text = "%dP" % player_id
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", body_color.lightened(0.25))
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.add_theme_constant_override("outline_size", 5)
	tag.size = Vector2(60, 22)
	tag.position = Vector2(-30, -BODY_SIZE.y - 44)
	add_child(tag)


func _resolve_animation(animation: String) -> String:
	var frames := _sprite.sprite_frames
	for attempt in 8:
		if frames.has_animation(animation):
			return animation
		if ANIM_FALLBACKS.has(animation):
			animation = ANIM_FALLBACKS[animation]
		elif animation != "idle":
			animation = "cast"
		else:
			break
	return ""


func _update_sprite() -> void:
	var animation := "idle"
	var duration := 0.0  # 大於 0 時,調整播放速度讓動畫剛好在這段時間內播完
	match state:
		State.MOVE: animation = "walk"
		State.JUMP: animation = "jump"
		State.DASH: animation = "dash"
		State.TELEPORT: animation = "teleport"
		State.GUARD: animation = "guard"
		State.ATTACK:
			animation = _attack_anim
			duration = _move.startup + _move.active + _move.recovery
		State.CAST:
			animation = _cast_anim
			duration = _cast_duration
		State.BURST: animation = "burst"
		State.HITSTUN: animation = "hit"
		State.STUNNED: animation = "stunned"
		State.LAUNCHED: animation = "launched"
		State.DOWN: animation = "down"
		State.GETUP:
			animation = "getup"
			duration = GETUP_TIME
		State.KO: animation = "ko" if is_on_floor() else "launched"

	animation = _resolve_animation(animation)
	if animation != "" and (animation != _current_anim or _anim_restart):
		var frames := _sprite.sprite_frames
		var natural := frames.get_frame_count(animation) / maxf(frames.get_animation_speed(animation), 0.01)
		_sprite.speed_scale = natural / duration if duration > 0.0 else 1.0
		_sprite.stop()
		_sprite.play(animation)
		_current_anim = animation
	_anim_restart = false
	_sprite.flip_h = facing < 0

	var tint := Color.WHITE
	match state:
		State.HITSTUN, State.LAUNCHED: tint = Color(1.8, 1.8, 1.8)
		State.GUARD: tint = Color(0.6, 0.6, 0.7)
		State.GETUP, State.TELEPORT: tint = Color(1, 1, 1, 0.5)
		State.BURST: tint = Color(1.6, 1.6, 1.0)
		State.STUNNED: tint = Color(0.75, 0.55, 1.0)
		State.KO: tint = Color(0.55, 0.55, 0.55)
	_sprite.modulate = tint


func _update_visual() -> void:
	if _has_sprite:
		_update_sprite()
		return
	var lying := state == State.DOWN or (state == State.KO and is_on_floor())
	if lying:
		_body.size = LYING_SIZE
		_body.position = Vector2(-LYING_SIZE.x / 2.0, -LYING_SIZE.y)
	else:
		_body.size = BODY_SIZE
		_body.position = Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y)
	_eye.visible = not lying
	_eye.position = Vector2(facing * 14.0 - _eye.size.x / 2.0, -98.0)

	var color := body_color
	match state:
		State.HITSTUN, State.LAUNCHED: color = body_color.lerp(Color.WHITE, 0.7)
		State.GUARD: color = body_color.darkened(0.45)
		State.DASH: color = body_color.lightened(0.35)
		State.GETUP, State.TELEPORT: color = Color(body_color, 0.5)
		State.BURST: color = body_color.lerp(Color(1, 1, 0.6), 0.8)
		State.CAST: color = body_color.lerp(Color(0.75, 0.9, 1.0), 0.6)
		State.STUNNED: color = body_color.lerp(Color(0.55, 0.3, 0.8), 0.75)
		State.KO: color = body_color.darkened(0.6)
	_body.color = color
