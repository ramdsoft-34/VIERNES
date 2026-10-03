"""Datos para el intérprete neuronal de Viernes.

- Tokenizador idéntico al de la app (`lib/ai/nlu/ml/nlu_tokenizer.dart`).
- Generador de frases sintéticas en español colombiano, etiquetadas por
  construcción (BIO por palabra + intención).
- Cargador de las frases reales exportadas por la app (JSONL), que solo se
  usan si el usuario dio su consentimiento en el teléfono.
"""

from __future__ import annotations

import json
import random
import re
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Tokenizador (debe coincidir exactamente con el de Dart)
# ---------------------------------------------------------------------------

_FOLD = {
    "á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n",
    "à": "a", "è": "e", "ì": "i", "ò": "o", "ù": "u",
}
_TOKEN = re.compile(r"[a-z0-9]+")
NUM = "<num>"
PAD = "<pad>"


def fold(text: str) -> str:
    out = []
    for ch in text:
        low = ch.lower()
        f = _FOLD.get(low, low)
        out.append(f if len(f) == len(ch) else ch)
    return "".join(out)


def tokenize(text: str) -> list[tuple[str, int, int]]:
    """Tokens normalizados con su posición en el texto original."""
    return [(m.group(), m.start(), m.end()) for m in _TOKEN.finditer(fold(text))]


def normalize_token(token: str) -> str:
    return NUM if token.isdigit() else token


def fnv1a(token: str) -> int:
    h = 0x811C9DC5
    for b in token.encode("utf-8"):
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
    return h


# ---------------------------------------------------------------------------
# Etiquetas
# ---------------------------------------------------------------------------

SLOTS = ["TAREA", "FECHA", "HORA", "REP", "PRIO", "ANTIC"]
TAGS = ["O"] + [f"{p}-{s}" for s in SLOTS for p in ("B", "I")]
INTENTS = ["crear", "consultar", "cancelar", "otro"]


@dataclass
class Example:
    tokens: list[str]
    tags: list[str]
    intent: str
    # Peso por token: 0 = etiqueta desconocida (datos reales parciales).
    weights: list[float] = field(default_factory=list)
    text: str = ""


def _segments_to_example(segments: list[tuple[str, str]], intent: str) -> Example:
    tokens, tags = [], []
    text_parts = []
    for text, label in segments:
        if not text:
            continue
        text_parts.append(text)
        toks = [t for t, _, _ in tokenize(text)]
        for i, tok in enumerate(toks):
            tokens.append(tok)
            if label == "O":
                tags.append("O")
            else:
                tags.append(("B-" if i == 0 else "I-") + label)
    return Example(tokens, tags, intent, [1.0] * len(tokens), " ".join(text_parts))


# ---------------------------------------------------------------------------
# Vocabulario de las plantillas
# ---------------------------------------------------------------------------

NAMES = [
    "Juan", "Sofi", "Camila", "Andrés", "Valentina", "Santiago", "Mateo",
    "Daniela", "Laura", "Felipe", "mi mamá", "mi papá", "la abuela", "el tío Jorge",
    "doña Rosa", "don Carlos", "Mariana", "Alejandro", "Paula", "Sebastián",
    "Natalia", "Julián", "Isabella", "Nicolás", "Luisa", "Ricardo", "Tatiana",
    "mi novia", "mi hermano", "el jefe", "la profe", "el doctor Pérez",
]
PLACES = [
    "el banco", "la EPS", "el centro comercial", "la universidad", "el colegio",
    "la oficina", "el gimnasio", "la droguería", "el supermercado", "Unicentro",
    "la notaría", "el aeropuerto", "la terminal", "la clínica", "el parque",
    "Pasto", "Medellín", "Bogotá", "Cali", "la casa de la abuela", "el taller",
]
ITEMS = [
    "leche", "pan", "huevos", "arroz", "café", "las medicinas", "pañales",
    "frutas", "el regalo de Sofi", "pilas", "un cargador", "detergente",
    "papel higiénico", "la torta", "flores", "aguacates", "arepas", "queso",
]
BILLS = [
    "el arriendo", "la luz", "el agua", "el gas", "internet", "la tarjeta de crédito",
    "el celular", "la administración", "el seguro del carro", "la cuota del préstamo",
    "el SOAT", "la matrícula", "Netflix", "la pensión del colegio",
]

TASK_TEMPLATES = [
    "llamar a {name}", "escribirle a {name}", "felicitar a {name}",
    "recoger a {name} en {place}", "visitar a {name}", "pagar {bill}",
    "comprar {item}", "ir a {place}", "pasar por {place}", "sacar la basura",
    "tomar la pastilla", "tomarme la pastilla de la presión", "regar las matas",
    "entregar el informe", "enviar el correo a {name}", "revisar el correo",
    "hacer ejercicio", "salir a correr", "ir al gimnasio", "estudiar para el parcial",
    "hacer la tarea de inglés", "llevar el carro al taller", "renovar el pasaporte",
    "sacar cita en {place}", "cancelar la cita del odontólogo", "darle comida al perro",
    "bañar al gato", "lavar la ropa", "planchar la camisa", "cocinar el almuerzo",
    "descongelar el pollo", "apagar el horno", "cargar el celular",
    "mandarle la plata a {name}", "devolverle el libro a {name}", "reunión con {name}",
    "la reunión de trabajo", "la cita médica", "el cumpleaños de {name}",
    "preparar la presentación", "imprimir los documentos", "firmar el contrato",
    "llamar al banco", "hablar con {name}", "ver el partido", "meditar",
    "tomar agua", "estirarme", "pedir el domicilio", "comprarle {item} a {name}",
    "la clase de baile", "recoger los exámenes", "pagarle a {name}",
    "llevar a {name} a {place}", "agendar la vacuna", "hacer mercado",
    "limpiar la nevera", "cambiar las sábanas", "revisar las llantas",
    "echarle gasolina al carro", "subir las fotos", "responder el mensaje de {name}",
    "confirmar la reserva", "comprar los tiquetes a {place}", "hacer el pago de {bill}",
    "terminar el proyecto", "mandar la cotización", "llamar a la EPS",
]

DATES = [
    "hoy", "mañana", "pasado mañana", "el lunes", "el martes", "el miércoles",
    "el jueves", "el viernes", "el sábado", "el domingo", "este lunes", "este viernes",
    "el próximo martes", "el próximo sábado", "la otra semana", "el fin de semana",
    "el 15 de octubre", "el 3 de noviembre", "el 20 de diciembre", "el primero de enero",
    "el 5", "el 28", "esta noche", "esta tarde", "mañana en la mañana",
    "mañana por la tarde", "el lunes en la noche", "fin de mes", "a fin de mes",
    "dentro de una semana", "en dos días", "hoy en la noche", "el 14 de febrero",
]
TIMES = [
    "a las 8", "a las 8 de la mañana", "a las 3 de la tarde", "a las 7 de la noche",
    "a las 8 y media", "a las 10 menos cuarto", "a las 6 y cuarto", "al mediodía",
    "a la medianoche", "a las 9 pm", "a las 6 am", "a las 2", "a las 4:30",
    "a las ocho", "a las tres y media", "a eso de las 5", "como a las 11",
    "en 20 minutos", "en una hora", "en media hora", "en 10 minutos",
    "en una hora y media", "antes de las 5", "antes de las 8 de la noche",
    "temprano", "en la mañana", "en la tarde", "en la noche", "a primera hora",
]
REPS = [
    "todos los días", "todos los lunes", "cada lunes y miércoles", "cada 15 días",
    "de lunes a viernes", "el 5 de cada mes", "todas las noches", "cada semana",
    "todos los meses", "cada año", "cada 8 horas", "los fines de semana",
    "todos los martes y jueves", "diario",
]
PRIOS = ["urgente", "es urgente", "es importante", "importante", "sin prisa",
         "no es urgente", "con prioridad alta"]
ANTICS = [
    "avísame 15 minutos antes", "avísame media hora antes", "con una hora de anticipación",
    "recuérdamelo un día antes", "avísame 10 minutos antes", "con tiempo",
    "un rato antes",
]
COMMANDS = [
    "recuérdame", "recuérdame que tengo que", "recuérdame que debo", "acuérdame de",
    "avísame que tengo que", "no me dejes olvidar", "tengo que", "debo", "necesito",
    "hay que", "pon un recordatorio para", "agenda", "anota", "por favor recuérdame",
    "oye viernes recuérdame", "viernes recuérdame", "me recuerdas", "me puedes recordar",
    "créame un recordatorio para", "quiero que me recuerdes", "no se me puede olvidar",
    "", "", "",
]
QUERIES = [
    ("qué tengo", None), ("qué tengo para", None), ("qué hay", None),
    ("cuáles son mis pendientes", None), ("léeme la agenda de", None),
    ("tengo algo", None), ("qué me toca", None), ("dime mis recordatorios de", None),
    ("qué pendientes tengo", None), ("muéstrame la agenda de", None),
    ("cómo está mi día", None), ("qué tengo que hacer", None),
]
QUERY_DATES = ["hoy", "mañana", "esta semana", "el lunes", "el viernes",
               "pasado mañana", "el fin de semana", "esta tarde", "esta noche", ""]
CANCELS = [
    "cancela", "cancélalo", "olvídalo", "déjalo así", "nada", "no nada",
    "ya no quiero", "ya no lo necesito", "no necesito nada", "ya no hace falta",
    "no importa", "me equivoqué", "fue sin querer", "te llamé sin querer",
    "no te estaba hablando", "falsa alarma", "no era nada", "no gracias",
    "mejor no", "ahora no", "después te digo", "olvídalo gracias", "ya no",
    "perdón me equivoqué", "no era contigo", "para", "basta", "chao",
]
OTHERS = [
    "hola", "hola viernes", "cómo estás", "qué hora es", "cuéntame un chiste",
    "gracias", "muchas gracias", "pon música", "qué clima hace", "quién eres",
    "te quiero", "buenos días", "buenas noches", "estoy cansado", "qué haces",
    "abre whatsapp", "llama a emergencias", "cuánto es dos más dos",
    "estás ahí", "me escuchas", "jaja", "eh", "este", "no sé",
]


def _fill(template: str, rng: random.Random, pools: dict[str, list[str]]) -> str:
    return re.sub(r"\{(\w+)\}", lambda m: rng.choice(pools[m.group(1)]), template)


def _variant(text: str, rng: random.Random) -> str:
    """Variaciones de dictado: sin tildes, en minúsculas, números en letras."""
    r = rng.random()
    if r < 0.25:
        text = fold(text)
    elif r < 0.5:
        text = text.lower()
    return text


VERBS = [
    "llamar", "pagar", "comprar", "enviar", "mandar", "revisar", "entregar", "recoger",
    "llevar", "traer", "buscar", "lavar", "limpiar", "arreglar", "cocinar", "preparar",
    "estudiar", "leer", "escribir", "responder", "contestar", "confirmar", "cancelar",
    "renovar", "reservar", "agendar", "imprimir", "firmar", "escanear", "subir", "bajar",
    "descargar", "instalar", "actualizar", "cargar", "guardar", "sacar", "poner", "quitar",
    "cambiar", "devolver", "prestar", "vender", "regalar", "felicitar", "visitar",
    "acompañar", "esperar", "despertar", "bañar", "peinar", "alimentar", "regar", "podar",
    "barrer", "trapear", "planchar", "doblar", "empacar", "desempacar", "organizar",
    "ordenar", "botar", "reciclar", "medir", "pesar", "contar", "calcular", "transferir",
    "consignar", "retirar", "cobrar", "facturar", "cotizar", "negociar", "diseñar",
    "programar", "probar", "grabar", "editar", "publicar", "compartir", "invitar",
    "saludar", "practicar", "ensayar", "entrenar", "correr", "nadar", "caminar",
    "montar", "manejar", "parquear", "tanquear", "inflar", "desinfectar", "vacunar",
    "tomar", "tomarme", "aplicar", "recordar", "repasar", "terminar", "empezar",
    "comenzar", "abrir", "cerrar", "apagar", "prender", "encender", "conectar",
    "desconectar", "hornear", "descongelar", "servir", "pedir", "solicitar",
    "tramitar", "radicar", "matricular", "inscribir", "averiguar", "preguntar",
]
OBJECTS = [
    "el informe", "la factura", "el recibo", "los documentos", "la cédula", "el pasaporte",
    "la licencia", "el carro", "la moto", "la bicicleta", "las llantas", "el aceite",
    "la ropa", "las sábanas", "los platos", "la cocina", "el baño", "la nevera",
    "el horno", "la lavadora", "las matas", "el jardín", "el perro", "el gato",
    "los niños", "la niña", "el bebé", "la torta", "el almuerzo", "la comida",
    "el mercado", "las compras", "el regalo", "las flores", "las fotos", "el video",
    "la presentación", "el proyecto", "la tarea", "el examen", "el parcial", "la tesis",
    "el contrato", "la cotización", "la propuesta", "el correo", "el mensaje",
    "la llamada", "la cita", "la reunión", "la reserva", "los tiquetes", "el vuelo",
    "la maleta", "las medicinas", "la pastilla", "la vitamina", "la insulina",
    "las gafas", "el celular", "el computador", "la tablet", "el cargador",
    "la contraseña", "la aplicación", "la página web", "el servidor", "la base de datos",
    "el arriendo", "la cuota", "el préstamo", "la tarjeta", "los servicios",
    "la luz", "el agua", "el gas", "el internet", "la pensión", "el seguro",
    "el paquete", "el pedido", "el domicilio", "la caja", "las llaves", "la puerta",
    "la basura", "el reciclaje", "las cuentas", "el presupuesto", "los impuestos",
    "la declaración de renta", "el certificado", "la constancia", "la matrícula",
    "el uniforme", "los zapatos", "la camisa", "el vestido", "la chaqueta",
    "el libro", "la guitarra", "el piano", "la clase", "el curso", "el taller",
]
OBJECT_SUFFIXES = ["", "", "", " de {name}", " para {name}", " en {place}", " a {name}",
                   " con {name}", " del trabajo", " de la casa", " del colegio"]

# Palabras inventadas: reemplazan palabras de la tarea para que el modelo
# aprenda por el contexto y no memorice el vocabulario.
_SYLLABLES = ["ma", "lo", "te", "xi", "fo", "ru", "ne", "ca", "zu", "lei", "dy", "pra",
              "tor", "quin", "bel", "ga", "mon", "tri", "sa", "vo", "jen", "gui", "char"]
_VERB_ENDINGS = ["ar", "er", "ir", "arle", "arme", "earle"]


def _fake_word(rng: random.Random, verb: bool = False) -> str:
    word = "".join(rng.choice(_SYLLABLES) for _ in range(rng.randint(2, 3)))
    return word + rng.choice(_VERB_ENDINGS) if verb else word


def _task_text(rng: random.Random, pools, task_source) -> str:
    templates, verbs, objects = task_source
    if rng.random() < 0.45:
        return _fill(rng.choice(templates), rng, pools)
    obj = rng.choice(objects) + rng.choice(OBJECT_SUFFIXES)
    return _fill(f"{rng.choice(verbs)} {obj}", rng, pools)


def _dropout_task(text: str, rng: random.Random, rate: float) -> str:
    if rate <= 0:
        return text
    words = text.split()
    out = []
    for i, w in enumerate(words):
        if rng.random() < rate:
            out.append(_fake_word(rng, verb=(i == 0)))
        else:
            out.append(w)
    return " ".join(out)


def generate(n: int, seed: int, task_source, word_dropout: float = 0.0) -> list[Example]:
    rng = random.Random(seed)
    pools = {"name": NAMES, "place": PLACES, "item": ITEMS, "bill": BILLS}
    out: list[Example] = []
    while len(out) < n:
        r = rng.random()
        if r < 0.70:
            task = _dropout_task(_task_text(rng, pools, task_source), rng, word_dropout)
            out.append(_create(rng, task))
        elif r < 0.82:
            q, _ = rng.choice(QUERIES)
            d = rng.choice(QUERY_DATES)
            out.append(_segments_to_example(
                [(_variant(q, rng), "O"), (_variant(d, rng), "FECHA")], "consultar"))
        elif r < 0.92:
            out.append(_segments_to_example([(_variant(rng.choice(CANCELS), rng), "O")],
                                            "cancelar"))
        else:
            out.append(_segments_to_example([(_variant(rng.choice(OTHERS), rng), "O")],
                                            "otro"))
    return out


def _create(rng: random.Random, task: str) -> Example:
    cmd = rng.choice(COMMANDS)
    parts: dict[str, tuple[str, str]] = {"task": (task, "TAREA")}
    if rng.random() < 0.8:
        parts["date"] = (rng.choice(DATES), "FECHA")
    if rng.random() < 0.65:
        parts["time"] = (rng.choice(TIMES), "HORA")
    if rng.random() < 0.15:
        parts["rep"] = (rng.choice(REPS), "REP")
        if rng.random() < 0.6:
            parts.pop("date", None)
    if rng.random() < 0.1:
        parts["prio"] = (rng.choice(PRIOS), "PRIO")
    if rng.random() < 0.1:
        parts["antic"] = (rng.choice(ANTICS), "ANTIC")

    when = [k for k in ("date", "time", "rep") if k in parts]
    if rng.random() < 0.3:
        rng.shuffle(when)
    extras = [k for k in ("prio", "antic") if k in parts]
    order_choice = rng.random()
    if order_choice < 0.5:
        order = ["cmd", "task"] + when + extras
    elif order_choice < 0.8:
        order = when + ["cmd", "task"] + extras
    else:
        order = ["cmd"] + when + ["task"] + extras
    if extras and rng.random() < 0.3:
        order = extras + [k for k in order if k not in extras]

    segments = []
    for key in order:
        if key == "cmd":
            segments.append((cmd, "O"))
        else:
            segments.append(parts[key])
        if rng.random() < 0.12:
            segments.append((rng.choice(["por favor", "porfa", "eh", "pues"]), "O"))
    segments = [(_variant(t, rng), l) for t, l in segments]
    return _segments_to_example(segments, "crear")


def split_tasks(seed: int = 7, holdout: float = 0.2):
    """Separa plantillas, verbos y objetos para medir si generaliza a tareas
    que nunca vio."""
    rng = random.Random(seed)

    def split(items):
        items = items[:]
        rng.shuffle(items)
        k = int(len(items) * holdout)
        return items[k:], items[:k]

    t_train, t_test = split(TASK_TEMPLATES)
    v_train, v_test = split(sorted(set(VERBS)))
    o_train, o_test = split(OBJECTS)
    return (t_train, v_train, o_train), (t_test, v_test, o_test)


# ---------------------------------------------------------------------------
# Frases reales exportadas por la app (JSONL de "Exportar frases")
# ---------------------------------------------------------------------------


def load_real(paths: list[Path]) -> list[Example]:
    """Cada conversación aporta su primera frase con el título final marcado
    como TAREA. Las demás palabras quedan con peso 0 (no se sabe si eran
    fecha u hora), así el modelo aprende los títulos reales sin olvidar lo
    demás."""
    out = []
    for path in paths:
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            row = json.loads(line)
            utterances = row.get("utterances") or []
            final = row.get("final") or {}
            if not utterances or not final.get("title"):
                continue
            text = utterances[0]
            toks = tokenize(text)
            title_toks = [t for t, _, _ in tokenize(final["title"])]
            words = [t for t, _, _ in toks]
            start = _find_sublist(words, title_toks)
            if start < 0:
                continue
            tags, weights = [], []
            for i in range(len(words)):
                if start <= i < start + len(title_toks):
                    tags.append("B-TAREA" if i == start else "I-TAREA")
                    weights.append(1.0)
                else:
                    tags.append("O")
                    weights.append(0.0)
            out.append(Example(words, tags, "crear", weights, text))
    return out


def _find_sublist(words: list[str], sub: list[str]) -> int:
    if not sub:
        return -1
    for i in range(len(words) - len(sub) + 1):
        if words[i:i + len(sub)] == sub:
            return i
    return -1
