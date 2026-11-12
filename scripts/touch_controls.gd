class_name TouchControls
extends CanvasLayer
## 對戰畫面的觸控按鈕。每顆按鈕直接按下 / 放開對應玩家的輸入動作,
## 所以角色與電腦對手的程式都不用知道現在是鍵盤還是觸控。
##
## 左下:左、右移動與防禦。右下:3x3 的動作按鈕。
## 上方:回選角。整場結束時在畫面中央顯示「再戰一場 / 回選角」。

signal rematch_requested
signal back_requested

const BUTTON_SIZE := 104.0
const BUTTON_GAP := 10.0
const MARGIN := Vector2(24, 22)  # 離安全區邊緣的距離;瀏海與圓角由安全區處理
const IDLE_ALPHA := 0.42
const PRESSED_ALPHA := 0.9

## 要操作的玩家編號
var player_id: int = 1

var _buttons: Array[Dictionary] = []  # {node, side("left"/"right"), offset(離角落的距離)}
var _skill_labels: Array[Label] = []
var _menu_root: Control
var _menu_button: Button
var _match_over_box: VBoxContainer


func _ready() -> void:
	layer = 5
	var step := BUTTON_SIZE + BUTTON_GAP
	var half := BUTTON_SIZE / 2.0

	# 方向:上排左右,下排防禦。滑過去就算按下,拇指不用離開螢幕。
	_add_button("left", "◀", "left", Vector2(half, half + step), true)
	_add_button("right", "▶", "left", Vector2(half + step, half + step), true)
	_add_button("down", "防禦", "left", Vector2(half + step / 2.0, half), true)

	# 動作:由右下角往左、往上排
	var grid := [
		["attack", "攻擊"], ["jump", "跳"], ["dash", "衝刺"],
		["skill", "技能"], ["skill2", "技能"], ["special", "大招"],
		["super", "超必殺"], ["teleport", "幽步"], ["escape", "脫出"],
	]
	for index in grid.size():
		@warning_ignore("integer_division")
		var offset := Vector2(half + (index % 3) * step, half + (index / 3) * step)
		var label := _add_button(grid[index][0], grid[index][1], "right", offset, false)
		if grid[index][0] in ["skill", "skill2", "super"]:
			_skill_labels.append(label)

	_build_menu()
	get_viewport().size_changed.connect(_layout)
	_layout()


## 把三顆招式按鈕的文字換成角色自己的招式名稱(技能、上+技能、超必殺)。
func set_skill_labels(labels: Array) -> void:
	for i in mini(labels.size(), _skill_labels.size()):
		_skill_labels[i].text = str(labels[i])


func set_match_over(is_over: bool) -> void:
	_match_over_box.visible = is_over
	_menu_button.visible = not is_over


func _add_button(action_name: String, text: String, side: String, offset: Vector2, passby: bool) -> Label:
	var button := TouchScreenButton.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * BUTTON_SIZE
	button.shape = shape
	button.action = GameState.action(player_id, action_name)
	button.passby_press = passby
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(button)

	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.92, 1.0, 0.28)
	style.border_color = Color(1, 1, 1, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	face.add_theme_stylebox_override("panel", style)
	face.size = Vector2.ONE * BUTTON_SIZE
	face.position = -face.size / 2.0
	button.add_child(face)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.size = face.size
	label.position = face.position
	button.add_child(label)

	button.modulate.a = IDLE_ALPHA
	button.pressed.connect(func() -> void: button.modulate.a = PRESSED_ALPHA)
	button.released.connect(func() -> void: button.modulate.a = IDLE_ALPHA)
	_buttons.append({"node": button, "side": side, "offset": offset})
	return label


func _build_menu() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_menu_root = root

	_menu_button = _make_menu_button("回選角", 18, Vector2(96, 40))
	_menu_button.anchor_left = 0.5
	_menu_button.anchor_right = 0.5
	_menu_button.offset_left = -48
	_menu_button.offset_right = 48
	_menu_button.offset_top = 74
	_menu_button.offset_bottom = 114
	_menu_button.modulate.a = 0.75
	_menu_button.pressed.connect(func() -> void: back_requested.emit())
	root.add_child(_menu_button)

	_match_over_box = VBoxContainer.new()
	_match_over_box.add_theme_constant_override("separation", 16)
	_match_over_box.anchor_left = 0.5
	_match_over_box.anchor_right = 0.5
	_match_over_box.anchor_top = 0.5
	_match_over_box.anchor_bottom = 0.5
	_match_over_box.offset_left = -150
	_match_over_box.offset_right = 150
	_match_over_box.offset_top = 70
	_match_over_box.offset_bottom = 230
	_match_over_box.visible = false
	root.add_child(_match_over_box)
	var rematch := _make_menu_button("再戰一場", 28, Vector2(300, 72))
	rematch.pressed.connect(func() -> void: rematch_requested.emit())
	_match_over_box.add_child(rematch)
	var back := _make_menu_button("回選角", 28, Vector2(300, 72))
	back.pressed.connect(func() -> void: back_requested.emit())
	_match_over_box.add_child(back)


func _make_menu_button(text: String, font_size: int, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", font_size)
	return button


## 依目前畫面大小,把按鈕貼齊安全區的左下與右下角。
func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var area := GameState.safe_area(get_viewport())  # 左, 上, 右, 下
	GameState.fit_to_safe_area(_menu_root)
	for entry in _buttons:
		var node: TouchScreenButton = entry.node
		var offset: Vector2 = entry.offset + MARGIN
		var x := area.x + offset.x if entry.side == "left" else view.x - area.z - offset.x
		node.position = Vector2(x, view.y - area.w - offset.y)
