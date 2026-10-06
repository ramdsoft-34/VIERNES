"""Corta cada frase (las dos tomas), la limpia, la nivela y mide su calidad.

Salida:
- clips/<id>_<toma>.wav           frase recortada y nivelada (48 kHz)
- app/<id>.m4a                    mejor toma de cada frase, para la app
- metricas.json                   medidas por frase y toma
"""
import json
import os
import re
import subprocess
import unicodedata
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
APP = r'C:\Users\melod\Documents\viernes\assets\voice'
TARGET_RMS = -19.0   # dBFS de la voz (≈ -16 LUFS en frases cortas)
PEAK_LIMIT = -1.5    # dBFS


def load(path):
    with wave.open(path) as w:
        rate = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    return data.astype(np.float64) / 32768.0, rate


def save(path, x, rate):
    y = np.clip(x, -1, 1)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((y * 32767).astype(np.int16).tobytes())


def db(v):
    return 20 * np.log10(max(v, 1e-9))


def frame_db(x, rate):
    hop = int(rate * 0.01)
    win = int(rate * 0.025)
    if len(x) < win:
        return np.array([-120.0])
    f = np.lib.stride_tricks.sliding_window_view(x, win)[::hop]
    return 20 * np.log10(np.sqrt(np.mean(f ** 2, axis=1)) + 1e-9)


def expand(x, rate, start, end, lo, hi):
    """Mueve los bordes hasta el silencio real (el reconocedor a veces corta
    la primera o la última sílaba), sin pasar a la frase vecina."""
    hop = int(rate * 0.01)
    win = int(rate * 0.02)
    full = frame_db(x[int(lo * rate):int(hi * rate)], rate)
    if len(full) < 5:
        return lo, hi
    floor = np.percentile(full, 10)
    thr = floor + max(10.0, (np.max(full) - floor) * 0.18)

    def quiet_run(t, step):
        run = 0
        while lo <= t <= hi:
            i = int(t * rate)
            e = 20 * np.log10(np.sqrt(np.mean(x[i:i + win] ** 2)) + 1e-9)
            run = run + 1 if e < thr else 0
            if run >= 8:  # 80 ms de silencio
                return t - step * 8 * 0.01
            t += step * 0.01
        return lo if step < 0 else hi

    a = quiet_run(start, -1) - 0.06
    b = quiet_run(end, 1) + 0.10
    return max(lo, a), min(hi, b)


def fold(t):
    t = unicodedata.normalize('NFD', t.lower())
    t = ''.join(c for c in t if unicodedata.category(c) != 'Mn')
    return ' '.join(re.findall(r'[a-zñ0-9]+', t))


def main():
    os.makedirs(os.path.join(HERE, 'clips'), exist_ok=True)
    os.makedirs(APP, exist_ok=True)
    align = json.load(open(os.path.join(HERE, 'alineacion.json'), encoding='utf-8'))
    metrics = {}
    for name, items in align.items():
        take = name.split('_')[0]
        x, rate = load(os.path.join(HERE, 'wav', name + '.wav'))
        for k, it in enumerate(items):
            if 'inicio' not in it:
                continue
            prev_end = items[k - 1].get('fin', 0) if k > 0 else 0
            next_start = items[k + 1].get('inicio', len(x) / rate) if k + 1 < len(items) else len(x) / rate
            lo = (prev_end + it['inicio']) / 2
            hi = (it['fin'] + next_start) / 2
            a, b = expand(x, rate, it['inicio'], it['fin'], lo, hi)
            seg = x[int(a * rate):int(b * rate)].copy()
            # Filtro paso alto suave (quita golpes y zumbido grave).
            alpha = np.exp(-2 * np.pi * 70 / rate)
            y = np.zeros_like(seg)
            prev_x = prev_y = 0.0
            for i, v in enumerate(seg):
                prev_y = alpha * (prev_y + v - prev_x)
                prev_x = v
                y[i] = prev_y
            seg = y
            level = frame_db(seg, rate)
            voice = level[level > np.max(level) - 30]
            rms = 10 * np.log10(np.mean(10 ** (voice / 10)))
            peak = db(np.max(np.abs(seg)))
            floor = float(np.percentile(level, 5))
            gain = min(TARGET_RMS - rms, PEAK_LIMIT - peak)
            seg = seg * 10 ** (gain / 20)
            fade = int(rate * 0.015)
            seg[:fade] *= np.linspace(0, 1, fade)
            seg[-fade:] *= np.linspace(1, 0, fade)
            def edb(s_):
                return 20 * np.log10(np.sqrt(np.mean(s_ ** 2)) + 1e-9)
            i_pk = int(np.argmax(np.abs(seg)))
            pk = edb(seg[max(0, i_pk - 480):i_pk + 480])
            edge = max(edb(seg[int(.015 * rate):int(.05 * rate)]),
                       edb(seg[-int(.05 * rate):-int(.015 * rate)])) - pk
            out = os.path.join(HERE, 'clips', f"{it['id']:03d}_{take}.wav")
            save(out, seg, rate)
            words = len(fold(it['texto']).split())
            dur = len(seg) / rate
            metrics.setdefault(str(it['id']), {})[take] = {
                'texto': it['texto'],
                'duracion_s': round(dur, 2),
                'palabras_por_seg': round(words / max(it['fin'] - it['inicio'], 0.1), 2),
                'voz_original_dbfs': round(float(rms), 1),
                'pico_original_dbfs': round(float(peak), 1),
                'ruido_dbfs': round(floor, 1),
                'ganancia_db': round(float(gain), 1),
                'entendido': round(it['reconocidas'] / it['palabras'], 2),
                'borde_cortado': bool(edge > -25),
                'archivo': out,
            }
    # Mejor toma: la que mejor se entendió; si empatan, la menos saturada y
    # la que necesitó menos ganancia (más cerca del micrófono).
    manifest = []
    for pid, takes in sorted(metrics.items(), key=lambda kv: int(kv[0])):
        best = max(takes.items(), key=lambda kv: (
            kv[1]['entendido'], not kv[1]['borde_cortado'],
            kv[1]['pico_original_dbfs'] < -0.8, -abs(kv[1]['ganancia_db'])))
        takes['elegida'] = best[0]
        dest = os.path.join(APP, f'{int(pid):03d}.m4a')
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', best[1]['archivo'],
                        '-c:a', 'aac', '-b:a', '64k', '-ar', '44100', dest], check=True)
        manifest.append({
            'id': int(pid),
            'texto': best[1]['texto'],
            'archivo': f'{int(pid):03d}.m4a',
            'toma': best[0],
            'duracion': best[1]['duracion_s'],
        })
    json.dump({'version': 1, 'frases': manifest},
              open(os.path.join(APP, 'manifest.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    json.dump(metrics, open(os.path.join(HERE, 'metricas.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('frases:', len(metrics), 'para la app:', len(manifest))


if __name__ == '__main__':
    main()
