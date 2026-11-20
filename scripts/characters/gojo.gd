class_name GojoFighter
extends Fighter
## 以五條悟為藍本的角色。氣量上限是 5 格(在 gojo.tscn 設定 max_energy = 500)。
## 蒼(skill):在前方生成吸引點,把對手拉過去並造成多段小傷害。不耗氣,有冷卻。
## 赫(上 + skill):向前射出排斥彈,命中造成大傷害並擊飛。耗 1 格氣。
##   按住可以凝聚最多 2.5 秒,球體越大、傷害越高;放開就射出。
## 領域展開・無量空處(下 + special):定身對手 5 秒,期間對手受到的傷害變成 1.5 倍,
##   並讓對手「氣閉」20 秒(無法累積氣量)。耗 4 格氣,取代通用超必殺。

# 蒼
const BLUE_COOLDOWN := 5.5  # 從出招算起;比吸引點的持續時間長,所以不能無縫連放
const BLUE_CAST := 0.45
const BLUE_RELEASE := 0.20
const BLUE_OFFSET := Vector2(240, -60)
const BLUE_DURATION := 2.9
const BLUE_RANGE := 430.0
const BLUE_PULL_SPEED := 430.0
const BLUE_TICK := 0.2
const BLUE_HIT_RADIUS := 80.0
const BLUE_SIZE := 96.0
const BLUE_COLOR := Color(0.3, 0.55, 1.0)
# 赫:按住凝聚,放開(或凝聚到上限)射出。點一下就是最小的赫。
const RED_COST := 100
const RED_RELEASE := 0.28      # 抬手到最快能射出的時間
const RED_CHARGE_MAX := 2.5    # 最多凝聚幾秒(從抬手算起)
const RED_RECOVERY := 0.22     # 射出後的收招時間
const RED_OFFSET := Vector2(50, -60)
const RED_SPEED := 950.0
const RED_LIFETIME := 0.9
const RED_SIZE := 56.0
const RED_SIZE_MAX := 130.0
const RED_DAMAGE := 160
const RED_DAMAGE_MAX := 360
const RED_COLOR := Color(1.0, 0.25, 0.25)
const AI_CHARGE_DISTANCE := 380.0  # 電腦:離對手超過這個距離才會凝聚
const AI_CHARGE_MAX := 1.2         # 電腦:平常最多凝聚幾秒# 領域展開
const DOMAIN_COST := 400
const DOMAIN_CAST := 0.90
const DOMAIN_RELEASE := 0.55
const DOMAIN_STUN := 5.0
const DOMAIN_DAMAGE := 120
const DOMAIN_VULNERABILITY := 1.5  # 定身期間對手受到的傷害倍率
const DOMAIN_SEAL := 20.0          # 中招後「氣閉」幾秒:期間無法累積氣量
const DOMAIN_FADE := 0.25
const DOMAIN_FX_DIR := "res://assets/domain_void_fx"  # 領域背景的點陣圖:星空與黑洞

var _blue_cooldown := 0.0
var _blue_time := 0.0
var _blue_tick := 0.0
var _blue_position := Vector2.ZERO
var _blue_node: ColorRect
var _blue_move: AttackData

var _red_charging := false
var _red_charge_time := 0.0
var _red_size := RED_SIZE
var _red_time := 0.0
var _red_direction := 1
var _red_node: ColorRect
var _red_move: AttackData

var _domain_node: Node2D

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_preload_sheet(DOMAIN_FX_DIR)
	_blue_move = AttackData.make(14, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.28, false, 0.0)
	_blue_move.builds_energy = false
	_red_move = AttackData.make(RED_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(750, -500), 0.0, true, 0.0)
	_red_move.builds_energy = false


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_clear_blue()
	_clear_red()
	_clear_domain()
	_blue_cooldown = 0.0
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_blue_cooldown = maxf(_blue_cooldown - delta, 0.0)
	_tick_blue(delta)
	_tick_red_charge(delta)
	_tick_red(delta)
	# 領域的星空與黑洞跟著鏡頭走,一直鋪滿畫面
	if is_instance_valid(_domain_node) and _domain_node.has_node("Art"):
		(_domain_node.get_node("Art") as Node2D).global_position = _screen_center()


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if _spend_energy(RED_COST):
			_start_red_charge()
			return true
		return false
	if _skill1_pressed() and _blue_cooldown <= 0.0:
		_blue_cooldown = BLUE_COOLDOWN
		_start_cast(BLUE_CAST, BLUE_RELEASE, _release_blue)
		return true
	return false


func super_cost() -> int:
	return DOMAIN_COST


func _start_super() -> void:
	_start_cast(DOMAIN_CAST, DOMAIN_RELEASE, _release_domain)


## 電腦操作時:決定存氣的回合不放赫,存滿 4 格馬上開領域。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and energy < DOMAIN_COST


func ai_wants_super() -> bool:
	return energy >= DOMAIN_COST and opponent != null and opponent.state != State.STUNNED


## 領域的施法時間長,被打斷就白白損失 4 格氣。
func ai_super_is_safe() -> bool:
	return _ai_opponent_cannot_interrupt()


## 電腦操作時赫要凝聚多久:對手被定身就凝聚到滿,離得遠就隨意凝聚一下,近身直接射。
func ai_skill2_hold() -> float:
	if opponent == null:
		return 0.0
	if opponent.state == State.STUNNED:
		return RED_CHARGE_MAX
	if absf(opponent.global_position.x - global_position.x) > AI_CHARGE_DISTANCE:
		return randf_range(RED_RELEASE, AI_CHARGE_MAX)
	return 0.0


# ---------- 蒼 ----------

func _release_blue() -> void:
	_clear_blue()
	_blue_position = global_position + Vector2(BLUE_OFFSET.x * facing, BLUE_OFFSET.y)
	_blue_position.x = clampf(_blue_position.x, arena_min_x, arena_max_x)
	_blue_time = BLUE_DURATION
	_blue_tick = 0.0
	# 球體比角色大,畫成半透明才看得到被吸進去的對手
	_blue_node = _make_orb(BLUE_SIZE, Color(BLUE_COLOR, 0.7), _blue_position, "void")
	_callout("蒼", BLUE_COLOR, "blue")


func _tick_blue(delta: float) -> void:
	if _blue_time <= 0.0:
		return
	_blue_time -= delta
	_blue_tick -= delta
	# 讓吸引點有脈動感
	var pulse := 1.0 + 0.25 * sin(_blue_time * 30.0)
	_blue_node.scale = Vector2(pulse, pulse)

	if opponent != null and not opponent.is_invulnerable():
		var distance := absf(_blue_position.x - opponent.global_position.x)
		if distance <= BLUE_RANGE:
			if not opponent.is_immovable():
				opponent.global_position.x = move_toward(opponent.global_position.x, _blue_position.x, BLUE_PULL_SPEED * delta)
			distance = absf(_blue_position.x - opponent.global_position.x)
			if distance <= BLUE_HIT_RADIUS and _blue_tick <= 0.0:
				_blue_tick = BLUE_TICK
				opponent.take_hit(_blue_move, self)

	if _blue_time <= 0.0:
		_clear_blue()


func _clear_blue() -> void:
	_blue_time = 0.0
	if is_instance_valid(_blue_node):
		_blue_node.queue_free()
	_blue_node = null


# ---------- 赫 ----------

## 開始凝聚:紅色球體出現在身前,按住期間越來越大。
func _start_red_charge() -> void:
	_clear_red()
	# 施法時間先設成放不完,射出時才改成「現在 + 收招時間」。
	_start_cast(RED_CHARGE_MAX + RED_RECOVERY + 1.0, INF, Callable())
	_red_charging = true
	_red_charge_time = 0.0
	_red_node = _make_orb(RED_SIZE, RED_COLOR, global_position)
	_resize_red(RED_SIZE * 0.3)


func _tick_red_charge(delta: float) -> void:
	if not _red_charging:
		return
	if state != State.CAST:
		_clear_red()  # 凝聚途中被打斷
		return
	_red_charge_time += delta
	# 抬手期間球體長到基本大小;之後才算凝聚,越久越大、傷害越高。
	var charge := clampf(inverse_lerp(RED_RELEASE, RED_CHARGE_MAX, _red_charge_time), 0.0, 1.0)
	if _red_charge_time < RED_RELEASE:
		_resize_red(RED_SIZE * lerpf(0.3, 1.0, _red_charge_time / RED_RELEASE))
	else:
		_resize_red(lerpf(RED_SIZE, RED_SIZE_MAX, charge))
	# 蓄得越久越亮(用 modulate:光球的圖是貼在這個節點底下的)
	_red_node.modulate = Color.WHITE.lerp(Color(1.6, 1.5, 1.5), charge)

	var holding := _held("skill2") or _held("skill")
	if _red_charge_time >= RED_CHARGE_MAX or (_red_charge_time >= RED_RELEASE and not holding):
		_fire_red(charge)


## 把凝聚好的球體射出去。charge 是 0~1 的凝聚程度。
func _fire_red(charge: float) -> void:
	_red_charging = false
	_red_move.damage = int(round(lerpf(RED_DAMAGE, RED_DAMAGE_MAX, charge)))
	_red_direction = facing
	_red_time = RED_LIFETIME
	_cast_fired = true
	_cast_duration = _state_time + RED_RECOVERY
	_callout("赫", RED_COLOR, "red")


## 調整凝聚中的球體大小。球體靠近自己的那一側固定不動,變大時往前、往上長。
func _resize_red(orb_size: float) -> void:
	_red_size = orb_size
	var center := global_position + Vector2(
			(RED_OFFSET.x + (orb_size - RED_SIZE) / 2.0) * facing,
			minf(RED_OFFSET.y, -orb_size / 2.0 - 4.0))
	_red_node.size = Vector2(orb_size, orb_size)
	_red_node.pivot_offset = _red_node.size / 2.0
	_red_node.position = center - _red_node.size / 2.0


func _tick_red(delta: float) -> void:
	if _red_time <= 0.0:
		return
	_red_time -= delta
	_red_node.position.x += _red_direction * RED_SPEED * delta
	var center := _red_node.position + _red_node.size / 2.0

	if opponent != null and not opponent.is_invulnerable():
		var target_center := opponent.global_position + Vector2(0, -BODY_SIZE.y / 2.0)
		var reach := Vector2(_red_size + BODY_SIZE.x, _red_size + BODY_SIZE.y) / 2.0
		if absf(target_center.x - center.x) <= reach.x and absf(target_center.y - center.y) <= reach.y:
			opponent.take_hit(_red_move, self)
			_clear_red()
			return

	if _red_time <= 0.0:
		_clear_red()


func _clear_red() -> void:
	_red_charging = false
	_red_time = 0.0
	if is_instance_valid(_red_node):
		_red_node.queue_free()
	_red_node = null


# ---------- 領域展開・無量空處 ----------

func _release_domain() -> void:
	Sfx.play("domain_void")
	_clear_domain()
	_domain_node = _make_domain_effect()
	if opponent != null:
		opponent.stun(DOMAIN_STUN, DOMAIN_DAMAGE, DOMAIN_VULNERABILITY)
		if opponent.state == State.STUNNED:
			opponent.seal_energy(DOMAIN_SEAL)


func _make_domain_effect() -> Node2D:
	var effect := Node2D.new()
	effect.z_index = -1  # 蓋住背景,但在角色後面
	effect.modulate = Color(1, 1, 1, 0)
	get_parent().add_child(effect)

	var center := global_position + Vector2(0, -250)
	var darkness := ColorRect.new()
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.color = Color(0.02, 0.02, 0.07, 0.94)
	darkness.size = Vector2(6000, 4000)
	darkness.position = center - darkness.size / 2.0
	effect.add_child(darkness)

	var sky := _sheet_sprite(DOMAIN_FX_DIR, "sky")
	if sky != null:
		# 點陣的星空(偶爾有流星劃過)加上正中央的黑洞,整組跟著鏡頭走。
		# 一張星空不夠寬螢幕用,左右各再接一張鏡像的。
		var backdrop := Node2D.new()
		backdrop.name = "Art"
		effect.add_child(backdrop)
		backdrop.global_position = _screen_center()
		var width := (sky.sprite_frames.get_frame_texture("sky", 0) as AtlasTexture).region.size.x * sky.scale.x
		for side in [-1, 0, 1]:
			var piece := sky if side == 0 else _sheet_sprite(DOMAIN_FX_DIR, "sky")
			piece.position.x = side * width
			if side != 0:
				piece.scale.x = -piece.scale.x
			backdrop.add_child(piece)
		var hole := _sheet_sprite(DOMAIN_FX_DIR, "hole")
		if hole != null:
			hole.position = Vector2(230, -80)
			backdrop.add_child(hole)
	else:
		# 沒有點陣圖時:用色塊撒星點
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261111
		for i in 140:
			var star := ColorRect.new()
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var star_size := rng.randf_range(2.0, 6.0)
			star.size = Vector2(star_size, star_size)
			star.position = center + Vector2(rng.randf_range(-1300, 1300), rng.randf_range(-520, 320))
			star.color = Color(0.8, 0.9, 1.0, rng.randf_range(0.4, 1.0))
			effect.add_child(star)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "領域展開\n無量空處"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.size = Vector2(700, 180)
	var art := effect.get_node_or_null("Art") as Node2D
	if art != null:
		# 標題和背景一起對齊畫面:字在左,黑洞在右,不互相擋到
		title.position = Vector2(-610, 110 - art.global_position.y)
		art.add_child(title)
	else:
		title.position = Vector2(global_position.x - 350, 110)
		effect.add_child(title)

	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 1.0, DOMAIN_FADE)
	tween.tween_interval(DOMAIN_STUN - DOMAIN_FADE * 2.0)
	tween.tween_property(effect, "modulate:a", 0.0, DOMAIN_FADE)
	tween.tween_callback(effect.queue_free)
	return effect


func _clear_domain() -> void:
	if is_instance_valid(_domain_node):
		_domain_node.queue_free()
	_domain_node = null


# ---------- 共用 ----------

## 在場景中建立一團咒力:style 是 "orb"(光球,赫)或 "void"(把東西吸進去的漩渦,蒼)。
func _make_orb(orb_size: float, color: Color, center: Vector2, style: String = "orb") -> ColorRect:
	return _spawn_rect(Vector2(orb_size, orb_size), color, center, 1, style)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
