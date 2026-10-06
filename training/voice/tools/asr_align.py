"""Ubica cada frase del guion en las grabaciones con reconocimiento de voz.

1. Vosk (español) transcribe cada audio con el tiempo de cada palabra.
2. Se alinean las palabras del guion con las reconocidas (programación
   dinámica, con parecido difuso entre palabras).
3. Cada frase va desde su primera hasta su última palabra encontrada.

Salida: alineacion.json con inicio, fin y qué tan bien se entendió cada frase.
"""
import difflib
import glob
import json
import os
import re
import subprocess
import unicodedata
import wave

from vosk import KaldiRecognizer, Model, SetLogLevel

HERE = os.path.dirname(os.path.abspath(__file__))
GUION = r'C:\Users\melod\Documents\viernes\training\voice\guion-grabacion.md'
SetLogLevel(-1)
model = Model(os.path.join(HERE, 'vosk-model-small-es-0.42'))

NUMS = {
    '1': 'uno', '2': 'dos', '3': 'tres', '4': 'cuatro', '5': 'cinco', '6': 'seis',
    '7': 'siete', '8': 'ocho', '9': 'nueve', '10': 'diez', '11': 'once', '12': 'doce',
    '15': 'quince', '20': 'veinte', '30': 'treinta', '45': 'cuarenta y cinco',
}


def fold(text):
    t = unicodedata.normalize('NFD', text.lower())
    t = ''.join(c for c in t if unicodedata.category(c) != 'Mn')
    t = re.sub(r'\d+', lambda m: ' ' + NUMS.get(m.group(0), m.group(0)) + ' ', t)
    return re.findall(r'[a-zñ]+', t)


def phrases():
    out = {}
    for line in open(GUION, encoding='utf-8'):
        m = re.match(r'^(\d+)\.\s+(.*)$', line.strip())
        if m:
            out[int(m.group(1))] = m.group(2)
    return out


def transcribe(path):
    tmp = path.replace('.wav', '.16k.wav')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', path, '-ar', '16000',
                    '-ac', '1', tmp], check=True)
    words = []
    with wave.open(tmp) as w:
        rec = KaldiRecognizer(model, 16000)
        rec.SetWords(True)
        while True:
            data = w.readframes(4000)
            if not data:
                break
            if rec.AcceptWaveform(data):
                words += json.loads(rec.Result()).get('result', [])
        words += json.loads(rec.FinalResult()).get('result', [])
    return words


def sim(a, b):
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def align(ref, hyp):
    """ref: [(word, phrase_id)], hyp: [word dict]. Devuelve ref_idx -> hyp_idx."""
    n, m = len(ref), len(hyp)
    GAP = -0.45
    score = [[0.0] * (m + 1) for _ in range(n + 1)]
    move = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        score[i][0] = i * GAP
        move[i][0] = 1
    for j in range(1, m + 1):
        score[0][j] = j * GAP * 0.6
        move[0][j] = 2
    for i in range(1, n + 1):
        ri = ref[i - 1][0]
        for j in range(1, m + 1):
            s = sim(ri, hyp[j - 1]['w'])
            diag = score[i - 1][j - 1] + (s * 2 - 1 if s >= 0.5 else -1.0)
            up = score[i - 1][j] + GAP
            left = score[i][j - 1] + GAP * 0.6  # palabras de más (repeticiones)
            best = max(diag, up, left)
            score[i][j] = best
            move[i][j] = 0 if best == diag else (1 if best == up else 2)
    match = {}
    i, j = n, m
    while i > 0 or j > 0:
        mv = move[i][j]
        if i > 0 and j > 0 and mv == 0:
            if sim(ref[i - 1][0], hyp[j - 1]['w']) >= 0.5:
                match[i - 1] = j - 1
            i -= 1
            j -= 1
        elif i > 0 and (mv == 1 or j == 0):
            i -= 1
        else:
            j -= 1
    return match


def main():
    texts = phrases()
    result = {}
    for path in sorted(glob.glob(os.path.join(HERE, 'wav', '*.wav'))):
        if path.endswith('.16k.wav'):
            continue
        name = os.path.splitext(os.path.basename(path))[0]
        first, last = map(int, name.split('_')[1].split('-'))
        ids = list(range(first, last + 1))
        hyp = [{'w': fold(w['word'])[0] if fold(w['word']) else w['word'],
                's': w['start'], 'e': w['end']} for w in transcribe(path)]
        ref = [(w, pid) for pid in ids for w in fold(texts[pid])]
        match = align(ref, hyp)
        items = []
        for pid in ids:
            idx = [k for k, (_, p) in enumerate(ref) if p == pid]
            found = [match[k] for k in idx if k in match]
            item = {'id': pid, 'texto': texts[pid], 'palabras': len(idx),
                    'reconocidas': len(found)}
            if found:
                item['inicio'] = hyp[min(found)]['s']
                item['fin'] = hyp[max(found)]['e']
                item['oido'] = ' '.join(h['w'] for h in hyp[min(found):max(found) + 1])
            items.append(item)
        result[name] = items
        ok = sum(1 for it in items if it['reconocidas'] / it['palabras'] >= 0.6)
        print(f'{name}: {len(hyp)} palabras oídas; {ok}/{len(items)} frases bien ubicadas')
    json.dump(result, open(os.path.join(HERE, 'alineacion.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
