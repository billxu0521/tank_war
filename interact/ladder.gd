class_name Ladder
extends StaticBody3D
## 梯子：看著它按 F 抓住，W/S 上下爬，爬到頂自動站上去，Space 或 F 放手。
## 爬的邏輯在 cowboy.gd（start_climb / climb_step），這裡只記梯子的幾個點。

var prompt := "爬梯子"
## 站在梯子前面的腳底位置（最低點）
var foot := Vector3.ZERO
## 腳爬到這個高度就算到頂，直接站到 exit
var top_y := 0.0
## 到頂之後站的地方（閣樓上、筒倉頂）
var exit := Vector3.ZERO
## 爬的時候面向哪（rotation.y）
var yaw := 0.0


func interact(who: Node) -> void:
	who.start_climb(self)
