extends Control
## 選角畫面。雙方各自左右選擇、攻擊鍵確認;都確認後進入對戰。
## P2 為電腦時,P1 確認自己的角色後,接著用同一組按鍵替電腦選角色。

const CARD_SIZE := Vector2(260, 330)
const CONFIRM_DELAY := 0.6

var _cursor: Array[int] = [0, 1]
var _confirmed: Array[bool] = [false, false]
var _starting := false
var _cards: Array[PanelContainer] = []
var _markers: Array = []  # 每張卡片上的 [P1 標記, P2 標記]
var _mode_label: Label
var _status_label: Label


func _ready() -> void:
	GameState.setup_input()
	_cursor = GameState.selection.duplicate()
	_build_ui()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		GameState.cpu_enabled = not GameState.cpu_enabled
		_confirmed[1] = false
		_refresh()
		return

	for player_index in 2:
		# 這組按鍵目前控制誰的游標
		var target := player_index
		if player_index == 0 and _confirmed[0] and GameState.cpu_enabled:
			target = 1
		elif player_index == 1 and GameState.cpu_enabled:
			continue
		if _confirmed[target]:
			continue
		var player_id := player_index + 1
		if event.is_action_pressed(GameState.action(player_id, "left")):
			_move_cursor(target, -1)
		elif event.is_action_pressed(GameState.action(player_id, "right")):
			_move_cursor(target, 1)
		elif event.is_action_pressed(GameState.action(player_id, "attack")):
			_confirmed[target] = true
			_refresh()
			_try_start()
		else:
			continue
		get_viewport().set_input_as_handled()
		return


func _move_cursor(target: int, step: int) -> void:
	_cursor[target] = posmod(_cursor[target] + step, GameState.CHARACTERS.size())
	_refresh()


func _try_start() -> void:
	if not (_confirmed[0] and _confirmed[1]):
		return
	_starting = true
	GameState.selection = [_cursor[0], _cursor[1]]
	_status_label.text = "對戰開始!"
	await get_tree().create_timer(CONFIRM_DELAY).timeout
	get_tree().change_scene_to_file(GameState.FIGHT_SCENE)


func _refresh() -> void:
	for card_index in _cards.size():
		for player_index in 2:
			var marker: Label = _markers[card_index][player_index]
			marker.visible = _cursor[player_index] == card_index
			var who := "P1" if player_index == 0 else ("電腦" if GameState.cpu_enabled else "P2")
			marker.text = "%s%s" % [who, " OK" if _confirmed[player_index] else ""]
	_mode_label.text = "P2:%s(F1 切換)" % ("電腦操作" if GameState.cpu_enabled else "玩家操作")
	if not _confirmed[0]:
		_status_label.text = "P1 選擇角色:A / D 移動,J 確認"
	elif not _confirmed[1]:
		if GameState.cpu_enabled:
			_status_label.text = "選擇電腦的角色:A / D 移動,J 確認"
		else:
			_status_label.text = "P2 選擇角色:← / → 移動,數字鍵盤 1 確認"
	if not GameState.cpu_enabled and not _confirmed[0] and not _confirmed[1]:
		_status_label.text = "P1:A / D 移動,J 確認      P2:← / → 移動,數字鍵盤 1 確認"


# ---------- 介面 ----------

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.11, 0.17)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 26)
	add_child(column)

	column.add_child(_label("選擇角色", 48))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	column.add_child(row)
	for info: Dictionary in GameState.CHARACTERS:
		row.add_child(_build_card(info))

	_status_label = _label("", 22)
	column.add_child(_status_label)
	_mode_label = _label("", 16)
	_mode_label.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_mode_label)


func _build_card(info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.19, 0.28)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	# P1 / P2 游標標記
	var marker_row := HBoxContainer.new()
	marker_row.custom_minimum_size = Vector2(0, 30)
	box.add_child(marker_row)
	var pair: Array[Label] = []
	for player_index in 2:
		var marker := _label("", 20)
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if player_index == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		marker.add_theme_color_override("font_color", GameState.PLAYER_COLORS[player_index].lightened(0.2))
		marker_row.add_child(marker)
		pair.append(marker)
	_markers.append(pair)

	# 角色示意:身體色塊 + 頭髮色塊
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(0, 130)
	box.add_child(portrait)
	var center_x := CARD_SIZE.x / 2.0 - 16
	var loaded := SpriteSheetLoader.load_character(info.get("sprites", ""))
	if loaded.is_empty():
		# 沒有素材時的後備:身體色塊 + 頭髮色塊
		var body := ColorRect.new()
		body.color = Color(0.6, 0.62, 0.7)
		body.size = Vector2(50, 100)
		body.position = Vector2(center_x - 25, 26)
		portrait.add_child(body)
		var hair := ColorRect.new()
		hair.color = info.hair
		hair.size = Vector2(56, 20)
		hair.position = body.position + Vector2(-3, -14)
		portrait.add_child(hair)
	else:
		var canvas: Vector2 = loaded.canvas
		var sprite := AnimatedSprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = loaded.frames
		sprite.centered = false
		sprite.scale = Vector2.ONE * float(loaded.scale)
		sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y)
		sprite.position = Vector2(center_x, 130)
		portrait.add_child(sprite)
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

	box.add_child(_label(info.name, 30))
	var summary := _label(info.summary, 16)
	summary.modulate = Color(1, 1, 1, 0.8)
	box.add_child(summary)

	_cards.append(card)
	return card


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
