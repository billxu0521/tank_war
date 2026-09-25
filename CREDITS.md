# 第三方素材

槍的模型是自己用 Blender 程式建的（`blender/weapons.py`），不需要標示。


## FPS Character Asset（Joblab Studio）

`assets/audio/`（腳步、跳躍、霰彈槍、彈孔音效）、`assets/textures/bullet_hole.png`、
`assets/textures/muzzle_flash.png`

來自使用者提供的 fps-character-asset 素材包（`resouce/fps-character-asset/`，
Media 內標示 Joblab Studio Games）。**包內沒有授權檔，正式發布前要確認出處與授權條款。**


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
