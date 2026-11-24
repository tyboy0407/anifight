class_name StoryData
extends RefCounted
## 故事模式的內容與規則:有哪些故事、每一章每一關的對話與對手,以及主角怎麼成長。
## 進度(打到第幾關、等級、配點)存在 StorySave;畫面在 story.gd。
##
## 新增一篇故事:在 STORIES 加一筆。一篇故事的主角是一位角色,章節(chapters)裡是一關一關的 stages:
##   id / title    關卡編號與標題
##   foe           對手。{"character": 角色名字, "form": 型態編號}(名單裡的角色),
##                 或 {"info": {...}}(只在故事裡出現的對手,格式同 GameState.CHARACTERS 的一筆)
##   health / damage   對手的生命與傷害倍率(1 = 和一般對戰一樣)
##   think / idle      電腦的反應速度(越大越慢)與發呆的機率
##   rounds            要贏幾回合(預設 1)
##   exp               第一次過關拿到的經驗值(重打只有一部分,見 REPLAY_EXP)
##   unlock            過關後主角領悟的能力(abilities 裡的 id);沒有就不寫
##   tip               對戰開場顯示的一行提示
##   before / after    開打前、打贏後的對話。每一句是 [誰, 內容] 或 [誰, 內容, 顯示的名字];
##                     「誰」是 CAST 的 id,空字串是旁白。
## 還沒做好的章節寫在 coming,故事畫面上會顯示成「製作中」。

const MAX_LEVEL := 30
const POINTS_PER_LEVEL := 2
const STAT_CAP := 20         # 每一項能力最多加幾點
const REPLAY_EXP := 0.25     # 重打已經過關的關卡,經驗值只有這個比例
## 可以配點的能力:id 對應 Fighter.apply_story 的設定;step 是每一點增加的比例。
const STATS: Array[Dictionary] = [
	{"id": "health", "name": "體力", "note": "生命上限", "step": 0.03},
	{"id": "damage", "name": "攻擊", "note": "造成的傷害", "step": 0.025},
	{"id": "energy", "name": "咒力", "note": "累積氣量的速度", "step": 0.04},
]

## 對話裡會出現的人。character 是名單裡的角色名字(用他的待機圖);
## sprites + animation 是直接指定圖;big 是體型特別大的(圖以中心對齊)。
const CAST := {
	"yuta": {"name": "乙骨憂太", "character": "乙骨憂太"},
	"gojo": {"name": "五條悟", "character": "五條悟"},
	"kaneki": {"name": "金木研", "character": "金木研"},
	"minato": {"name": "波風湊", "character": "波風湊"},
	"sasuke": {"name": "宇智波佐助", "character": "宇智波佐助"},
	"toji": {"name": "伏黑甚爾", "character": "伏黑甚爾"},
	"curse": {"name": "咒靈", "sprites": "res://assets/characters/curse", "animation": "idle"},
	"rika": {"name": "里香", "sprites": "res://assets/summons_fx", "animation": "rika", "big": true},
}

const CURSE_INFO := {
	"name": "低級咒靈",
	"scene": "res://scenes/characters/curse.tscn",
	"sprites": "res://assets/characters/curse",
	"hair": Color(0.42, 0.3, 0.5),
	"skills": ["", "", ""],
	"summary": "",
}

const STORIES: Array[Dictionary] = [
	{
		"id": "yuta",
		"character": "乙骨憂太",
		"title": "守護篇章",
		"tagline": "控制不住的力量,會不會傷害到同伴?",
		# 隨劇情領悟的能力,依領悟的順序。key 是對戰時的按鍵提示。
		"abilities": [
			{"id": "buff", "name": "我也可以!", "key": "招式二", "note": "把咒力灌進刀裡,10 秒內普攻傷害提升"},
			{"id": "friend", "name": "不准欺負我的朋友!", "key": "招式一", "note": "氣量滿 4 格時:必定黑閃的一拳"},
			{"id": "speech", "name": "飛走吧!", "key": "招式一", "note": "複製來的咒言,把對手震飛"},
			{"id": "rika", "name": "來吧,里香!", "key": "大招", "note": "召喚里香並肩作戰"},
		],
		# 還不會最後一項能力時的特殊狀態,顯示在能力清單下面
		"passive": "里香失控:血量低於 35% 時,里香會自己衝出來 15 秒(每回合一次)",
		"chapters": [
			{
				"title": "第一章　捲入",
				"stages": [
					{
						"id": "1-1", "title": "第一個任務",
						"foe": {"info": CURSE_INFO},
						"health": 0.6, "damage": 0.8, "think": 1.8, "idle": 0.35,
						"exp": 80,
						"tip": "只靠刀戰鬥:普攻連按三下,第三下會把對手打飛",
						"before": [
							["", "東京都立咒術高等專門學校。乙骨憂太入學後的第三個星期。"],
							["gojo", "憂太~今天有個簡單的任務。廢棄隧道裡的低級咒靈,你一個人去。"],
							["yuta", "一、一個人嗎?可是老師,我……"],
							["gojo", "你怕的不是咒靈,是你背後那一位。對吧?"],
							["yuta", "……上次里香失控的時候,教室的牆少了半面。要是當時有同學站在那裡——"],
							["gojo", "所以才要你去。力量這種東西,不用,就永遠學不會怎麼握住它。"],
							["", "隧道深處。空氣像泡過水的布一樣沉。"],
							["curse", "嘻……嘻嘻……一起……玩……"],
							["yuta", "(握緊刀。只靠我自己。里香,拜託妳,不要出來。)"],
						],
						"after": [
							["yuta", "哈……哈……打倒了。只靠我自己……"],
							["", "咒靈消散的地方,空間像玻璃一樣裂開了一道縫。"],
							["yuta", "這是什麼……帳?不對,咒力的感覺完全不一樣——"],
							["rika", "憂……太……危險……"],
							["yuta", "里香!?不行,不要出來——!"],
							["", "裂縫猛然張開,把少年連同他的詛咒一起吞了進去。"],
						],
					},
					{
						"id": "1-2", "title": "異界的喰種",
						"foe": {"character": "金木研"},
						"health": 0.75, "damage": 0.85, "think": 1.4, "idle": 0.2,
						"exp": 120,
						"unlock": "buff",
						"tip": "血量太低時,里香會不受控制地衝出來",
						"before": [
							["", "醒來的時候,天空是沒見過的顏色。"],
							["", "廢墟、森林、樣式陌生的城牆,像被誰隨手拼在同一片大地上。"],
							["yuta", "這裡是……哪裡?手機沒有訊號,也感覺不到帳的邊界。"],
							["kaneki", "……別動。", "???"],
							["kaneki", "你身上有味道。不是人,也不是喰種。是更大、更餓的東西。", "白髮的青年"],
							["yuta", "喰、喰種?那個,我不是可疑的人!我只是掉進了一道裂縫——"],
							["kaneki", "你背後那個,正盯著我看。把這裡的人當成獵物的傢伙,我見過太多了。", "白髮的青年"],
							["yuta", "她不是——里香不會——(……我真的敢保證嗎?)"],
							["kaneki", "答不出來嗎。那我只好先折斷你的手腳,再慢慢問。", "白髮的青年"],
						],
						"after": [
							["kaneki", "……停手吧。你的刀一直在發抖,卻一次都沒有對準要害。"],
							["yuta", "因為我不想傷害任何人。剛才里香衝出來的時候……對不起。"],
							["kaneki", "道歉?被襲擊的是你。……原來如此。你不是在操控牠,是在拚命拉住牠。"],
							["kaneki", "我叫金木研。我的身體裡,也住著不是我的東西。餓起來的時候,我不知道自己會做出什麼事。"],
							["yuta", "金木先生也是……"],
							["kaneki", "這個世界很奇怪。忍者、術師、喰種——從不同地方掉進來的人全混在一起,每個人都很緊張。"],
							["kaneki", "帶著那種東西到處走,你會被所有人當成敵人。小心一點,術師。"],
							["yuta", "(來自不同世界的人……那我,回得去嗎?)"],
							["yuta", "(不對。在想著回去之前——我得先握住自己的力量。)"],
							["", "乙骨第一次試著把咒力主動送進刀身。刀刃亮起了淡淡的藍光。"],
						],
					},
				],
			},
			{
				"title": "第二章　嫌疑",
				"stages": [
					{
						"id": "2-1", "title": "金色閃光",
						"foe": {"character": "波風湊"},
						"health": 0.85, "damage": 0.9, "think": 1.25, "idle": 0.14,
						"exp": 150,
						"tip": "新能力「我也可以!」:用招式二強化普攻 10 秒",
						"before": [
							["", "「帶著怪物的白衣少年」。傳言在異界跑得比乙骨的腳步快得多。"],
							["", "第三天,他在一座臨時搭起的營地外被攔了下來。"],
							["minato", "請在那裡停下。再往前,就是避難的人們休息的地方了。", "金髮的忍者"],
							["yuta", "我、我只是想問路。還有……如果可以的話,想要一點水。"],
							["minato", "抱歉。昨晚巡邏的人說,看見一隻巨大的怪物跟在一個少年身後。描述和你完全一致。", "金髮的忍者"],
							["yuta", "……那是里香。她不會隨便攻擊人。大概。"],
							["minato", "「大概」保護不了我身後的孩子們。我是木葉的忍者,波風湊。在確認你無害之前,不能讓你過去。"],
							["yuta", "(他是對的。換成是我,也不會讓我這種人靠近。)"],
							["yuta", "……我明白了。那就請您確認吧。用我的刀。"],
						],
						"after": [
							["minato", "到此為止吧。那隻怪物好幾次想從背後撲向我,你每一次都搶先擋在牠前面。"],
							["yuta", "因為那樣的話,就不是「我」在戰鬥了。而且……會有人受傷。"],
							["minato", "你在害怕自己的力量。"],
							["yuta", "……是的。"],
							["minato", "我有一個兒子。他的體內,被我親手封進了一股足以毀掉村子的力量。"],
							["minato", "我相信他總有一天能和那股力量好好相處。不是靠壓住它——而是因為他的身邊,會有想保護的人。"],
							["yuta", "想保護的人……"],
							["minato", "水和乾糧你拿去。營地我還是不能讓你進,但有件事要告訴你:東邊的山道上有人在打聽你。黑髮、紅眼睛的少年,殺氣很重。"],
						],
					},
					{
						"id": "2-2", "title": "寫輪眼",
						"foe": {"character": "宇智波佐助"},
						"health": 0.9, "damage": 0.95, "think": 1.15, "idle": 0.1,
						"exp": 180,
						"tip": "按住防禦(S)可以擋下千鳥與豪火球",
						"before": [
							["", "東邊的山道。雷聲從沒有雲的天上傳來。"],
							["sasuke", "找到了。帶著怪物的傢伙。", "黑髮的少年"],
							["yuta", "又、又來了……那個,我真的不是敵人——"],
							["sasuke", "是不是敵人不重要。那股力量,你是從哪裡得到的?", "黑髮的少年"],
							["yuta", "得到……?里香不是那種東西!她是——"],
							["sasuke", "我需要力量。足以殺掉某個男人的力量。如果被詛咒就能換來那種東西,我不介意。"],
							["yuta", "……你搞錯了。這不是值得羨慕的東西。"],
							["sasuke", "那就用身體告訴我。宇智波佐助——這雙眼睛會看穿你的一切。"],
						],
						"after": [
							["sasuke", "嘖……那隻怪物最後撲出來的時候,你居然對著牠喊「停下」。對敵人手下留情?"],
							["yuta", "你不是敵人。你只是和我一樣,被某件事困住了。"],
							["sasuke", "……少自以為是。"],
							["yuta", "里香是我很重要的人。她死的時候,我沒能放手。這份力量,是我「不肯放手」的結果。"],
							["yuta", "所以拜託你,不要說你不介意被詛咒。"],
							["sasuke", "……哼。那種吵死人的力量,我不要了。"],
							["sasuke", "給你一個忠告。有人出了高價要你的命。接下委託的,是個連這雙眼睛都看不出半點查克拉的男人。"],
							["yuta", "看不出……?完全沒有咒力的人?"],
						],
					},
					{
						"id": "2-3", "title": "術師殺手",
						"foe": {"character": "伏黑甚爾"},
						"health": 0.85, "damage": 0.85, "think": 1.15, "idle": 0.1,
						"rounds": 2,
						"exp": 260,
						"unlock": "friend",
						"tip": "頭目戰:要贏兩回合",
						"before": [
							["", "夜裡。乙骨在廢墟邊緣生了一小堆火。"],
							["", "金木不知什麼時候跟了上來,坐在火堆的另一邊。"],
							["kaneki", "你快把整個異界的人都打過一輪了,術師。"],
							["yuta", "我也不想的……金木先生為什麼跟來?"],
							["kaneki", "想看看拚命拉著怪物的人,最後會走到哪裡。"],
							["toji", "喲。氣氛還挺溫馨的嘛。", "???"],
							["", "沒有腳步聲,沒有氣息。那個男人像是從夜色裡直接長出來的。"],
							["toji", "特級過咒怨靈的宿主。這筆賞金,夠我在賽艇場泡上三個月。", "嘴角有疤的男人"],
							["yuta", "(完全感覺不到咒力……!)金木先生,快退後!"],
							["toji", "放心,錢只算你一個人的。——不過擋路的傢伙,我可不保證。", "嘴角有疤的男人"],
						],
						"after": [
							["", "男人的刀尖越過乙骨,直指他身後的金木。那一瞬間,里香比誰都先動了。"],
							["rika", "不准……欺負……憂太——!!"],
							["", "巨大的爪子橫掃而出。不分敵我。金木就在那道軌跡上。"],
							["yuta", "里香,停下!!"],
							["", "乙骨沒有閃開。他衝進爪子底下,用整個身體擋在金木前面。"],
							["", "爪尖停在他額前一寸的地方。"],
							["yuta", "……不准傷害他。他是我的朋友。"],
							["rika", "憂太……的……朋友……"],
							["toji", "哈。養的怪物聽話了一次,就這麼高興?……算了,今天收工。賠本的生意我不做。", "嘴角有疤的男人"],
							["kaneki", "……你剛才,是第一次對牠下命令。而不是拜託牠。"],
							["yuta", "我好像有一點點明白了。我怕的不是里香。是那個什麼都不敢握住的自己。"],
							["", "握緊的拳頭上,黑色的火花一閃而過。"],
							["toji", "對了,小鬼。西邊有個蒙面的白髮忍者也在找你。聽說那傢伙,能把看過的招式全部變成自己的。", "嘴角有疤的男人"],
							["yuta", "把別人的招式……變成自己的?"],
							["", "第二章　完"],
						],
					},
				],
			},
		],
		"coming": ["第三章　對手"],
	},
]


static func story(story_id: String) -> Dictionary:
	for entry in STORIES:
		if entry.id == story_id:
			return entry
	return {}


## 一篇故事所有的關卡,依順序攤平成一列;每一關多帶一個 chapter(第幾章,從 0 起算)。
static func stages(story_id: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var chapters: Array = story(story_id).get("chapters", [])
	for chapter_index in chapters.size():
		for stage: Dictionary in chapters[chapter_index].stages:
			var entry := stage.duplicate()
			entry["chapter"] = chapter_index
			list.append(entry)
	return list


## 升到下一級需要多少經驗值。
static func exp_to_next(level: int) -> int:
	return 40 + 40 * level


## 這個等級總共拿到幾點可以分配的點數。
static func points_at(level: int) -> int:
	return (level - 1) * POINTS_PER_LEVEL


## 還沒分配的點數。
static func free_points(progress: Dictionary) -> int:
	var spent := 0
	for stat in STATS:
		spent += int(progress.stats.get(stat.id, 0))
	return points_at(int(progress.level)) - spent


## 某一項能力現在的倍率(1 = 沒有加成)。
static func stat_scale(progress: Dictionary, stat_id: String) -> float:
	for stat in STATS:
		if stat.id == stat_id:
			return 1.0 + float(stat.step) * int(progress.stats.get(stat_id, 0))
	return 1.0


## 已經領悟的能力(id),看過了幾關來決定。
static func abilities(story_id: String, cleared: int) -> Array[String]:
	var learned: Array[String] = []
	var list := stages(story_id)
	for index in mini(cleared, list.size()):
		var unlock := str(list[index].get("unlock", ""))
		if not unlock.is_empty():
			learned.append(unlock)
	return learned


## 加上經驗值,該升級就升級。回傳升了幾級。
static func add_exp(progress: Dictionary, amount: int) -> int:
	var gained := 0
	progress.exp = int(progress.exp) + amount
	while int(progress.level) < MAX_LEVEL and int(progress.exp) >= exp_to_next(int(progress.level)):
		progress.exp = int(progress.exp) - exp_to_next(int(progress.level))
		progress.level = int(progress.level) + 1
		gained += 1
	if int(progress.level) >= MAX_LEVEL:
		progress.exp = 0
	return gained


## 對手的角色資料(格式同 GameState.CHARACTERS 的一筆)。
static func foe_info(stage: Dictionary) -> Dictionary:
	var foe: Dictionary = stage.foe
	if foe.has("info"):
		return foe.info
	var index := GameState.find_character(str(foe.get("character", "")))
	return GameState.form_info(maxi(index, 0), int(foe.get("form", 0)))


## 準備好一場故事對戰的設定,交給 GameState.story_fight(內容見那裡的說明)。
static func fight_setup(story_id: String, stage_index: int, progress: Dictionary) -> Dictionary:
	var entry := story(story_id)
	var stage := stages(story_id)[stage_index]
	var hero := GameState.CHARACTERS[maxi(GameState.find_character(str(entry.character)), 0)]
	return {
		"story": story_id,
		"stage": stage_index,
		"fighters": [hero, foe_info(stage)],
		"setups": [
			{
				"health": stat_scale(progress, "health"),
				"damage": stat_scale(progress, "damage"),
				"energy": stat_scale(progress, "energy"),
				"abilities": abilities(story_id, int(progress.cleared)),
			},
			{"health": float(stage.get("health", 1.0)), "damage": float(stage.get("damage", 1.0))},
		],
		"rounds": int(stage.get("rounds", 1)),
		"cpu": {"think": float(stage.get("think", 1.0)), "idle": float(stage.get("idle", 0.0))},
		"tip": str(stage.get("tip", "")),
	}
