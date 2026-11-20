extends SceneTree
## 角色平衡用的模擬:讓電腦對電腦打完整的對戰,輸出每一回合的結果。
##
## 執行方式(在專案資料夾,headless 會以最快速度模擬):
##   godot --headless --fixed-fps 60 --path . --script tools/balance_sim.gd -- <第幾個工人> <工人總數> <每種對戰打幾場>
## 把所有對戰組合平均分給幾個工人,就能同時開好幾個程序一起跑。例如開 4 個:
##   ... -- 0 4 4      ... -- 1 4 4      ... -- 2 4 4      ... -- 3 4 4
## 每一回合輸出一行:
##   ROUND <P1> <P2> <贏家:1、2 或 0 平手> <P1 剩餘血量比例> <P2 剩餘血量比例> <這回合用了幾秒>
## 電腦的打法不等於玩家的打法,結果只能看出「明顯太強或太弱」,不能當成精確的強度。

## 參與統計的角色:[名稱, 角色索引, 型態索引]
const ROSTER := [
	["gojo", 0, 0], ["gojo_young", 0, 1], ["sukuna", 1, 0], ["yuta", 2, 0],
	["yuji", 3, 0], ["megumi", 4, 0], ["toji", 5, 0], ["minato", 6, 0],
]


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var worker := int(args[0]) if args.size() > 0 else 0
	var workers := int(args[1]) if args.size() > 1 else 1
	var matches := int(args[2]) if args.size() > 2 else 2
	Sfx.muted = true  # 只改記憶體裡的設定,不寫進設定檔
	var pair_number := 0
	for a in ROSTER.size():
		for b in range(a + 1, ROSTER.size()):
			if pair_number % workers == worker:
				for index in matches:
					# 輪流交換左右兩邊,抵銷 P1 / P2 位置的影響
					if index % 2 == 0:
						await _play_match(ROSTER[a], ROSTER[b])
					else:
						await _play_match(ROSTER[b], ROSTER[a])
			pair_number += 1
	quit()


func _play_match(first: Array, second: Array) -> void:
	GameState.cpu_enabled = true
	GameState.selection = [first[1], second[1]]
	GameState.forms = [first[2], second[2]]
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var scene := current_scene
	var p1: Fighter = scene.get_node("Fighter1")
	var p2: Fighter = scene.get_node("Fighter2")
	var cpu := CpuController.new()
	cpu.fighter = p1
	scene.add_child(cpu)
	var was_active := false
	var started_at := 0.0
	var clock := 0.0
	while not scene._match_over:
		await physics_frame
		clock += 1.0 / 60.0
		var active: bool = scene._round_active
		if active and not was_active:
			started_at = clock
		elif was_active and not active:
			var left1 := float(p1.health) / p1.max_health
			var left2 := float(p2.health) / p2.max_health
			var winner := 0
			if left1 > left2:
				winner = 1
			elif left2 > left1:
				winner = 2
			print("ROUND %s %s %d %.3f %.3f %.1f" % [first[0], second[0], winner, left1, left2, clock - started_at])
		was_active = active
