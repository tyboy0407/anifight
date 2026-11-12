class_name FightHUD
extends CanvasLayer
## 對戰介面:雙方血條、勝場、倒數計時、中央訊息。全部用程式建立。

const ENERGY_PER_SEGMENT := 100
const ENERGY_SEGMENT_WIDTH := 96.0
const ENERGY_SEGMENT_GAP := 6.0
## 一側所有氣量格的總寬度上限;格數多的角色每格會變窄,不超出血條。
const ENERGY_ROW_WIDTH := 466.0

var _bars: Array[ProgressBar] = []
var _energy_bars: Array = [[], []]
var _root: Control
var _win_labels: Array[Label] = []
var _combo_labels: Array[Label] = []
var _combo_tweens: Array = [null, null]
var _mode_label: Label
var _hint_label: Label
var _names: Array[String] = ["", ""]
var _wins: Array[int] = [0, 0]
var _timer_label: Label
var _message_label: Label
var _message_token := 0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root
	# 手機上讓整個介面避開瀏海與圓角
	get_viewport().size_changed.connect(func() -> void: GameState.fit_to_safe_area(_root))
	GameState.fit_to_safe_area(_root)

	_bars = [
		_make_bar(root, true, Color(0.95, 0.4, 0.35)),
		_make_bar(root, false, Color(0.35, 0.6, 0.95)),
	]
	_win_labels = [_make_win_label(root, true), _make_win_label(root, false)]

	for side in 2:
		var combo := _make_label(root, 34, HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT)
		combo.anchor_left = 0.0 if side == 0 else 0.5
		combo.anchor_right = 0.5 if side == 0 else 1.0
		combo.offset_left = 40
		combo.offset_right = -40
		combo.offset_top = 130
		combo.offset_bottom = 220
		combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		combo.modulate.a = 0.0
		_combo_labels.append(combo)

	_mode_label = _make_label(root, 14, HORIZONTAL_ALIGNMENT_RIGHT)
	_mode_label.anchor_left = 0.5
	_mode_label.anchor_right = 1.0
	_mode_label.offset_left = 70
	_mode_label.offset_right = -40
	_mode_label.offset_top = 104
	_mode_label.offset_bottom = 124
	_mode_label.modulate = Color(1, 1, 1, 0.75)

	_timer_label = _make_label(root, 36, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.offset_left = -50
	_timer_label.offset_right = 50
	_timer_label.offset_top = 18
	_timer_label.offset_bottom = 68

	_message_label = _make_label(root, 64, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.visible = false

	_hint_label = _make_label(root, 14, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.anchor_right = 1.0
	_hint_label.offset_top = -56
	_hint_label.offset_bottom = -8
	_hint_label.modulate = Color(1, 1, 1, 0.75)


func set_health(player_index: int, current: int, maximum: int) -> void:
	_bars[player_index].max_value = maximum
	_bars[player_index].value = current


## 氣量以每格 100 分段顯示;滿格的段落會變亮。
func set_energy(player_index: int, current: int, maximum: int) -> void:
	@warning_ignore("integer_division")
	var segments := maxi(maximum / ENERGY_PER_SEGMENT, 1)
	if _energy_bars[player_index].size() != segments:
		# 氣量上限因角色而異,格數不同時重建這一側的氣量格
		for old: ProgressBar in _energy_bars[player_index]:
			old.queue_free()
		_energy_bars[player_index] = []
		for segment in segments:
			_energy_bars[player_index].append(_make_energy_segment(_root, player_index == 0, segment, segments))
	for segment in segments:
		var bar: ProgressBar = _energy_bars[player_index][segment]
		bar.value = clampi(current - segment * ENERGY_PER_SEGMENT, 0, ENERGY_PER_SEGMENT)
		bar.modulate = Color.WHITE if bar.value >= ENERGY_PER_SEGMENT else Color(1, 1, 1, 0.55)


## 顯示攻擊方的連段數與累計傷害。兩段以上才顯示;連段結束後淡出。
func set_combo(attacker_index: int, hits: int, damage: int) -> void:
	var label := _combo_labels[attacker_index]
	var tween: Tween = _combo_tweens[attacker_index]
	if hits >= 2:
		if tween != null:
			tween.kill()
			_combo_tweens[attacker_index] = null
		label.text = "%d HITS\n%d DMG" % [hits, damage]
		label.modulate.a = 1.0
	elif hits == 0 and label.modulate.a > 0.0 and tween == null:
		tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_property(label, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func() -> void: _combo_tweens[attacker_index] = null)
		_combo_tweens[attacker_index] = tween


func set_p2_mode(text: String) -> void:
	_mode_label.text = text


func set_hint(text: String) -> void:
	_hint_label.text = text


func set_names(p1_name: String, p2_name: String) -> void:
	_names = [p1_name, p2_name]
	_refresh_win_labels()


func set_wins(p1_wins: int, p2_wins: int) -> void:
	_wins = [p1_wins, p2_wins]
	_refresh_win_labels()


func _refresh_win_labels() -> void:
	_win_labels[0].text = "P1 %s   勝 %d" % [_names[0], _wins[0]]
	_win_labels[1].text = "勝 %d   %s P2" % [_wins[1], _names[1]]


func set_time(seconds_left: float) -> void:
	_timer_label.text = str(ceili(maxf(seconds_left, 0.0)))


## duration 為 0 時訊息會一直顯示,直到下一次呼叫。
func show_message(text: String, duration: float = 0.0) -> void:
	_message_token += 1
	_message_label.text = text
	_message_label.visible = true
	if duration > 0.0:
		var token := _message_token
		await get_tree().create_timer(duration).timeout
		if token == _message_token:
			_message_label.visible = false


func _make_bar(root: Control, left: bool, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.0 if left else 0.5
	bar.anchor_right = 0.5 if left else 1.0
	bar.offset_left = 40 if left else 70
	bar.offset_right = -70 if left else -40
	bar.offset_top = 28
	bar.offset_bottom = 56
	# 兩邊血條都從外側往中央扣。
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if left else ProgressBar.FILL_BEGIN_TO_END
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	root.add_child(bar)
	return bar


## 氣量格從畫面外側往中央排列。
func _make_energy_segment(root: Control, left: bool, segment: int, segment_count: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = ENERGY_PER_SEGMENT
	var fitted := (ENERGY_ROW_WIDTH - ENERGY_SEGMENT_GAP * (segment_count - 1)) / segment_count
	var width := minf(ENERGY_SEGMENT_WIDTH, fitted)
	var start := 40.0 + segment * (width + ENERGY_SEGMENT_GAP)
	if left:
		bar.offset_left = start
		bar.offset_right = start + width
	else:
		bar.anchor_left = 1.0
		bar.anchor_right = 1.0
		bar.offset_left = -start - width
		bar.offset_right = -start
		bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	bar.offset_top = 62
	bar.offset_bottom = 74
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.25)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	root.add_child(bar)
	return bar


func _make_win_label(root: Control, left: bool) -> Label:
	var label := _make_label(root, 18, HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT)
	label.anchor_left = 0.0 if left else 0.5
	label.anchor_right = 0.5 if left else 1.0
	label.offset_left = 40 if left else 70
	label.offset_right = -70 if left else -40
	label.offset_top = 78
	label.offset_bottom = 104
	return label


func _make_label(root: Control, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	root.add_child(label)
	return label
