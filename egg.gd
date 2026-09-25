class_name Egg
extends Node3D
## 蛋。位置和持有者都由主機決定再同步出去，客戶端只負責畫。

## 0 = 沒人拿，其他 = 拿著它的牛仔編號
@export var carrier := 0
## 撿取進度（秒）。換人或走開就歸零。
@export var pickup := 0.0
## 撤離進度（秒）。離開圈子或陣亡就歸零；敵人站在圈內不會中斷。
@export var extract := 0.0
