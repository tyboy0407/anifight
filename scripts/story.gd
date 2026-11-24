extends Control
## 故事模式的畫面。先選一位角色的故事,進到他的頁面:左邊是等級、配點與已經領悟的能力,
## 右邊是章節與關卡。點一關:先播開場對話,再進對戰(main.tscn,設定放在 GameState.story_fight);
## 打完回到這裡,贏了就播結尾對話、結算經驗值與新能力。
## 故事的內容與成長規則在 StoryData,進度存檔在 StorySave。
## 鍵盤:W / S 選關卡、J 開始、1 / 2 / 3 加點、Esc 返回。

enum View { PICK, HUB }

const PANEL_COLOR := Color(0.15, 0.17, 0.25)
const GOLD := Color(1.0, 0.84, 0.45)
const PICK_CARD_SIZE := Vector2(300, 380)
const STAGE_ROW_HEIGHT := 60.0
const LEFT_WIDTH := 400.0

var _view := View.PICK
var _story_id := ""
var _story: Dictionary = {}
var _progress: Dictionary = {}
var _stages: Array[Dictionary] = []
var _cursor := 0                 # 選角色時:第幾篇故事;角色頁面:第幾關
var _page: Control               # 目前這一頁的內容;換頁時整個換掉
var _overlay: Control            # 蓋在上面的對話或結算視窗;沒有就是 null
var _leaving := false
var _safe_controls: Array[Control] = []
var _back_button: Button
var _title_label: Label
var _toast_label: Label
var _pick_cards: Array[PanelContainer] = []
var _stage_rows: Array[PanelContainer] = []
var _pressed_row := -1           # 滑鼠 / 手指正按住哪一列(放開時還在同一列才算點選)
var _reward_continue: Callable


func _ready() -> void:
	GameState.setup_input()
	Sfx.warm_up()
	Sfx.play_music("select")
	_build_frame()
	get_viewport().size_changed.connect(_on_viewport_resized)
	# 從對戰回來:接著處理那一關的結果
	var fight := GameState.story_fight
	var result := GameState.story_result
	GameState.story_fight = {}
	GameState.story_result = ""
	if not fight.is_empty() and not result.is_empty() and not StoryData.story(str(fight.get("story", ""))).is_empty():
		_open_story(str(fight.story))
		_after_fight(int(fight.get("stage", 0)), result == "win")
	else:
		_show_pick()


func _on_viewport_resized() -> void:
	for control in _safe_controls:
		if is_instance_valid(control):
			GameState.fit_to_safe_area(control)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if _overlay != null:
		# 結算視窗:J / Enter 繼續(對話視窗自己處理按鍵)
		if _reward_continue.is_valid() and (event.is_action_pressed("ui_accept") or event.is_action_pressed(GameState.action(1, "attack"))):
			get_viewport().set_input_as_handled()
			_reward_continue.call()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_back()
			return
		if _view == View.HUB and key in [KEY_1, KEY_2, KEY_3]:
			get_viewport().set_input_as_handled()
			_add_point(str(StoryData.STATS[key - KEY_1].id))
			return
	var step := 0
	for action_name: String in ["up", "left"]:
		if event.is_action_pressed(GameState.action(1, action_name)):
			step = -1
	for action_name: String in ["down", "right"]:
		if event.is_action_pressed(GameState.action(1, action_name)):
			step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		_move_cursor(step)
	elif event.is_action_pressed(GameState.action(1, "attack")) or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _view == View.PICK:
			_pick(_cursor)
		else:
			_start_stage(_cursor)


func _move_cursor(step: int) -> void:
	var count := StoryData.STORIES.size() if _view == View.PICK else _open_stage_count()
	if count <= 0:
		return
	_cursor = posmod(_cursor + step, count)
	Sfx.play("ui_move")
	_refresh_cursor()


## 左上角的返回:角色頁面回到選角色,選角色回到主選單。
func _on_back() -> void:
	if _leaving or _overlay != null:
		return
	Sfx.play("ui_move")
	if _view == View.HUB:
		_show_pick()
	else:
		_leaving = true
		get_tree().change_scene_to_file(GameState.MENU_SCENE)


# ---------- 選角色 ----------

func _show_pick() -> void:
	_view = View.PICK
	_cursor = maxi(_story_index(_story_id), 0)
	_back_button.text = "◀ 主選單"
	_title_label.text = "故事模式"
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_set_page(column)
	column.add_child(_label("選擇角色,體驗他的故事", 22, 0.75))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	_pick_cards.clear()
	for index in StoryData.STORIES.size():
		row.add_child(_build_pick_card(index))
	row.add_child(_build_coming_card())
	column.add_child(_label("" if GameState.touch_enabled else "J 確認      Esc 回主選單", 16, 0.6))
	_refresh_cursor()


func _story_index(story_id: String) -> int:
	for index in StoryData.STORIES.size():
		if StoryData.STORIES[index].id == story_id:
			return index
	return -1


func _build_pick_card(index: int) -> PanelContainer:
	var entry: Dictionary = StoryData.STORIES[index]
	var progress := StorySave.load_progress(str(entry.id))
	var total := StoryData.stages(str(entry.id)).size()
	var card := _panel(PANEL_COLOR, 12, 16)
	card.custom_minimum_size = PICK_CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_pick_card_input.bind(index))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(_portrait(str(entry.character), Vector2(PICK_CARD_SIZE.x - 32, 140)))
	box.add_child(_label(str(entry.character), 30))
	var title := _label("《%s》" % entry.title, 24)
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var tagline := _label(str(entry.tagline), 16, 0.8)
	tagline.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tagline.custom_minimum_size.x = PICK_CARD_SIZE.x - 32
	box.add_child(tagline)
	var state := "Lv.%d      進度 %d / %d" % [progress.level, mini(int(progress.cleared), total), total]
	box.add_child(_label(state if int(progress.cleared) > 0 or int(progress.level) > 1 else "尚未開始", 18, 0.9))
	_pick_cards.append(card)
	return card


## 還沒做的角色:一張暗的卡片。
func _build_coming_card() -> PanelContainer:
	var card := _panel(Color(0.12, 0.13, 0.19), 12, 16)
	card.custom_minimum_size = PICK_CARD_SIZE
	card.modulate = Color(1, 1, 1, 0.6)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(_label("?", 80, 0.5))
	box.add_child(_label("更多角色", 26))
	box.add_child(_label("製作中,敬請期待", 18, 0.8))
	return card


func _on_pick_card_input(event: InputEvent, index: int) -> void:
	if _leaving or _overlay != null or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_pressed_row = index
	elif _pressed_row == index:
		_pressed_row = -1
		_pick(index)


func _pick(index: int) -> void:
	Sfx.play("ui_confirm")
	_open_story(str(StoryData.STORIES[index].id))
	_show_hub()


# ---------- 角色頁面 ----------

func _open_story(story_id: String) -> void:
	_story_id = story_id
	_story = StoryData.story(story_id)
	_stages = StoryData.stages(story_id)
	_progress = StorySave.load_progress(story_id)


## 現在可以打的關卡數:已經過關的,加上下一關。
func _open_stage_count() -> int:
	return mini(int(_progress.cleared) + 1, _stages.size())


func _show_hub(focus_stage: int = -1) -> void:
	_view = View.HUB
	_back_button.text = "◀ 返回"
	_title_label.text = "%s《%s》" % [_story.character, _story.title]
	_cursor = clampi(focus_stage if focus_stage >= 0 else int(_progress.cleared), 0, maxi(_open_stage_count() - 1, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_set_page(row)
	row.add_child(_build_status_panel())
	row.add_child(_build_stage_panel())
	_refresh_cursor()


## 左半邊:等級、經驗值、配點、能力。
func _build_status_panel() -> Control:
	var panel := _panel(PANEL_COLOR, 12, 14)
	panel.custom_minimum_size.x = LEFT_WIDTH
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	top.add_child(_portrait(str(_story.character), Vector2(110, 100)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	top.add_child(info)
	var level := int(_progress.level)
	var level_label := _label("Lv.%d" % level, 32)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.add_theme_color_override("font_color", GOLD)
	info.add_child(level_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = StoryData.exp_to_next(level)
	bar.value = int(_progress.exp) if level < StoryData.MAX_LEVEL else bar.max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.75, 1.0)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	info.add_child(bar)
	var exp_text := "經驗值 %d / %d" % [_progress.exp, StoryData.exp_to_next(level)] if level < StoryData.MAX_LEVEL else "已達最高等級"
	var exp_label := _label(exp_text, 15, 0.75)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.add_child(exp_label)

	# 配點
	var free := StoryData.free_points(_progress)
	var points_row := HBoxContainer.new()
	box.add_child(points_row)
	var points_label := _label("可分配點數  %d" % free, 20)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if free > 0:
		points_label.add_theme_color_override("font_color", GOLD)
	points_row.add_child(points_label)
	var reset := _button("重置配點", 16, Vector2(104, 34))
	reset.disabled = free == StoryData.points_at(level)
	reset.pressed.connect(_reset_points)
	points_row.add_child(reset)
	for index in StoryData.STATS.size():
		box.add_child(_build_stat_row(index, free))
	var hint := _label("升級得到點數,只在故事模式有效" if GameState.touch_enabled else "升級得到點數(按 1 / 2 / 3 也能加),只在故事模式有效", 13, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)

	# 能力
	var learned := StoryData.abilities(_story_id, int(_progress.cleared))
	var abilities: Array = _story.get("abilities", [])
	for ability: Dictionary in abilities:
		box.add_child(_build_ability_row(ability, learned.has(ability.id)))
	if not abilities.is_empty() and not learned.has(abilities[-1].id) and _story.has("passive"):
		var passive := _label(str(_story.passive), 13, 0.8)
		passive.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		passive.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		passive.add_theme_color_override("font_color", Color(1.0, 0.72, 0.88))
		box.add_child(passive)
	return panel


func _build_stat_row(index: int, free: int) -> Control:
	var stat: Dictionary = StoryData.STATS[index]
	var points := int(_progress.stats.get(stat.id, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(str(stat.name), 22)
	name_label.custom_minimum_size.x = 56
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var bonus := roundi(float(stat.step) * points * 1000.0) / 10.0
	var note := _label("%s +%s%%" % [stat.note, str(bonus).trim_suffix(".0")], 16, 0.8)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	row.add_child(_label("%d 點" % points, 18, 0.9))
	var plus := _button("+", 24, Vector2(52, 36))
	plus.disabled = free <= 0 or points >= StoryData.STAT_CAP
	plus.pressed.connect(_add_point.bind(str(stat.id)))
	row.add_child(plus)
	return row


func _build_ability_row(ability: Dictionary, learned: bool) -> Control:
	# 第一行:名字,右邊是按哪個鍵(還沒領悟的寫「尚未領悟」);領悟了才有第二行的說明
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	var line := HBoxContainer.new()
	box.add_child(line)
	var title := _label("%s  %s" % ["◆" if learned else "◇", ability.name], 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(title)
	var key := _label(str(ability.key) if learned else "尚未領悟", 14, 0.8)
	if learned:
		key.add_theme_color_override("font_color", GOLD)
	line.add_child(key)
	if learned:
		var note := _label(str(ability.note), 13, 0.75)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(note)
	else:
		box.modulate = Color(1, 1, 1, 0.45)
	return box


func _add_point(stat_id: String) -> void:
	if _overlay != null or StoryData.free_points(_progress) <= 0:
		return
	var points := int(_progress.stats.get(stat_id, 0))
	if points >= StoryData.STAT_CAP:
		return
	_progress.stats[stat_id] = points + 1
	StorySave.save_progress(_story_id, _progress)
	Sfx.play("ui_confirm")
	_show_hub(_cursor)


func _reset_points() -> void:
	_progress.stats = {}
	StorySave.save_progress(_story_id, _progress)
	Sfx.play("ui_move")
	_show_hub(_cursor)


## 右半邊:章節與關卡。
func _build_stage_panel() -> Control:
	var panel := _panel(PANEL_COLOR, 12, 14)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	_stage_rows.clear()
	var chapters: Array = _story.get("chapters", [])
	var stage_index := 0
	for chapter: Dictionary in chapters:
		box.add_child(_chapter_header(str(chapter.title)))
		for stage: Dictionary in chapter.stages:
			box.add_child(_build_stage_row(stage_index, stage))
			stage_index += 1
	for title: String in _story.get("coming", []):
		var header := _chapter_header(title)
		header.modulate = Color(1, 1, 1, 0.5)
		box.add_child(header)
		var note := _label("製作中,敬請期待", 18, 0.5)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(note)
	return panel


func _chapter_header(text: String) -> Label:
	var header := _label(text, 22)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_color_override("font_color", GOLD)
	return header


func _build_stage_row(index: int, stage: Dictionary) -> PanelContainer:
	var cleared := int(_progress.cleared)
	var open := index <= cleared
	var row := _panel(Color(0.2, 0.23, 0.34), 8, 10)
	row.custom_minimum_size.y = STAGE_ROW_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		row.gui_input.connect(_on_stage_row_input.bind(index))
	else:
		row.modulate = Color(1, 1, 1, 0.4)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	row.add_child(line)
	var number := _label(str(stage.id), 24)
	number.custom_minimum_size.x = 54
	line.add_child(number)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 0)
	line.add_child(texts)
	var title := _label(str(stage.title) if open else "? ? ?", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(title)
	var foe_text := "對手:%s" % StoryData.foe_info(stage).name
	if int(stage.get("rounds", 1)) > 1:
		foe_text += "      頭目戰"
	var foe := _label(foe_text if open else "先通過前一關", 14, 0.7)
	foe.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	texts.add_child(foe)
	var state := _label("已過關" if index < cleared else ("挑戰 ▶" if open else "未開放"), 18)
	state.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65) if index < cleared else GOLD)
	state.custom_minimum_size.x = 84
	line.add_child(state)
	_stage_rows.append(row)
	return row


func _on_stage_row_input(event: InputEvent, index: int) -> void:
	if _leaving or _overlay != null or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	# 放開時還在同一列才算點選(中間拖動捲軸的不算)
	if click.pressed:
		_pressed_row = index
		_cursor = index
		_refresh_cursor()
	elif _pressed_row == index:
		_pressed_row = -1
		_start_stage(index)


## 鍵盤游標:游標所在的卡片 / 關卡邊框比較亮。觸控沒有游標。
func _refresh_cursor() -> void:
	var rows: Array[PanelContainer] = _pick_cards if _view == View.PICK else _stage_rows
	for index in rows.size():
		var style := rows[index].get_theme_stylebox("panel") as StyleBoxFlat
		var focused := index == _cursor and not GameState.touch_enabled
		style.border_color = GOLD if focused else Color(0.55, 0.62, 0.9, 0.35)


# ---------- 進行一關 ----------

## 開始第 index 關:播開場對話,然後進對戰。
func _start_stage(index: int) -> void:
	if _leaving or _overlay != null or index < 0 or index >= _open_stage_count():
		return
	Sfx.play("ui_confirm")
	var stage := _stages[index]
	_play_dialogue(stage.get("before", []), func() -> void:
		_leaving = true
		GameState.story_fight = StoryData.fight_setup(_story_id, index, _progress)
		GameState.story_result = ""
		Sfx.play("ui_start")
		get_tree().change_scene_to_file(GameState.FIGHT_SCENE))


## 對戰打完回到這裡。贏了:存檔、播結尾對話(第一次過關才播)、結算。
func _after_fight(index: int, won: bool) -> void:
	index = clampi(index, 0, _stages.size() - 1)
	if not won:
		_show_hub(index)
		_toast("沒能過關。調整配點、看看能力說明,再挑戰一次吧")
		return
	var stage := _stages[index]
	var first := index >= int(_progress.cleared)
	var gained := int(stage.get("exp", 0)) if first else roundi(int(stage.get("exp", 0)) * StoryData.REPLAY_EXP)
	var level_before := int(_progress.level)
	StoryData.add_exp(_progress, gained)
	if first:
		_progress.cleared = index + 1
	StorySave.save_progress(_story_id, _progress)
	var summary := {
		"stage": stage, "exp": gained, "first": first,
		"level_before": level_before, "level": int(_progress.level),
		"unlock": str(stage.get("unlock", "")) if first else "",
	}
	_show_hub(index + 1 if first else index)
	if first:
		_play_dialogue(stage.get("after", []), _show_reward.bind(summary))
	else:
		_show_reward(summary)


func _play_dialogue(lines: Array, then: Callable) -> void:
	if lines.is_empty():
		then.call()
		return
	var dialogue := StoryDialogue.new()
	_set_overlay(dialogue)
	dialogue.finished.connect(func() -> void:
		_set_overlay(null)
		then.call())
	dialogue.play(lines, _story_id)


## 過關的結算:經驗值、升級、新能力。
func _show_reward(summary: Dictionary) -> void:
	var cover := Control.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.05, 0.88)
	cover.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	var panel := _panel(Color(0.14, 0.16, 0.25), 14, 28)
	panel.custom_minimum_size.x = 520
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = GOLD
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var stage: Dictionary = summary.stage
	var headline := _label("過關!", 44)
	headline.add_theme_color_override("font_color", GOLD)
	box.add_child(headline)
	box.add_child(_label("%s  %s" % [stage.id, stage.title], 22, 0.85))
	box.add_child(_label("獲得經驗值 +%d%s" % [summary.exp, "" if summary.first else "(重打)"], 24))
	if int(summary.level) > int(summary.level_before):
		var up := _label("等級提升!Lv.%d → Lv.%d" % [summary.level_before, summary.level], 26)
		up.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		box.add_child(up)
		var points := (int(summary.level) - int(summary.level_before)) * StoryData.POINTS_PER_LEVEL
		box.add_child(_label("得到 %d 點可分配點數" % points, 20, 0.9))
	var unlock := str(summary.unlock)
	if not unlock.is_empty():
		for ability: Dictionary in _story.get("abilities", []):
			if ability.id != unlock:
				continue
			var learned := _label("領悟新能力:%s" % ability.name, 26)
			learned.add_theme_color_override("font_color", Color(1.0, 0.72, 0.88))
			box.add_child(learned)
			var note := _label("%s:%s" % [ability.key, ability.note], 18, 0.9)
			note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			note.custom_minimum_size.x = 460
			box.add_child(note)
	if summary.first and int(_progress.cleared) >= _stages.size():
		box.add_child(_label("目前的章節都完成了,故事待續", 20, 0.85))
	var next := _button("繼續", 26, Vector2(220, 60))
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(next)
	_reward_continue = func() -> void:
		_reward_continue = Callable()
		Sfx.play("ui_confirm")
		_set_overlay(null)
		_show_hub(_cursor)  # 重畫:等級、點數、新能力
	next.pressed.connect(func() -> void: _reward_continue.call())
	_set_overlay(cover)
	Sfx.play("victory")


func _set_overlay(node: Control) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_overlay = node
	if node != null:
		add_child(node)


# ---------- 介面 ----------

## 不隨換頁改變的部分:背景、上方的標題、左上角的音效開關與返回、下方的提示。
func _build_frame() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.1, 0.11, 0.17)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_safe_controls.append(overlay)
	GameState.fit_to_safe_area(overlay)

	var sound := _button("", 20, Vector2.ZERO)
	sound.offset_left = 30
	sound.offset_right = 150
	sound.offset_top = 24
	sound.offset_bottom = 72
	Sfx.setup_button(sound)
	overlay.add_child(sound)
	_back_button = _button("◀ 主選單", 20, Vector2.ZERO)
	_back_button.offset_left = 162
	_back_button.offset_right = 292
	_back_button.offset_top = 24
	_back_button.offset_bottom = 72
	_back_button.pressed.connect(_on_back)
	overlay.add_child(_back_button)

	_title_label = _label("", 34)
	_title_label.anchor_right = 1.0
	_title_label.offset_left = 300
	_title_label.offset_right = -300
	_title_label.offset_top = 22
	_title_label.offset_bottom = 74
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(_title_label)

	_toast_label = _label("", 20)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.anchor_right = 1.0
	_toast_label.offset_top = -30
	_toast_label.offset_bottom = -2
	overlay.add_child(_toast_label)
	if GameState.touch_enabled:
		OrientationNotice.attach_if_touch(self)


## 換掉中間那一頁的內容(標題列下面的整塊區域)。
func _set_page(content: Control) -> void:
	if _page != null:
		_safe_controls.erase(_page)
		_page.queue_free()
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", 30)
	holder.add_theme_constant_override("margin_right", 30)
	holder.add_theme_constant_override("margin_top", 88)
	holder.add_theme_constant_override("margin_bottom", 32)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	move_child(holder, 1)  # 背景之上、角落的按鈕之下
	holder.add_child(content)
	_page = holder
	_safe_controls.append(holder)
	GameState.fit_to_safe_area(holder)
	_pressed_row = -1


func _toast(text: String) -> void:
	_toast_label.text = text
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(_toast_label) and _toast_label.text == text:
		_toast_label.text = ""


## 角色的待機動畫,腳踩在 area 的底邊中央。
func _portrait(character_name: String, area: Vector2) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = area
	var index := GameState.find_character(character_name)
	if index < 0:
		return holder
	var loaded := SpriteSheetLoader.load_character(GameState.CHARACTERS[index].get("sprites", ""))
	if loaded.is_empty():
		return holder
	var canvas: Vector2 = loaded.canvas
	var sprite := AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = loaded.frames
	sprite.centered = false
	sprite.scale = Vector2.ONE * float(loaded.scale)
	sprite.offset = Vector2(-canvas.x / 2.0, -canvas.y)
	sprite.position = Vector2(area.x / 2.0, area.y)
	holder.add_child(sprite)
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	return holder


func _panel(color: Color, radius: int, margin: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.62, 0.9, 0.35)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _button(text: String, font_size: int, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _label(text: String, font_size: int, alpha: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = alpha
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
