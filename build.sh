#!/bin/sh
# 打包 PC 版。需要先在 Godot 裡裝好對應版本的 export templates。
set -e
cd "$(dirname "$0")"

echo "== 先跑自我檢查 =="
godot --headless --script test_battle.gd

for target in "Windows Desktop:build/windows/TankWar.exe" "macOS:build/macos/TankWar.zip"; do
	preset="${target%%:*}"
	out="${target#*:}"
	echo "== 匯出 $preset =="
	mkdir -p "$(dirname "$out")"
	godot --headless --export-release "$preset" "$out" >/dev/null
	cp 說明.txt "$(dirname "$out")/"
	ls -lh "$out"
done
