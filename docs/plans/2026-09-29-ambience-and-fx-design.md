# 環境音效 + 粒子特效庫

## 特效庫（`fx.gd`，全部一行叫得出來）

- `Fx.hit(world, 位置, 法線, 材質)`：著彈碎屑。材質表 `Fx.SURFACES`：土、木屑、石屑、血
- `Fx.puff(...)` / `Fx.gun_smoke(...)`：一團煙。槍口黑火藥煙從 `shot_fx.gd` 搬進來
- `Fx.chimney(父節點, 位置)`：一直冒的煙
- `Fx.drift(父節點)`：落葉 + 飛蟲，`main._process` 每幀搬到鏡頭位置

材質判斷在 `Bullet.surface_of()`：會扣血 → 血；group `ground`（地形）→ 土；
group `stone`（石頭掩體）→ 石屑；其他都當木頭。原本的火花拿掉。

## 環境聲（`main.gd`，不另做系統）

- 全場背景：一個 `AudioStreamPlayer` 循環播 forest.ogg
- 定點：`_sound_at(音檔, 位置, 距離)`，目前每個果園掛一個鳥叫

## 規則

- 都不走網路同步，各台自己播
- 自我檢查：`_case_fx_and_ambience`（三種材質都打得出來、每種著彈有粒子、煙囪、鳥叫、背景聲都在）

## 刻意沒做

- 各類音量分開調：等有設定選單再做
- 背景聲隨區域變化：等有區域系統再做
