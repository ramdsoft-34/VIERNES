"""Entrena el intérprete neuronal de Viernes y lo exporta para la app.

Uso (Colab o cualquier Python 3.10+ con TensorFlow):

    python train_nlu.py --out /content/drive/MyDrive/Viernes/modelos

Salidas:
    nlu_model.json    pesos para `assets/ai/nlu_model.json` (inferencia en Dart)
    nlu_parity.json   casos de prueba para verificar que Dart da lo mismo
    nlu_metrics.json  métricas (intención y etiquetas, con tareas no vistas)

Arquitectura (pequeña a propósito, ~250 mil parámetros):
    palabra → embedding(48) → conv1d(96, k=3) → conv1d(96, k=3)
      ├─ por palabra: dense → softmax(etiquetas BIO)
      └─ máximo global → dense → softmax(intención)
Las posiciones de relleno se anulan con una máscara para que la inferencia
sin relleno en el teléfono dé exactamente lo mismo.
"""

from __future__ import annotations

import argparse
import base64
import collections
import datetime as dt
import json
import os
import random
from pathlib import Path

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
from tensorflow import keras  # noqa: E402

import nlu_data as data  # noqa: E402

MAX_LEN = 32
EMB = 48
HIDDEN = 96
OOV_BUCKETS = 512
MIN_COUNT = 2
VERSION = "nn-es-1.0"


def build_vocab(examples):
    counts = collections.Counter(
        data.normalize_token(t) for ex in examples for t in ex.tokens
    )
    words = sorted(w for w, c in counts.items() if c >= MIN_COUNT and w != data.NUM)
    return [data.PAD, data.NUM] + words


def token_id(token, index, vocab_size):
    token = data.normalize_token(token)
    if token in index:
        return index[token]
    return vocab_size + data.fnv1a(token) % OOV_BUCKETS


def encode(examples, index, vocab_size):
    n = len(examples)
    ids = np.zeros((n, MAX_LEN), np.int32)
    tags = np.zeros((n, MAX_LEN), np.int32)
    weights = np.zeros((n, MAX_LEN), np.float32)
    intents = np.zeros((n,), np.int32)
    tag_index = {t: i for i, t in enumerate(data.TAGS)}
    for i, ex in enumerate(examples):
        toks = ex.tokens[:MAX_LEN]
        for j, tok in enumerate(toks):
            ids[i, j] = token_id(tok, index, vocab_size)
            tags[i, j] = tag_index[ex.tags[j]]
            weights[i, j] = ex.weights[j] if ex.weights else 1.0
        intents[i] = data.INTENTS.index(ex.intent)
    return ids, tags, weights, intents


def build_model(total_ids):
    ids = keras.Input((MAX_LEN,), dtype="int32", name="ids")
    mask = keras.ops.expand_dims(keras.ops.cast(ids > 0, "float32"), -1)
    x = keras.layers.Embedding(total_ids, EMB, name="embedding")(ids) * mask
    h = keras.layers.Conv1D(HIDDEN, 3, padding="same", activation="relu",
                            name="conv1")(x) * mask
    h = keras.layers.Dropout(0.15)(h)
    h = keras.layers.Conv1D(HIDDEN, 3, padding="same", activation="relu",
                            name="conv2")(h) * mask
    tags = keras.layers.Dense(len(data.TAGS), activation="softmax", name="tags")(
        keras.layers.Dropout(0.15)(h))
    pooled = keras.ops.max(h + (mask - 1.0) * 1e4, axis=1)
    intent = keras.layers.Dense(len(data.INTENTS), activation="softmax",
                                name="intent")(keras.layers.Dropout(0.2)(pooled))
    model = keras.Model(ids, {"tags": tags, "intent": intent})
    model.compile(
        optimizer=keras.optimizers.Adam(2e-3),
        loss={"tags": "sparse_categorical_crossentropy",
              "intent": "sparse_categorical_crossentropy"},
        loss_weights={"tags": 1.0, "intent": 0.5},
    )
    return model


def spans(tags):
    out, cur = set(), None
    for i, t in enumerate(tags + ["O"]):
        if t.startswith("B-") or t == "O" or (cur and t[2:] != cur[0]):
            if cur:
                out.add((cur[0], cur[1], i))
                cur = None
        if t.startswith("B-") or (t.startswith("I-") and cur is None):
            cur = (t[2:], i)
    return out


def evaluate(model, examples, index, vocab_size, name):
    ids, tags, weights, intents = encode(examples, index, vocab_size)
    pred = model.predict(ids, batch_size=256, verbose=0)
    intent_pred = pred["intent"].argmax(-1)
    tag_pred = pred["tags"].argmax(-1)
    tp = fp = fn = 0
    title_exact = title_total = 0
    for i, ex in enumerate(examples):
        n = min(len(ex.tokens), MAX_LEN)
        gold = spans(ex.tags[:n])
        guess = spans([data.TAGS[k] for k in tag_pred[i, :n]])
        tp += len(gold & guess)
        fp += len(guess - gold)
        fn += len(gold - guess)
        gold_t = {s for s in gold if s[0] == "TAREA"}
        if gold_t:
            title_total += 1
            title_exact += int(gold_t == {s for s in guess if s[0] == "TAREA"})
    precision = tp / max(tp + fp, 1)
    recall = tp / max(tp + fn, 1)
    metrics = {
        "intent_accuracy": float((intent_pred == intents).mean()),
        "span_f1": 2 * precision * recall / max(precision + recall, 1e-9),
        "title_exact": title_exact / max(title_total, 1),
        "n": len(examples),
    }
    print(f"[{name}] " + ", ".join(f"{k}={v:.3f}" if isinstance(v, float) else f"{k}={v}"
                                   for k, v in metrics.items()))
    return metrics


def b64(array):
    return base64.b64encode(np.asarray(array, "<f4").tobytes()).decode()


def export(model, vocab, out_dir: Path, metrics):
    layers = {l.name: l for l in model.layers}
    weights = {
        "embedding": layers["embedding"].get_weights()[0],
        "conv1.kernel": layers["conv1"].get_weights()[0],
        "conv1.bias": layers["conv1"].get_weights()[1],
        "conv2.kernel": layers["conv2"].get_weights()[0],
        "conv2.bias": layers["conv2"].get_weights()[1],
        "tags.kernel": layers["tags"].get_weights()[0],
        "tags.bias": layers["tags"].get_weights()[1],
        "intent.kernel": layers["intent"].get_weights()[0],
        "intent.bias": layers["intent"].get_weights()[1],
    }
    payload = {
        "version": VERSION,
        "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "maxLen": MAX_LEN,
        "oovBuckets": OOV_BUCKETS,
        "vocab": vocab,
        "tags": data.TAGS,
        "intents": data.INTENTS,
        "metrics": metrics,
        "tensors": {k: {"shape": list(v.shape), "data": b64(v)} for k, v in weights.items()},
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "nlu_model.json"
    path.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    print(f"Modelo: {path} ({path.stat().st_size / 1024:.0f} KB)")


def export_parity(model, vocab, out_dir: Path):
    index = {w: i for i, w in enumerate(vocab)}
    sentences = [
        "recuérdame mañana a las 8 llamar a Juan",
        "Tengo que pagar el arriendo el 5 de cada mes",
        "qué tengo para mañana",
        "ya no lo necesito",
        "hola viernes",
        "el viernes a las 3 de la tarde reunión con el jefe urgente",
        "Comprar xilófono para Zuleidy en 20 minutos",
    ]
    cases = []
    for s in sentences:
        toks = data.tokenize(s)[:MAX_LEN]
        ids = [token_id(t, index, len(vocab)) for t, _, _ in toks]
        padded = np.zeros((1, MAX_LEN), np.int32)
        padded[0, :len(ids)] = ids
        pred = model.predict(padded, verbose=0)
        cases.append({
            "text": s,
            "ids": ids,
            "intent": [round(float(p), 5) for p in pred["intent"][0]],
            "tags": [data.TAGS[k] for k in pred["tags"][0, :len(ids)].argmax(-1)],
            "tagProbs": [round(float(p), 5) for p in pred["tags"][0, :len(ids)].max(-1)],
        })
    path = out_dir / "nlu_parity.json"
    path.write_text(json.dumps(cases, ensure_ascii=False, indent=1), encoding="utf-8")
    for c in cases:
        print(f"  {c['text']!r}: {data.INTENTS[int(np.argmax(c['intent']))]} {c['tags']}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="out")
    parser.add_argument("--real", nargs="*", default=[],
                        help="archivos JSONL exportados por la app")
    parser.add_argument("--n", type=int, default=40000)
    parser.add_argument("--epochs", type=int, default=12)
    args = parser.parse_args()

    random.seed(1)
    np.random.seed(1)
    tf.random.set_seed(1)

    train_templates, test_templates = data.split_task_templates()
    train = data.generate(args.n, seed=1, task_templates=train_templates)
    valid = data.generate(3000, seed=2, task_templates=train_templates)
    unseen = data.generate(3000, seed=3, task_templates=test_templates)

    real_paths = [Path(p) for p in args.real if Path(p).exists()]
    real = data.load_real(real_paths)
    if real:
        rng = random.Random(4)
        rng.shuffle(real)
        k = max(1, len(real) // 5)
        real_test, real_train = real[:k], real[k:]
        # Lo real pesa más: son frases de verdad del usuario.
        train += real_train * 5
        print(f"Frases reales: {len(real_train)} para entrenar, {len(real_test)} para medir")
    else:
        real_test = []
        print("Sin frases reales todavía: solo datos sintéticos.")

    vocab = build_vocab(train)
    index = {w: i for i, w in enumerate(vocab)}
    total_ids = len(vocab) + OOV_BUCKETS
    print(f"Vocabulario: {len(vocab)} palabras + {OOV_BUCKETS} cubetas")

    model = build_model(total_ids)
    x, y_tags, w_tags, y_int = encode(train, index, len(vocab))
    vx, vy_tags, vw_tags, vy_int = encode(valid, index, len(vocab))
    model.fit(
        x, {"tags": y_tags, "intent": y_int},
        sample_weight={"tags": w_tags, "intent": np.ones(len(x), np.float32)},
        validation_data=(vx, {"tags": vy_tags, "intent": vy_int},
                         {"tags": vw_tags, "intent": np.ones(len(vx), np.float32)}),
        epochs=args.epochs, batch_size=64, verbose=2,
        callbacks=[keras.callbacks.EarlyStopping(patience=2, restore_best_weights=True)],
    )
    model.summary()

    metrics = {
        "valid": evaluate(model, valid, index, len(vocab), "validación"),
        "unseen_tasks": evaluate(model, unseen, index, len(vocab), "tareas no vistas"),
    }
    if real_test:
        metrics["real"] = evaluate(model, real_test, index, len(vocab), "frases reales")

    out = Path(args.out)
    export(model, vocab, out, metrics)
    export_parity(model, vocab, out)
    (out / "nlu_metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
