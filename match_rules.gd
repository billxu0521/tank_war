class_name MatchRules
extends RefCounted
## 模式規則表（main.gd 的 RULES 搬過來）：模式之間的差別都寫在這張表裡，main 查表，不再散在 if rules == &"..."。
## 只放資料，不跑流程。加新模式就加一筆、把每個欄位填完。
##
## 欄位：
## lives：每個牛仔能重生幾次（-1 不限）；用完就出局、不再回場。dino：有沒有恐龍 boss。
## egg：有沒有蛋和撤離。timer：有沒有四分鐘時限。
## pilot：大廳勾「我想當恐龍」的人能不能操作尼諾拉（對抗模式）。
## party：派對模式（規則本體在 party.gd，main 會建 $Party）。
## end：靠命數判勝負的規則（main._check_lives_end）：&"last_standing" 死鬥、&"all_out_dino_wins" 恐龍決鬥、&""＝沒有。
## boss_hp：恐龍 boss 的血量；0 代表不改（用 boss.tscn 的預設）。
## boss_kill_wins：打倒恐龍就所有牛仔獲勝（恐龍決鬥）。
## timeout_msg：時間到還沒人帶蛋撤離時，每台顯示的字。
##
## 牛仔之間本來就打得到（PvP），恐龍決鬥的「隊友火力」不用另外開

const EGG_TIMEOUT := "時間到，沒有人把蛋帶走"

const RULES := {
	&"egg": {name = "搶蛋", lives = -1, dino = true, egg = true, timer = true,
		pilot = false, party = false, end = &"", boss_hp = 0, boss_kill_wins = false, timeout_msg = EGG_TIMEOUT,
		desc = "先把蛋帶進撤離區的人贏，一局四分鐘。場上有一隻恐龍，死了五秒後重生（不限次數）。"},
	&"deathmatch": {name = "死鬥", lives = 3, dino = false, egg = false, timer = false,
		pilot = false, party = false, end = &"last_standing", boss_hp = 0, boss_kill_wins = false, timeout_msg = EGG_TIMEOUT,
		desc = "沒有恐龍、沒有蛋。每個人可以重生 3 次，用完就出局，最後剩下的一個人獲勝。"},
	&"versus": {name = "對抗", lives = -1, dino = true, egg = true, timer = true,
		pilot = true, party = false, end = &"", boss_hp = 0, boss_kill_wins = false, timeout_msg = "時間到，尼諾拉守住了蛋，尼諾拉獲勝！",
		desc = "搶蛋，但尼諾拉由玩家操作（勾「我想當恐龍」的人每局抽一個，沒人勾就是電腦）。帶蛋撤離的牛仔贏，時間到沒人撤離就是尼諾拉贏。"},
	&"dino_duel": {name = "恐龍決鬥", lives = 5, dino = true, egg = false, timer = false,
		pilot = false, party = false, end = &"all_out_dino_wins", boss_hp = 3000, boss_kill_wins = true, timeout_msg = EGG_TIMEOUT,
		desc = "所有牛仔合力打一隻恐龍，打死牠大家一起贏。每人可以重生 5 次，全部出局就是恐龍贏。小心，打到隊友一樣會扣血。"},
	# 規則本體在 party.gd（命數、計時、計分自己管，不走上面的 lives／timer；lives 填 -1 讓舊的命數系統不插手）
	&"party": {name = "派對", lives = -1, dino = true, egg = true, timer = true,
		pilot = false, party = true, end = &"", boss_hp = 0, boss_kill_wins = false, timeout_msg = EGG_TIMEOUT,
		desc = "四個人輪流當恐龍，四回合加總比分數（不到四人用電腦補）。恐龍先花 15 秒藏蛋，牛仔每回合 3 條命，帶蛋撤離就贏這回合。"},
}
