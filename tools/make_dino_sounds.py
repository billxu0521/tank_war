"""程式合成恐龍的叫聲（boss.gd 的預備動作用）：
   growl 咬之前的低吼（0.7 秒）、roar 蓄力的長吼（1.6 秒）、snarl 撲擊前的短咆哮（0.5 秒）、yelp 被打斷的哀叫（0.6 秒）。
做法：低頻鋸齒波（聲帶）＋濾過的雜訊（氣息），音高照包絡滑動，再加 20~30Hz 的粗糙顫動（大隻動物的喉音），
最後過幾個共振峰（嘴巴和胸腔）。體型大就把音高壓低（知識庫「生物音效設計」：體型決定音高和音量）。
   （要 numpy：用 Blender 附的 Python）
   /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 tools/make_dino_sounds.py   → assets/audio/dino/*.wav
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = 'assets/audio/dino'
rng = np.random.default_rng(20261001)


def bandpass(x, f, q):
    """二階帶通濾波（RBJ 公式）"""
    w = 2 * math.pi * f / SR
    a = math.sin(w) / (2 * q)
    b0, b2 = a, -a
    a0, a1, a2 = 1 + a, -2 * math.cos(w), 1 - a
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = (b0 * v + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def lowpass(x, f):
    a = math.exp(-2 * math.pi * f / SR)
    y = np.zeros_like(x)
    p = 0.0
    for i, v in enumerate(x):
        p = (1 - a) * v + a * p
        y[i] = p
    return y


def creature(dur, pitch, env, rough=24.0, breath=0.5, formants=((220, 3.0), (520, 4.0), (1100, 5.0))):
    """dur 秒；pitch(t)、env(t) 是 0~1 時間的函式"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    u = t / dur
    f = np.array([pitch(x) for x in u])
    phase = np.cumsum(f) / SR
    saw = 2 * (phase % 1.0) - 1                       # 聲帶
    wobble = 1 + 0.35 * np.sin(2 * math.pi * rough * t + rng.uniform(0, 6)) * (0.6 + 0.4 * rng.standard_normal(n).clip(-1, 1))
    noise = lowpass(rng.standard_normal(n), 1800)      # 氣息
    src = saw * wobble + noise * breath
    voice = sum(bandpass(src, fc, q) for fc, q in formants) + lowpass(src, 160) * 0.8   # 嘴巴和胸腔的共振
    e = np.array([env(x) for x in u])
    y = voice * e
    return y / (np.abs(y).max() + 1e-9) * 0.9


def write(name, y):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(y, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print('->', os.path.join(OUT, name + '.wav'))


def ad(attack, release):
    """起音 attack、最後 release 收掉（都是 0~1 的時間比例）"""
    return lambda u: min(1.0, u / attack) * min(1.0, (1 - u) / release)


if __name__ == '__main__':
    write('growl', creature(0.7, lambda u: 48 + 18 * u, ad(0.25, 0.15), rough=22, breath=0.6))
    write('roar', creature(1.6, lambda u: 55 + 45 * math.sin(math.pi * min(u * 1.3, 1)), ad(0.12, 0.3), rough=28, breath=0.8,
                           formants=((260, 2.5), (640, 3.5), (1300, 4.5), (2400, 6.0))))
    write('snarl', creature(0.5, lambda u: 70 + 30 * u, ad(0.1, 0.2), rough=31, breath=1.0))
    write('yelp', creature(0.6, lambda u: 140 - 70 * u, ad(0.05, 0.5), rough=18, breath=0.5,
                           formants=((380, 3.0), (900, 4.0), (1800, 5.0))))
