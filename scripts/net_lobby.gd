class_name NetLobby
extends Control
## 連線對戰的房間視窗(蓋在選角畫面上):建立房間、輸入房間號碼加入、等對手到齊。
## 兩個人到齊、確認版本一樣之後發出 paired,由選角畫面切換成連線選角;按返回則發出 cancelled。
## 房間號碼用畫面上的數字鍵輸入(手機瀏覽器在遊戲裡叫不出鍵盤),有鍵盤的話也可以直接打數字。

signal paired
signal cancelled

enum View { MENU, HOSTING, JOINING, CONNECTING, PAIRED }

const CODE_LENGTH := 4
const ERRORS := {
	"no_room": "找不到這個房間,請確認號碼",
	"full": "這個房間已經有兩個人了",
	"bad_code": "房間號碼是四個數字",
	"busy": "現在開不了房間,請再試一次",
	"offline": "連不上伺服器,請檢查網路後再試",
	"closed": "和伺服器的連線中斷了",
	"version": "雙方的遊戲版本不一樣\n請兩邊都重新整理網頁後再試",
}

var _net: NetSession
var _view := View.MENU
var _typed := ""
var _box: VBoxContainer
var _code_label: Label
var _message_label: Label


func _ready() -> void:
	_net = NetSession.get_session()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 壓暗背景,並擋住後面的選角畫面
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.05, 0.94)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	GameState.fit_to_safe_area(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 14)
	center.add_child(_box)
	_show(View.MENU)


func _process(_delta: float) -> void:
	var messages := _net.take_messages()
	for index in messages.size():
		var message: Dictionary = messages[index]
		if message.has("sys"):
			match str(message.sys):
				"room":
					if _view == View.HOSTING:
						_show(View.HOSTING)  # 重畫:這次有房間號碼了
				"joined":
					# 兩個人到齊:先互報版本和操作方式
					_net.send_message({"t": "hello", "v": GameState.NET_VERSION, "touch": GameState.touch_enabled})
					_show(View.PAIRED)
				"left":
					# 對方還沒進選角就走了:開房間的人繼續等
					_show(View.HOSTING if _net.status == NetSession.Status.WAITING else View.MENU)
				"error":
					_fail(str(message.get("reason", "offline")))
				"closed":
					_fail("closed")
		elif str(message.get("t", "")) == "hello":
			if int(message.get("v", -1)) != GameState.NET_VERSION:
				_net.leave()
				_fail("version")
				return
			var me := _net.role - 1
			GameState.net_touch[me] = GameState.touch_enabled
			GameState.net_touch[1 - me] = bool(message.get("touch", false))
			# 後面還沒看的訊息(對方可能已經在選角了)留給選角畫面
			_net.put_back(messages.slice(index + 1))
			paired.emit()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key: int = (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		_back()
	elif _view == View.JOINING:
		if key >= KEY_0 and key <= KEY_9:
			_type(str(key - KEY_0))
		elif key >= KEY_KP_0 and key <= KEY_KP_9:
			_type(str(key - KEY_KP_0))
		elif key == KEY_BACKSPACE:
			_erase()
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			_join()


# ---------- 動作 ----------

func _host() -> void:
	Sfx.play("ui_confirm")
	_net.create_room()
	_show(View.HOSTING)


func _open_join() -> void:
	Sfx.play("ui_confirm")
	_typed = ""
	_show(View.JOINING)


func _join() -> void:
	if _typed.length() != CODE_LENGTH:
		_message_label.text = ERRORS.bad_code
		return
	Sfx.play("ui_confirm")
	_net.join_room(_typed)
	_show(View.CONNECTING)


func _type(digit: String) -> void:
	if _typed.length() >= CODE_LENGTH:
		return
	_typed += digit
	Sfx.play("ui_move")
	_update_code()


func _erase() -> void:
	if _typed.is_empty():
		return
	_typed = _typed.left(-1)
	Sfx.play("ui_move")
	_update_code()


## 返回上一層;在第一層就關掉整個視窗。
func _back() -> void:
	Sfx.play("ui_move")
	if _view == View.MENU:
		cancelled.emit()
		return
	_net.leave()
	_show(View.MENU)


func _fail(reason: String) -> void:
	var text: String = ERRORS.get(reason, ERRORS.offline)
	# 輸入號碼後加入失敗:留在輸入畫面,可以直接改號碼
	_show(View.JOINING if _view == View.CONNECTING else View.MENU)
	_message_label.text = text


# ---------- 畫面 ----------

func _show(view: View) -> void:
	_view = view
	for child in _box.get_children():
		child.queue_free()
	_code_label = null
	_box.add_child(_label("連線對戰", 44))
	match view:
		View.MENU:
			_box.add_child(_label("一個人建立房間,把房間號碼告訴對方;另一個人輸入號碼加入", 18, 0.75))
			_box.add_child(_button("建立房間", _host))
			_box.add_child(_button("加入房間", _open_join))
		View.HOSTING:
			_box.add_child(_label("房間號碼", 22, 0.75))
			var code := _label(_spaced(_net.code) if not _net.code.is_empty() else "建立中…", 84 if not _net.code.is_empty() else 40)
			code.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
			_box.add_child(code)
			_box.add_child(_label("把號碼告訴對手,等他加入…", 20, 0.75))
		View.JOINING:
			_box.add_child(_label("輸入房間號碼", 22, 0.75))
			_code_label = _label("", 72)
			_code_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
			_box.add_child(_code_label)
			_update_code()
			_box.add_child(_keypad())
		View.CONNECTING:
			_box.add_child(_label("正在加入房間 %s…" % _spaced(_typed), 26))
		View.PAIRED:
			_box.add_child(_label("對手到齊了,準備進入選角…", 26))
	_message_label = _label("", 20)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_box.add_child(_message_label)
	if view != View.PAIRED:
		_box.add_child(_button("返回", _back, Vector2(200, 54), 22))


## 數字鍵:1 到 9、倒退、0、加入。
func _keypad() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for digit in range(1, 10):
		grid.add_child(_button(str(digit), _type.bind(str(digit)), Vector2(96, 64), 30))
	grid.add_child(_button("←", _erase, Vector2(96, 64), 28))
	grid.add_child(_button("0", _type.bind("0"), Vector2(96, 64), 30))
	grid.add_child(_button("加入", _join, Vector2(96, 64), 24))
	return grid


func _update_code() -> void:
	if _code_label != null:
		_code_label.text = _spaced(_typed.rpad(CODE_LENGTH, "_"))
	if _message_label != null:
		_message_label.text = ""


## 數字之間留空格,比較好念給對方聽。
func _spaced(text: String) -> String:
	return " ".join(text.split(""))


func _label(text: String, font_size: int, alpha: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = alpha
	return label


func _button(text: String, action: Callable, minimum_size: Vector2 = Vector2(300, 68), font_size: int = 28) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(action)
	return button
