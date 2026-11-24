extends Control
## 主畫面選單:故事模式、連線對戰、電腦對戰。遊戲一開始和每個模式結束後都回到這裡。
## 鍵盤用 W / S(或上下鍵)移動、J(或 Enter)確認;也可以直接點。
## 連線對戰的房間視窗(NetLobby)開在這個畫面上,兩個人到齊後才進選角畫面。

const ITEMS: Array[Dictionary] = [
	{"id": "story", "title": "故事模式", "note": "選一位角色,一章一章體驗他的故事", "color": Color(1.0, 0.76, 0.38)},
	{"id": "net", "title": "連線對戰", "note": "建立房間或輸入房間號碼,和朋友對打", "color": Color(0.45, 0.74, 1.0)},
	{"id": "cpu", "title": "電腦對戰", "note": "自由選角,和電腦對打", "color": Color(0.56, 0.88, 0.62)},
]
const BUTTON_SIZE := Vector2(460, 92)
const SHOWCASE := ["乙骨憂太", "五條悟", "金木研", "波風湊"]  # 兩側站著的角色,從裡面挑兩位

var _cursor := 0
var _buttons: Array[PanelContainer] = []
var _pressed := -1          # 滑鼠 / 手指正按住哪一個項目
var _lobby: NetLobby        # 房間視窗;沒開啟時是 null
var _leaving := false
var _safe_controls: Array[Control] = []
var _toast_label: Label


func _ready() -> void:
	GameState.setup_input()
	Sfx.warm_up()
	Sfx.play_music("select")
	# 回到主選單就是離開了任何進行中的模式
	GameState.story_fight = {}
	GameState.story_result = ""
	if GameState.net_active():
		NetSession.get_session().leave()
		GameState.set_net_role(0)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_refresh()
	if not GameState.menu_notice.is_empty():
		_toast(GameState.menu_notice)
		GameState.menu_notice = ""


func _on_viewport_resized() -> void:
	for control in _safe_controls:
		GameState.fit_to_safe_area(control)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _lobby != null:
		return
	var step := 0
	var confirm := false
	for player_id in [1, 2]:
		if event.is_action_pressed(GameState.action(player_id, "up")):
			step = -1
		elif event.is_action_pressed(GameState.action(player_id, "down")):
			step = 1
		elif event.is_action_pressed(GameState.action(player_id, "attack")):
			confirm = true
	if event.is_action_pressed("ui_accept"):
		confirm = true
	if step != 0:
		_cursor = posmod(_cursor + step, ITEMS.size())
		Sfx.play("ui_move")
		_refresh()
		get_viewport().set_input_as_handled()
	elif confirm:
		get_viewport().set_input_as_handled()
		_choose(_cursor)


func _choose(index: int) -> void:
	if _leaving or _lobby != null:
		return
	_cursor = index
	_refresh()
	Sfx.play("ui_confirm")
	match str(ITEMS[index].id):
		"story":
			_go(GameState.STORY_SCENE)
		"cpu":
			GameState.cpu_enabled = true
			_go(GameState.SELECT_SCENE)
		"net":
			_lobby = NetLobby.new()
			_lobby.paired.connect(_on_lobby_paired)
			_lobby.cancelled.connect(_close_lobby)
			add_child(_lobby)


func _go(scene: String) -> void:
	_leaving = true
	get_tree().change_scene_to_file(scene)


func _close_lobby() -> void:
	if _lobby != null:
		_lobby.queue_free()
		_lobby = null


## 兩個人到齊:進選角畫面,每個人只選自己的角色(選角畫面看到連線還在,就會用連線的方式選角)。
func _on_lobby_paired() -> void:
	GameState.set_net_role(NetSession.get_session().role)
	_go(GameState.SELECT_SCENE)


func _on_item_input(event: InputEvent, index: int) -> void:
	if _leaving or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	# 放開時才算數:按下的那一下如果換了畫面,放開會落在新的畫面上
	if click.pressed:
		_pressed = index
		_cursor = index
		_refresh()
	elif _pressed == index:
		_pressed = -1
		_choose(index)


func _refresh() -> void:
	for index in _buttons.size():
		var style := _buttons[index].get_theme_stylebox("panel") as StyleBoxFlat
		var color: Color = ITEMS[index].color
		# 鍵盤操作時,游標所在的項目比較亮;觸控沒有游標
		var focused := index == _cursor and not GameState.touch_enabled
		style.border_color = color if focused else Color(color, 0.4)
		style.bg_color = Color(0.2, 0.23, 0.34) if focused else Color(0.15, 0.17, 0.25)


func _toast(text: String) -> void:
	_toast_label.text = text
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_toast_label) and _toast_label.text == text:
		_toast_label.text = ""


# ---------- 介面 ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.11, 0.17)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_build_showcase()

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_safe_controls.append(column)
	GameState.fit_to_safe_area(column)

	var title := _label("ANIFIGHT", 76)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.12, 0.2))
	title.add_theme_constant_override("outline_size", 10)
	column.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	for index in ITEMS.size():
		column.add_child(_build_item(index))
	var hint := _label("" if GameState.touch_enabled else "W / S 移動      J 確認", 16)
	hint.modulate = Color(1, 1, 1, 0.6)
	column.add_child(hint)

	_build_corner_buttons()


## 一個選單項目:大字的名稱,下面一行小字說明。
func _build_item(index: int) -> PanelContainer:
	var info: Dictionary = ITEMS[index]
	var item := PanelContainer.new()
	item.custom_minimum_size = BUTTON_SIZE
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.set_content_margin_all(10)
	item.add_theme_stylebox_override("panel", style)
	item.gui_input.connect(_on_item_input.bind(index))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	item.add_child(box)
	var title := _label(info.title, 36)
	title.add_theme_color_override("font_color", (info.color as Color).lightened(0.35))
	box.add_child(title)
	var note := _label(info.note, 16)
	note.modulate = Color(1, 1, 1, 0.7)
	box.add_child(note)
	_buttons.append(item)
	return item


## 選單兩側各站一位角色(待機動畫),純裝飾。
func _build_showcase() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var names := SHOWCASE.duplicate()
	names.shuffle()
	for side in 2:
		var index := GameState.find_character(names[side])
		if index < 0:
			continue
		var loaded := SpriteSheetLoader.load_character(GameState.CHARACTERS[index].get("sprites", ""))
		if loaded.is_empty():
			continue
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.anchor_left = 0.14 if side == 0 else 0.86
		holder.anchor_right = holder.anchor_left
		holder.anchor_top = 0.82
		holder.anchor_bottom = 0.82
		layer.add_child(holder)
		var canvas: Vector2 = loaded.canvas
		var sprite := AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = loaded.frames
		sprite.centered = false
		sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y)
		# 比對戰時大一些;右邊那位面向左
		var size := float(loaded.scale) * 2.0
		sprite.scale = Vector2(size if side == 0 else -size, size)
		sprite.modulate = Color(1, 1, 1, 0.9)
		holder.add_child(sprite)
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


## 角落的按鈕:左上是音效開關,右上是全螢幕(觸控);畫面下方是一行會自己消失的提示。
func _build_corner_buttons() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_safe_controls.append(overlay)
	GameState.fit_to_safe_area(overlay)

	var sound := Button.new()
	sound.focus_mode = Control.FOCUS_NONE
	sound.add_theme_font_size_override("font_size", 20)
	sound.offset_left = 30
	sound.offset_right = 150
	sound.offset_top = 24
	sound.offset_bottom = 72
	Sfx.setup_button(sound)
	overlay.add_child(sound)

	_toast_label = _label("", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = -44
	_toast_label.offset_bottom = -10
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_toast_label)

	if not GameState.touch_enabled:
		return
	var platform := GameState.web_platform()
	if platform.get("fullscreen", true):
		# 手機瀏覽器的網址列很佔空間,提供全螢幕切換
		var fullscreen := Button.new()
		fullscreen.text = "全螢幕"
		fullscreen.focus_mode = Control.FOCUS_NONE
		fullscreen.add_theme_font_size_override("font_size", 20)
		fullscreen.anchor_left = 1.0
		fullscreen.anchor_right = 1.0
		fullscreen.offset_left = -150
		fullscreen.offset_right = -30
		fullscreen.offset_top = 24
		fullscreen.offset_bottom = 72
		fullscreen.pressed.connect(_toggle_fullscreen)
		overlay.add_child(fullscreen)
	elif platform.get("ios", false) and not platform.get("standalone", false):
		# iPhone 的 Safari 不支援網頁全螢幕;從主畫面開啟才不會有網址列
		_toast_label.text = "想要全螢幕:點 Safari 的分享按鈕,選「加入主畫面」,再從主畫面開啟"
		_toast_label.add_theme_font_size_override("font_size", 16)
	OrientationNotice.attach_if_touch(self)


func _toggle_fullscreen() -> void:
	var window := get_window()
	var is_fullscreen := window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	window.mode = Window.MODE_WINDOWED if is_fullscreen else Window.MODE_FULLSCREEN


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
