class_name Sfx
extends Node
## 音效管理器。遊戲各處呼叫 Sfx.play("名稱") 就會播放 assets/sfx/ 底下對應的音效。
##
## 音效檔由 tools/make_sfx.py 合成;有多個變化版的(hit_light_1、hit_light_2…)每次隨機挑一個。
## 網頁版的音訊功能比較少(不保證能變調、不保證匯流排靜音有效),所以這裡不用那些功能:
## 變化靠多個檔案,靜音靠「乾脆不播」,同時發聲靠多個播放器輪流用。
##
## 靜音:鍵盤 M,或畫面上的音效按鈕。設定會存起來,下次開啟沿用。
##
## 實際播放的是掛在場景樹根部的一個 Sfx 節點,播放器和音效檔都由它持有,
## 遊戲關閉時跟著場景樹一起釋放。靜態變數只放純資料,不放節點、資源或 Callable。

## 靜音狀態改變。button_label 是音效按鈕上要顯示的新文字。
signal muted_changed(button_label: String)

const DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 12          # 最多同時播放幾個聲音
const MIN_INTERVAL := 60    # 同一個音效至少隔幾毫秒才再播(多段攻擊同一瞬間打好幾下時不會疊成爆音)

## 音效名稱 -> 變化版數量。要和 tools/make_sfx.py 的 SOUNDS 一致。
const SOUNDS := {
	# 共用戰鬥
	"swing": 2, "hit_light": 3, "hit_heavy": 2, "guard": 1, "land": 1, "down": 1, "jump": 1,
	"dash": 1, "teleport": 1, "burst": 1, "ko": 1, "special": 1, "bounce": 2, "wall_crash": 1,
	# 介面
	"ui_move": 1, "ui_confirm": 1, "ui_start": 1, "round_start": 1, "time_up": 1, "victory": 1,
	# 招牌招式
	"black_flash": 1, "domain_void": 1, "domain_shrine": 1, "slash": 2, "blue": 1, "red": 1,
	"infinity": 1, "overflow": 1, "powerup": 1, "speech": 1, "friend_charge": 1, "rika_summon": 1,
	"rika_claw": 1, "cannon_charge": 1, "cannon_fire": 1, "shikigami": 2, "combine": 1,
	"divergent": 1, "parry": 1, "weapon_swap": 1, "bind": 1,
	# 火影忍者系列
	"kunai": 2, "rasengan": 1, "rasengan_burst": 1, "mark": 1, "poof": 1,
	"chidori": 1, "thunder": 1, "fireball": 1, "kirin_charge": 1, "kirin": 1, "snake_bite": 1, "snake_cage": 1,
}

static var muted := false
## 每個音效被要求播放的次數(不論有沒有靜音)。給測試確認播放點用。
static var requests: Dictionary = {}

## 現在應該播的背景音樂(assets/music/ 底下的檔名,不含副檔名);空字串代表不播。
static var music := ""

static var _instance_id := 0              # 根部那個 Sfx 節點的 instance id;0 代表還沒建立
static var _last_played: Dictionary = {}  # 名稱 -> 上次播放的時間(毫秒)
static var _settings_loaded := false

var _streams: Dictionary = {}  # 名稱 -> Array[AudioStream]
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_player: AudioStreamPlayer
var _music_playing := ""       # 播放器現在放的是哪一首
var _music_streams: Dictionary = {}  # 曲名 -> AudioStream
var _unlocked := false         # 玩家按過任何鍵 / 點過畫面了沒(瀏覽器在那之前不給播聲音)


## 播放一個音效。variant 指定要第幾個變化版(從 0 起算);不指定就隨機。
static func play(sound: String, variant: int = -1) -> void:
	requests[sound] = requests.get(sound, 0) + 1
	var host := _host()
	if muted or host == null or not host.is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -MIN_INTERVAL)) < MIN_INTERVAL:
		return
	var streams: Array = host._streams.get(sound, [])
	if streams.is_empty():
		return
	_last_played[sound] = now
	host._play(streams[variant % streams.size()] if variant >= 0 else streams.pick_random())


## 在場景一開始呼叫:先把播放器和音效檔準備好,第一個音效才不會漏掉或卡頓。
static func warm_up() -> void:
	_host()


## 換背景音樂(循環播放)。已經在播同一首就不會重頭來;傳空字串是停止。
static func play_music(track: String) -> void:
	music = track
	var host := _host()
	if host != null and host.is_inside_tree():
		host._sync_music()


static func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	var config := ConfigFile.new()
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)
	var host := _host()
	if host == null:
		return
	if muted:
		for player in host._players:
			player.stop()
	host._sync_music()
	host.muted_changed.emit(button_text())


static func toggle_muted() -> void:
	set_muted(not muted)


## 音效按鈕上要顯示的文字。
static func button_text() -> String:
	return "聲音:關" if muted else "聲音:開"


## 把一個按鈕變成音效開關:按下切換靜音,文字跟著靜音狀態更新(用鍵盤 M 切換時也會更新)。
## 連線接在按鈕自己的方法上,按鈕被釋放時會自動斷開。
static func setup_button(button: Button) -> void:
	button.text = button_text()
	button.pressed.connect(_on_button_pressed)
	var host := _host()
	if host != null:
		host.muted_changed.connect(button.set_text)


static func _on_button_pressed() -> void:
	toggle_muted()
	play("ui_confirm")


## 取得掛在場景樹根部的管理器;第一次呼叫時建立。
static func _host() -> Sfx:
	if not _settings_loaded:
		_settings_loaded = true
		var config := ConfigFile.new()
		if config.load(SETTINGS_PATH) == OK:
			muted = config.get_value("audio", "muted", false)
	var host := instance_from_id(_instance_id) as Sfx if _instance_id != 0 else null
	if host == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		host = Sfx.new()
		host.name = "Sfx"
		_instance_id = host.get_instance_id()
		# 場景還在建立時不能直接加到根節點,延後到這一幀結束
		tree.root.add_child.call_deferred(host)
	return host


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for sound: String in SOUNDS:
		var count: int = SOUNDS[sound]
		var streams: Array = []
		for i in count:
			var path := "%s%s%s.wav" % [DIR, sound, "_%d" % (i + 1) if count > 1 else ""]
			var stream := load(path) as AudioStream
			if stream == null:
				push_warning("找不到音效檔:%s" % path)
			else:
				streams.append(stream)
		_streams[sound] = streams
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_sync_music()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_muted()
	# 瀏覽器要等玩家第一次按鍵或點畫面才准播聲音:那一刻把音樂重新起頭,不然會一直沒有音樂
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if pressed and not _unlocked:
		_unlocked = true
		_music_playing = ""
		_sync_music()


## 讓音樂播放器的狀態符合「現在該播哪一首、有沒有靜音」。
func _sync_music() -> void:
	var wanted := "" if muted else music
	if wanted == _music_playing and (wanted.is_empty() or _music_player.playing):
		return
	_music_playing = wanted
	_music_player.stop()
	if wanted.is_empty():
		return
	if not _music_streams.has(wanted):
		var path := "%s%s.wav" % [MUSIC_DIR, wanted]
		var stream := load(path) as AudioStreamWAV if ResourceLoader.exists(path) else null
		if stream != null:
			# 從頭到尾循環
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_music_streams[wanted] = stream
	var music_stream: AudioStream = _music_streams[wanted]
	if music_stream == null:
		return
	_music_player.stream = music_stream
	_music_player.play()


func _play(stream: AudioStream) -> void:
	# 找一個閒著的播放器;都在忙就輪流蓋掉
	var player: AudioStreamPlayer = null
	for candidate in _players:
		if not candidate.playing:
			player = candidate
			break
	if player == null:
		player = _players[_next_player]
		_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.play()
