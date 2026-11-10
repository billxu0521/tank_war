class_name HitRules
extends Object
## 物理規則（docs/規劃/2026-11-10-物理規則.md）：每塊積木有材質、每次攻擊有力道，查表得結果。數字在 balance.csv 的 mat_* 列。
## ponytail: 第一版只有「壞」和「穿」；燒、推（火、風）第二、三版再加

const MATS: Array[StringName] = [&"wood", &"tree", &"brick", &"iron", &"stone"]
const BLOCK := -1

## 耐久（= 積木等級：1、2 挨幾下倒，3 打不壞）
static func level(mat: StringName) -> int:
	return Balance.whole("mat_%s_hp" % mat)

static func burns(mat: StringName) -> bool:
	return Balance.num("mat_%s_burn" % mat) > 0.0

## 厚度：子彈力道 ≥ 厚度才穿
static func thick(mat: StringName) -> int:
	return Balance.whole("mat_%s_thick" % mat)

static func pushable(mat: StringName) -> bool:
	return Balance.num("mat_%s_push" % mat) > 0.0

## 沒指定材質的塊照等級給（1 木頭、2 磚、3 石頭）
static func default_mat(lv: int) -> StringName:
	return [&"wood", &"brick", &"stone"][clampi(lv, 1, 3) - 1]

## 力道 force 打得壞這種材質嗎（耐久 3 永遠不壞）
static func breaks(force: int, mat: StringName) -> bool:
	var hp := level(mat)
	return hp < 3 and force >= hp

## 子彈穿過去以後剩的力道；BLOCK（-1）= 擋住
static func pierce(force: int, mat: StringName) -> int:
	if mat == &"":
		return BLOCK
	var t := thick(mat)
	return force - t if force >= t else BLOCK
