# 手的驗收：讀 tools/hand_overlay_metrics.py 的 report.json，照審查定的條件逐條印「過／沒過」。
#   python3 tools/hand_accept.py 25
# 條件（2026-10-04 第 24 版審查）：
#   1. 握槍三格（4、5、6）拇指往圈外凸（我們多出）< 10 px
#   2. 掌根偏薄：第 3、5 格「手掌」我們少了 < 12 px
#   3. 張開四指靠攏：第 1、2 格四指（食指～小指）的差異 < 10 px
#   4. 張開拇指下垂：第 3 格拇指差異 < 12 px
import json, os, sys

N = sys.argv[1]
R = json.load(open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                'docs/image/hands_iter/v%s_diff/report.json' % N)))['views']


def worst(views, pred):
    """這幾格裡，部位名字符合 pred 的形狀差異最厚幾 px（姿勢不同的不算）"""
    out = []
    for i in views:
        for b in R[i - 1]['blobs']:
            if not b['note'] and pred(b):
                out.append((b['thick'], i, b['bone'], b['side']))
    return max(out) if out else (0, '-', '-', '-')


TESTS = [
    # 握槍拇指只看往外凸的（我們多出）：「少了」都在握圈內側——參考手裡是空的、拇指收在圈裡，我們圈裡是握把
    ('1 握槍拇指往外凸', (4, 5, 6), lambda b: b['bone'].startswith('拇指') and b['side'] == '我們多出', 10),
    ('2 掌根偏薄', (3, 5), lambda b: b['bone'] == '手掌' and b['side'] == '我們少了', 12),
    ('3 張開四指', (1, 2), lambda b: b['bone'][:2] in ('食指', '中指', '無名', '小指'), 10),
    ('4 張開拇指', (3,), lambda b: b['bone'].startswith('拇指'), 12),
]
ok_all = True
for name, views, pred, lim in TESTS:
    t, i, bone, side = worst(views, pred)
    ok = t < lim
    ok_all &= ok
    print('%s：最厚 %d px（第 %s 格 %s %s），目標 < %d → %s' % (name, t, i, bone, side, lim, '過' if ok else '沒過'))
print('重疊：' + '、'.join('%d格 %.0f%%' % (k + 1, v['iou'] * 100) for k, v in enumerate(R)))
print('全部過' if ok_all else '還有沒過的')
