class_name StorySave
extends RefCounted
## 故事模式的進度存檔。每一篇故事各存一份:過了幾關、等級、經驗值、每一項能力加了幾點。
## 存在 user://(網頁版是瀏覽器裡這個網站的儲存空間),清掉瀏覽器資料就會不見。

## 存檔的位置。測試時可以換成別的檔案,免得動到真的進度。
static var path := "user://story.cfg"


## 讀出某一篇故事的進度;還沒玩過就是全新的。
static func load_progress(story_id: String) -> Dictionary:
	var progress := {"cleared": 0, "level": 1, "exp": 0, "stats": {}}
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return progress
	progress.cleared = maxi(int(config.get_value(story_id, "cleared", 0)), 0)
	progress.level = clampi(int(config.get_value(story_id, "level", 1)), 1, StoryData.MAX_LEVEL)
	progress.exp = maxi(int(config.get_value(story_id, "exp", 0)), 0)
	var saved: Variant = config.get_value(story_id, "stats", {})
	if saved is Dictionary:
		for stat in StoryData.STATS:
			progress.stats[stat.id] = clampi(int(saved.get(stat.id, 0)), 0, StoryData.STAT_CAP)
	# 存檔被改壞、點數超過等級給的量:把配點清掉重來
	if StoryData.free_points(progress) < 0:
		progress.stats = {}
	return progress


static func save_progress(story_id: String, progress: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(path)  # 保留其他故事的進度;檔案還不存在也沒關係
	config.set_value(story_id, "cleared", int(progress.cleared))
	config.set_value(story_id, "level", int(progress.level))
	config.set_value(story_id, "exp", int(progress.exp))
	config.set_value(story_id, "stats", progress.stats)
	config.save(path)
