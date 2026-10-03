"""程式合成炸藥的聲音（cowboy/explosive.gd 用）：
   boom 爆炸（2 秒）：一記很短的高頻爆裂＋往下掉的低頻悶響＋拖長的隆隆尾音（遠處山谷的回音）
   fuse 引信燃燒（1 秒，循環播）：嘶嘶的高頻雜訊，偶爾劈啪一下
   launch 魚叉射出（0.4 秒）：悶的一聲「咚」加一點金屬擦過的嘶聲
做法跟 make_dino_sounds.py 一樣：濾過的雜訊加包絡。
   （要 numpy：用 Blender 附的 Python）
   /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 tools/make_explosive_sounds.py   → assets/audio/weapons/*.wav
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = 'assets/audio/weapons'
rng = np.random.default_rng(20261004)


def lowpass(x, f):
    a = math.exp(-2 * math.pi * f / SR)
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p
        y[i] = p
    return y


def highpass(x, f):
    return x - lowpass(x, f)


def write(name, y):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('->', os.path.join(OUT, name + '.wav'))


def boom():
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    crack = highpass(rng.standard_normal(n), 1500) * np.exp(-t / 0.02)            # 爆裂：20 毫秒
    body = lowpass(rng.standard_normal(n), 300) * np.exp(-t / 0.35) * 6.0         # 悶響
    thump = np.sin(2 * math.pi * np.cumsum(55 * np.exp(-t / 0.3) + 30) / SR) * np.exp(-t / 0.25)   # 往下掉的低音
    rumble = lowpass(rng.standard_normal(n), 120) * np.exp(-t / 0.9) * 5.0         # 隆隆的尾音
    y = crack * 0.6 + body + thump * 0.8 + rumble
    y *= np.minimum(1.0, t / 0.002)
    return y / (np.abs(y).max() + 1e-9) * 0.95


def fuse():
    n = int(1.0 * SR)
    hiss = highpass(rng.standard_normal(n), 3000) * 0.5
    pops = np.zeros(n)
    for at in rng.uniform(0, 1, 9):
        i = int(at * n)
        k = np.arange(min(400, n - i))
        pops[i:i + len(k)] += rng.standard_normal(len(k)) * np.exp(-k / 60)
    y = hiss + highpass(pops, 1200) * 0.8
    k = int(0.02 * SR)
    y[:k] *= np.linspace(0, 1, k)           # 頭尾淡入淡出，循環播接得起來
    y[-k:] *= np.linspace(1, 0, k)
    return y / (np.abs(y).max() + 1e-9) * 0.5


def launch():
    n = int(0.4 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * math.pi * np.cumsum(140 * np.exp(-t / 0.05) + 60) / SR) * np.exp(-t / 0.08)
    puff = lowpass(rng.standard_normal(n), 900) * np.exp(-t / 0.06) * 3.0
    scrape = highpass(rng.standard_normal(n), 4000) * np.exp(-t / 0.15) * 0.3
    y = thud + puff + scrape
    return y / (np.abs(y).max() + 1e-9) * 0.9


if __name__ == '__main__':
    write('boom', boom())
    write('fuse', fuse())
    write('launch', launch())
