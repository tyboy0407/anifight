extends SceneTree
## 自動切圖工具:找出 sprite sheet 上每一個圖塊的邊界,依列排好,輸出 sheet.json 的骨架。
##
## 用法(在專案資料夾):
##   godot --headless --path . --script tools/slice_sheet.gd -- res://assets/characters/<id>/sheet.png
##
## 輸出(和圖片同一個資料夾):
##   sheet.json          若已存在則不覆蓋,改寫成 sheet.sliced.json
##   sheet_preview.png   標出每個圖塊的框與「列-序號」編號,用來對照哪幾格是哪個動作
##
## 接著在 sheet.json 的 "animations" 填入各動作引用哪一列的哪幾格,例如:
##   "idle": {"row": 0, "from": 0, "to": 3, "fps": 8, "loop": true}

const MIN_SIZE := 6        # 小於這個邊長的碎塊視為雜點
const MERGE_GAP := 3       # 相距這麼近的圖塊視為同一格(例如和身體分開的特效)
const BACKGROUND_TOLERANCE := 0.04
const ROW_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.3), Color(0.3, 0.8, 1.0), Color(0.4, 1.0, 0.4),
	Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 1.0), Color(1.0, 0.6, 0.2),
]
## 3x5 點陣數字與連字號,用來在預覽圖上標編號
const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111",
	"3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001001001001", "8": "111101111101111",
	"9": "111101111001111", "-": "000000111000000",
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("請指定圖片,例如:-- res://assets/characters/gojo/sheet.png")
		quit(1)
		return
	_slice(args[0])
	quit()


func _slice(path: String) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		printerr("讀不到圖片:%s" % path)
		return
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()

	# 判斷背景:有透明像素就用透明度,否則把左上角的顏色當成背景色
	var corner := image.get_pixel(0, 0)
	var uses_alpha := image.detect_alpha() != Image.ALPHA_NONE
	var solid := PackedByteArray()
	solid.resize(width * height)
	for y in height:
		for x in width:
			var pixel := image.get_pixel(x, y)
			var is_background := pixel.a < 0.04 if uses_alpha else _similar(pixel, corner)
			solid[y * width + x] = 0 if is_background else 1

	var boxes := _merge_close(_find_boxes(solid, width, height))
	var rows := _group_rows(boxes)

	var rows_data: Array = []
	for row: Array in rows:
		var row_data: Array = []
		for box: Rect2i in row:
			row_data.append([box.position.x, box.position.y, box.size.x, box.size.y])
		rows_data.append(row_data)
	var data := {"scale": 2.0, "foot_offset": 0, "rows": rows_data, "animations": {}}
	if not uses_alpha:
		data["background"] = [corner.r8, corner.g8, corner.b8]

	var dir := path.get_base_dir()
	var json_path := dir.path_join("sheet.json")
	if FileAccess.file_exists(json_path):
		json_path = dir.path_join("sheet.sliced.json")
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var preview_path := dir.path_join("sheet_preview.png")
	_make_preview(image, rows).save_png(ProjectSettings.globalize_path(preview_path))

	print("圖片 %dx%d,背景:%s" % [width, height, "透明" if uses_alpha else "純色 %s" % [data["background"]]])
	print("找到 %d 個圖塊,分成 %d 列:" % [boxes.size(), rows.size()])
	for i in rows.size():
		var row: Array = rows[i]
		var first: Rect2i = row[0]
		print("  第 %d 列:%d 格(y=%d,高約 %d)" % [i, row.size(), first.position.y, first.size.y])
	print("已寫入 %s 與 %s" % [json_path, preview_path])


func _similar(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < BACKGROUND_TOLERANCE


## 以八方向連通找出每一塊不透明區域的外框。
func _find_boxes(solid: PackedByteArray, width: int, height: int) -> Array[Rect2i]:
	var boxes: Array[Rect2i] = []
	var visited := PackedByteArray()
	visited.resize(width * height)
	var stack := PackedInt32Array()
	for start in width * height:
		if solid[start] == 0 or visited[start] == 1:
			continue
		var min_x := width
		var min_y := height
		var max_x := 0
		var max_y := 0
		stack.clear()
		stack.append(start)
		visited[start] = 1
		while not stack.is_empty():
			var index := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x := index % width
			@warning_ignore("integer_division")
			var y := index / width
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_y = mini(min_y, y)
			max_y = maxi(max_y, y)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= width or ny >= height:
						continue
					var neighbor := ny * width + nx
					if solid[neighbor] == 1 and visited[neighbor] == 0:
						visited[neighbor] = 1
						stack.append(neighbor)
		boxes.append(Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1))
	return boxes


## 把彼此很近的外框併成一格,並丟掉雜點。
func _merge_close(boxes: Array[Rect2i]) -> Array[Rect2i]:
	var merged := true
	while merged:
		merged = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if boxes[i].grow(MERGE_GAP).intersects(boxes[j]):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					merged = true
					break
			if merged:
				break
	var result: Array[Rect2i] = []
	for box in boxes:
		if box.size.x >= MIN_SIZE and box.size.y >= MIN_SIZE:
			result.append(box)
	return result


## 垂直範圍有重疊的外框歸為同一列;列由上到下、列內由左到右排序。
func _group_rows(boxes: Array[Rect2i]) -> Array:
	var sorted := boxes.duplicate()
	sorted.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().y < b.get_center().y)
	var rows: Array = []
	var row_top := 0
	var row_bottom := -1
	for box: Rect2i in sorted:
		var center_y := box.get_center().y
		if rows.is_empty() or center_y > row_bottom or center_y < row_top:
			rows.append([box])
			row_top = box.position.y
			row_bottom = box.end.y
		else:
			rows[rows.size() - 1].append(box)
			row_top = mini(row_top, box.position.y)
			row_bottom = maxi(row_bottom, box.end.y)
	for row: Array in rows:
		row.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.position.x < b.position.x)
	return rows


## 預覽圖:放大兩倍,深色底,畫出每格的框與「列-序號」。
func _make_preview(source: Image, rows: Array) -> Image:
	var zoom := 2
	var preview := Image.create(source.get_width() * zoom, source.get_height() * zoom, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.15, 0.15, 0.18))
	var scaled := source.duplicate() as Image
	scaled.resize(source.get_width() * zoom, source.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	preview.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i.ZERO)
	for row_index in rows.size():
		var color := ROW_COLORS[row_index % ROW_COLORS.size()]
		var row: Array = rows[row_index]
		for column in row.size():
			var box: Rect2i = row[column]
			var rect := Rect2i(box.position * zoom, box.size * zoom).grow(1)
			_stroke(preview, rect, color)
			_draw_text(preview, "%d-%d" % [row_index, column], rect.position + Vector2i(2, 2), color)
	return preview


func _stroke(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.end.x):
		_put(image, Vector2i(x, rect.position.y), color)
		_put(image, Vector2i(x, rect.end.y - 1), color)
	for y in range(rect.position.y, rect.end.y):
		_put(image, Vector2i(rect.position.x, y), color)
		_put(image, Vector2i(rect.end.x - 1, y), color)


func _draw_text(image: Image, text: String, at: Vector2i, color: Color) -> void:
	# 先墊一塊黑底,確保編號在任何圖上都讀得到
	for y in 7:
		for x in text.length() * 4 + 1:
			_put(image, at + Vector2i(x - 1, y - 1), Color.BLACK)
	for i in text.length():
		var glyph: String = GLYPHS.get(text[i], "")
		for bit in glyph.length():
			if glyph[bit] == "1":
				@warning_ignore("integer_division")
				_put(image, at + Vector2i(i * 4 + bit % 3, bit / 3), color)


func _put(image: Image, point: Vector2i, color: Color) -> void:
	if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
		image.set_pixelv(point, color)
