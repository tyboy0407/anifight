class_name StoryDialogue
extends Control
## 故事模式的對話視窗:蓋滿整個畫面,左右各站一個人,下方是對話框,字一個一個出現。
## 點畫面(或按 J / Enter / 空白鍵)繼續:字還沒出完就先全部顯示,出完了就換下一句。右上角可以跳過整段。
## 用法:add_child(dialogue);dialogue.play(lines, hero_id);播完(或跳過)發出 finished。
## lines 的格式見 StoryData:每一句是 [誰, 內容] 或 [誰, 內容, 顯示的名字],「誰」是空字串就是旁白。

signal finished

const TYPE_SPEED := 42.0          # 每秒出現幾個字
const PORTRAIT_SCALE := 2.0       # 立繪比對戰時的角色大幾倍
const BIG_SCALE := 1.5            # 體型特別大的(里香)放大的倍率
const DIM := Color(0.38, 0.38, 0.46)
const NARRATION_COLOR := Color(0.8, 0.86, 1.0)
const BOX_HEIGHT := 190.0

var _lines: Array = []
var _hero := ""                   # 主角的 id:固定站左邊,其他人站右邊
var _index := -1
var _shown := 0.0                 # 這一句已經出現幾個字
var _done := false
var _slots: Array[Control] = []   # 左、右兩個立繪的位置
var _slot_who: Array[String] = ["", ""]
var _name_label: Label
var _text_label: Label
var _next_label: Label
var _safe: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 整個畫面都可以點,也擋住後面的東西
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.05, 0.09)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	# 背景:對戰場地的夜空,壓暗
	var sky_path := "res://assets/stage/sky.png"
	if ResourceLoader.exists(sky_path):
		var sky := TextureRect.new()
		sky.texture = load(sky_path)
		sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sky.modulate = Color(0.55, 0.55, 0.7)
		sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sky)

	_safe = Control.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	GameState.fit_to_safe_area(_safe)
	get_viewport().size_changed.connect(func() -> void: GameState.fit_to_safe_area(_safe))

	# 立繪:腳踩在對話框的上緣
	for side in 2:
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.anchor_left = 0.2 if side == 0 else 0.8
		slot.anchor_right = slot.anchor_left
		slot.anchor_top = 1.0
		slot.anchor_bottom = 1.0
		slot.offset_top = -BOX_HEIGHT - 24
		slot.offset_bottom = -BOX_HEIGHT - 24
		_safe.add_child(slot)
		_slots.append(slot)

	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.anchor_right = 1.0
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = -BOX_HEIGHT - 16
	box.offset_bottom = -16
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.16, 0.94)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.62, 0.9, 0.7)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", style)
	_safe.add_child(box)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	column.add_child(_name_label)
	_text_label = Label.new()
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_label.add_theme_font_size_override("font_size", 26)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text_label)
	_next_label = Label.new()
	_next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_label.text = "▼ 點一下繼續" if GameState.touch_enabled else "▼ J 繼續"
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_label.add_theme_font_size_override("font_size", 16)
	_next_label.modulate = Color(1, 1, 1, 0.6)
	column.add_child(_next_label)

	var skip := Button.new()
	skip.text = "跳過 ▶"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 20)
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -150
	skip.offset_right = -30
	skip.offset_top = 24
	skip.offset_bottom = 72
	skip.pressed.connect(_finish)
	_safe.add_child(skip)


## 開始播一段對話。hero 是主角在 StoryData.CAST 裡的 id。
func play(lines: Array, hero: String) -> void:
	_lines = lines
	_hero = hero
	_index = -1
	_done = false
	if _lines.is_empty():
		_finish.call_deferred()
		return
	_advance()


func _process(delta: float) -> void:
	if _done or _index < 0:
		return
	var total := _text_label.get_total_character_count()
	if _shown < total:
		_shown = minf(_shown + TYPE_SPEED * delta, total)
		_text_label.visible_characters = int(_shown)
	_next_label.visible = _shown >= total


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tap()


func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	match (event as InputEventKey).physical_keycode:
		KEY_J, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_KP_1:
			_tap()
		KEY_ESCAPE:
			_finish()


## 字還沒出完:全部顯示;出完了:下一句。
func _tap() -> void:
	if _done:
		return
	var total := _text_label.get_total_character_count()
	if _shown < total:
		_shown = total
		_text_label.visible_characters = -1
	else:
		Sfx.play("ui_move")
		_advance()


func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_finish()
		return
	var line: Array = _lines[_index]
	var who := str(line[0])
	_text_label.text = str(line[1])
	_text_label.visible_characters = 0
	_shown = 0.0
	if who.is_empty():
		# 旁白:沒有名字,兩邊的人都退到暗處
		_name_label.text = ""
		_text_label.add_theme_color_override("font_color", NARRATION_COLOR)
		_light(-1)
		return
	var cast: Dictionary = StoryData.CAST.get(who, {})
	_name_label.text = str(line[2]) if line.size() > 2 else str(cast.get("name", who))
	_text_label.add_theme_color_override("font_color", Color.WHITE)
	var side := 0 if who == _hero else 1
	if _slot_who[side] != who:
		_slot_who[side] = who
		_fill_slot(_slots[side], cast, side == 1)
	_light(side)


## 說話的那一邊亮起來,另一邊變暗。side 是 -1 時兩邊都暗。
func _light(side: int) -> void:
	for index in 2:
		_slots[index].modulate = Color.WHITE if index == side else DIM


## 在 slot 裡放上這個人的圖(待機動畫);flip 是面向左。
func _fill_slot(slot: Control, cast: Dictionary, flip: bool) -> void:
	for child in slot.get_children():
		child.queue_free()
	var dir := str(cast.get("sprites", ""))
	if cast.has("character"):
		var index := GameState.find_character(str(cast.character))
		if index >= 0:
			dir = str(GameState.CHARACTERS[index].get("sprites", ""))
	var loaded := SpriteSheetLoader.load_character(dir)
	if loaded.is_empty():
		return
	var animation := str(cast.get("animation", "idle"))
	var sprite := AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = loaded.frames
	var big: bool = cast.get("big", false)
	# scale 是另外再放大的倍率(巨型咒靈);tint 是染色(用同一套圖的不同咒靈)
	var size := float(loaded.scale) * (BIG_SCALE if big else PORTRAIT_SCALE) * float(cast.get("scale", 1.0))
	sprite.scale = Vector2(-size if flip else size, size)
	sprite.self_modulate = cast.get("tint", Color.WHITE)
	if big:
		# 召喚物那一組圖:對齊點已經在腳底,不用再位移;本來就很大,放大的倍率小一點
		sprite.centered = true
	else:
		var canvas: Vector2 = loaded.canvas
		sprite.centered = false
		sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y)
	slot.add_child(sprite)
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
