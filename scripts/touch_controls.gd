class_name TouchControls
extends CanvasLayer
## 對戰畫面的觸控按鈕。按鈕直接按下 / 放開對應玩家的輸入動作,
## 所以角色與電腦對手的程式都不用知道現在是鍵盤還是觸控。
##
## 左下:左、右兩個三角形方向鍵,下方是長方形的防禦鍵。
## 右下:大圓的普攻,周圍是招式一、招式二、大招(超必殺)、跳、衝刺。
## 衝刺鍵有三種作用:
##   點一下     立刻衝刺(倒地時是快速起身)
##   按住 1 秒  發動幽步
##   受擊時     變成脫出
## 上方:回選角。整場結束時在畫面中央顯示「再戰一場 / 回選角」。

signal rematch_requested
signal back_requested

const MARGIN := Vector2(24, 22)  # 離安全區邊緣的距離;瀏海與圓角由安全區處理
const IDLE_ALPHA := 0.45
const PRESSED_ALPHA := 0.95
const FILL_COLOR := Color(0.9, 0.92, 1.0, 0.28)
const BORDER_COLOR := Color(1, 1, 1, 0.8)
const TELEPORT_HOLD := 1.0        # 衝刺鍵按住多久變成幽步
const TELEPORT_RETRY := 0.12      # 幽步沒放出來(例如人在空中)時,按住期間多久再試一次
const PULSE_TIME := 0.05          # 由程式代按的動作要按住多久
const DASH_TEXT := "衝刺"
const TELEPORT_TEXT := "幽步"
const ESCAPE_TEXT := "脫出"

## 按鈕配置。offset 是按鈕中心離「所在那一側的下方角落」的距離;size 是直徑或寬高。
const LAYOUT := [
	{"key": "left", "action": "left", "shape": "triangle_left", "side": "left", "offset": Vector2(86, 198), "size": Vector2(112, 140), "passby": true},
	{"key": "right", "action": "right", "shape": "triangle_right", "side": "left", "offset": Vector2(204, 198), "size": Vector2(112, 140), "passby": true},
	{"key": "down", "action": "down", "shape": "rect", "side": "left", "offset": Vector2(146, 62), "size": Vector2(180, 112), "text": "防禦", "passby": true},
	{"key": "attack", "action": "attack", "shape": "circle", "side": "right", "offset": Vector2(181, 105), "size": Vector2(156, 156), "text": "普攻", "font": 34},
	{"key": "skill", "action": "skill", "shape": "circle", "side": "right", "offset": Vector2(368, 82), "size": Vector2(88, 88), "text": "招式一", "font": 20},
	{"key": "skill2", "action": "skill2", "shape": "circle", "side": "right", "offset": Vector2(319, 224), "size": Vector2(104, 104), "text": "招式二", "font": 22},
	{"key": "super", "action": "super", "shape": "circle", "side": "right", "offset": Vector2(156, 286), "size": Vector2(126, 126), "text": "大招", "font": 26},
	{"key": "jump", "action": "jump", "shape": "circle", "side": "right", "offset": Vector2(48, 186), "size": Vector2(92, 92), "text": "跳", "font": 24},
	# 衝刺鍵沒有固定的動作,由 _on_dash_pressed 決定要送出什麼
	{"key": "dash", "action": "", "shape": "circle", "side": "right", "offset": Vector2(49, 60), "size": Vector2(86, 86), "text": DASH_TEXT, "font": 22},
]

## 要操作的玩家編號
var player_id: int = 1
## 被操作的角色。用來判斷是否正在受擊、幽步是否已經放出。
var fighter: Fighter

var _buttons: Array[Dictionary] = []  # {key, node, side, offset}
var _dash_button: TouchScreenButton
var _dash_label: Label
var _dash_held := false
var _dash_time := 0.0
var _teleport_timer := 0.0
var _teleport_done := false
var _pulses: Dictionary = {}  # 代按中的動作 -> 剩餘秒數
var _menu_root: Control
var _menu_button: Button
var _match_over_box: VBoxContainer


func _ready() -> void:
	layer = 5
	for spec: Dictionary in LAYOUT:
		_add_button(spec)
	_dash_button.pressed.connect(_on_dash_pressed)
	_dash_button.released.connect(_on_dash_released)
	_build_menu()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_on_dash_released()
	for action_name: String in _pulses.keys():
		Input.action_release(action_name)
	_pulses.clear()


func _process(delta: float) -> void:
	for action_name: String in _pulses.keys():
		_pulses[action_name] -= delta
		if _pulses[action_name] <= 0.0:
			Input.action_release(action_name)
			_pulses.erase(action_name)

	if _dash_held:
		_dash_time += delta
		if _is_teleporting():
			_teleport_done = true  # 每次按住只發動一次幽步
		elif _dash_time >= TELEPORT_HOLD and not _teleport_done:
			# 按住滿一秒:發動幽步。當下放不出來(例如人在空中)就每隔一小段時間再試。
			_teleport_timer -= delta
			if _teleport_timer <= 0.0:
				_teleport_timer = TELEPORT_RETRY
				_pulse("teleport")
	_update_dash_label()


func set_match_over(is_over: bool) -> void:
	_match_over_box.visible = is_over
	_menu_button.visible = not is_over


# ---------- 衝刺鍵 ----------

func _is_hit() -> bool:
	return fighter != null and fighter.can_escape()


func _is_teleporting() -> bool:
	return fighter != null and fighter.state == Fighter.State.TELEPORT


func _on_dash_pressed() -> void:
	if _is_hit():
		_pulse("escape")
		return
	_dash_held = true
	_dash_time = 0.0
	_teleport_timer = 0.0
	_teleport_done = false
	Input.action_press(GameState.action(player_id, "dash"))


func _on_dash_released() -> void:
	if _dash_held:
		_dash_held = false
		Input.action_release(GameState.action(player_id, "dash"))


## 代替玩家按一下某個動作。
func _pulse(action_name: String) -> void:
	var action := GameState.action(player_id, action_name)
	if not _pulses.has(action):
		Input.action_press(action)
	_pulses[action] = PULSE_TIME


func _update_dash_label() -> void:
	var text := DASH_TEXT
	var color := Color.WHITE
	if _is_hit():
		text = ESCAPE_TEXT
		# 氣不夠脫出時顯示得暗一點
		var affordable := fighter.energy >= Fighter.ESCAPE_COST
		color = Color(1.0, 0.75, 0.35) if affordable else Color(0.6, 0.6, 0.6)
	elif _dash_held:
		# 按住時逐漸變色,提示快要變成幽步
		var progress := clampf(_dash_time / TELEPORT_HOLD, 0.0, 1.0)
		color = Color.WHITE.lerp(Color(0.45, 0.9, 1.0), progress)
		if progress >= 1.0 and not _teleport_done:
			text = TELEPORT_TEXT
	_dash_label.text = text
	_dash_label.modulate = color


# ---------- 建立按鈕 ----------

func _add_button(spec: Dictionary) -> void:
	var button := TouchScreenButton.new()
	var button_size: Vector2 = spec.size
	var shape_kind: String = spec.shape
	if shape_kind == "circle":
		var circle := CircleShape2D.new()
		circle.radius = button_size.x / 2.0
		button.shape = circle
	else:
		# 三角形的判定範圍用整個長方形,比圖形本身大,比較好按
		var rect := RectangleShape2D.new()
		rect.size = button_size
		button.shape = rect
	var action_name: String = spec.action
	if not action_name.is_empty():
		button.action = GameState.action(player_id, action_name)
	button.passby_press = spec.get("passby", false)
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	add_child(button)

	match shape_kind:
		"circle":
			var points := PackedVector2Array()
			for i in 48:
				points.append(Vector2.from_angle(TAU * i / 48.0) * (button_size.x / 2.0))
			_add_outline_shape(button, points)
		"rect":
			button.add_child(_make_panel(button_size, 14))
		"triangle_left":
			_add_triangle(button, -1.0)
		"triangle_right":
			_add_triangle(button, 1.0)

	var label: Label = null
	if spec.has("text"):
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = spec.text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", spec.get("font", 26))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.size = button_size
		label.position = -button_size / 2.0
		button.add_child(label)

	button.modulate.a = IDLE_ALPHA
	button.pressed.connect(func() -> void: button.modulate.a = PRESSED_ALPHA)
	button.released.connect(func() -> void: button.modulate.a = IDLE_ALPHA)
	_buttons.append({"key": spec.key, "node": button, "side": spec.side, "offset": spec.offset})
	if spec.key == "dash":
		_dash_button = button
		_dash_label = label


func _make_panel(panel_size: Vector2, corner_radius: int) -> Panel:
	var face := Panel.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = FILL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(corner_radius)
	style.corner_detail = 16
	face.add_theme_stylebox_override("panel", style)
	face.size = panel_size
	face.position = -panel_size / 2.0
	return face


## 方向鍵的三角形。direction 為 -1 時尖端朝左,1 時朝右。
func _add_triangle(button: TouchScreenButton, direction: float) -> void:
	_add_outline_shape(button, PackedVector2Array([
		Vector2(34.0 * direction, 0.0),
		Vector2(-28.0 * direction, -56.0),
		Vector2(-28.0 * direction, 56.0),
	]))


## 半透明填色加白色外框的多邊形(圓形與三角形共用)。
func _add_outline_shape(button: TouchScreenButton, points: PackedVector2Array) -> void:
	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = FILL_COLOR
	button.add_child(fill)
	var outline := Line2D.new()
	outline.points = points
	outline.closed = true
	outline.width = 3.0
	outline.default_color = BORDER_COLOR
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	button.add_child(outline)


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
