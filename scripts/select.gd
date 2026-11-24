extends Control
## 選角畫面。先選作品系列,再選裡面的角色;按「換系列」(或 Esc)可以回到系列清單,
## 已經選好的角色不會取消,所以雙方可以來自不同系列。
## 雙方各自左右選擇、攻擊鍵確認;都確認後進入對戰。
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
const SERIES_CARD_SIZE := Vector2(300, 330)
const SERIES_PREVIEW := 3  # 系列卡片上露出幾位角色

var _series := -1               # 正在看哪個系列的角色(GameState.SERIES 的索引);-1 是系列清單
var _roster: Array[int] = []    # 這個系列的角色(GameState.CHARACTERS 的索引),依卡片順序
var _series_cursor := 0         # 系列清單上,鍵盤游標停在第幾張卡片
var _series_cards: Array[PanelContainer] = []
var _series_pressed := -1       # 滑鼠 / 手指正按住哪張系列卡片
var _ios_tip := false           # iPhone 的 Safari:每一頁底下加「加入主畫面」的提示
var _page: Control              # 目前這一頁的內容;換頁時整個換掉
var _safe_controls: Array[Control] = []  # 要避開瀏海的容器;畫面大小改變時重新內縮
var _cursor: Array[int] = [0, 1]
var _form: Array[int] = [0, 0]  # 雙方替游標所在的角色選的型態
var _confirmed: Array[bool] = [false, false]
var _starting := false
# 下面三個陣列都是「這一頁的第幾張卡片」,不是角色編號;兩者用 _roster 對照
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
# 連線對戰(_net 是 null 就是單機)
var _net: NetSession
var _net_sent := ""         # 上次告訴對方的選角狀態;有變才再送
var _net_clock := 0.0
var _lobby: NetLobby        # 房間視窗;沒開啟時是 null
var _net_button: Button     # 左上角的「連線對戰 / 離開房間」
var _toast_label: Label


func _ready() -> void:
	GameState.setup_input()
	Sfx.warm_up()
	Sfx.play_music("select")
	if GameState.net_active():
		# 從連線對戰回到選角:房間還在就繼續連線選角,連線已經不在了就回到單機
		_net = NetSession.get_session()
		if _net.status != NetSession.Status.PAIRED:
			_net.leave()
			GameState.set_net_role(0)
			_net = null
	_cursor = GameState.selection.duplicate()
	for player_index in 2:
		_form[player_index] = GameState.forms[player_index] if GameState.forms[player_index] < GameState.form_count(_cursor[player_index]) else 0
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	# 上次選過系列就直接回到那個系列的角色清單,否則先選系列
	var last := GameState.series
	_show_page(last if GameState.playable_series().has(last) else -1)


func _on_viewport_resized() -> void:
	for control in _safe_controls:
		GameState.fit_to_safe_area(control)
	if _series >= 0:
		_fit_view()


func _process(delta: float) -> void:
	if _net != null:
		_net_poll(delta)
	if _series < 0:
		return
	_tick_scroll(delta)
	if _press_card < 0:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS and GameState.form_count(_press_card) > 1:
		var card_index := _press_card
		_press_card = -1
		_open_form_popup(card_index)


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _lobby != null:
		return
	if _popup != null:
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			_close_form_popup()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1 \
			and not GameState.touch_enabled and _net == null:
		GameState.cpu_enabled = not GameState.cpu_enabled
		_confirmed[1] = false
		Sfx.play("ui_move")
		_refresh()
		return
	if _series < 0:
		_series_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
		_back_to_series()
		get_viewport().set_input_as_handled()
		return
	if _net != null:
		_net_input(event)
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
	return _roster.size() * _card_step() - CARD_GAP


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


## 捲到看得見指定角色的位置;已經整張看得見就不動。那個角色不在這個系列裡就什麼都不做。
func _ensure_visible(character_index: int) -> void:
	var slot := _roster.find(character_index)
	if slot < 0:
		return
	var left := slot * _card_step()
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
	var five := mini(_roster.size(), VISIBLE_CARDS) * _card_step() - CARD_GAP
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
	if not is_instance_valid(_strip) or not is_instance_valid(_view):
		return  # 已經換到系列清單了
	var needed := _strip.get_combined_minimum_size()
	_view.custom_minimum_size.y = needed.y
	_strip.size = needed


## 現在輪到誰選角:P1 還沒確認就是 P1,否則是 P2 / 電腦。連線對戰時每個人只選自己的。
func _pick_target() -> int:
	if _net != null:
		return GameState.local_player()
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
	# 游標只在這個系列的角色之間移動,到底了繞回另一頭
	var slot := _roster.find(_cursor[target])
	_cursor[target] = _roster[posmod(slot + step, _roster.size()) if slot >= 0 else 0]
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
	if not (_confirmed[0] and _confirmed[1]) or _starting:
		return
	if _net != null:
		# 連線對戰:由房主決定亂數種子與按鍵延遲,通知對方後雙方一起開始
		if _net.role == 1:
			var start := {"t": "start", "sel": [_cursor[0], _cursor[1]], "forms": [_form[0], _form[1]],
					"seed": randi() & 0x7FFFFFFF, "delay": _net_pick_delay()}
			_net.send_message(start)
			_net_start(start)
		return
	_start_fight()


func _start_fight() -> void:
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
	_net_share()
	if _series < 0:
		_refresh_series()
		return
	# 卡片顯示的型態:游標停在上面的玩家選的那個;兩人都在同一張時,以正在選角的人為準
	var order: Array[int] = [1, 0]
	if _pick_target() == 1:
		order = [0, 1]
	for slot in _cards.size():
		var character_index := _roster[slot]
		var shown := 0
		for player_index: int in order:
			if _cursor[player_index] == character_index:
				shown = _form[player_index]
		_show_form(slot, shown)
		for player_index in 2:
			var marker: Label = _markers[slot][player_index]
			marker.visible = _cursor[player_index] == character_index
			var who := "P1" if player_index == 0 else ("電腦" if GameState.cpu_enabled else "P2")
			if _net != null:
				who = "你" if player_index == GameState.local_player() else "對手"
			marker.text = "%s%s" % [who, " OK" if _confirmed[player_index] else ""]
	if _net != null:
		_refresh_net_text()
		return
	if GameState.touch_enabled:
		_mode_label.text = "對手由電腦操作      長按角色可以選擇型態"
		if _max_scroll() > 0.0:
			_mode_label.text += "      左右滑動看更多角色"
		if not _confirmed[0]:
			_status_label.text = "點選你的角色"
		elif not _confirmed[1]:
			_status_label.text = "你:%s      點選對手的角色" % _picked_name(0)
		return
	_mode_label.text = "P2:%s(F1 切換)      有多種型態的角色:長按卡片,或按 W / S 切換      Esc 換系列" % ("電腦操作" if GameState.cpu_enabled else "玩家操作")
	if not _confirmed[0]:
		_status_label.text = "P1 選擇角色:A / D 移動,J 確認"
	elif not _confirmed[1]:
		if GameState.cpu_enabled:
			_status_label.text = "P1:%s      選擇電腦的角色:A / D 移動,J 確認" % _picked_name(0)
		else:
			_status_label.text = "P2 選擇角色:← / → 移動,數字鍵盤 1 確認"
	if not GameState.cpu_enabled and not _confirmed[0] and not _confirmed[1]:
		_status_label.text = "P1:A / D 移動,J 確認      P2:← / → 移動,數字鍵盤 1 確認"


## 把這一頁第 slot 張卡片上的名字、說明與角色圖換成指定的型態。
func _show_form(slot: int, form_index: int) -> void:
	var parts: Dictionary = _card_parts[slot]
	if parts.shown == form_index:
		return
	parts.shown = form_index
	var character_index := _roster[slot]
	var info := GameState.form_info(character_index, form_index)
	_set_name(parts.name, info.name, 30, CARD_SIZE.x - CARD_MARGIN * 2)
	(parts.summary as Label).text = info.summary
	_fill_portrait(parts.portrait, info, CARD_SIZE.x - CARD_MARGIN * 2)
	var count := GameState.form_count(character_index)
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
	var name_label := _label("", 28)
	_set_name(name_label, info.name, 28, FORM_CARD_SIZE.x - 32)
	box.add_child(name_label)
	var summary := _label(info.summary, 15)
	summary.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	summary.custom_minimum_size.x = FORM_CARD_SIZE.x - 32
	summary.modulate = Color(1, 1, 1, 0.85)
	box.add_child(summary)
	return card


# ---------- 介面 ----------

## 不隨換頁改變的部分:背景、左上角的音效開關、觸控模式的全螢幕按鈕。
## 中間的內容(系列清單或角色清單)由 _show_page 建立。
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.11, 0.17)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_build_sound_button()
	if GameState.touch_enabled:
		_build_touch_extras()


## 換到另一頁:series_index 是 -1 時顯示系列清單,否則顯示那個系列的角色清單。
## 已經確認的選角不受影響。
func _show_page(series_index: int) -> void:
	_close_form_popup()
	if _page != null:
		_safe_controls.erase(_page)
		_page.queue_free()
	_cards.clear()
	_card_parts.clear()
	_markers.clear()
	_dots.clear()
	_arrows.clear()
	_series_cards.clear()
	_view = null
	_strip = null
	_press_card = -1
	_pointer_down = false
	_dragging = false
	_series = series_index
	GameState.series = series_index

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	add_child(column)
	move_child(column, 1)  # 背景之上、角落的按鈕之下
	_page = column
	# 手機上讓內容避開瀏海與底部橫條
	_safe_controls.append(column)
	GameState.fit_to_safe_area(column)

	if series_index < 0:
		column.add_child(_label("選擇系列", 48))
		_build_series_row(column)
	else:
		_roster = GameState.characters_in(series_index)
		# 還沒選好的人:游標不在這個系列裡,就移到這個系列的前面幾位
		for player_index in 2:
			if not _confirmed[player_index] and not _roster.has(_cursor[player_index]):
				_cursor[player_index] = _roster[mini(player_index, _roster.size() - 1)]
				_form[player_index] = 0
		_build_header(column, GameState.SERIES[series_index])
		_build_carousel(column)

	_status_label = _label("", 22)
	column.add_child(_status_label)
	_mode_label = _label("", 16)
	_mode_label.modulate = Color(1, 1, 1, 0.7)
	column.add_child(_mode_label)
	if _ios_tip:
		# iPhone 的 Safari 不支援網頁全螢幕;從主畫面開啟才不會有網址列
		var tip := _label("想要全螢幕:點 Safari 的分享按鈕,選「加入主畫面」,再從主畫面開啟", 16)
		tip.modulate = Color(1.0, 0.9, 0.55, 0.9)
		column.add_child(tip)

	_refresh()
	if series_index >= 0:
		# 一開始就讓正在選角的那個游標在畫面內,不要有捲動動畫
		_scroll = 0.0
		_scroll_target = 0.0
		_ensure_visible(_cursor[_pick_target()])
		_scroll = _scroll_target
		_apply_scroll()


# ---------- 系列清單 ----------

## 每個有角色的系列一張大卡片,排成一列。
func _build_series_row(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	var list := GameState.playable_series()
	_series_cursor = clampi(_series_cursor, 0, list.size() - 1)
	for slot in list.size():
		row.add_child(_build_series_card(list[slot], slot))


## 系列卡片:露出前幾位角色、系列名稱、角色數。
func _build_series_card(series_index: int, slot: int) -> PanelContainer:
	var info: Dictionary = GameState.SERIES[series_index]
	var members := GameState.characters_in(series_index)
	var card := PanelContainer.new()
	card.custom_minimum_size = SERIES_CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.19, 0.28)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	style.set_border_width_all(3)
	style.border_color = Color(info.color, 0.45)
	card.add_theme_stylebox_override("panel", style)
	card.gui_input.connect(_on_series_card_input.bind(series_index, slot))

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)

	var preview := HBoxContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.alignment = BoxContainer.ALIGNMENT_CENTER
	preview.add_theme_constant_override("separation", 0)
	box.add_child(preview)
	var slot_width := (SERIES_CARD_SIZE.x - 32.0) / SERIES_PREVIEW
	for index in mini(members.size(), SERIES_PREVIEW):
		var portrait := Control.new()
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.custom_minimum_size = Vector2(slot_width, 130)
		preview.add_child(portrait)
		_fill_portrait(portrait, GameState.CHARACTERS[members[index]], slot_width)

	var name_label := _label(info.name, 38)
	name_label.add_theme_color_override("font_color", (info.color as Color).lightened(0.45))
	box.add_child(name_label)
	var count := _label("%d 位角色" % members.size(), 18)
	count.modulate = Color(1, 1, 1, 0.75)
	box.add_child(count)

	_series_cards.append(card)
	return card


## 點系列卡片:放開時才進去(按下的那一下如果換了頁,放開會落在新的一頁上)。
func _on_series_card_input(event: InputEvent, series_index: int, slot: int) -> void:
	if _starting or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_series_cursor = slot
		_series_pressed = slot
		_refresh()
	elif _series_pressed == slot:
		_series_pressed = -1
		_enter_series(series_index)


## 系列清單的鍵盤操作:任一位玩家的左右移動、攻擊鍵確認。
func _series_input(event: InputEvent) -> void:
	var list := GameState.playable_series()
	for player_id in [0, 1, 2]:  # 0 是連線對戰時這台裝置上的人
		if event.is_action_pressed(GameState.action(player_id, "left")):
			_series_cursor = posmod(_series_cursor - 1, list.size())
		elif event.is_action_pressed(GameState.action(player_id, "right")):
			_series_cursor = posmod(_series_cursor + 1, list.size())
		elif event.is_action_pressed(GameState.action(player_id, "attack")):
			get_viewport().set_input_as_handled()
			_enter_series(list[_series_cursor])
			return
		else:
			continue
		Sfx.play("ui_move")
		_refresh()
		get_viewport().set_input_as_handled()
		return


func _enter_series(series_index: int) -> void:
	Sfx.play("ui_confirm")
	_show_page(series_index)


## 從角色清單回到系列清單,游標停在剛才那個系列上。
func _back_to_series() -> void:
	if _starting or _popup != null:
		return
	_series_cursor = maxi(GameState.playable_series().find(_series), 0)
	Sfx.play("ui_move")
	_show_page(-1)


func _refresh_series() -> void:
	var list := GameState.playable_series()
	for slot in _series_cards.size():
		var style := _series_cards[slot].get_theme_stylebox("panel") as StyleBoxFlat
		var color: Color = GameState.SERIES[list[slot]].color
		# 鍵盤操作時,游標所在的卡片邊框比較亮;觸控沒有游標
		var focused := slot == _series_cursor and not GameState.touch_enabled
		style.border_color = color.lightened(0.3) if focused else Color(color, 0.45)
	if _net != null:
		_refresh_net_text()
		return
	if GameState.touch_enabled:
		_mode_label.text = "對手由電腦操作"
		_status_label.text = "你:%s      點選對手的系列" % _picked_name(0) if _confirmed[0] else "點選系列"
		return
	_mode_label.text = "P2:%s(F1 切換)" % ("電腦操作" if GameState.cpu_enabled else "玩家操作")
	if _confirmed[0]:
		_status_label.text = "P1:%s      選擇對手的系列:A / D 移動,J 確認" % _picked_name(0)
	else:
		_status_label.text = "選擇系列:A / D 移動,J 確認"


# ---------- 角色清單 ----------

## 角色清單的標題列:回到系列清單的按鈕,加上這個系列的名稱。
func _build_header(column: VBoxContainer, info: Dictionary) -> void:
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 20)
	column.add_child(header)
	var back := Button.new()
	back.text = "◀ 換系列"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size = Vector2(130, 48)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back_to_series)
	header.add_child(back)
	var title := _label("%s:選擇角色" % info.name, 42)
	title.add_theme_color_override("font_color", (info.color as Color).lightened(0.55))
	header.add_child(title)


## 角色卡片區:左箭頭、只露出五張卡片的視窗、右箭頭,下方一排位置指示的小圓點。
## 所有角色一頁放得下時不需要捲動,箭頭與圓點都不顯示(由 _fit_view 決定)。
func _build_carousel(column: VBoxContainer) -> void:
	var count := _roster.size()

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
	for slot in count:
		_strip.add_child(_build_card(_roster[slot]))
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

	_net_button = Button.new()
	_net_button.focus_mode = Control.FOCUS_NONE
	_net_button.add_theme_font_size_override("font_size", 20)
	_net_button.offset_left = 162
	_net_button.offset_right = 292
	_net_button.offset_top = 24
	_net_button.offset_bottom = 72
	_net_button.text = "離開房間" if _net != null else "連線對戰"
	_net_button.pressed.connect(_on_net_button)
	overlay.add_child(_net_button)

	# 畫面下方的一行提示(例如「對手已離線」),過幾秒自己消失
	_toast_label = _label("", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = -44
	_toast_label.offset_bottom = -10
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_toast_label)


## 觸控模式的附加介面:全螢幕按鈕,或是 iPhone 上改用「加入主畫面」的提示。
func _build_touch_extras() -> void:
	var platform := GameState.web_platform()
	if platform.get("fullscreen", true):
		# 手機瀏覽器的網址列很佔空間,提供全螢幕切換
		var overlay := Control.new()
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)
		_safe_controls.append(overlay)
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
		_ios_tip = true  # 每一頁的最下面加一行「加入主畫面」的提示(見 _show_page)
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

	var name_label := _label("", 30)
	_set_name(name_label, info.name, 30, CARD_SIZE.x - CARD_MARGIN * 2)
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


## 把角色名字放進標籤:名字太長就把字縮小到放得進 width,不要把卡片撐寬。
func _set_name(label: Label, text: String, font_size: int, width: float) -> void:
	var font := label.get_theme_font("font")
	var fitted := font_size
	while fitted > 14 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	label.text = text
	label.add_theme_font_size_override("font_size", fitted)
	# 字縮小後高度不變,下面的說明才不會跟著往上跳
	label.custom_minimum_size.y = font.get_height(font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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

# ---------- 連線對戰 ----------

## 左上角的按鈕:單機時開啟房間視窗,連線中則是離開房間。
func _on_net_button() -> void:
	if _starting or _popup != null or _lobby != null:
		return
	Sfx.play("ui_confirm")
	if _net != null:
		_leave_net("已離開房間")
		return
	_lobby = NetLobby.new()
	_lobby.paired.connect(_on_lobby_paired)
	_lobby.cancelled.connect(_close_lobby)
	add_child(_lobby)


func _close_lobby() -> void:
	if _lobby != null:
		_lobby.queue_free()
		_lobby = null


## 兩個人到齊:切換成連線選角,每個人只選自己的角色。
func _on_lobby_paired() -> void:
	_close_lobby()
	_net = NetSession.get_session()
	GameState.set_net_role(_net.role)
	_confirmed = [false, false]
	_net_sent = ""
	_net_button.text = "離開房間"
	_show_page(_series)


## 回到單機的選角(自己離開房間,或對方離線了)。
func _leave_net(notice: String) -> void:
	if _net != null:
		_net.leave()
	_net = null
	GameState.set_net_role(0)
	_confirmed = [false, false]
	_starting = false
	_net_button.text = "連線對戰"
	_close_form_popup()
	_show_page(_series)
	_toast(notice)


func _toast(text: String) -> void:
	_toast_label.text = text
	if text.is_empty():
		return
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_toast_label) and _toast_label.text == text:
		_toast_label.text = ""


## 每一幀看看對方送了什麼來:他的選角、開始對戰的通知,或是他離開了。
func _net_poll(delta: float) -> void:
	for message: Dictionary in _net.take_messages():
		if message.has("sys"):
			if str(message.sys) in ["left", "closed", "error"]:
				_leave_net("對手已離線,回到單機模式")
				return
			continue
		match str(message.get("t", "")):
			"sel":
				var other := 1 - GameState.local_player()
				var character := int(message.get("c", 0))
				if character >= 0 and character < GameState.CHARACTERS.size() and not _starting:
					_cursor[other] = character
					_form[other] = clampi(int(message.get("f", 0)), 0, GameState.form_count(character) - 1)
					_confirmed[other] = bool(message.get("ok", false))
					_refresh()
					_try_start()
			"start":
				if not _starting and _net.role == 2:
					_net_start(message)
					return
	# 連線狀態(直連 / 中繼、延遲)會變,定時更新畫面上的文字
	_net_clock -= delta
	if _net_clock <= 0.0 and not _starting:
		_net_clock = 0.5
		_refresh_net_text()


## 自己的選角有變就告訴對方。
func _net_share() -> void:
	if _net == null or _starting:
		return
	var me := GameState.local_player()
	var state := {"t": "sel", "c": _cursor[me], "f": _form[me], "ok": _confirmed[me]}
	var text := JSON.stringify(state)
	if text != _net_sent:
		_net_sent = text
		_net.send_message(state)


## 連線選角的鍵盤操作:只移動自己的游標。
func _net_input(event: InputEvent) -> void:
	var me := GameState.local_player()
	if _confirmed[me]:
		return
	if event.is_action_pressed(GameState.action(0, "left")):
		_move_cursor(me, -1)
	elif event.is_action_pressed(GameState.action(0, "right")):
		_move_cursor(me, 1)
	elif event.is_action_pressed(GameState.action(0, "up")):
		_cycle_form(me, -1)
	elif event.is_action_pressed(GameState.action(0, "down")):
		_cycle_form(me, 1)
	elif event.is_action_pressed(GameState.action(0, "attack")):
		_confirmed[me] = true
		Sfx.play("ui_confirm")
		_refresh()
		_try_start()
	else:
		return
	get_viewport().set_input_as_handled()


func _refresh_net_text() -> void:
	if _net == null or not is_instance_valid(_status_label):
		return
	var me := GameState.local_player()
	var other := 1 - me
	var foe := "對手:%s(已確認)" % _picked_name(other) if _confirmed[other] else "對手:選擇中"
	if _confirmed[me]:
		_status_label.text = "你:%s(已確認)      %s" % [_picked_name(me), foe]
	elif GameState.touch_enabled:
		_status_label.text = "%s      %s" % ["點選系列" if _series < 0 else "點選你的角色", foe]
	else:
		_status_label.text = "%s:A / D 移動,J 確認      %s" % ["選擇系列" if _series < 0 else "選擇你的角色", foe]
	var hint := "長按角色可以選擇型態" if GameState.touch_enabled else "W / S 切換型態   Esc 換系列"
	_mode_label.text = "連線對戰   房間 %s   %s      %s" % [_net.code, _net.describe(), hint]


## 按鍵要延後幾格才生效:要比「按鍵送到對方那裡的時間」再多一點,對方才來得及收到。
## 來回的時間還沒量到的話先用保守的數字。
func _net_pick_delay() -> int:
	if _net.rtt_ms < 0.0:
		return 6
	var one_way_frames := (_net.rtt_ms / 2.0 + 10.0) / (1000.0 / Engine.physics_ticks_per_second)
	return clampi(ceili(one_way_frames) + 1, 2, 14)


## 雙方都確認了:記下選角、種子與延遲,進入對戰。
func _net_start(start: Dictionary) -> void:
	var picks: Array = start.get("sel", [])
	var forms: Array = start.get("forms", [])
	if picks.size() != 2 or forms.size() != 2:
		return
	for player_index in 2:
		_cursor[player_index] = clampi(int(picks[player_index]), 0, GameState.CHARACTERS.size() - 1)
		_form[player_index] = clampi(int(forms[player_index]), 0, GameState.form_count(_cursor[player_index]) - 1)
	_confirmed = [true, true]
	GameState.net_seed = int(start.get("seed", 0))
	GameState.net_delay = clampi(int(start.get("delay", 6)), 1, 20)
	_refresh()
	_start_fight()
