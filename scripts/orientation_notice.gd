class_name OrientationNotice
extends CanvasLayer
## 手機直放時蓋住畫面,提示玩家把手機橫放。只在觸控模式下使用。

var _cover: ColorRect


func _ready() -> void:
	layer = 50
	_cover = ColorRect.new()
	_cover.color = Color(0.06, 0.07, 0.11)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)

	var label := Label.new()
	label.text = "請把手機橫放"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(label)

	get_window().size_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var window_size := get_window().size
	_cover.visible = window_size.y > window_size.x


## 觸控模式下才加上提示。
static func attach_if_touch(parent: Node) -> void:
	if GameState.touch_enabled:
		parent.add_child(OrientationNotice.new())
