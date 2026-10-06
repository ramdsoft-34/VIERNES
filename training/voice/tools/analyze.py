import glob
import json
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
EXPECTED = {'1-65': 65, '66-115': 50, '116-180': 65}


def load(path):
    with wave.open(path) as w:
        rate = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    return data.astype(np.float32) / 32768.0, rate


def db(x):
    return 20 * np.log10(np.maximum(x, 1e-9))


def segments(x, rate, min_silence=0.30, min_speech=0.18):
    hop = int(rate * 0.010)
    win = int(rate * 0.025)
    n = (len(x) - win) // hop
    rms = np.array([np.sqrt(np.mean(x[i * hop:i * hop + win] ** 2)) for i in range(n)])
    level = db(rms)
    floor = np.percentile(level, 10)
    speech_level = np.percentile(level, 90)
    thr = floor + max(8.0, (speech_level - floor) * 0.30)
    active = level > thr
    # rellenar silencios cortos
    segs = []
    i = 0
    while i < n:
        if active[i]:
            start = i
            gap = 0
            j = i
            while j < n:
                if active[j]:
                    gap = 0
                else:
                    gap += 1
                    if gap * 0.010 >= min_silence:
                        break
                j += 1
            end = j - gap
            if (end - start) * 0.010 >= min_speech:
                segs.append((start * hop / rate, (end * hop + win) / rate))
            i = j
        else:
            i += 1
    return segs, floor, speech_level, level


report = {}
for path in sorted(glob.glob(os.path.join(HERE, 'wav', '*.wav'))):
    name = os.path.splitext(os.path.basename(path))[0]
    x, rate = load(path)
    segs, floor, speech, level = segments(x, rate)
    peak = float(np.max(np.abs(x)))
    clipped = int(np.sum(np.abs(x) > 0.995))
    voiced = np.concatenate([x[int(a * rate):int(b * rate)] for a, b in segs]) if segs else x
    speech_rms = float(db(np.sqrt(np.mean(voiced ** 2))))
    durs = [b - a for a, b in segs]
    key = name.split('_')[1]
    report[name] = {
        'duracion_s': round(len(x) / rate, 1),
        'pico_dbfs': round(float(db(peak)), 1),
        'muestras_saturadas': clipped,
        'voz_rms_dbfs': round(speech_rms, 1),
        'ruido_fondo_dbfs': round(float(floor), 1),
        'snr_db': round(float(speech - floor), 1),
        'segmentos': len(segs),
        'frases_esperadas': EXPECTED.get(key),
        'seg_min_s': round(min(durs), 2) if durs else None,
        'seg_mediana_s': round(float(np.median(durs)), 2) if durs else None,
        'seg_max_s': round(max(durs), 2) if durs else None,
        'voz_total_s': round(sum(durs), 1),
    }
    with open(os.path.join(HERE, name + '.segs.json'), 'w') as f:
        json.dump(segs, f)

print(json.dumps(report, indent=1, ensure_ascii=False))
