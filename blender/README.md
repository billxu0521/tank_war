# 模型是程式建的

跟 trex.gd 一樣的路線：模型不用手捏，用 Blender Python 建，改數字就重跑。

- `common.py` — box / cyl / blob 這些小工具，最後 `finish()` 合併並加倒角
- `weapons.py` — 牛仔的三把槍（左輪、單管散彈、槓桿步槍），各自匯出一個 `.glb`
- `tree.py` — 闊葉樹大中小三棵（`TreeOak` / `TreeOakM` / `TreeOakS`），進 `trees.glb`。**不用開 Blender**，背景直接跑，
  一輪迭代用 `tools/model_iter.sh tree <版號>`（做法和教訓見 [docs/程式建模迭代.md](../docs/程式建模迭代.md)）
- `house.py` — 農舍三種（`House1` 前廊農舍、`House2` 圓木小屋、`House3` 直板高屋），各帶碰撞 `House<N>Col`，門 `HouseDoor` 共用，進 `houses.glb`。
  跟 tree.py 一樣背景跑：`tools/model_iter.sh house <版號>`
- `kit.py` — 場景小物件（`docs/image/house.png` 裡房子以外的）：吊燈、木桶、木箱、方草捆、車輪、柵欄、圍欄門、繫柱架、風車、倉庫，進 `kits.glb`。
  借用 house.py 的材質和工具（讀到 house.py 裡「以上是材質和工具」那行為止）。`REF=docs/image/house.png tools/model_iter.sh kit <版號>`
- `props.py` — 場景物件：穀倉（牆身＋屋頂分開，照實際大小縮放）、筒倉、柵欄、乾草捲、松樹、
  麥子、草叢、恐龍蛋、篷車（撤離點），全部進 `props.glb`
- `cowboy.py` — 牛仔：身體（原點在腳底）、頭（原點在眼睛 1.6 公尺，跟著上下看轉）、兩條腿（原點在髖關節，走路擺動）、
  自己看的靴子、第一人稱握槍的手（HandGrip / HandSupport，位置寫在各槍場景的 grip_hand / support_hand；
  右手的拇指 HandGripThumb、前臂 HandGripArm 分開，左輪扳擊錘和轉手臂用；HandLoad 是左輪換彈捏子彈的左手）
- `trex.py` — 18 個部件，**名字和位置直接抄 trex.gd 的 `_rig()`**，所以程式動畫不用改

## 怎麼重建

不用開 Blender 也可以，背景跑（`tree.py` 就是這樣做的）：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python-expr "BASE='$PWD/blender'; exec(open(BASE+'/props.py').read()); export('$PWD/models')"
```

或者 Blender 開著、BlenderMCP 連上之後，在 Blender 裡執行：

```python
BASE = '<這個資料夾的絕對路徑>'
exec(open(BASE + '/trex.py').read())    # 或 cowboy.py / weapons.py
export('<專案>/models/trex.glb')           # 每支腳本最後都有自己的 export()
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

## 看模型

`common.py` 的 `view(eye, target)`：視窗從 eye 看向 target（Blender 座標），SOLID 著色看材質顏色。
截圖檢查用，比手調視角可靠。

## 硬表面和生物

`finish()` 預設每個面平面著色（槍、金屬邊要利）。生物傳 `smooth=True`（暴龍），
槍的木頭部分用 `smooth_mats=('wood', 'wood2')` 只讓木頭圓滑。
圓弧的木頭件（槍托、護木）和外套用 `loft()` / `vloft()`：在幾個位置訂斷面接成一條，
比方塊疊起來像樣得多。

## 場景物件（props.py）

遊戲裡**碰撞還是 main.gd 自己拼的方塊和圓柱**（看不見），模型只負責外觀。
所以改模型不會動到翻越高度、掩蔽、恐龍爬牆。要對齊的數字：
- 穀倉基準 14 × 20 × 8、屋頂斜度 0.55 ＝ main.gd 的 `BARN_BASE`、`BARN_PITCH`
- 屋頂斜板的擺法（`gable_roof()`）照抄 main.gd 的 `_roof()`，碰撞就是那樣算的
- 農舍在 house.py：主屋牆 10 × 8、地板高 0.45（`HOUSE_FLOOR`）、煙囪頂（`HOUSE_KINDS`）跟 main.gd 共用
- 筒倉基準高 15、樹幹基準高 5；柵欄一段 2.5 公尺（在 kit.py） ＝ `SILO_BASE_H`、`FENCE_SEG`、`TREE_BASE_TRUNK`
- 麥子、草叢沒有碰撞，遊戲裡用 MultiMesh 撒幾千叢，模型要保持在幾十個三角形以內

## 空心建築（穀倉、農舍）

蓋牆用 `wall()`（自動在門窗開口處切開）、要擋人的家具用 `solid()`：兩個都會順便記一份碰撞方塊，
最後 `make_col()` 合成 `BarnCol` / `House<N>Col`（這幾個函式在 common.py，house.py 也用），遊戲拿來當碰撞形狀（看不見）。
畫面和碰撞只在這裡定義一次。門是另外的物件（`BarnDoorSlide`、`BarnBackDoor`、`HouseDoor`），
原點在門軸或底部中央，遊戲裡會動。門和梯子的位置常數（`BARN_DOOR_*`、`BARN_BACK_X`、
`BARN_LOFT`、`BARN_LADDER_X`）跟 main.gd 共用。
