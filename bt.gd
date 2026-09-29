class_name BT
extends RefCounted
## 最小的行為樹：選擇（Sel）、依序（Seq）、條件（Cond）、動作（Act）四種節點。
## 每幀從根 tick 一次，由上往下找第一條走得通的分支——優先序就是樹的排列順序。
##
## ponytail: 沒有黑板（blackboard）、沒有裝飾節點、也不記 RUNNING 的節點：
## 每幀從頭評估，高優先的分支隨時可以插隊（例如追逐途中有人撿了蛋，下一幀就改追持蛋者）。
## 樹大到要記憶執行位置、或要重複／計時裝飾時再加。

enum { SUCCESS, FAILURE, RUNNING }


class Task:
	func tick(_dt: float) -> int:
		return FAILURE


## 選擇：由左到右，第一個不是 FAILURE 的就用它的結果
class Sel extends Task:
	var kids: Array
	func _init(k: Array) -> void:
		kids = k
	func tick(dt: float) -> int:
		for k: Task in kids:
			var r := k.tick(dt)
			if r != FAILURE:
				return r
		return FAILURE


## 依序：由左到右，全部 SUCCESS 才算 SUCCESS；遇到不是 SUCCESS 的就停在那
class Seq extends Task:
	var kids: Array
	func _init(k: Array) -> void:
		kids = k
	func tick(dt: float) -> int:
		for k: Task in kids:
			var r := k.tick(dt)
			if r != SUCCESS:
				return r
		return SUCCESS


## 條件：Callable() -> bool
class Cond extends Task:
	var f: Callable
	func _init(c: Callable) -> void:
		f = c
	func tick(_dt: float) -> int:
		return SUCCESS if f.call() else FAILURE


## 動作：Callable(dt) -> int（SUCCESS / FAILURE / RUNNING）
class Act extends Task:
	var f: Callable
	func _init(c: Callable) -> void:
		f = c
	func tick(dt: float) -> int:
		return f.call(dt)
