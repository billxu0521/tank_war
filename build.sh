#!/bin/sh
# 打包 PC 版。需要先在 Godot 裡裝好對應版本的 export templates。
set -e
cd "$(dirname "$0")"

echo "== 先跑自我檢查 =="
# Godot 遇到 Parse Error、測試 FAIL 也可能回 0，所以不看退出碼，只看輸出：要有 OK：那行，且沒有錯誤字樣。
# 測試最後一行常是引擎結束時的 resources still in use，不能只看最後一行
LOG=$(mktemp)
godot --headless --script test_battle.gd 2>&1 | tee "$LOG"
if ! grep -q '^OK：' "$LOG" || grep -qE 'SCRIPT ERROR|Parse Error|FAIL' "$LOG"; then
	rm -f "$LOG"
	echo "自我檢查沒過，停止打包"
	exit 1
fi
rm -f "$LOG"

for target in "Windows Desktop:build/windows/OvD.exe" "macOS:build/macos/OvD.zip"; do
	preset="${target%%:*}"
	out="${target#*:}"
	echo "== 匯出 $preset =="
	mkdir -p "$(dirname "$out")"
	godot --headless --export-release "$preset" "$out" >/dev/null
	cp docs/發布/說明.txt "$(dirname "$out")/"
	ls -lh "$out"
done
