# 模型是程式建的

跟 trex.gd 一樣的路線：模型不用手捏，用 Blender Python 建，改數字就重跑。

- `common.py` — box / cyl / blob 這些小工具，最後 `finish()` 合併並加倒角
- `weapons.py` — 牛仔的三把槍（左輪、單管散彈、槓桿步槍），各自匯出一個 `.glb`
- `tank.py` — 車體、砲塔、砲管三個物件（坦克版留下的，模型檢視器還在用）
- `trex.py` — 18 個部件，**名字和位置直接抄 trex.gd 的 `_rig()`**，所以程式動畫不用改

## 怎麼重建

Blender 開著、BlenderMCP 連上之後，在 Blender 裡執行：

```python
BASE = '<這個資料夾的絕對路徑>'
exec(open(BASE + '/tank.py').read())    # 或 trex.py
```

匯出前務必做這三件事，不然位置會跑掉：
1. `transform_apply(rotation=True, scale=True)` — 旋轉要烘進網格
2. 原點搬到該去的地方（戰車是世界原點，恐龍是各自的骨頭位置）
3. `location = (0,0,0)`

然後 `export_scene.gltf(..., export_yup=True)` 存到 `models/`，再跑 `godot --headless --import`。

## 改了模型要注意

`trex.py` 的 `RIG` 是從 `trex.gd` 抄來的。**那邊改了骨頭位置，這邊也要跟著改**，
不然部件會對不上骨頭。

## 槍（weapons.py）

會動的零件（轉輪、擊錘、拉桿、折開的槍管）各自一個物件，**原點就在轉軸上**，
匯出後節點位置＝轉軸。遊戲裡 `cowboy/weapon.gd` 直接轉那個節點做動作。

```python
BASE = '<這個資料夾的絕對路徑>'
exec(open(BASE + '/weapons.py').read())
show_layout('Rifle'); side_view((0, 0.17, -0.5), 1.0)   # 只看一把、正側面
export('<專案>/models')                                   # 三個 .glb
```

之後跑 `godot --headless --import`。

**跟遊戲共用的數字**：
- `SIGHT`（準星高度）＝武器場景 `ads_position` 的 `-y`。改了要去 `cowboy/weapons/*.tscn` 改
- 擊錘、開膛扳的頂端要**低於** `SIGHT`，不然舉槍時擋在瞄準線上
- 零件物件名字＝武器場景裡 `cylinder_path` / `hammer_path` / `lever_path` / `barrel_path` 的最後一段
