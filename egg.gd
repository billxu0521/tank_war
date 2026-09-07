class_name Egg
extends Node3D
## 蛋。位置和持有者都由主機決定再同步出去，客戶端只負責畫。

## 0 = 沒人拿，其他 = 拿著它的坦克編號
@export var carrier := 0
