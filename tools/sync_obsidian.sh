#!/bin/sh
# 把 GitHub 上 main 的 docs/ 鏡像到 Obsidian（~/ObsidianVault/OvD 法外狂徒大戰恐龍/文件/）。
# 單向：repo 為主，Obsidian 只讀，在那邊改會被下次同步蓋掉。只搬 .md 和文件裡有用到的圖，影片和其他圖不搬（1 GB 多）。
# 用 origin/main 不用工作目錄：在功能分支上改到一半的文件不會跑進去，切分支也不會讓鏡像跳來跳去。
# git hook 在每次提交、拉取、切分支後自動在背景跑（安裝：tools/sync_obsidian.sh --install）。
set -e
cd "$(dirname "$0")/.."
if [ "$1" = "--install" ]; then
	for h in post-commit post-merge post-checkout; do
		printf '#!/bin/sh\n(tools/sync_obsidian.sh >/dev/null 2>&1 &)\n' > .git/hooks/$h
		chmod +x .git/hooks/$h
	done
	echo "已安裝 git hook"
	exit 0
fi
VAULT="$HOME/ObsidianVault/OvD 法外狂徒大戰恐龍"
[ -d "$VAULT" ] || { echo "找不到 $VAULT，跳過"; exit 0; }
git fetch -q origin main 2>/dev/null || true   # 沒網路就用上次抓到的
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git archive origin/main docs | tar -x -C "$TMP"
python3 - "$TMP/docs" <<'PY'
# 留下 .md 和 .md 裡用到的圖（![](相對路徑) 或 ![[檔名]]），其他刪掉
import os, re, sys, urllib.parse
root = sys.argv[1]
keep = set()
for d, _, fs in os.walk(root):
    for f in fs:
        if f.endswith(".md"):
            p = os.path.join(d, f)
            keep.add(p)
            t = open(p, encoding="utf-8", errors="ignore").read()
            for m in re.findall(r"!\[[^\]]*\]\(<?([^)>]+?)>?(?:\s+\"[^\"]*\")?\)", t):
                keep.add(os.path.normpath(os.path.join(d, urllib.parse.unquote(m))))
for d, _, fs in os.walk(root, topdown=False):
    for f in fs:
        p = os.path.join(d, f)
        if p not in keep:
            os.remove(p)
    if not os.listdir(d):
        os.rmdir(d)
PY
rsync -a --delete "$TMP/docs/" "$VAULT/文件/"
# 專案目錄（MOC）：每次重產。Obsidian 健康檢查只認 [[ ]] 連結，每篇都要列到才不會被當孤兒
python3 - "$VAULT" <<'PY'
import os, sys, datetime
vault = sys.argv[1]
top = os.path.basename(vault)
docs = os.path.join(vault, "文件")
groups = {}
for d, ds, fs in os.walk(docs):
    ds.sort()
    for f in sorted(fs):
        if f.endswith(".md"):
            rel = os.path.relpath(os.path.join(d, f), docs)
            groups.setdefault(os.path.dirname(rel) or "（根目錄）", []).append(rel[:-3])
out = ["---", f"title: {top}", "tags: [OvD, 遊戲, godot]", f"date: {datetime.date.today()}", "---", "",
       f"# {top}", "",
       "Outlaws vs Dinosaurs，Godot 4 第一人稱射擊：牛仔打恐龍（內部名 tankwar）。程式在 `~/project/tank-war`。", "",
       "> [!info] 自動產生，別手改",
       "> `文件/` 是 repo `docs/` 的唯讀鏡像（GitHub main），由 repo 的 `tools/sync_obsidian.sh` 在提交、拉取、切分支後更新；這頁也是它產生的。",
       "> 要改文件請在 repo 改。repo 裡的連結是一般 Markdown 連結，在 Obsidian 也點得開。", "",
       f"入口：[[{top}/文件/README|文件索引]]", ""]
for g in sorted(groups, key=lambda g: (g.startswith("image"), g)):   # 截圖說明放最後
    out.append(f"## {g}")
    out += [f"- [[{top}/文件/{r}|{os.path.basename(r)}]]" for r in groups[g]]
    out.append("")
open(os.path.join(vault, top + ".md"), "w", encoding="utf-8").write("\n".join(out))
PY
echo "已同步 $(find "$VAULT/文件" -name '*.md' | wc -l | tr -d ' ') 篇到 $VAULT/文件"
