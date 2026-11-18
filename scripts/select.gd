extends Control
## 選角畫面。雙方各自左右選擇、攻擊鍵確認;都確認後進入對戰。
## P2 為電腦時,P1 確認自己的角色後,接著用同一組按鍵替電腦選角色。
## 也可以直接用滑鼠或手指點角色卡片:第一下選自己,第二下選對手。
## 有多種型態的角色:長按卡片會彈出型態視窗,鍵盤則用上 / 下切換。
## 一次只顯示五位角色;角色更多時可以左右拖曳、按兩側的箭頭或用滑鼠滾輪捲動,
## 鍵盤的游標移到畫面外也會自動捲過去。

const VISIBLE_CARDS := 5  # 一次顯示幾位角色
const CARD_SIZE := Vector2(192, 330)
const CARD_GAP := 14  # 五張卡片、間距加上兩側的箭頭,要放得進 1152 寬的畫面
const CARD_MARGIN := 12  # 卡片內容離邊框的距離
const SUMMARY_FONT := 14
const ARROW_SIZE := Vector2(44, 120)
const CAROUSEL_GAP := 10.0     # 箭頭和卡片區之間的距離
const SIDE_MARGIN := 4.0       # 整個卡片區離畫面(安全區)兩側至少留多少
const DOT_SIZE := 10.0
const DRAG_THRESHOLD := 12.0   # 按住後移動超過這個距離才算拖曳,不然算點選
const FLICK_SPEED := 600.0     # 放開時的速度超過這個值,就順著甩的方向多捲一位
const SCROLL_SPEED := 16.0     # 捲動對齊的速度,越大越快到位
const FORM_CARD_SIZE := Vector2(250, 330)
const CONFIRM_DELAY := 0.6
const LONG_PRESS := 0.45  # 按住卡片這麼久就算長按

var _cursor: Array[int] = [0, 1]
var _form: Array[int] = [0, 0]  # 雙方替游標所在的角色選的型態
var _confirmed: Array[bool] = [false, false]
var _starting := false
var _cards: Array[PanelContainer] = []
var _card_parts: Array[Dictionary] = []  # 每張卡片上會隨型態更新的部分:name、summary、portrait、tag、shown
var _markers: Array = []  # 每張卡片上的 [P1 標記, P2 標記]
var _mode_label: Label
var _status_label: Label
var _press_card := -1  # 正被按住的卡片;-1 代表沒有
var _press_time := 0.0
var _popup: Control  # 型態視窗;沒開啟時是 null
# 橫向捲動
var _view: Control            # 只露出五張卡片的視窗
var _strip: HBoxContainer     # 排著所有卡片的長條,在視窗裡左右移動
var _arrows: Array[Button] = []
var _dots: Array[Panel] = []
var _dot_row: HBoxContainer
var _scroll := 0.0            # 目前捲到哪裡(像素)
var _scroll_target := 0.0     # 要對齊到的位置
var _pointer_down := false    # 手指 / 滑鼠正按在卡片區
var _dragging := false
var _drag_from_x := 0.0
var _drag_from_scroll := 0.0
var _drag_velocity := 0.0


func _ready() -> void:
	GameState.setup_input()
	Sfx.warm_up()
	_cursor = GameState.selection.duplicate()
	for player_index in 2:
		_form[player_index] = GameState.forms[player_index] if GameState.forms[player_index] < GameState.form_count(_cursor[player_index]) else 0
	_build_ui()
	_refresh()
	# 一開始就讓 P1 的游標在畫面內,不要有捲動動畫
	_ensure_visible(_cursor[0])
	_scroll = _scroll_target
	_apply_scroll()


func _process(delta: float) -> void:
	_tick_scroll(delta)
	if _press_card < 0:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS and GameState.form_count(_press_card) > 1:
		var card_index := _press_card
		_press_card = -1
		_open_form_popup(card_index)


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return
	if _popup != null:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_close_form_popup()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1 \
			and not GameState.touch_enabled:
		GameState.cpu_enabled = not GameState.cpu_enabled
		_confirmed[1] = false
		Sfx.play("ui_move")
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
		elif event.is_action_pressed(GameState.action(player_id, "up")):
			_cycle_form(target, -1)
		elif event.is_action_pressed(GameState.action(player_id, "down")):
			_cycle_form(target, 1)
		elif event.is_action_pressed(GameState.action(player_id, "attack")):
			_confirmed[target] = true
			Sfx.play("ui_confirm")
			_refresh()
			_try_start()
			if not _starting:
				# 接著換另一個游標:先捲到看得到它的地方
				_ensure_visible(_cursor[_pick_target()])
		else:
			continue
		get_viewport().set_input_as_handled()
		return


## 用滑鼠或手指操作角色卡片:點一下選角(先選自己,再選對手),長按開啟型態視窗,
## 按住左右拖曳則是捲動。選角在放開時才生效,這樣才分得出點一下、長按和拖曳。
## card_index 是 -1 時代表按在卡片之間的空隙:只能拖曳。
func _on_card_input(event: InputEvent, card_index: int) -> void:
	if _starting or _popup != null:
		return
	if event is InputEventMouseMotion:
		_drag_to(event as InputEventMouseMotion)
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		_scroll_by(1)
	elif click.pressed and click.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
		_scroll_by(-1)
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_pointer_down = true
		_dragging = false
		_drag_from_x = click.global_position.x
		_drag_from_scroll = _scroll
		_drag_velocity = 0.0
		_press_card = card_index
		_press_time = 0.0
	elif _pointer_down:
		_pointer_down = false
		var pressed_card := _press_card
		_press_card = -1
		if _dragging:
			_dragging = false
			_snap_after_drag()
		elif pressed_card == card_index and card_index >= 0:
			var target := _pick_target()
			# 這位玩家已經用鍵盤替這張卡片挑好型態的話就沿用,否則是原本的樣子
			_pick(card_index, _form[target] if _cursor[target] == card_index else 0)


# ---------- 橫向捲動 ----------

## 相鄰兩張卡片的間隔(卡片寬加間距)。
func _card_step() -> float:
	return CARD_SIZE.x + CARD_GAP


## 所有卡片排成一列的總寬度。
func _strip_width() -> float:
	return GameState.CHARACTERS.size() * _card_step() - CARD_GAP


func _view_width() -> float:
	return _view.custom_minimum_size.x


func _max_scroll() -> float:
	return maxf(_strip_width() - _view_width(), 0.0)


## 往左(-)或往右(+)捲幾張卡片。
func _scroll_by(cards: int) -> void:
	var slot := roundi(_scroll_target / _card_step()) + cards
	var target := clampf(slot * _card_step(), 0.0, _max_scroll())
	if not is_equal_approx(target, _scroll_target):
		_scroll_target = target
		Sfx.play("ui_move")


## 捲到看得見指定卡片的位置;已經整張看得見就不動。
func _ensure_visible(card_index: int) -> void:
	var left := card_index * _card_step()
	var right := left + CARD_SIZE.x
	if left < _scroll_target:
		_scroll_target = left
	elif right > _scroll_target + _view_width():
		_scroll_target = right - _view_width()
	_scroll_target = clampf(_scroll_target, 0.0, _max_scroll())


## 依畫面寬度決定卡片區要多寬:最多五張;螢幕比較窄(或被瀏海佔掉)就縮到放得下,
## 這時露出的卡片不到五張,一樣可以捲動。
func _fit_view() -> void:
	var area := GameState.safe_area(get_viewport())
	var room := get_viewport().get_visible_rect().size.x - area.x - area.z - SIDE_MARGIN * 2.0
	var five := mini(GameState.CHARACTERS.size(), VISIBLE_CARDS) * _card_step() - CARD_GAP
	var scrollable := _strip_width() > minf(five, room)
	for arrow in _arrows:
		arrow.visible = scrollable
	_dot_row.visible = scrollable
	if scrollable:
		room -= (ARROW_SIZE.x + CAROUSEL_GAP) * 2.0
	_view.custom_minimum_size.x = clampf(room, CARD_SIZE.x, five)
	_scroll_target = clampf(_scroll_target, 0.0, _max_scroll())
	_scroll = clampf(_scroll, 0.0, _max_scroll())
	_apply_scroll()


## 按住移動:超過一小段距離才算拖曳,之後畫面跟著手指走。
func _drag_to(motion: InputEventMouseMotion) -> void:
	if not _pointer_down:
		return
	if motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		_pointer_down = false  # 放開的那一下沒收到(例如中途跳出型態視窗)
		_dragging = false
		return
	var moved := motion.global_position.x - _drag_from_x
	if not _dragging and absf(moved) > DRAG_THRESHOLD:
		_dragging = true
		_press_card = -1  # 開始拖曳就不算點選,也不會變成長按
	if _dragging:
		_scroll = clampf(_drag_from_scroll - moved, 0.0, _max_scroll())
		_scroll_target = _scroll
		_drag_velocity = motion.velocity.x
		_apply_scroll()


## 放開後對齊到卡片邊緣;甩得夠快就順著方向多捲一位。
func _snap_after_drag() -> void:
	var slot := _scroll / _card_step()
	if _drag_velocity < -FLICK_SPEED:
		slot = ceilf(slot)   # 往左甩:看更右邊的角色
	elif _drag_velocity > FLICK_SPEED:
		slot = floorf(slot)
	else:
		slot = roundf(slot)
	_scroll_target = clampf(slot * _card_step(), 0.0, _max_scroll())


func _tick_scroll(delta: float) -> void:
	if _dragging or is_equal_approx(_scroll, _scroll_target):
		return
	_scroll = lerpf(_scroll, _scroll_target, 1.0 - exp(-SCROLL_SPEED * delta))
	if absf(_scroll - _scroll_target) < 0.5:
		_scroll = _scroll_target
	_apply_scroll()


## 依目前的捲動位置擺放卡片,並更新箭頭與位置指示。
func _apply_scroll() -> void:
	_strip.position.x = -roundf(_scroll)
	_set_arrow_enabled(_arrows[0], _scroll_target > 0.5)
	_set_arrow_enabled(_arrows[1], _scroll_target < _max_scroll() - 0.5)
	for index in _dots.size():
		# 卡片的中心在視窗內就算正在顯示
		var center := index * _card_step() + CARD_SIZE.x / 2.0
		var shown := center >= _scroll and center <= _scroll + _view_width()
		_dots[index].modulate.a = 1.0 if shown else 0.3


func _set_arrow_enabled(arrow: Button, enabled: bool) -> void:
	arrow.disabled = not enabled
	arrow.modulate.a = 1.0 if enabled else 0.3


## 卡片內容變多變少時(例如切換型態),讓視窗和長條的高度跟著調整。
func _fit_strip() -> void:
	var needed := _strip.get_combined_minimum_size()
	_view.custom_minimum_size.y = needed.y
	_strip.size = needed


## 現在輪到誰選角:P1 還沒確認就是 P1,否則是 P2 / 電腦。
func _pick_target() -> int:
	return 1 if _confirmed[0] else 0


## 替目前輪到的玩家選定角色與型態並確認。
func _pick(card_index: int, form_index: int) -> void:
	var target := _pick_target()
	if _confirmed[target]:
		return
	_cursor[target] = card_index
	_form[target] = form_index
	_confirmed[target] = true
	Sfx.play("ui_confirm")
	_refresh()
	_try_start()


func _toggle_fullscreen() -> void:
	var window := get_window()
	var is_fullscreen := window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	window.mode = Window.MODE_WINDOWED if is_fullscreen else Window.MODE_FULLSCREEN


func _move_cursor(target: int, step: int) -> void:
	_cursor[target] = posmod(_cursor[target] + step, GameState.CHARACTERS.size())
	_form[target] = 0
	Sfx.play("ui_move")
	_ensure_visible(_cursor[target])
	_refresh()


func _cycle_form(target: int, step: int) -> void:
	var count := GameState.form_count(_cursor[target])
	if count <= 1:
		return
	_form[target] = posmod(_form[target] + step, count)
	Sfx.play("ui_move")
	_refresh()


func _try_start() -> void:
	if not (_confirmed[0] and _confirmed[1]):
		return
	_starting = true
	GameState.selection = [_cursor[0], _cursor[1]]
	GameState.forms = [_form[0], _form[1]]
	_status_label.text = "對戰開始!  %s  VS  %s" % [_picked_name(0), _picked_name(1)]
	Sfx.play("ui_start")
	await get_tree().create_timer(CONFIRM_DELAY).timeout
	get_tree().change_scene_to_file(GameState.FIGHT_SCENE)


func _picked_name(player_index: int) -> String:
	return GameState.form_info(_cursor[player_index], _form[player_index]).name


func _refresh() -> void:
	# 卡片顯示的型態:游標停在上面的玩家選的那個;兩人都在同一張時,以正在選角的人為準
	var order: Array[int] = [1, 0]
	if _pick_target() == 1:
		order = [0, 1]
	for card_index in _cards.size():
		var shown := 0
		for player_index: int in order:
			if _cursor[player_index] == card_index:
				shown = _form[player_index]
		_show_form(card_index, shown)
		for player_index in 2:
			var marker: Label = _markers[card_index][player_index]
			marker.visible = _cursor[player_index] == card_index
			var who := "P1" if player_index == 0 else ("電腦" if GameState.cpu_enabled else "P2")
			marker.text = "%s%s" % [who, " OK" if _confirmed[player_index] else ""]
	if GameState.touch_enabled:
		_mode_label.text = "對手由電腦操作      長按角色可以選擇型態"
		if _max_scroll() > 0.0:
			_mode_label.text += "      左右滑動看更多角色"
		if not _confirmed[0]:
			_status_label.text = "點選你的角色"
		elif not _confirmed[1]:
			_status_label.text = "你:%s      點選對手的角色" % _picked_name(0)
		return
	_mode_label.text = "P2:%s(F1 切換)      有多種型態的角色:長按卡片,或按 W / S 切換" % ("電腦操作" if GameState.cpu_enabled else "玩家操作")
	if not _confirmed[0]:
		_status_label.text = "P1 選擇角色:A / D 移動,J 確認"
	elif not _confirmed[1]:
		if GameState.cpu_enabled:
			_status_label.text = "P1:%s      選擇電腦的角色:A / D 移動,J 確認" % _picked_name(0)
		else:
			_status_label.text = "P2 選擇角色:← / → 移動,數字鍵盤 1 確認"
	if not GameState.cpu_enabled and not _confirmed[0] and not _confirmed[1]:
		_status_label.text = "P1:A / D 移動,J 確認      P2:← / → 移動,數字鍵盤 1 確認"


## 把卡片上的名字、說明與角色圖換成指定的型態。
func _show_form(card_index: int, form_index: int) -> void:
	var parts: Dictionary = _card_parts[card_index]
	if parts.shown == form_index:
		return
	parts.shown = form_index
	var info := GameState.form_info(card_index, form_index)
	(parts.name as Label).text = info.name
	(parts.summary as Label).text = info.summary
	_fill_portrait(parts.portrait, info, CARD_SIZE.x - CARD_MARGIN * 2)
	var count := GameState.form_count(card_index)
	(parts.tag as Label).text = "型態 %d / %d" % [form_index + 1, count] if count > 1 else ""


# ---------- 型態視窗 ----------

func _open_form_popup(card_index: int) -> void:
	Sfx.play("ui_move")
	_pointer_down = false
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)

	# 壓暗背景;點空白處取消
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.05, 0.92)
	dim.gui_input.connect(_on_popup_backdrop_input)
	_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(center)
	GameState.fit_to_safe_area(center)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	column.add_child(_label("%s:選擇型態" % GameState.CHARACTERS[card_index].name, 34))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	for form_index in GameState.form_count(card_index):
		row.add_child(_build_form_card(card_index, form_index))

	var hint := _label("點一個型態出戰,點空白處取消", 18)
	hint.modulate = Color(1, 1, 1, 0.75)
	column.add_child(hint)


func _close_form_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null


func _on_popup_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_form_popup()


func _on_form_card_input(event: InputEvent, card_index: int, form_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_form_popup()
		_pick(card_index, form_index)


func _build_form_card(card_index: int, form_index: int) -> PanelContainer:
	var info := GameState.form_info(card_index, form_index)
	var card := PanelContainer.new()
	card.custom_minimum_size = FORM_CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.23, 0.35)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.65, 1.0, 0.7)
	card.add_theme_stylebox_override("panel", style)
	card.gui_input.connect(_on_form_card_input.bind(card_index, form_index))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var portrait := Control.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(0, 140)
	box.add_child(portrait)
	_fill_portrait(portrait, info, FORM_CARD_SIZE.x - 32)
	box.add_child(_label(info.name, 28))
	var summary := _label(info.summary, 15)
	summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	summary.custom_minimum_size.x = FORM_CARD_SIZE.x - 32
	summary.modulate = Color(1, 1, 1, 0.85)
	box.add_child(summary)
	return card


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
	column.add_theme_constant_override("separation", 20)
	add_child(column)
	# 手機上讓內容避開瀏海與底部橫條
	get_viewport().size_changed.connect(func() -> void: GameState.fit_to_safe_area(column))
	GameState.fit_to_safe_area(column)

	column.add_child(_label("選擇角色", 48))

	_build_carousel(column)

	_status_label = _label("", 22)
	column.add_child(_status_label)
	_mode_label = _label("", 16)
	_mode_label.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_mode_label)

	_build_sound_button()
	if GameState.touch_enabled:
		_build_touch_extras(column)


## 角色卡片區:左箭頭、只露出五張卡片的視窗、右箭頭,下方一排位置指示的小圓點。
## 所有角色一頁放得下時不需要捲動,箭頭與圓點都不顯示(由 _fit_view 決定)。
func _build_carousel(column: VBoxContainer) -> void:
	var count := GameState.CHARACTERS.size()

	var carousel := HBoxContainer.new()
	carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	carousel.add_theme_constant_override("separation", int(CAROUSEL_GAP))
	column.add_child(carousel)

	_arrows = [_make_arrow("◀", -1), _make_arrow("▶", 1)]
	carousel.add_child(_arrows[0])

	_view = Control.new()
	_view.clip_contents = true  # 視窗外的卡片不顯示,也點不到
	_view.custom_minimum_size = Vector2(CARD_SIZE.x, CARD_SIZE.y)  # 寬度稍後由 _fit_view 決定
	_view.gui_input.connect(_on_card_input.bind(-1))
	carousel.add_child(_view)
	carousel.add_child(_arrows[1])

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", CARD_GAP)
	_view.add_child(_strip)
	for card_index in count:
		_strip.add_child(_build_card(card_index))
	_strip.minimum_size_changed.connect(_fit_strip)
	_fit_strip()

	_dot_row = HBoxContainer.new()
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", 8)
	_dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_dot_row)
	for index in count:
		var dot := Panel.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.85, 0.88, 1.0)
		style.set_corner_radius_all(int(DOT_SIZE / 2.0))
		dot.add_theme_stylebox_override("panel", style)
		_dot_row.add_child(dot)
		_dots.append(dot)
	get_viewport().size_changed.connect(_fit_view)
	_fit_view()


func _make_arrow(text: String, direction: int) -> Button:
	var arrow := Button.new()
	arrow.text = text
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.custom_minimum_size = ARROW_SIZE
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.pressed.connect(_scroll_by.bind(direction))
	return arrow


## 左上角的音效開關(鍵盤也可以按 M)。
func _build_sound_button() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	get_viewport().size_changed.connect(func() -> void: GameState.fit_to_safe_area(overlay))
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


## 觸控模式的附加介面:全螢幕按鈕,或是 iPhone 上改用「加入主畫面」的提示。
func _build_touch_extras(column: VBoxContainer) -> void:
	var platform := GameState.web_platform()
	if platform.get("fullscreen", true):
		# 手機瀏覽器的網址列很佔空間,提供全螢幕切換
		var overlay := Control.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		get_viewport().size_changed.connect(func() -> void: GameState.fit_to_safe_area(overlay))
		GameState.fit_to_safe_area(overlay)

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
		var tip := _label("想要全螢幕:點 Safari 的分享按鈕,選「加入主畫面」,再從主畫面開啟", 16)
		tip.modulate = Color(1.0, 0.9, 0.55, 0.9)
		column.add_child(tip)
	OrientationNotice.attach_if_touch(self)


func _build_card(card_index: int) -> PanelContainer:
	var info: Dictionary = GameState.CHARACTERS[card_index]
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.19, 0.28)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(CARD_MARGIN)
	card.add_theme_stylebox_override("panel", style)

	# 整張卡片都可以點;內部的容器不攔截點擊
	card.gui_input.connect(_on_card_input.bind(card_index))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	# P1 / P2 游標標記
	var marker_row := HBoxContainer.new()
	marker_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	var portrait := Control.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.custom_minimum_size = Vector2(0, 130)
	box.add_child(portrait)
	_fill_portrait(portrait, info, CARD_SIZE.x - CARD_MARGIN * 2)

	var name_label := _label(info.name, 30)
	box.add_child(name_label)
	# 有多種型態的角色:標示目前顯示的是第幾個
	var count := GameState.form_count(card_index)
	var tag := _label("型態 1 / %d" % count if count > 1 else "", 13)
	tag.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	tag.visible = count > 1
	box.add_child(tag)
	var summary := _label(info.summary, SUMMARY_FONT)
	# 太長的說明自動換行,不要把卡片撐寬
	summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	summary.custom_minimum_size.x = CARD_SIZE.x - CARD_MARGIN * 2
	summary.modulate = Color(1, 1, 1, 0.8)
	box.add_child(summary)

	_cards.append(card)
	_card_parts.append({"name": name_label, "summary": summary, "portrait": portrait, "tag": tag, "shown": 0})
	return card


## 在 portrait 裡畫出角色示意圖:有素材就播待機動畫,沒有就用色塊。
## inner_width 是卡片扣掉內邊距後的寬度,用來把圖置中。
func _fill_portrait(portrait: Control, info: Dictionary, inner_width: float) -> void:
	for child in portrait.get_children():
		child.queue_free()
	var bottom := portrait.custom_minimum_size.y
	var center_x := inner_width / 2.0
	var loaded := SpriteSheetLoader.load_character(info.get("sprites", ""))
	if loaded.is_empty():
		# 沒有素材時的後備:身體色塊 + 頭髮色塊
		var body := ColorRect.new()
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.color = Color(0.6, 0.62, 0.7)
		body.size = Vector2(50, 100)
		body.position = Vector2(center_x - 25, bottom - 104)
		portrait.add_child(body)
		var hair := ColorRect.new()
		hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hair.color = info.hair
		hair.size = Vector2(56, 20)
		hair.position = body.position + Vector2(-3, -14)
		portrait.add_child(hair)
		return
	var canvas: Vector2 = loaded.canvas
	var sprite := AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = loaded.frames
	sprite.centered = false
	sprite.scale = Vector2.ONE * float(loaded.scale)
	sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y)
	sprite.position = Vector2(center_x, bottom)
	portrait.add_child(sprite)
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
