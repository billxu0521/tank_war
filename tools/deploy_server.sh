#!/bin/sh
# 把專用伺服器（測試站）裝到雲端主機上，或更新成目前的版本。
# 用法：tools/deploy_server.sh 使用者@主機位址
#
# 會做的事：匯出 Linux 版 → 複製到主機的 ~/tankwar/ → 裝成開機自動啟動、掛掉自動重開的服務（systemd）。
# 主機要先開好防火牆的 UDP 24680（main.gd 的 PORT）。看伺服器的輸出：ssh 上去打 journalctl -u tankwar -f
set -e
cd "$(dirname "$0")/.."
HOST=${1:?用法：tools/deploy_server.sh 使用者@主機位址}

echo "== 匯出 Linux 版 =="
mkdir -p build/linux
godot --headless --export-release "Linux" build/linux/TankWar.x86_64 >/dev/null

echo "== 複製到 $HOST =="
ssh "$HOST" 'mkdir -p ~/tankwar'
scp build/linux/TankWar.x86_64 "$HOST":tankwar/TankWar.x86_64.new
ssh "$HOST" 'mv ~/tankwar/TankWar.x86_64.new ~/tankwar/TankWar.x86_64 && chmod +x ~/tankwar/TankWar.x86_64'

echo "== 裝成服務（掛掉自動重開、開機自動啟動） =="
USER_NAME=$(ssh "$HOST" whoami)
HOME_DIR=$(ssh "$HOST" 'echo $HOME')
ssh "$HOST" "sudo tee /etc/systemd/system/tankwar.service >/dev/null" <<EOF
[Unit]
Description=西部牛仔打恐龍 測試站
After=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$HOME_DIR/tankwar
ExecStart=$HOME_DIR/tankwar/TankWar.x86_64 --headless -- --server
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
ssh "$HOST" 'sudo systemctl daemon-reload && sudo systemctl enable tankwar >/dev/null 2>&1 && sudo systemctl restart tankwar'
sleep 3
ssh "$HOST" 'sudo journalctl -u tankwar -n 5 --no-pager'
echo "== 好了。大廳的「連到測試站」要連的位址寫在 main.gd 的 TEST_SERVER =="
