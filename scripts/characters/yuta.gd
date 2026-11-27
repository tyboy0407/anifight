class_name YutaFighter
extends Fighter
## 以乙骨憂太為藍本的角色。普通攻擊用刀,判定比徒手角色長。
##
## 一般狀態
## 氣量上限是 8 格(在 yuta.tscn 設定 max_energy = 800)。
##   普通攻擊(按四下):兩刀、一腳把對手踢退兩三步、舉刀衝刺斬過去(停在對手身後,對手倒地)。
##   一刀斬(skill):閃身到對手面前一刀往上斬,對手浮空,可以接普通攻擊。耗 1 格氣,有冷卻。
##   我也可以!(上 + skill):咒力附刀,10 秒內普通攻擊傷害提升。耗 1 格氣。
##   來吧,里香!(下 + special):召喚里香,進入里香狀態 60 秒。耗 5 格氣。
## 里香狀態
##   地面連段變成 5 段,每次普攻命中里香都會追加一擊。
##   skill 變成「飛走吧!」:咒言,前方大範圍擊飛(和一刀斬共用冷卻)。
##   下 + special 改為「真是失禮,這可是純愛」:里香在身後蓄力 3 秒後向前射出
##   大範圍咒力砲,結束後退出里香狀態。不耗氣。
##   被動「不准欺負憂太!」:憂太被打中時有 10% 機率,里香出手把對手拍飛。
## 被動「咒力滿盈」
##   里香在場的期間就是咒力滿盈(和氣量多少無關)。期間:
##   氣量會緩慢自動恢復(每 20 秒 1 格)。
##   上 + skill 變成「不准欺負我的朋友!」:短暫蓄力後向前揮拳,必定黑閃(傷害 2 倍)、防禦也擋不住,
##   對手低空飛出後在地上翻滾彈跳,一路滾到場邊。
##   skill 與 上 + skill 的耗氣量加倍(各 2 格)。
## 故事模式
##   招式隨劇情領悟(見 apply_story):還沒領悟的按了沒有反應(一刀斬一開始就會)。
##   還不能控制里香的時候,血量掉到三成五以下里香會自己衝出來(每回合一次):
##   期間和里香狀態一樣(也算咒力滿盈),而且更常替憂太出手,但放不了純愛砲。

const SPEECH_COLOR := Color(1.0, 0.95, 0.6)
const CURSE_COLOR := Color(0.55, 0.85, 1.0)
const RIKA_COLOR := Color(1.0, 0.7, 0.88)
const BLADE_COLOR := Color(0.85, 0.92, 1.0)

# 普通攻擊第三下:一腳把對手踢退兩三步(地面摩擦下大約滑 220 像素)
const KICK_DAMAGE := 40
const KICK_PUSH := 1250.0
const KICK_HITSTUN := 0.55        # 夠久,第四下衝過去還打得到
# 普通攻擊第四下:舉刀、衝刺斬過去,停在對手身後
const RUSH_WINDUP := 0.16         # 舉刀的時間
const RUSH_SPEED := 2400.0
const RUSH_TIME := 0.18           # 沒斬到人的話衝這麼久(約 430 像素)
const RUSH_EXTRA := 0.10          # 斬到人了但還沒穿到身後:最多再多衝這麼久
const RUSH_RECOVERY := 0.26
const RUSH_PASS := 105.0          # 斬到人之後停在對手身後多遠
const RUSH_DAMAGE := 100
const RUSH_SIZE := Vector2(150, 100)
const RUSH_KNOCKDOWN := Vector2(40, -340)  # 小小浮起來就倒地
# 招式一(沒有里香):一刀斬
const IAI_COST := 100
const IAI_WINDUP := 0.12
const IAI_SPEED := 2200.0
const IAI_TIME := 0.15            # 最遠閃身約 330 像素
const IAI_DAMAGE := 85
const IAI_LAUNCH := Vector2(40, -640)  # 打高不打遠:落下來之前接得到普通攻擊
const IAI_SIZE := Vector2(110, 100)
const IAI_HIT_RECOVERY := 0.14    # 斬中了收招很短
const IAI_MISS_RECOVERY := 0.30
const IAI_FOLLOW_TIME := 0.9      # 電腦:斬中後這段時間內會按普攻追打
const SKILL1_COOLDOWN := 3.0      # 一刀斬與「飛走吧!」共用
# 招式一(里香在場):飛走吧!
const SPEECH_COST := 100
const SPEECH_DAMAGE := 78         # 原本 60,里香在場時提升三成
const SPEECH_KNOCKBACK := Vector2(1250, -470)
const SPEECH_CAST := 0.50
const SPEECH_RELEASE := 0.22
const SPEECH_SIZE := Vector2(380, 170)
const SPEECH_OFFSET := Vector2(215, -65)
# 我也可以!
const BUFF_COST := 100
const BUFF_CAST := 0.40
const BUFF_RELEASE := 0.20
const BUFF_DURATION := 10.0
const BUFF_DAMAGE_SCALE := 1.5
# 咒力滿盈(里香在場的期間)
const OVERFLOW_COST_SCALE := 2    # 滿盈期間招式一、招式二的耗氣倍率
const OVERFLOW_REGEN := 5.0       # 滿盈期間每秒自動恢復的氣量(20 秒一格)
const OVERFLOW_NOTE_DELAY := 0.55 # 「咒力滿盈」的浮字晚一點出來,不和「來吧,里香!」疊在一起
const ENERGY_GAIN_SCALE := 1.8    # 打人、挨打累積氣量的倍率
# 不准欺負我的朋友!(咒力滿盈時的招式二)
const FRIEND_COST := 100
const FRIEND_COOLDOWN := 3.0
const FRIEND_DAMAGE := 130        # 必定黑閃,實際是 2 倍
const FRIEND_CHARGE := 0.40       # 揮拳前的蓄力時間
const FRIEND_KNOCKBACK := Vector2(1150, -420)  # 低空飛出,落地後翻滾彈跳到場邊
const FRIEND_RANGE := 300.0       # 電腦:對手在這個距離內才出拳
# 來吧,里香!
const RIKA_COST := 500
const RIKA_CAST := 0.80
const RIKA_RELEASE := 0.50
const RIKA_DURATION := 60.0
const RIKA_FOLLOW_OFFSET := Vector2(-85, -25)
const RIKA_FOLLOW_SPEED := 9.0
const RIKA_STRIKE_DELAY := 0.10
const RIKA_STRIKE_REACH := 280.0
# 不准欺負憂太!
const PROTECT_CHANCE := 0.10
const PROTECT_REACH := 420.0  # 對手在這個距離內里香才撲得到;遠程攻擊打中憂太不會觸發
const PROTECT_DAMAGE := 40
# 真是失禮,這可是純愛
const CANNON_CAST := 0.50
const CANNON_RELEASE := 0.20
const CANNON_CHARGE := 3.0
const CANNON_FIRE := 0.60
const CANNON_TICK := 0.12
const CANNON_SIZE := Vector2(1500, 180)
const CANNON_HEIGHT := -70.0
const CANNON_BEAM_ART_LENGTH := 440.0  # 光束在點陣圖上的長度(像素),見 tools/pixelfx_custom/anifight/love-beam.js

# 故事模式:里香失控
const RAMPAGE_HEALTH := 0.35      # 血量掉到這個比例以下就失控
const RAMPAGE_DURATION := 15.0
const RAMPAGE_PROTECT_CHANCE := 0.35
## 故事模式裡隨劇情領悟的能力:buff 我也可以!、friend 不准欺負我的朋友!、speech 飛走吧!、rika 來吧,里香!與純愛砲
const STORY_ABILITIES: Array[String] = ["buff", "friend", "speech", "rika"]

enum Cannon { NONE, CHARGING, FIRING }
enum Iai { NONE, WINDUP, RUSH, RECOVER }

var _skill1_cooldown := 0.0
var _speech_move: AttackData

# 普通攻擊第三、四下
var _kick_move: AttackData
var _rush_move: AttackData      # 只管時間(舉刀、衝刺、收招),判定由 _tick_rush 自己算
var _rush_hit_move: AttackData  # 衝刺斬實際打在對手身上的數值
var _rush_started := false
var _rush_hit := false
var _rush_done := false
var _rush_stop_x := 0.0
var _ghost_timer := 0.0

# 一刀斬
var _iai := Iai.NONE
var _iai_time := 0.0
var _iai_move: AttackData
var _iai_follow := 0.0  # 電腦:斬中後還有幾秒可以追打

var _was_overflowing := false
var _overflow_note := 0.0  # 「咒力滿盈」的浮字還要等幾秒才出來
var _regen_bank := 0.0  # 自動回氣還沒滿 1 點的零頭
var _friend_cooldown := 0.0
var _friend_move: AttackData
var _friend_health := 0  # 出拳前對手的血量,用來判斷這一拳有沒有打到

var _buff_time := 0.0
var _boosted: Dictionary = {}  # 原招式 -> 強化後的複本

var _normal_chain: Array[AttackData] = []
var _rika_chain: Array[AttackData] = []
var _rika_time := 0.0
var _rika_node: Node2D
var _rika_strike_timer := -1.0
var _rika_move: AttackData
var _protect_move: AttackData
## 被動的觸發機率。獨立成變數是為了測試時可以調成必定觸發。
var protect_chance := PROTECT_CHANCE

var _cannon := Cannon.NONE
var _cannon_time := 0.0
var _cannon_tick := 0.0
var _cannon_direction := 1
var _cannon_origin := Vector2.ZERO
var _cannon_charge_node: ColorRect
var _cannon_beam_node: ColorRect
var _cannon_move: AttackData
var _cannon_final_move: AttackData

var _abilities: Array[String] = STORY_ABILITIES.duplicate()  # 會用的能力;一般對戰是全部
var _rampage_ready := false   # 故事模式:這一回合里香還沒失控過
var _rampaging := false       # 現在的里香狀態是失控來的
var _status_label: Label

@onready var _hair: ColorRect = $Hair


func _ready() -> void:
	super()
	_preload_sheet(SUMMONS_FX_DIR)
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
	# 沒有里香時的四段:兩刀、一腳踢退、衝刺斬
	_kick_move = AttackData.make(KICK_DAMAGE, 0.08, 0.10, 0.22, Vector2(70, -52), Vector2(104, 52), Vector2(KICK_PUSH, 0), KICK_HITSTUN, false, 150.0)
	_rush_move = AttackData.make(0, RUSH_WINDUP + RUSH_TIME, 0.0, RUSH_RECOVERY, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.0, false, 0.0)
	_rush_hit_move = AttackData.make(RUSH_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, RUSH_KNOCKDOWN, 0.0, true, 0.0)
	_normal_chain = [
		_slash(50, 0.06, 0.17, 0.32, false),
		_slash(60, 0.07, 0.19, 0.34, false),
		_kick_move,
		_rush_move,
	]
	# 里香狀態的五連擊
	_rika_chain = [
		_slash(45, 0.07, 0.18, 0.34, false),
		_slash(50, 0.07, 0.18, 0.34, false),
		_slash(55, 0.08, 0.20, 0.34, false),
		_slash(60, 0.08, 0.20, 0.36, false),
		_slash(100, 0.11, 0.32, 0.0, true),
	]
	_ground_moves = _normal_chain
	_air_move = AttackData.make(65, 0.05, 0.20, 0.10, Vector2(60, -40), Vector2(110, 70), Vector2(260, 0), 0.30, false, 0.0)

	_iai_move = AttackData.make(IAI_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, IAI_LAUNCH, 0.0, true, 0.0)
	_iai_move.builds_energy = false
	_speech_move = AttackData.make(SPEECH_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, SPEECH_KNOCKBACK, 0.0, true, 0.0)
	_speech_move.builds_energy = false
	var flash_damage := int(round(FRIEND_DAMAGE * BLACK_FLASH_DAMAGE_SCALE))
	_friend_move = AttackData.make(flash_damage, 0.05, 0.14, 0.40, Vector2(90, -62), Vector2(170, 90), FRIEND_KNOCKBACK, 0.0, true, 520.0)
	_friend_move.builds_energy = false
	_friend_move.tumbles = true
	_friend_move.unblockable = true
	_friend_move.color = Color(0.1, 0.02, 0.04, 0.85)
	_rika_move = AttackData.make(30, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0.36, false, 0.0)
	_protect_move = AttackData.make(PROTECT_DAMAGE, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(720, -480), 0.0, true, 0.0)
	_protect_move.builds_energy = false
	_cannon_move = AttackData.make(70, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(120, 0), 0.30, false, 0.0)
	_cannon_move.builds_energy = false
	_cannon_final_move = AttackData.make(70, 0.0, 0.0, 0.0, Vector2.ZERO, Vector2.ZERO, Vector2(800, -600), 0.0, true, 0.0)
	_cannon_final_move.builds_energy = false


## 拿刀的角色:揮擊畫成刀光(第三下是用腳踢的,畫成一般的弧線)。
func _slash_effect() -> String:
	return "swish" if _move == _kick_move else "slash"


func _slash(damage: int, startup: float, recovery: float, hitstun: float, launches: bool) -> AttackData:
	var knockback := CHAIN_LAUNCH if launches else Vector2(170, 0)
	var move := AttackData.make(damage, startup, 0.10, recovery, Vector2(80, -62), Vector2(120, 56), knockback, hitstun, launches, 230.0 if launches else 130.0)
	move.color = Color(0.85, 0.92, 1.0, 0.75)
	return move


## 故事模式:只會用已經領悟的能力;還不會召喚里香的時候,里香會自己失控。
func apply_story(setup: Dictionary) -> void:
	super(setup)
	if setup.has("abilities"):
		_abilities.assign(setup.abilities)
		_rampage_ready = not _knows("rika")


func _knows(ability: String) -> bool:
	return _abilities.has(ability)


## 招式一(一刀斬)一開始就會;招式二要領悟「我也可以!」或黑閃拳才有。
func action_available(key: String) -> bool:
	match key:
		"skill2": return _knows("buff") or _knows("friend")
		"super": return _knows("rika")
	return true


func reset(spawn_position: Vector2, spawn_facing: int) -> void:
	_rampage_ready = not _knows("rika")
	_skill1_cooldown = 0.0
	_friend_cooldown = 0.0
	_buff_time = 0.0
	_was_overflowing = false
	_overflow_note = 0.0
	_regen_bank = 0.0
	_iai = Iai.NONE
	_iai_follow = 0.0
	_cancel_cannon()
	_exit_rika()
	super(spawn_position, spawn_facing)


func _physics_process(delta: float) -> void:
	super(delta)
	_skill1_cooldown = maxf(_skill1_cooldown - delta, 0.0)
	_friend_cooldown = maxf(_friend_cooldown - delta, 0.0)
	_buff_time = maxf(_buff_time - delta, 0.0)
	_iai_follow = maxf(_iai_follow - delta, 0.0)
	_tick_iai(delta)
	_tick_overflow(delta)
	_tick_rika(delta)
	_tick_cannon(delta)
	_update_status()


func in_rika_state() -> bool:
	return _rika_time > 0.0


## 咒力滿盈:里香在場的期間(故事模式裡里香失控衝出來也算)。
func overflowing() -> bool:
	return in_rika_state()


## 觸控按鈕的提示:招式二現在是不是必定黑閃的那一拳。
func skill2_empowered() -> bool:
	return overflowing() and _knows("friend")


## 招式一、招式二實際的耗氣量:咒力滿盈時加倍。
func _skill_cost(base_cost: int) -> int:
	return base_cost * OVERFLOW_COST_SCALE if overflowing() else base_cost


func _tick_overflow(delta: float) -> void:
	var now := overflowing()
	if now and not _was_overflowing:
		_overflow_note = OVERFLOW_NOTE_DELAY
	_was_overflowing = now
	if _overflow_note > 0.0:
		_overflow_note -= delta
		if _overflow_note <= 0.0 and now and state != State.KO:
			_callout("咒力滿盈", CURSE_COLOR, "overflow")
	# 滿盈期間緩慢回氣。氣量是整數,不足 1 點的部分先存著。
	if not now or state == State.KO or energy_sealed():
		_regen_bank = 0.0
		return
	_regen_bank += OVERFLOW_REGEN * delta
	var whole := int(_regen_bank)
	if whole > 0:
		_regen_bank -= whole
		_set_energy(energy + whole)  # 不經過 add_energy:回氣不套用累積氣量的加成


## 咒力量龐大:打人、挨打累積氣量的速度比別人快(8 格的氣條才存得滿)。
func add_energy(amount: int) -> void:
	super(int(round(amount * ENERGY_GAIN_SCALE)) if amount > 0 else amount)


func _try_character_actions() -> bool:
	if _skill2_pressed():
		if overflowing() and _knows("friend"):
			# 咒力滿盈:招式二是必定黑閃的那一拳
			if _friend_cooldown > 0.0 or not _spend_energy(_skill_cost(FRIEND_COST)):
				return false
			_friend_cooldown = FRIEND_COOLDOWN
			_start_friend_punch()
			return true
		if _knows("buff") and _spend_energy(_skill_cost(BUFF_COST)):
			_start_cast(BUFF_CAST, BUFF_RELEASE, _release_buff)
			return true
		return false
	if _skill1_pressed() and _skill1_cooldown <= 0.0:
		# 里香在場時是「飛走吧!」,其餘時間是一刀斬
		var shouts := _shouts()
		if not _spend_energy(_skill_cost(SPEECH_COST if shouts else IAI_COST)):
			return false
		_skill1_cooldown = SKILL1_COOLDOWN
		if shouts:
			_start_cast(SPEECH_CAST, SPEECH_RELEASE, _release_speech)
		else:
			_start_iai()
		return true
	return false


## 招式一現在是不是「飛走吧!」(里香在場,而且已經領悟了)。
func _shouts() -> bool:
	return in_rika_state() and _knows("speech")


## 里香狀態下的純愛砲不耗氣(代價是結束里香狀態);蓄力中不能再放一次。
func super_cost() -> int:
	if _cannon != Cannon.NONE or not _knows("rika"):
		return max_energy + 1
	return 0 if in_rika_state() else RIKA_COST


## 電腦操作時:決定存氣的回合先不用招式,存到 5 格召喚里香;里香出來之後才又開始用招式。
func ai_saving_energy() -> bool:
	return ai_saves_this_round and not in_rika_state()


## 里香要 5 格氣才召喚得出來,存氣的回合幾乎整回合都不能出招,所以電腦比較少選擇存氣。
func _ai_save_chance() -> float:
	return 0.25


## 電腦操作時:還沒召喚里香的話,氣夠了就先召喚。
func ai_wants_super() -> bool:
	return not in_rika_state() and energy >= RIKA_COST


## 召喚里香的施法時間長,被打斷就白白損失 5 格氣。(純愛砲不耗氣,隨時可以放。)
func ai_super_is_safe() -> bool:
	return in_rika_state() or _ai_opponent_cannot_interrupt()


## 電腦操作時:招式一也要耗氣,存氣中不放;冷卻中、氣不夠也不按。
func ai_skill_range() -> float:
	if ai_saving_energy() or _skill1_cooldown > 0.0:
		return 0.0
	if _shouts():
		# 「飛走吧!」的聲波只到身前四百像素左右,太遠放只是浪費氣
		return SPEECH_OFFSET.x + SPEECH_SIZE.x / 2.0 if energy >= _skill_cost(SPEECH_COST) else 0.0
	# 一刀斬:閃身搆得到的距離內
	return IAI_SPEED * IAI_TIME + 90.0 if energy >= _skill_cost(IAI_COST) else 0.0


## 招式二:咒力滿盈時是近身的黑閃拳;平常是「我也可以!」,已經附刀了就不再放一次。
func ai_skill2_ready() -> bool:
	if skill2_empowered():
		return _friend_cooldown <= 0.0 and energy >= _skill_cost(FRIEND_COST)
	return _knows("buff") and _buff_time <= 0.0 and energy >= _skill_cost(BUFF_COST)


func ai_skill2_range() -> float:
	return FRIEND_RANGE if skill2_empowered() else INF


## 一刀斬把人斬到半空了:按普通攻擊追打。
func ai_wants_attack() -> bool:
	if _iai_follow <= 0.0 or opponent == null or opponent.state != State.LAUNCHED or opponent.is_invulnerable():
		return false
	return state in [State.IDLE, State.MOVE] and absf(opponent.global_position.x - global_position.x) <= 170.0


func _start_super() -> void:
	if in_rika_state():
		_start_cast(CANNON_CAST, CANNON_RELEASE, _begin_cannon)
	else:
		_start_cast(RIKA_CAST, RIKA_RELEASE, _enter_rika)


# ---------- 普通攻擊 ----------

func _start_attack(move: AttackData, combo_step: int) -> void:
	super(move, combo_step)
	if move == _rush_move:
		_attack_anim = "dash_slash"
		_rush_started = false
		_rush_hit = false
		_rush_done = false


func _tick_attack(delta: float) -> void:
	if _move == _rush_move:
		_tick_rush(delta)
	super(delta)


## 第四下:舉刀之後整個人衝出去,斬過對手、停在對方身後。沒斬到人就衝到底。
func _tick_rush(delta: float) -> void:
	var time := _state_time - RUSH_WINDUP
	if time < 0.0 or _rush_done:
		return
	if not _rush_started:
		_rush_started = true
		_ghost_timer = 0.0
		Sfx.play("dash")
		_spawn_dust(global_position, 3, 0.5)
	velocity.x = facing * RUSH_SPEED
	_leave_trail(delta)
	if not _rush_hit and _rect_hits_opponent(global_position + Vector2(facing * 40.0, -60.0), RUSH_SIZE):
		_rush_hit = true
		_rush_stop_x = clampf(opponent.global_position.x + facing * RUSH_PASS, arena_min_x, arena_max_x)
		_cut_effect(opponent.global_position, 1.25)
		opponent.take_hit(_effective_move(_rush_hit_move), self)
	var passed := _rush_hit and (global_position.x - _rush_stop_x) * facing >= 0.0
	if passed or time >= RUSH_TIME + (RUSH_EXTRA if _rush_hit else 0.0):
		_rush_done = true
		velocity.x = 0.0
		if passed:
			global_position.x = _rush_stop_x
		# 提早斬完:直接進收招,動畫跳到揮完刀的那一格
		_state_time = maxf(_state_time, RUSH_WINDUP + RUSH_TIME)
		if _has_sprite and _sprite.animation == &"dash_slash":
			_sprite.frame = maxi(_sprite.frame, 4)


## 斬在對手身上的一道刀光(at 是對手的腳底)。
func _cut_effect(at: Vector2, size: float) -> void:
	Sfx.play("swing")
	_spawn_effect("slash", at + Vector2(-facing * 70.0, 0.0), _bright(BLADE_COLOR, 1.5), size, facing < 0)


## 衝刺、閃身時每隔一小段時間留下一個淡藍色的殘影。
func _leave_trail(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0:
		return
	_ghost_timer = 0.03
	var ghost := _copy_of_self(_sprite.animation, _sprite.frame) if _has_sprite else null
	if ghost == null:
		return
	ghost.flip_h = _sprite.flip_h
	ghost.modulate = Color(0.8, 1.2, 2.0, 0.5)
	ghost.global_position = global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


# ---------- 一刀斬 ----------

## 壓低身體把刀收在腰間,一瞬間閃到對手面前往上斬。被防禦住的話對手不會浮空。
func _start_iai() -> void:
	_face_opponent()
	_iai = Iai.WINDUP
	_iai_follow = 0.0
	_callout("一刀斬", BLADE_COLOR, "swing")
	_start_cast(IAI_WINDUP + IAI_TIME + IAI_MISS_RECOVERY, IAI_WINDUP, _release_iai, "iai")


func _release_iai() -> void:
	if _iai != Iai.WINDUP:
		return
	_iai = Iai.RUSH
	_iai_time = IAI_TIME
	_ghost_timer = 0.0
	Sfx.play("dash")


func _tick_iai(delta: float) -> void:
	if _iai == Iai.NONE:
		return
	if state != State.CAST:
		_iai = Iai.NONE  # 被打斷,或整招結束
		return
	if _iai != Iai.RUSH:
		return
	velocity.x = facing * IAI_SPEED
	_iai_time -= delta
	_leave_trail(delta)
	if _rect_hits_opponent(global_position + Vector2(facing * 60.0, -60.0), IAI_SIZE):
		velocity.x = 0.0
		_cut_effect(opponent.global_position, 1.1)
		if _land(_iai_move):
			screen_shake.emit(6.0)
			_iai_follow = IAI_FOLLOW_TIME
		_finish_iai(IAI_HIT_RECOVERY)
	elif _iai_time <= 0.0:
		velocity.x = 0.0
		_finish_iai(IAI_MISS_RECOVERY)


func _finish_iai(after: float) -> void:
	_iai = Iai.RECOVER
	_cast_duration = _state_time + after
	if _has_sprite and _sprite.animation == &"iai":
		_sprite.frame = maxi(_sprite.frame, 2)  # 揮刀的那一格


# ---------- 飛走吧! ----------

func _release_speech() -> void:
	_callout("飛走吧!", SPEECH_COLOR, "speech")
	var origin := global_position + Vector2(0, SPEECH_OFFSET.y)
	# 聲波:三道由小到大、往前擴散的波紋。圖的原點在嘴邊,最遠剛好到判定的盡頭
	var shout := _spawn_effect("shout", origin + Vector2(facing * 18.0, 0), _bright(SPEECH_COLOR, 1.4), 1.0, facing < 0)
	for i in (0 if shout != null else 3):
		var wave := _spawn_rect(Vector2(12, 60 + i * 45), Color(SPEECH_COLOR, 0.8), origin + Vector2(facing * (60 + i * 55), 0), 2)
		var tween := wave.create_tween()
		tween.tween_property(wave, "position:x", wave.position.x + facing * 160.0, 0.3)
		tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.3)
		tween.tween_callback(wave.queue_free)
	var center := global_position + Vector2(SPEECH_OFFSET.x * facing, SPEECH_OFFSET.y)
	if _rect_hits_opponent(center, SPEECH_SIZE):
		opponent.take_hit(_speech_move, self)


# ---------- 不准欺負我的朋友! ----------

## 先原地蓄力,蓄力結束的瞬間向前衝出揮拳。蓄力中被打會中斷,氣不退還。
func _start_friend_punch() -> void:
	_callout("不准欺負我的朋友!", BLACK_FLASH_COLOR, "friend_charge")
	_start_cast(FRIEND_CHARGE + 0.1, FRIEND_CHARGE, _release_friend_punch)
	# 拳頭上凝聚的咒力:由小變大的暗紅色方塊
	var glow := _spawn_rect(Vector2(16, 16), Color(BLACK_FLASH_COLOR, 0.8), global_position + Vector2(facing * 40.0, -66.0), 2)
	var tween := glow.create_tween()
	tween.tween_property(glow, "scale", Vector2(2.2, 2.2), FRIEND_CHARGE)
	tween.parallel().tween_property(glow, "rotation", PI, FRIEND_CHARGE)
	tween.tween_property(glow, "modulate:a", 0.0, 0.08)
	tween.tween_callback(glow.queue_free)


func _release_friend_punch() -> void:
	_start_attack(_friend_move, SPECIAL_STEP)


# ---------- 我也可以! ----------

func _release_buff() -> void:
	_buff_time = BUFF_DURATION
	_callout("我也可以!", CURSE_COLOR, "powerup")
	_power_burst(CURSE_COLOR)


## 強化期間,刀的普通攻擊(地面與空中)傷害提升;里香的追擊與耗氣招式不受影響。
func _effective_move(move: AttackData) -> AttackData:
	if move == _friend_move and opponent != null:
		_friend_health = opponent.health
	if _buff_time <= 0.0 or not _is_normal_attack(move):
		return move
	if not _boosted.has(move):
		var copy: AttackData = move.duplicate()
		copy.damage = int(round(move.damage * BUFF_DAMAGE_SCALE))
		_boosted[move] = copy
	return _boosted[move]


func normal_attack_scale() -> float:
	return BUFF_DAMAGE_SCALE if _buff_time > 0.0 else 1.0


func _is_normal_attack(move: AttackData) -> bool:
	return move == _air_move or move == _rush_hit_move or _normal_chain.has(move) or _rika_chain.has(move)


# ---------- 里香狀態 ----------

func _enter_rika() -> void:
	_rika_time = RIKA_DURATION
	_ground_moves = _rika_chain
	_callout("來吧,里香!", RIKA_COLOR, "rika_summon")
	_show_rika()


## 故事模式:里香不受控制,自己衝出來。時間比召喚的短,但更常替憂太出手。
func _rampage() -> void:
	_rampage_ready = false
	_rampaging = true
	_rika_time = RAMPAGE_DURATION
	_ground_moves = _rika_chain
	_callout("里香……不要出來!", RIKA_COLOR, "rika_summon")
	screen_shake.emit(8.0)
	_show_rika()


func _show_rika() -> void:
	if not is_instance_valid(_rika_node):
		_rika_node = _make_rika()
		_rika_node.global_position = global_position + Vector2(RIKA_FOLLOW_OFFSET.x * facing, RIKA_FOLLOW_OFFSET.y - 60)


func _exit_rika() -> void:
	_rampaging = false
	_rika_time = 0.0
	_rika_strike_timer = -1.0
	_ground_moves = _normal_chain
	if is_instance_valid(_rika_node):
		var node := _rika_node
		var tween := node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.35)
		tween.tween_callback(node.queue_free)
	_rika_node = null


func _tick_rika(delta: float) -> void:
	if not in_rika_state():
		return
	if state == State.KO:
		_cancel_cannon()
		_exit_rika()
		return
	_rika_time -= delta
	if _rika_time <= 0.0:
		if _cannon == Cannon.NONE:
			_exit_rika()
			return
		_rika_time = 0.01  # 純愛砲進行中,等它結束再退出

	# 開砲時里香留在原地,其餘時間跟在憂太身後
	if _cannon != Cannon.FIRING:
		var target := global_position + Vector2(RIKA_FOLLOW_OFFSET.x * facing, RIKA_FOLLOW_OFFSET.y)
		target.y += sin(Time.get_ticks_msec() / 260.0) * 6.0
		_rika_node.global_position = _rika_node.global_position.lerp(target, minf(RIKA_FOLLOW_SPEED * delta, 1.0))
		_rika_node.scale.x = facing

	if _rika_strike_timer >= 0.0:
		_rika_strike_timer -= delta
		if _rika_strike_timer < 0.0:
			_rika_strike()


## 普通攻擊命中後,里香稍後追加一擊。「不准欺負我的朋友!」打到對手就是黑閃(防禦擋不住;被無下限這類擋下就不算)。
func _on_attack_hit(target: Fighter, move: AttackData) -> void:
	if move == _friend_move:
		if target.health < _friend_health:
			_black_flash_effect(target.global_position + Vector2(0, -60))
			screen_shake.emit(10.0)
		return
	if in_rika_state() and _cannon == Cannon.NONE and _is_normal_attack(move):
		_rika_strike_timer = RIKA_STRIKE_DELAY


func _rika_strike() -> void:
	if opponent == null or opponent.is_invulnerable():
		return
	if global_position.distance_to(opponent.global_position) > RIKA_STRIKE_REACH:
		return
	_rika_claw(opponent, 130.0)
	opponent.take_hit(_rika_move, self)


## 里香撲到目標身旁揮爪的演出(不含傷害)。
func _rika_claw(target: Fighter, claw_length: float) -> void:
	Sfx.play("rika_claw")
	var side := int(signf(target.global_position.x - global_position.x))
	if side == 0:
		side = facing
	_rika_node.global_position = target.global_position + Vector2(-side * 55.0, -20.0)
	_rika_node.scale.x = side
	_summon_play(_rika_node, "rika_strike")
	var claw_center := target.global_position + Vector2(0, -60)
	# 三道爪痕;沒有點陣特效時是三條線
	if _spawn_effect("claw", claw_center, _bright(RIKA_COLOR.lightened(0.2)), claw_length / 60.0, side < 0) != null:
		return
	for angle: float in [-0.5, 0.0, 0.5]:
		var claw := _spawn_rect(Vector2(claw_length, 6), RIKA_COLOR, claw_center, 2)
		claw.rotation = 0.9 * side + angle * 0.35
		var tween := claw.create_tween()
		tween.tween_property(claw, "modulate:a", 0.0, 0.18)
		tween.tween_callback(claw.queue_free)


# ---------- 不准欺負憂太! ----------

## 里香狀態的被動:憂太實際被打中(防禦成功不算)時,有機率由里香把攻擊者拍飛。
func take_hit(move: AttackData, attacker: Fighter) -> void:
	var health_before := health
	super(move, attacker)
	var was_hit := health < health_before and state != State.GUARD and state != State.KO
	if was_hit and _rampage_ready and not in_rika_state() and health <= max_health * RAMPAGE_HEALTH:
		_rampage()
		return
	if not was_hit or not in_rika_state() or _cannon != Cannon.NONE:
		return
	if attacker.is_invulnerable() or global_position.distance_to(attacker.global_position) > PROTECT_REACH:
		return
	if GameState.rng.randf() >= (RAMPAGE_PROTECT_CHANCE if _rampaging else protect_chance):
		return
	_callout("不准欺負憂太!", RIKA_COLOR)
	_rika_claw(attacker, 190.0)
	attacker.take_hit(_protect_move, self)


## 里香的外觀:有點陣圖(assets/summons_fx)就用圖,沒有的話用色塊拼出大型咒靈暫代。
## 原點在她的正下方(尾巴底端),面向右。
func _make_rika() -> Node2D:
	var rika := Node2D.new()
	var sprite := _summon_sprite("rika")
	if sprite != null:
		rika.add_child(sprite)
		# 揮爪的動畫播完就回到漂浮待機
		sprite.animation_finished.connect(sprite.play.bind("rika"))
		get_parent().add_child(rika)
		get_parent().move_child(rika, get_index())
		return rika
	var parts := [
		# [位置, 大小, 顏色]
		[Vector2(-38, -150), Vector2(76, 120), Color(0.16, 0.15, 0.2)],       # 軀幹
		[Vector2(-30, -196), Vector2(64, 58), Color(0.93, 0.92, 0.95)],       # 頭
		[Vector2(-30, -196), Vector2(64, 16), Color(0.16, 0.15, 0.2)],        # 頭髮
		[Vector2(-18, -158), Vector2(46, 10), Color(0.75, 0.15, 0.2)],        # 嘴
		[Vector2(10, -176), Vector2(12, 8), Color(0.1, 0.1, 0.12)],           # 眼
		[Vector2(30, -130), Vector2(52, 20), Color(0.93, 0.92, 0.95)],        # 前臂
		[Vector2(70, -138), Vector2(22, 36), Color(0.93, 0.92, 0.95)],        # 爪
		[Vector2(-58, -120), Vector2(24, 70), Color(0.93, 0.92, 0.95)],       # 後臂
	]
	for part: Array in parts:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = part[0]
		rect.size = part[1]
		rect.color = part[2]
		rika.add_child(rect)
	rika.modulate = Color(1, 1, 1, 0.92)
	get_parent().add_child(rika)
	# 排在憂太前面的節點順序 = 畫在憂太後面
	get_parent().move_child(rika, get_index())
	return rika


# ---------- 真是失禮,這可是純愛 ----------

func _begin_cannon() -> void:
	if not in_rika_state():
		return
	_cannon = Cannon.CHARGING
	_cannon_time = CANNON_CHARGE
	_rika_strike_timer = -1.0
	_callout("真是失禮,這可是純愛", RIKA_COLOR, "cannon_charge")
	_cannon_charge_node = _spawn_rect(Vector2(20, 20), RIKA_COLOR, _cannon_charge_point(), 2)


## 蓄力球的位置:里香的嘴前,在憂太身後上方,不會蓋住憂太。
func _cannon_charge_point() -> Vector2:
	return _rika_node.global_position + Vector2(facing * 75.0, -185.0)


## 砲擊的起點:里香所在位置、對手身體的高度。
func _cannon_muzzle() -> Vector2:
	return _rika_node.global_position + Vector2(facing * 70.0, CANNON_HEIGHT - RIKA_FOLLOW_OFFSET.y)


func _tick_cannon(delta: float) -> void:
	if _cannon == Cannon.NONE:
		return
	_cannon_time -= delta
	if _cannon == Cannon.CHARGING:
		# 蓄力球逐漸變大並閃爍
		var progress := 1.0 - _cannon_time / CANNON_CHARGE
		var orb_size := lerpf(20.0, 110.0, progress)
		_cannon_charge_node.size = Vector2(orb_size, orb_size)
		_cannon_charge_node.pivot_offset = _cannon_charge_node.size / 2.0
		_cannon_charge_node.position = _cannon_charge_point() - _cannon_charge_node.size / 2.0
		_cannon_charge_node.rotation += delta * 4.0
		_cannon_charge_node.modulate.a = 0.7 + 0.3 * sin(_cannon_time * 25.0)
		if _cannon_time <= 0.0:
			_fire_cannon()
		return

	# 開砲中:每隔一小段時間判定一次,最後一下擊飛
	_cannon_tick -= delta
	if _cannon_tick <= 0.0:
		_cannon_tick = CANNON_TICK
		var center := _cannon_origin + Vector2(_cannon_direction * CANNON_SIZE.x / 2.0, 0)
		if _rect_hits_opponent(center, CANNON_SIZE):
			opponent.take_hit(_cannon_final_move if _cannon_time <= CANNON_TICK else _cannon_move, self)
	if _cannon_time <= 0.0:
		_cancel_cannon()
		_exit_rika()


func _fire_cannon() -> void:
	Sfx.play("cannon_fire")
	_cannon = Cannon.FIRING
	_cannon_time = CANNON_FIRE
	_cannon_tick = 0.0
	_cannon_direction = facing
	_cannon_origin = _cannon_muzzle()
	if is_instance_valid(_cannon_charge_node):
		_cannon_charge_node.queue_free()
	_cannon_charge_node = null
	var center := _cannon_origin + Vector2(_cannon_direction * CANNON_SIZE.x / 2.0, 0)
	_cannon_beam_node = _spawn_rect(CANNON_SIZE, Color(RIKA_COLOR, 0.9), center, 1)
	var beam := _summon_sprite("beam")
	if beam != null:
		# 點陣的光束:色塊本身隱藏。圖長 440 像素,橫向拉到判定的長度;砲口那一端朝著里香
		_cannon_beam_node.color = Color(RIKA_COLOR, 0.0)
		beam.position = CANNON_SIZE / 2.0
		beam.scale.x = _cannon_direction * CANNON_SIZE.x / CANNON_BEAM_ART_LENGTH
		_cannon_beam_node.add_child(beam)
	else:
		var core := ColorRect.new()
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		core.color = Color(1, 1, 1, 0.9)
		core.size = Vector2(CANNON_SIZE.x, CANNON_SIZE.y * 0.45)
		core.position = Vector2(0, CANNON_SIZE.y * 0.275)
		_cannon_beam_node.add_child(core)
	var tween := _cannon_beam_node.create_tween()
	tween.tween_interval(CANNON_FIRE * 0.6)
	tween.tween_property(_cannon_beam_node, "modulate:a", 0.0, CANNON_FIRE * 0.4)


func _cancel_cannon() -> void:
	_cannon = Cannon.NONE
	for node: ColorRect in [_cannon_charge_node, _cannon_beam_node]:
		if is_instance_valid(node):
			node.queue_free()
	_cannon_charge_node = null
	_cannon_beam_node = null


# ---------- 顯示 ----------

func _update_status() -> void:
	var parts: PackedStringArray = []
	if _cannon == Cannon.CHARGING:
		parts.append("純愛砲 %.1f" % _cannon_time)
	elif in_rika_state() and _cannon == Cannon.NONE:
		parts.append("%s %d" % ["里香失控" if _rampaging else "里香", ceili(_rika_time)])
	if _buff_time > 0.0:
		parts.append("咒力附刀 %d" % ceili(_buff_time))
	if overflowing():
		parts.append("咒力滿盈")
	_status_label.text = "   ".join(parts)
	_status_label.add_theme_color_override("font_color", RIKA_COLOR if in_rika_state() else CURSE_COLOR)


func _update_visual() -> void:
	super()
	_hair.visible = _eye.visible
	if _has_sprite and _buff_time > 0.0 and state in [State.IDLE, State.MOVE, State.JUMP, State.ATTACK, State.DASH]:
		_sprite.modulate = Color(0.8, 1.15, 1.5)
