#!/bin/sh
# 測試站要用再開、用完就刪（Vultr 按小時計費；只關機還是會收錢，一定要刪）。
#   tools/test_server.sh up       建一台東京的主機、裝好遊戲伺服器，印出位址（約 3 分鐘）
#   tools/test_server.sh down     刪掉，停止計費
#   tools/test_server.sh status   現在有沒有開著、位址是什麼
# 需要：專案的 .env 有 VULTR_API_KEY（.env 不會上傳）；本機的 ~/.ssh/id_ed25519
set -e
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
: "${VULTR_API_KEY:?.env 裡要有 VULTR_API_KEY}"

LABEL=tankwar-test    # 沿用舊名：改了的話，已經開著的測試站 down 會找不到、一直計費
REGION=nrt            # 東京
PLAN=vhf-1c-1gb       # 1 顆高頻處理器、1GB，每月 6 美元（按小時算）
OS_ID=2284            # Ubuntu 24.04
KEY_NAME=tankwar      # Vultr 上已經登記的金鑰名字，沿用舊名
PORT=24680

api() {   # api 方法 路徑 [JSON]。失敗就把 Vultr 回的錯誤印出來再停
	# -4：Vultr 的 API 只放行白名單上的 IP，家裡網路走 IPv6 的話位址不在名單上，會被擋（401）
	OUT=$(curl -4 -s -w '\n%{http_code}' -X "$1" -H "Authorization: Bearer ${VULTR_API_KEY}" \
		-H "Content-Type: application/json" "https://api.vultr.com/v2/$2" ${3:+-d "$3"})
	CODE=$(echo "${OUT}" | tail -1)
	BODY=$(echo "${OUT}" | sed '$d')
	if [ "${CODE}" -ge 400 ]; then
		echo "Vultr 回錯誤（${CODE}）：${BODY}" >&2
		exit 1
	fi
	echo "${BODY}"
}

## 先存下回應再交給 jq：直接接管線的話 api 失敗會被 jq 的成功蓋掉，
## Vultr 出錯時會誤報「沒有開著的測試站」（2026-09-29 真的發生過，主機其實還開著在計費）
instance_id() {
	BODY=$(api GET "instances?label=${LABEL}") || exit 1
	echo "${BODY}" | jq -r '.instances[0].id // empty'
}

case "$1" in
up)
	if [ -n "$(instance_id)" ]; then
		echo "已經開著了："
		exec "$0" status
	fi
	# 本機的公鑰登記到 Vultr（只登記一次），新主機才讓我們用金鑰登入
	KEY_ID=$(api GET ssh-keys | jq -r --arg n "${KEY_NAME}" '.ssh_keys[] | select(.name==$n) | .id' | head -1)
	if [ -z "${KEY_ID}" ]; then
		KEY_ID=$(api POST ssh-keys "$(jq -n --arg n "${KEY_NAME}" --arg k "$(cat ~/.ssh/id_ed25519.pub)" '{name:$n, ssh_key:$k}')" | jq -r '.ssh_key.id')
	fi
	echo "== 建主機（東京、${PLAN}） =="
	ID=$(api POST instances "$(jq -n --arg r "${REGION}" --arg p "${PLAN}" --arg l "${LABEL}" --arg k "${KEY_ID}" --argjson o "${OS_ID}" \
		'{region:$r, plan:$p, label:$l, os_id:$o, sshkey_id:[$k], backups:"disabled"}')" | jq -r '.instance.id')
	[ -n "${ID}" ] && [ "${ID}" != "null" ] || { echo "建主機失敗（原因見上面 Vultr 的錯誤）"; exit 1; }
	echo "編號 ${ID}，等它開機…"
	while :; do
		INFO=$(api GET "instances/${ID}") || exit 1
		IP=$(echo "${INFO}" | jq -r '.instance.main_ip')
		STATE=$(echo "${INFO}" | jq -r '.instance.status + "/" + .instance.power_status + "/" + .instance.server_status')
		[ "${STATE}" = "active/running/ok" ] && [ "${IP}" != "0.0.0.0" ] && break
		sleep 10
	done
	echo "開機了：${IP}，等 SSH 可以連…"
	until ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@${IP}" true 2>/dev/null; do
		sleep 5
	done
	# Ubuntu 預設的防火牆只開 SSH，要把遊戲的連接埠打開
	ssh -o BatchMode=yes "root@${IP}" "ufw allow ${PORT}/udp >/dev/null 2>&1 || true"
	tools/deploy_server.sh "root@${IP}"
	echo
	echo "== 測試站開好了：${IP} =="
	echo "大廳 IP 欄填 ${IP}，按「加入（連線模式）」。用完記得 tools/test_server.sh down"
	;;
down)
	ID=$(instance_id)
	if [ -z "${ID}" ]; then
		echo "沒有開著的測試站"
		exit 0
	fi
	api DELETE "instances/${ID}"
	echo "刪掉了（${ID}），停止計費"
	;;
status)
	ID=$(instance_id)
	if [ -z "${ID}" ]; then
		echo "沒有開著的測試站"
		exit 0
	fi
	api GET "instances/${ID}" | jq -r '.instance | "開著：\(.main_ip)（\(.region)、\(.plan)，\(.date_created) 建的）"'
	;;
*)
	sed -n '2,6p' "$0"
	exit 1
	;;
esac
