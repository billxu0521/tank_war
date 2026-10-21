#!/usr/bin/env python3
# 假網路轉送程式：聽 127.0.0.1:24681，把 UDP 轉給 127.0.0.1:24680（專用伺服器），兩個方向都加延遲、抖動、掉包。
# 用法：LAG_MS=150 JITTER_MS=40 LOSS=0.05 python3 tools/lag_proxy.py（tools/net_check.sh 加 LAG=1 會自動開）
# 客戶端連 127.0.0.1:24681 就會走這裡；結束時（SIGTERM）印一行統計。只用標準函式庫。
import heapq, os, random, select, signal, socket, time

LISTEN = ("127.0.0.1", 24681)
SERVER = ("127.0.0.1", 24680)
LAG_MS = float(os.environ.get("LAG_MS", 150))
JITTER_MS = float(os.environ.get("JITTER_MS", 40))
LOSS = float(os.environ.get("LOSS", 0.05))

running = True
def _stop(*_):
    global running
    running = False
signal.signal(signal.SIGTERM, _stop)
signal.signal(signal.SIGINT, _stop)

front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
front.bind(LISTEN)
clients = {}        # 客戶端位址 -> 轉給伺服器的 socket
back_owner = {}     # 轉給伺服器的 socket -> 客戶端位址（回程用）
queue = []          # (到期時間, 序號, 目的 socket, 目的位址, 資料)
seq = 0
stats = {"fwd": 0, "drop": 0}

def now():
    return time.monotonic()

def schedule(sock, dest, data):
    global seq
    if random.random() < LOSS:
        stats["drop"] += 1
        return
    delay = max(0.0, LAG_MS + random.uniform(-JITTER_MS, JITTER_MS)) / 1000.0
    seq += 1
    heapq.heappush(queue, (now() + delay, seq, sock, dest, data))

while running:
    timeout = 0.1
    if queue:
        timeout = max(0.0, min(timeout, queue[0][0] - now()))
    readable, _, _ = select.select([front] + list(back_owner), [], [], timeout)
    for s in readable:
        data, addr = s.recvfrom(65535)
        if s is front:
            if addr not in clients:
                back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                clients[addr] = back
                back_owner[back] = addr
            schedule(clients[addr], SERVER, data)   # 客戶端 -> 伺服器
        else:
            schedule(front, back_owner[s], data)    # 伺服器 -> 客戶端（原路回去）
    t = now()
    while queue and queue[0][0] <= t:
        _, _, sock, dest, data = heapq.heappop(queue)
        sock.sendto(data, dest)
        stats["fwd"] += 1

print("轉送程式結束：轉了 %d 包，掉了 %d 包（LAG_MS=%g JITTER_MS=%g LOSS=%g）"
      % (stats["fwd"], stats["drop"], LAG_MS, JITTER_MS, LOSS), flush=True)
