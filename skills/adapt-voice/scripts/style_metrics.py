#!/usr/bin/env python3
"""Stil-Test für /utils:adapt-voice: misst Form und Wortschatz von Texten.

Befehle:
  show DATEI
      Kennzahlen für eine Textsammlung.
  compare ECHT AGENT [--reference TRAIN]
      Vergleicht zurückgehaltene echte Texte mit Texten des Agenten. Mit
      --reference kommen die typischen Wörter aus den Trainingsproben.

Texte stehen je unter einer Kopfzeile „### …“. Ohne Kopfzeilen trennt eine
Zeile „---“ oder eine Leerzeile die Texte.
"""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

EMOJI = re.compile(r"[\U0001F300-\U0001FAFF☀-➿⭐❤]|(?<!\w)[:;]-?[)D(P](?!\w)")
PLACEHOLDER = re.compile(r"\[(?:mail|link|iban|telefon|geheim|offen[^\]]*)\]")
TOKEN = re.compile(r"[A-Za-zÄÖÜäöüß']+")
AI_TELLS = [
    "—", "ich hoffe, es geht", "ich hoffe, diese", "es ist wichtig zu beachten", "zusammenfassend",
    "in der heutigen zeit", "nahtlos", "ganzheitlich", "spannende reise", "gerne helfe ich",
    "bei fragen stehe ich", "i hope this", "it's important to note", "in today's", "seamless", "delve",
]
DE_STOP = set("""
aber alle als also am an auch auf aus bei bin bis bist da damit dann das dass dein deine dem den der des dich die dir
doch du durch ein eine einem einen einer es für hab habe haben hat hier ich ihr im in ist ja jetzt kann kannst mal man
mehr mein meine mich mir mit muss nach nicht noch nur ob oder schon sein sich sie sind so über um und uns unser vom von
vor war was wenn wer wie wir wird wo zu zum zur gerade gibt geht würde wurde werden kein keine sehr nichts etwas
""".split())
EN_STOP = set("""
a about after all also am an and any are as at be because been but by can could did do does dont for from get got had
has have he her him his how i if im in into is it its just me my no not now of on or our out so that thats the their them
then there they this to u up us was we were what when which who will with would you your
""".split())


def read_texts(path):
    raw = Path(path).expanduser().read_text(encoding="utf-8")
    if re.search(r"^### ", raw, re.M):
        parts = re.split(r"^### .*$", raw, flags=re.M)
    elif re.search(r"^---\s*$", raw, re.M):
        parts = re.split(r"^---\s*$", raw, flags=re.M)
    else:
        parts = re.split(r"\n\s*\n", raw)
    return [p.strip() for p in parts if p.strip()]


def first_letter_lower(text):
    text = PLACEHOLDER.sub(" ", text)
    for c in text:
        if c.isalpha():
            return c.islower()
    return None


def ends_without_period(text):
    t = PLACEHOLDER.sub(" ", EMOJI.sub(" ", text)).rstrip()
    return bool(t) and t[-1] not in ".!?"


def sentences(text):
    return [s for s in re.split(r"(?<=[.!?])\s+|\n+", PLACEHOLDER.sub(" ", text)) if TOKEN.search(s)]


def metrics(texts):
    n = len(texts)
    words = [len(TOKEN.findall(PLACEHOLDER.sub(" ", t))) for t in texts]
    sents = [len(sentences(t)) for t in texts]
    lower = [first_letter_lower(t) for t in texts]
    lower = [x for x in lower if x is not None]
    toks = [w.lower() for t in texts for w in TOKEN.findall(PLACEHOLDER.sub(" ", t))]
    de = sum(1 for w in toks if w in DE_STOP)
    en = sum(1 for w in toks if w in EN_STOP)
    joined = "\n".join(texts).lower()
    return {
        "Texte": n,
        "Wörter pro Text": sum(words) / max(n, 1),
        "Wörter pro Satz": sum(words) / max(sum(sents), 1),
        "Satzanfang klein (%)": 100 * sum(lower) / max(len(lower), 1),
        "ohne Schlusspunkt (%)": 100 * sum(ends_without_period(t) for t in texts) / max(n, 1),
        "Emojis pro Text": sum(len(EMOJI.findall(t)) for t in texts) / max(n, 1),
        "Ausrufezeichen pro Text": sum(t.count("!") for t in texts) / max(n, 1),
        "Englisch-Anteil (%)": 100 * en / max(de + en, 1),
        "KI-Verräter": sum(joined.count(p) for p in AI_TELLS),
        "_tokens": toks,
    }


def typical_words(texts, top=25):
    """Stilwörter: in vielen Texten benutzt und meist klein geschrieben, also keine Namen und kaum Inhaltswörter."""
    count, lower, docs = Counter(), Counter(), Counter()
    for t in texts:
        seen = set()
        for w in TOKEN.findall(PLACEHOLDER.sub(" ", t)):
            k = w.lower()
            if len(k) < 2 or k in DE_STOP or k in EN_STOP:
                continue
            count[k] += 1
            lower[k] += w == k
            seen.add(k)
        docs.update(seen)
    min_docs = 3 if len(texts) >= 30 else 2
    ranked = sorted((k for k in count if docs[k] >= min_docs and lower[k] / count[k] >= 0.5),
                    key=lambda k: (-docs[k], -count[k], k))
    return ranked[:top]


def density(words, texts):
    toks = [w.lower() for t in texts for w in TOKEN.findall(PLACEHOLDER.sub(" ", t))]
    wanted = set(words)
    hits = Counter(w for w in toks if w in wanted)
    return 100 * sum(hits.values()) / max(len(toks), 1), hits


ROWS = [
    ("Wörter pro Text", "rel", 0.35),
    ("Wörter pro Satz", "rel", 0.35),
    ("Satzanfang klein (%)", "abs", 15),
    ("ohne Schlusspunkt (%)", "abs", 15),
    ("Emojis pro Text", "abs", 0.3),
    ("Ausrufezeichen pro Text", "abs", 0.3),
    ("Englisch-Anteil (%)", "abs", 15),
]


def fmt(v):
    return f"{v:.0f}" if abs(v) >= 10 else f"{v:.2f}".rstrip("0").rstrip(".") if v else "0"


def cmd_show(args):
    texts = read_texts(args.file)
    m = metrics(texts)
    for k, v in m.items():
        if not k.startswith("_"):
            print(f"{k}: {fmt(v)}")
    print("typische Wörter:", ", ".join(typical_words(texts)))


def cmd_compare(args):
    real, gen = read_texts(args.real), read_texts(args.generated)
    if not real or not gen:
        sys.exit("Eine der Dateien enthält keine Texte.")
    mr, mg = metrics(real), metrics(gen)
    off = []
    print("| Kennzahl | echt | Agent | Bewertung |")
    print("|---|---|---|---|")
    print(f"| Texte | {mr['Texte']} | {mg['Texte']} | |")
    for key, kind, tol in ROWS:
        r, g = mr[key], mg[key]
        ok = abs(g - r) <= tol if kind == "abs" else (abs(g - r) <= tol * max(r, 1e-9))
        if not ok:
            off.append(key)
        print(f"| {key} | {fmt(r)} | {fmt(g)} | {'ok' if ok else 'weicht ab'} |")
    ref = read_texts(args.reference) if args.reference else real
    words = typical_words(ref)
    missing = []
    if words:
        d_real, h_real = density(words, real)
        d_gen, h_gen = density(words, gen)
        ok = abs(d_gen - d_real) <= 0.5 * max(d_real, 0.5)
        if not ok:
            off.append("typische Wörter")
        missing = [w for w, _ in h_real.most_common() if w not in h_gen]
        print(f"| typische Wörter pro 100 Wörter | {fmt(d_real)} | {fmt(d_gen)} | {'ok' if ok else 'weicht ab'} |")
    tells_ok = mg["KI-Verräter"] == 0
    if not tells_ok:
        off.append("KI-Verräter")
    print(f"| KI-Verräter (Floskeln, Geviertstrich) | {mr['KI-Verräter']} | {mg['KI-Verräter']} | {'ok' if tells_ok else 'weicht ab'} |")
    print()
    if words:
        print("typische Wörter:", ", ".join(words))
        if missing:
            print("in echten Texten benutzt, beim Agenten nicht:", ", ".join(missing[:15]))
    if min(len(real), len(gen)) < 5:
        print("HINWEIS: weniger als 5 Texte auf einer Seite, die Zahlen sind nur ein grober Anhalt.")
    if not off:
        verdict = "trägt: der Agent trifft deinen Stil in allen Kennzahlen"
    elif len(off) <= 2 and tells_ok:
        verdict = "fast: nachschärfen bei " + ", ".join(off)
    else:
        verdict = "nachschärfen: " + ", ".join(off)
    print("ERGEBNIS:", verdict)


def main():
    p = argparse.ArgumentParser(description="Stil-Test (utils:adapt-voice)")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("show")
    s.add_argument("file")
    s.set_defaults(fn=cmd_show)
    s = sub.add_parser("compare")
    s.add_argument("real")
    s.add_argument("generated")
    s.add_argument("--reference")
    s.set_defaults(fn=cmd_compare)
    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
