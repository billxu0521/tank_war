# 第三方素材

## Low poly FPS Pistol Animated maj 07/06/2022

`assets/models/pistol/`

This work is based on ["Low poly FPS Pistol Animated maj 07/06/2022"](https://sketchfab.com/3d-models/low-poly-fps-pistol-animated-maj-07062022-baa81cafeeef4a099c698c4a6c380057)
by [ImageParSeconde](https://sketchfab.com/ImageParSeconde) licensed under
[CC-BY-4.0](http://creativecommons.org/licenses/by/4.0/).

CC-BY-4.0 允許商用，但**必須保留作者標示**。遊戲若要發布，這段文字要出現在
玩家看得到的地方（片尾、about 畫面或說明文件）。原始授權檔在
`assets/models/pistol/license.txt`。

## FPS Character Asset（Joblab Studio）

`assets/audio/`（腳步、跳躍、霰彈槍、彈孔音效）、`assets/textures/bullet_hole.png`、
`assets/textures/muzzle_flash.png`

來自使用者提供的 fps-character-asset 素材包（`resouce/fps-character-asset/`，
Media 內標示 Joblab Studio Games）。**包內沒有授權檔，正式發布前要確認出處與授權條款。**

## 武器模型（sawnoff / shotgun 等 *_animated.glb）

`assets/models/weapons/`

使用者提供的 Sketchfab 匯出檔（GLB 內含 Sketchfab_model 節點）。**沒有附授權資訊，
正式發布前要回 Sketchfab 找到原頁面確認授權與作者標示。**

## 手槍音效（freesound.org，CC0）

`assets/audio/weapons/pistol_shoot.mp3`、`assets/audio/weapons/pistol_reload.mp3`

- 射擊：["Small pistol gunshot indoors"](https://freesound.org/people/acidsnowflake/sounds/402789/)
  by acidsnowflake
- 換彈：["Gun Reload"](https://freesound.org/people/SecureSubset/sounds/787669/)
  by SecureSubset

兩者皆 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)（公眾領域，
可商用，不需標示），登記只是記錄出處。授權檔在
`assets/audio/weapons/pistol_sounds_license.txt`。

# 參考來源

## Godot 4 - Basic First Person Controller

CC0（公眾領域，不需標示），這裡登記只是記錄出處。手把輸入配置與用固定加速度
（`move_toward`）做移動，都是從它學來的。原始碼放在 `resouce/`（`.gdignore`
擋著不進匯入，也不進版控）。
