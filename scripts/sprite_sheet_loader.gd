class_name SpriteSheetLoader
extends RefCounted
## 從角色資料夾的 sheet.png + sheet.json 建立動畫資源。
##
## sheet.json 格式:
## {
##   "scale": 3.0,              // 顯示倍率
##   "foot_offset": 0,          // 腳底離格子底邊的像素數
##   "background": [r, g, b],   // 選填:要去背的純色背景(0-255);圖片本身透明就不用寫
##   "rows": [[[x, y, w, h], ...], ...],   // 選填:切圖工具輸出的各列圖塊
##   "animations": {
##     "idle": {"fps": 6, "loop": true, "frames": [[x, y, w, h], ...]},
##     "walk": {"fps": 10, "loop": true, "row": 1, "from": 0, "to": 5}   // 也可以引用 rows
##   }
## }
## 各格大小可以不同,載入時會以「底邊置中」對齊到同一個畫布大小。

const SHEET_IMAGE := "sheet.png"
const SHEET_DATA := "sheet.json"


## 回傳 {frames: SpriteFrames, scale: float, canvas: Vector2, foot_offset: float};
## 資料夾沒有素材或格式有誤時回傳空字典。
static func load_character(dir: String) -> Dictionary:
	if dir.is_empty():
		return {}
	var image_path := dir.path_join(SHEET_IMAGE)
	var data_path := dir.path_join(SHEET_DATA)
	if not FileAccess.file_exists(data_path) or not ResourceLoader.exists(image_path):
		return {}

	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary:
		push_warning("sprite sheet 設定檔格式錯誤: %s" % data_path)
		return {}
	var texture: Texture2D = load(image_path)
	if data.get("background") is Array:
		texture = _key_out_background(texture, data.background)

	var rows: Array = data.get("rows", [])
	var animations: Dictionary = data.get("animations", {})
	var resolved: Dictionary = {}  # 動畫名稱 -> Array[Rect2]
	var canvas := Vector2.ZERO
	for animation_name: String in animations:
		var rects := _resolve_rects(animations[animation_name], rows)
		if rects.is_empty():
			continue
		resolved[animation_name] = rects
		for rect in rects:
			canvas.x = maxf(canvas.x, rect.size.x)
			canvas.y = maxf(canvas.y, rect.size.y)
	if resolved.is_empty():
		return {}

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation_name: String in resolved:
		var spec: Dictionary = animations[animation_name]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, float(spec.get("fps", 8)))
		frames.set_animation_loop(animation_name, bool(spec.get("loop", true)))
		for rect: Rect2 in resolved[animation_name]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = rect
			# 用 margin 把大小不一的格子補成同一個畫布:水平置中、底邊對齊。
			var extra := canvas - rect.size
			atlas.margin = Rect2(floorf(extra.x / 2.0), extra.y, extra.x, extra.y)
			frames.add_frame(animation_name, atlas)

	return {
		"frames": frames,
		"scale": float(data.get("scale", 1.0)),
		"canvas": canvas,
		"foot_offset": float(data.get("foot_offset", 0.0)),
	}


static func _resolve_rects(spec: Dictionary, rows: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var source: Array = []
	if spec.has("frames"):
		source = spec.frames
	elif spec.has("row"):
		var row_index := int(spec.row)
		if row_index < 0 or row_index >= rows.size():
			return rects
		var row: Array = rows[row_index]
		var from := clampi(int(spec.get("from", 0)), 0, row.size() - 1)
		var to := clampi(int(spec.get("to", row.size() - 1)), from, row.size() - 1)
		source = row.slice(from, to + 1)
	for item: Array in source:
		rects.append(Rect2(item[0], item[1], item[2], item[3]))
	return rects


## 把純色背景變成透明。
static func _key_out_background(texture: Texture2D, background: Array) -> Texture2D:
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var key := Color8(int(background[0]), int(background[1]), int(background[2]))
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - key.r) + absf(pixel.g - key.g) + absf(pixel.b - key.b) < 0.04:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)
