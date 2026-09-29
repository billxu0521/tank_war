# 第三方素材

槍聲、換彈、空膛、著彈這幾個音效已經剪掉開頭的空白並轉成 WAV（原本 `pistol_shoot.mp3`
開頭空了 1.25 秒，開槍要等一秒多才響）。做法：
`ffmpeg -i x.mp3 -af "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.003" -c:a pcm_s16le x.wav`

槍的模型是自己用 Blender 程式建的（`blender/weapons.py`），不需要標示。


## FPS Character Asset（Joblab Studio）

`assets/audio/`（腳步、跳躍、霰彈槍、彈孔音效）、`assets/textures/bullet_hole.png`、
`assets/textures/muzzle_flash.png`

來自使用者提供的 fps-character-asset 素材包（`resouce/fps-character-asset/`，
Media 內標示 Joblab Studio Games）。**包內沒有授權檔，正式發布前要確認出處與授權條款。**


## 手槍音效（freesound.org，CC0）

`assets/audio/weapons/pistol_shoot.wav`、`assets/audio/weapons/pistol_reload.wav`

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


## 環境音效（opengameart.org，CC0）

`assets/audio/ambient/forest.ogg`（全場背景聲）、`assets/audio/ambient/birds.ogg`（果園鳥叫）

- 背景：["Forest Ambience"](https://opengameart.org/content/forest-ambience) by TinyWorlds，
  原檔太小聲，加了 20dB 轉成 ogg
- 鳥叫：["Ambient Bird Sounds"](https://opengameart.org/content/ambient-bird-sounds) by isaiah658，
  轉成單聲道（3D 定點聲要單聲道）

兩者皆 CC0（公眾領域，可商用，不需標示），登記只是記錄出處。
