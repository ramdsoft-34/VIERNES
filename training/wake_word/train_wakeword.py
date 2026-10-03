"""Entrena el detector propio de la palabra «Viernes» (openWakeWord).

Pensado para Google Colab con GPU:

    python train_wakeword.py --out /content/drive/MyDrive/Viernes/modelos

Pasos (cada uno se guarda en --work y se salta si ya existe):
 1. Voces: descarga voces Piper en español (España, México, Argentina…).
 2. Positivos: «Viernes», «Oye Viernes», «¿Viernes?»… con cada voz y
    variaciones de velocidad y entonación.
 3. Negativos difíciles: palabras parecidas («jueves», «invierno», «vienes»)
    y frases del guion de grabación sin la palabra.
 4. Aumentos: cambio de tono (más voces), ruido, volumen y reverberación.
 5. Características con los modelos de openWakeWord (melspectrograma +
    embeddings), los mismos que corren en el teléfono.
 6. Negativos generales: características precalculadas de openWakeWord
    (habla y ruido de miles de horas).
 7. Entrena un clasificador pequeño, mide aciertos y falsas activaciones por
    hora, y exporta a TensorFlow Lite.

Salidas en --out:
    viernes.tflite, melspectrogram.tflite, embedding_model.tflite
    wakeword_metrics.json
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import subprocess
import sys
import urllib.request
import wave
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np  # noqa: E402

SR = 16000
CLIP = 32000  # 2 s → 16 ventanas de embeddings de openWakeWord
OWW_RELEASE = "https://github.com/dscripka/openWakeWord/releases/download/v0.5.1"
HF = "https://huggingface.co"
PIPER_VOICES = f"{HF}/rhasspy/piper-voices/resolve/main/es"
VOICES = [
    "es_ES/davefx/medium/es_ES-davefx-medium",
    "es_ES/sharvard/medium/es_ES-sharvard-medium",
    "es_ES/carlfm/x_low/es_ES-carlfm-x_low",
    "es_ES/mls_10246/low/es_ES-mls_10246-low",
    "es_ES/mls_9972/low/es_ES-mls_9972-low",
    "es_MX/ald/medium/es_MX-ald-medium",
    "es_MX/claude/high/es_MX-claude-high",
    "es_AR/daniela/high/es_AR-daniela-high",
]
# Voz que no se usa al entrenar: mide si generaliza a una voz nueva.
HOLDOUT_VOICE = "es_AR-daniela-high"

POSITIVE_TEXTS = [
    "Viernes", "Viernes.", "¡Viernes!", "¿Viernes?", "Oye Viernes", "Oye, Viernes",
    "Hola Viernes", "Viernes, recuérdame", "Viernes...", "Ey Viernes",
]
ADVERSARIAL = [
    "jueves", "invierno", "vienes", "viene", "bienes", "tienes", "piernas",
    "verbena", "vernos", "Venus", "viernas", "fierro", "sierra", "pienses",
    "mientras", "siempre", "inviernos", "vientre", "viento", "Viena", "vieja",
    "Hernández", "eternos", "tiernas", "cuernos", "hierbas", "infiernos",
    "bien es", "vi eres", "el jueves", "este invierno", "si vienes", "tus bienes",
    "miércoles", "martes", "sábado", "domingo", "lunes", "festivo",
    "buenas noches", "oye Mercedes", "oye Andrés", "hola Fernanda", "oye Dolores",
]


def sh(cmd: str):
    print(f"$ {cmd}", flush=True)
    subprocess.run(cmd, shell=True, check=True)


def download(url: str, path: Path):
    if path.exists() and path.stat().st_size > 0:
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Descargando {url}", flush=True)
    tmp = path.with_suffix(path.suffix + ".part")
    urllib.request.urlretrieve(url, tmp)
    tmp.rename(path)
    return path


# ---------------------------------------------------------------------------
# 1–3. Síntesis con Piper
# ---------------------------------------------------------------------------


def load_voices(work: Path):
    from piper import PiperVoice  # type: ignore

    voices = {}
    for rel in VOICES:
        name = rel.split("/")[-1]
        try:
            onnx = download(f"{PIPER_VOICES}/{rel}.onnx", work / "voices" / f"{name}.onnx")
            download(f"{PIPER_VOICES}/{rel}.onnx.json",
                     work / "voices" / f"{name}.onnx.json")
            voices[name] = PiperVoice.load(str(onnx))
        except Exception as error:  # noqa: BLE001
            print(f"  (se omite la voz {name}: {error})")
    print(f"Voces disponibles: {list(voices)}")
    return voices


def synthesize(voice, text: str, length_scale: float, noise: float, noise_w: float,
               speaker: int | None) -> np.ndarray:
    """Devuelve audio float32 a 16 kHz. Soporta las API de piper-tts 1.2 y 1.3."""
    import io

    sample_rate = voice.config.sample_rate
    audio = None
    try:  # piper-tts >= 1.3
        from piper import SynthesisConfig  # type: ignore

        config = SynthesisConfig(
            length_scale=length_scale, noise_scale=noise, noise_w_scale=noise_w,
            speaker_id=speaker,
        )
        chunks = [c.audio_float_array for c in voice.synthesize(text, syn_config=config)]
        audio = np.concatenate(chunks) if chunks else np.zeros(0, np.float32)
    except ImportError:  # piper-tts 1.2
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wav:
            voice.synthesize(text, wav, length_scale=length_scale, noise_scale=noise,
                             noise_w=noise_w, speaker_id=speaker)
        buf.seek(0)
        with wave.open(buf, "rb") as wav:
            pcm = np.frombuffer(wav.readframes(wav.getnframes()), np.int16)
        audio = pcm.astype(np.float32) / 32768
    import librosa

    return librosa.resample(audio.astype(np.float32), orig_sr=sample_rate, target_sr=SR)


def speakers_of(voice) -> list[int | None]:
    n = getattr(voice.config, "num_speakers", 1) or 1
    return list(range(n)) if n > 1 else [None]


def make_clips(voices, texts, per_text: int, rng: random.Random):
    clips = {}
    for name, voice in voices.items():
        out = []
        for text in texts:
            for speaker in speakers_of(voice):
                for _ in range(per_text):
                    audio = synthesize(
                        voice, text,
                        length_scale=rng.uniform(0.75, 1.35),
                        noise=rng.uniform(0.4, 0.9),
                        noise_w=rng.uniform(0.5, 1.0),
                        speaker=speaker,
                    )
                    if audio.size > SR * 0.15:
                        out.append(audio)
        clips[name] = out
        print(f"  {name}: {len(out)} clips", flush=True)
    return clips


def guion_negatives(repo_root: Path) -> list[str]:
    path = repo_root / "training" / "voice" / "guion-grabacion.md"
    if not path.exists():
        return []
    phrases = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*\d+\.\s+(.*)$", line)
        if m and "viernes" not in m.group(1).lower():
            phrases.append(m.group(1).strip())
    return phrases


# ---------------------------------------------------------------------------
# 4. Aumentos
# ---------------------------------------------------------------------------


def augmenter():
    from audiomentations import (AddColorNoise, AddGaussianSNR, Compose, Gain,
                                 PitchShift, TimeStretch)

    steps = [
        PitchShift(min_semitones=-4, max_semitones=4, p=0.7),
        TimeStretch(min_rate=0.85, max_rate=1.15, p=0.4),
        Gain(min_gain_db=-18, max_gain_db=6, p=0.8),
        AddColorNoise(min_snr_db=5, max_snr_db=35, p=0.6),
        AddGaussianSNR(min_snr_db=10, max_snr_db=40, p=0.3),
    ]
    try:
        from audiomentations import RoomSimulator

        steps.insert(2, RoomSimulator(p=0.4, leave_length_unchanged=True))
    except Exception:  # noqa: BLE001
        print("  (sin RoomSimulator: falta pyroomacoustics)")
    return Compose(steps)


def place_in_clip(audio: np.ndarray, rng: random.Random, positive: bool) -> np.ndarray:
    """Clip de 2 s. En los positivos la palabra termina cerca del final, como
    cuando el detector la está escuchando en vivo."""
    out = np.zeros(CLIP, np.float32)
    audio = audio[:CLIP]
    if positive:
        end = CLIP - rng.randint(0, int(0.25 * SR))
        start = max(0, end - len(audio))
    else:
        start = rng.randint(0, max(0, CLIP - len(audio)))
    out[start:start + len(audio)] = audio[: CLIP - start]
    # Ruido de fondo muy bajo para que no haya silencio digital.
    out += np.random.normal(0, rng.uniform(1e-4, 3e-3), CLIP).astype(np.float32)
    return out


def to_int16(x: np.ndarray) -> np.ndarray:
    peak = max(1e-6, float(np.abs(x).max()))
    if peak > 1:
        x = x / peak
    return (x * 32767).astype(np.int16)


def build_set(clips: list[np.ndarray], copies: int, positive: bool, rng, aug):
    out = []
    for audio in clips:
        for _ in range(copies):
            x = place_in_clip(audio, rng, positive)
            x = aug(samples=x, sample_rate=SR)
            out.append(to_int16(x[:CLIP] if len(x) >= CLIP else np.pad(x, (0, CLIP - len(x)))))
    return np.stack(out) if out else np.zeros((0, CLIP), np.int16)


# ---------------------------------------------------------------------------
# 5–6. Características
# ---------------------------------------------------------------------------


def feature_models(work: Path):
    models = {}
    for name in ("melspectrogram", "embedding_model"):
        for ext in ("onnx", "tflite"):
            models[f"{name}.{ext}"] = download(f"{OWW_RELEASE}/{name}.{ext}",
                                               work / "oww" / f"{name}.{ext}")
    return models


def features(clips_int16: np.ndarray, models) -> np.ndarray:
    from openwakeword.utils import AudioFeatures  # type: ignore

    af = AudioFeatures(
        melspec_model_path=str(models["melspectrogram.onnx"]),
        embedding_model_path=str(models["embedding_model.onnx"]),
        inference_framework="onnx",
        device="gpu" if _has_gpu() else "cpu",
    )
    feats = af.embed_clips(clips_int16, batch_size=256)
    return feats[:, -16:, :].astype(np.float32)


def _has_gpu() -> bool:
    try:
        import onnxruntime as ort  # type: ignore

        return "CUDAExecutionProvider" in ort.get_available_providers()
    except Exception:  # noqa: BLE001
        return False


def general_negatives(work: Path, max_rows: int):
    train = download(
        f"{HF}/datasets/davidscripka/openwakeword_features/resolve/main/"
        "openwakeword_features_ACAV100M_2000_hrs_16bit.npy",
        work / "oww" / "acav_features.npy",
    )
    valid = download(
        f"{HF}/datasets/davidscripka/openwakeword_features/resolve/main/"
        "validation_set_features.npy",
        work / "oww" / "validation_set_features.npy",
    )
    acav = np.load(train, mmap_mode="r")
    print(f"Negativos generales: {acav.shape}")
    rows = np.sort(np.random.choice(acav.shape[0], min(max_rows, acav.shape[0]),
                                    replace=False))
    # Media precisión: 400 mil ventanas ocupan ~1,2 GB en vez de 2,5 GB.
    sample = np.asarray(acav[rows], np.float16)
    val = np.load(valid, mmap_mode="r")
    return sample, val


# ---------------------------------------------------------------------------
# 7. Clasificador
# ---------------------------------------------------------------------------


def build_classifier():
    import tensorflow as tf
    from tensorflow import keras

    inputs = keras.Input((16, 96), name="features")
    x = keras.layers.Flatten()(inputs)
    for _ in range(2):
        x = keras.layers.Dense(128)(x)
        x = keras.layers.LayerNormalization()(x)
        x = keras.layers.ReLU()(x)
        x = keras.layers.Dropout(0.3)(x)
    outputs = keras.layers.Dense(1, activation="sigmoid", name="score")(x)
    model = keras.Model(inputs, outputs)
    model.compile(optimizer=keras.optimizers.Adam(1e-3),
                  loss=keras.losses.BinaryCrossentropy(),
                  metrics=[keras.metrics.Recall(thresholds=0.5, name="recall")])
    tf.random.set_seed(1)
    return model


def false_activations_per_hour(scores: np.ndarray, threshold: float) -> float:
    """El conjunto de validación de openWakeWord son ventanas seguidas cada
    80 ms (~11 h). Una activación cuenta una vez aunque dure varias ventanas."""
    hours = len(scores) * 0.08 / 3600
    above = scores >= threshold
    activations = int(np.sum(above[1:] & ~above[:-1]) + (1 if above[0] else 0))
    return activations / max(hours, 1e-9)


def export_tflite(model, path: Path, sample: np.ndarray):
    import tensorflow as tf

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = converter.convert()
    path.write_bytes(tflite)
    interpreter = tf.lite.Interpreter(model_content=tflite)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    diffs = []
    for row in sample[:50]:
        interpreter.set_tensor(inp["index"], row[None].astype(np.float32))
        interpreter.invoke()
        diffs.append(abs(float(interpreter.get_tensor(out["index"])[0, 0])
                         - float(model(row[None], training=False)[0, 0])))
    print(f"TFLite: {path.stat().st_size / 1024:.0f} KB, diferencia máx. {max(diffs):.2e}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="out")
    parser.add_argument("--work", default="/content/work_wakeword")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--per-text", type=int, default=6)
    parser.add_argument("--copies", type=int, default=4)
    parser.add_argument("--general-negatives", type=int, default=400_000)
    parser.add_argument("--epochs", type=int, default=20)
    args = parser.parse_args()

    rng = random.Random(1)
    np.random.seed(1)
    work, out = Path(args.work), Path(args.out)
    work.mkdir(parents=True, exist_ok=True)
    out.mkdir(parents=True, exist_ok=True)

    cache = work / "features.npz"
    models = feature_models(work)
    if cache.exists():
        print("Usando características ya calculadas")
        z = np.load(cache)
        pos_train, pos_test, neg_hard = z["pos_train"], z["pos_test"], z["neg_hard"]
    else:
        voices = load_voices(work)
        print("Sintetizando positivos…")
        positives = make_clips(voices, POSITIVE_TEXTS, args.per_text, rng)
        print("Sintetizando negativos difíciles…")
        neg_texts = ADVERSARIAL + guion_negatives(Path(args.repo))[:250]
        negatives = make_clips(voices, neg_texts, 1, rng)
        aug = augmenter()
        train_pos = [a for n, c in positives.items() if n != HOLDOUT_VOICE for a in c]
        test_pos = positives.get(HOLDOUT_VOICE, [])
        all_neg = [a for c in negatives.values() for a in c]
        print("Aumentando y calculando características…")
        pos_train = features(build_set(train_pos, args.copies, True, rng, aug), models)
        pos_test = features(build_set(test_pos, 2, True, rng, aug), models)
        neg_hard = features(build_set(all_neg, 2, False, rng, aug), models)
        np.savez_compressed(cache, pos_train=pos_train, pos_test=pos_test, neg_hard=neg_hard)
    print(f"Positivos: {len(pos_train)} (entrenar) / {len(pos_test)} (voz nueva); "
          f"negativos difíciles: {len(neg_hard)}")

    neg_general, val_features = general_negatives(work, args.general_negatives)

    # Entrenamiento: los negativos difíciles se repiten para que pesen.
    x = np.concatenate([pos_train.astype(np.float16), neg_hard.astype(np.float16),
                        neg_hard.astype(np.float16), neg_general])
    del neg_general
    y = np.concatenate([np.ones(len(pos_train)), np.zeros(2 * len(neg_hard)),
                        np.zeros(len(neg_general))]).astype(np.float32)
    order = np.random.permutation(len(x))
    x, y = x[order], y[order]
    weight_pos = len(y) / (2 * max(1, y.sum()))
    model = build_classifier()
    model.fit(x, y, batch_size=1024, epochs=args.epochs, verbose=2,
              validation_split=0.05,
              class_weight={0: 1.0, 1: float(min(weight_pos, 50))})

    # Métricas
    val_scores = np.concatenate([
        model.predict(np.asarray(val_features[i:i + 50_000], np.float32),
                      batch_size=4096, verbose=0)[:, 0]
        for i in range(0, len(val_features), 50_000)
    ])
    test_scores = model.predict(pos_test, batch_size=1024, verbose=0)[:, 0] \
        if len(pos_test) else np.zeros(0)
    hard_scores = model.predict(neg_hard, batch_size=1024, verbose=0)[:, 0]
    table = []
    for t in (0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9):
        row = {
            "threshold": t,
            "recall_new_voice": float((test_scores >= t).mean()) if len(test_scores) else None,
            "false_per_hour": false_activations_per_hour(val_scores, t),
            "similar_words_triggered": float((hard_scores >= t).mean()),
        }
        table.append(row)
        print(row)
    good = [r for r in table if r["false_per_hour"] <= 0.5]
    best = max(good, key=lambda r: (r["recall_new_voice"] or 0)) if good else table[-1]
    print(f"Umbral sugerido: {best['threshold']}")

    export_tflite(model, out / "viernes.tflite", pos_test if len(pos_test) else pos_train)
    for name in ("melspectrogram.tflite", "embedding_model.tflite"):
        (out / name).write_bytes(models[name].read_bytes())
    (out / "wakeword_metrics.json").write_text(json.dumps({
        "suggested_threshold": best["threshold"],
        "table": table,
        "positives_train": int(len(pos_train)),
        "positives_new_voice": int(len(pos_test)),
        "hard_negatives": int(len(neg_hard)),
        "general_negatives": int(len(neg_general)),
        "holdout_voice": HOLDOUT_VOICE,
    }, indent=2), encoding="utf-8")
    print(f"Listo: {out}")


if __name__ == "__main__":
    sys.exit(main())
