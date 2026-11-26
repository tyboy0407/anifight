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
##   foe_setup         另外交給對手 apply_story 的設定(例如 {"sharingan": false}:卡卡西這一場不開寫輪眼)
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
const REPLAY_EXP := 0.5     # 重打已經過關的關卡,經驗值只有這個比例
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
	"kakashi": {"name": "卡卡西", "character": "卡卡西"},
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
		"passive": "里香失控:血量低於 35% 時,里香會顯化爆走 15 秒(每回合一次)",
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
							["gojo", "所以才要你去。不面對她,就永遠學不會怎麼掌握自己。"],
							["", "隧道深處。空氣像泡過水的布一樣沉。"],
							["curse", "嘻……嘻嘻……一起……玩……"],
							["yuta", "[握緊刀](里香,拜託妳,不要出來。)"],
						],
						"after": [
							["yuta", "哈……哈……打倒了。"],
							["", "(咒靈消散的地方,空間像玻璃一樣裂開了一道縫。)"],
							["yuta", "這是什麼……帳?不對,咒力的感覺完全不一樣——"],
							["rika", "憂……太……危險……"],
							["yuta", "里香!?不行,不要出來——!"],
							["", "裂縫猛然張開,把少年連同他的詛咒一起吞了進去。"],
						],
					},
					{
						"id": "1-2", "title": "異界的喰種",
						"foe": {"character": "金木研"},
						"health": 1, "damage": 0.85, "think": 1.4, "idle": 0.2,
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
						"health": 1.2, "damage": 0.9, "think": 1, "idle": 0.1,
						"exp": 150,
						"tip": "傳聞的金色閃光... 要小心他帶給你的印記",
						"before": [
							["", "「帶著怪物的白衣少年」。傳言在異界跑得比乙骨的腳步快得多。"],
							["", "第三天,他在一座臨時搭起的營地外被攔了下來。"],
							["minato", "請在那裡停下。再往前,就是避難的人們休息的地方了。", "金髮的忍者"],
							["yuta", "我、我只是想問路。還有……如果可以的話,想要一點水。"],
							["minato", "抱歉。昨晚巡邏的人說,看見一隻巨大的怪物跟在一個少年身後。描述和你完全一致。", "金髮的忍者"],
							["yuta", "……那是里香。她不會隨便攻擊人。"],
							["minato", "你的承諾保護不了我身後的孩子們。我是木葉的忍者,波風湊。在確認你無害之前,不能讓你過去。"],
							["yuta", "(他是對的。換成是我,也不會讓我這種人靠近。)"],
							["minato", "只要交過手，我就能知道你是善類，還是..."],
							["yuta", "……我明白了。"],
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
						"health": 1.3, "damage": 1.2, "think": 1, "idle": 0.1,
						"exp": 200,
						"tip": "按住防禦(S)可以擋下突如其來的攻擊...",
						"before": [
							["", "東邊的山道。雷聲從沒有雲的天上傳來。"],
							["sasuke", "找到了。帶著怪物的傢伙。", "黑髮的少年"],
							["yuta", "又、又來了……那個,我真的不是敵人——"],
							["sasuke", "是不是敵人不重要。那股力量,你是從哪裡得到的?", "黑髮的少年"],
							["yuta", "得到……?里香不是那種東西!她是——"],
							["sasuke", "我需要力量。足以殺掉某個男人的力量。"],
							["yuta", "……你搞錯了。這不是你可以奪走的東西。"],
							["sasuke", "我這雙眼睛會看穿你的一切。只有奪走才不會被奪走"],
						],
						"after": [
							["sasuke", "嘖……那隻怪物最後撲出來的時候,你居然對著牠喊「停下」。對敵人手下留情?"],
							["yuta", "你不是敵人。你只是和我一樣,被某件事困住了。"],
							["sasuke", "……少自以為是。"],
							["yuta", "里香是我很重要的人。她死的時候,我沒能放手。這份力量,是我「不肯放手」的結果。"],
							["sasuke", "……哼。吵死了。"],
							["sasuke", "給你一個忠告。有人出了高價要你的命。接下委託的,是個連這雙眼睛都看不出半點查克拉的男人。"],
							["yuta", "看不出……?完全沒有咒力的人?"],
						],
					},
					{
						"id": "2-3", "title": "術師殺手",
						"foe": {"character": "伏黑甚爾"},
						"health": 1.8, "damage": 1.1, "think": 1, "idle": 0.1,
						"rounds": 2,
						"exp": 350,
						"unlock": "friend",
						"tip": "頭目戰:要贏兩回合",
						"before": [
							["", "夜裡。乙骨在廢墟邊緣生了一小堆火。"],
							["", "金木不知什麼時候跟了上來,坐在火堆的另一邊。"],
							["kaneki", "你來到這裡一直在戰鬥,術師。"],
							["yuta", "我也不想的……金木先生為什麼跟來?"],
							["kaneki", "想看看你最後會走到哪裡。"],
							["toji", "喲。氣氛還挺溫馨的嘛。", "???"],
							["", "(沒有腳步聲,沒有氣息。那個男人像是從夜色裡直接長出來的。)"],
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
							["", "第二章　完"],
						],
					},
				],
			},
			{
				"title": "第三章　對手",
				"stages": [
					{
						"id": "3-1", "title": "拷貝忍者",
						"foe": {"character": "卡卡西"},
						# 第一場他還不用寫輪眼
						"foe_setup": {"sharingan": false},
						"health": 1.5, "damage": 1, "think": 0.8, "idle": 0.08,
						"exp": 300,
						"tip": "卡卡西會記住你的招式:你用滿五次,他就會拿你的招式打你",
						"before": [
							["", "西邊的河谷。霧很濃,水聲很近。"],
							["", "乙骨和金木沿著河走了半天,一路上沒有遇到任何人——直到一本書從樹上掉了下來。"],
							["kakashi", "啊,抱歉抱歉。看到精彩的地方,手滑了。", "蒙面的忍者"],
							["yuta", "(從什麼時候開始在那裡的……我完全沒有發現。)"],
							["kakashi", "帶著巨大怪物的白衣少年。打倒了金色閃光,逼退了宇智波的小鬼,還讓那個術師殺手空手而回。傳言裡的人就是你吧。", "蒙面的忍者"],
							["yuta", "那些都是誤會!我沒有想和任何人打——"],
							["kakashi", "我知道。真正危險的傢伙,不會每打完一場都向對方道歉。", "蒙面的忍者"],
							["kakashi", "我是旗木卡卡西。別人都叫我「拷貝忍者」。"],
							["yuta", "模仿……別人的招式?"],
							["kakashi", "所以我對你很有興趣。你身上的力量,有多少是「你自己的」?讓我看看吧。"],
							["kaneki", "術師,這個人的氣息和之前的都不一樣。小心。"],
						],
						"after": [
							["kakashi", "嗯——到這裡就好。你的刀很乾淨,是認真練過的刀。"],
							["yuta", "哈……哈……卡卡西先生,您剛才的出手……和我一模一樣。"],
							["kakashi", "看過一次,就記住了。很狡猾對吧?"],
							["yuta", "……用別人的招式戰鬥,是什麼感覺?"],
							["yuta", "我的力量,沒有一樣是我自己的。里香是因為我不肯放手才留下來的。我只是……一直被她保護著而已。"],
							["kakashi", "招式這種東西,不是偷來就能用的。你得先看懂那個人——他為什麼這樣出手、想保護什麼、害怕什麼。"],
							["kakashi", "每用一次,就等於把那個人再想起來一次。所以我從來不覺得,自己是一個人在戰鬥。"],
							["yuta", "把那個人……再想起來一次。"],
							["kakashi", "光用說的不夠。休息一下,再打一場。這次我會認真——你也試著「學」點什麼吧。"],
						],
					},
					{
						"id": "3-2", "title": "借來的力量",
						"foe": {"character": "卡卡西"},
						"health": 2, "damage": 1.3, "think": 0.6, "idle": 0.05,
						"rounds": 2,
						"exp": 500,
						"unlock": "speech",
						"tip": "頭目戰:卡卡西開了寫輪眼之後,你每用一次招式他就能拷貝",
						"before": [
							["", "黃昏。河谷的霧散了。"],
							["kakashi", "準備好了嗎。"],
							["", "卡卡西把護額往上推。那隻一直遮著的眼睛,是血一樣的紅色。"],
							["yuta", "那隻眼睛……和山道上那個少年的一樣。"],
							["kakashi", "這隻眼睛,是一個朋友留給我的。他把它交給我的時候說,要我替他看著未來。"],
							["kakashi", "所以我用它看到的每一招,都不只是我一個人的。"],
							["yuta", "(朋友留下來的……)"],
							["yuta", "(里香。妳留在我身邊,不是為了讓我害怕的,對吧。)"],
							["kakashi", "來吧,乙骨。別只是看著我——看著你想保護的那些人。"],
						],
						"after": [
							["", "最後一擊交錯的瞬間,乙骨腦海裡浮現的不是招式,而是一個人。"],
							["", "高專的教室。總是把衣領拉到嘴邊的同學,為了不傷到別人,連話都不敢好好說。"],
							["yuta", "(狗卷同學……你一直都是這樣,小心地握著自己的力量。)"],
							["yuta", "——飛走吧!"],
							["", "聲音化成了衝擊。卡卡西整個人被震退了好幾步。"],
							["kakashi", "……哈哈。這可不是我的招式。"],
							["yuta", "是我同學的。我一直看著他,卻從來沒想過……我也可以替他,把這份力量帶到這裡。"],
							["yuta", "謝謝妳,里香。還有——對不起,我一直把妳當成要拚命拉住的東西。"],
							["kakashi", "學得比我當年快多了。看來「拷貝忍者」的名號,得讓出一半。"],
							["kaneki", "你們兩個打完了的話,有件事要說。裂縫又出現了——而且這次不只一道。"],
							["kakashi", "果然。把我們這些人丟進同一個世界的東西,開始收網了。"],
							["kakashi", "乙骨,暫時一起行動吧。"],
							["yuta", "是!請多指教,卡卡西先生。"],
							["", "第三章　完"],
						],
					},
				],
			},
		],
		"coming": ["第四章"],
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
			{"health": float(stage.get("health", 1.0)), "damage": float(stage.get("damage", 1.0))}.merged(stage.get("foe_setup", {})),
		],
		"rounds": int(stage.get("rounds", 1)),
		"cpu": {"think": float(stage.get("think", 1.0)), "idle": float(stage.get("idle", 0.0))},
		"tip": str(stage.get("tip", "")),
	}
