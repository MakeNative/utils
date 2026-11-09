#!/usr/bin/env python3
"""Sammelt eigene Texte des Nutzers als Stilproben für /utils:adapt-voice.

Befehle:
  whatsapp-chats [--limit N]
      Chats der WhatsApp-App für macOS mit der Anzahl eigener Textnachrichten.
  whatsapp --chats ID[,ID…] --out DATEI [--since JJJJ-MM-TT] [--max N] [--append]
      Eigene Textnachrichten aus diesen Chats.
  whatsapp-export DATEI --senders
  whatsapp-export DATEI --me NAME --out DATEI [--append]
      Exportierter Chat („Chat exportieren“, ohne Medien), nur Nachrichten von NAME.
  mail --out DATEI [--max N] [--from ADRESSE[,ADRESSE]] [--append]
      Apple Mail, Ordner „Gesendet“, ohne zitierte Antworten und Signaturen. Mit
      --from auch „All Mail“, gefiltert auf die eigene Adresse (nötig bei Gmail).
  linkedin ORDNER --out DATEI [--me NAME] [--append]
      Entpackter LinkedIn-Datenexport: Beiträge, Kommentare, mit --me auch Nachrichten.
  files PFAD [PFAD …] --out DATEI [--per-file] [--append]
      .txt- oder .md-Dateien, ein Text je Absatz oder mit --per-file je Datei.
  split DATEI [--holdout 0.2] [--min 5] [--seed 1]
      Teilt die Proben in DATEI.train.txt und DATEI.holdout.txt für den Stil-Test.

Alles läuft lokal. Vor dem Schreiben ersetzt das Skript Mailadressen, Links,
Telefonnummern, IBANs und passwortartige Zeichenketten durch Platzhalter.
Jeder Text steht in der Ausgabe unter einer Kopfzeile „### Quelle · Kontext · Datum“.
"""

import argparse
import csv
import email
import email.policy
import email.utils
import random
import re
import shutil
import sqlite3
import sys
import tempfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

APPLE_EPOCH = 978307200
WA_DIR = Path.home() / "Library/Group Containers/group.net.whatsapp.WhatsApp.shared"

EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")
URL = re.compile(r"(?:https?://|www\.)\S+", re.I)
IBAN = re.compile(r"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,4})?\b")
PHONE = re.compile(r"(?<![\w.])\+?\d[\d \-/()]{7,}\d(?![\w.])")
DATE_LIKE = re.compile(r"^\d{4}-\d{2}-\d{2}$|^\d{1,2}\.\d{1,2}\.\d{2,4}$")
SECRET_CONTEXT = re.compile(r"\b(passw(?:ort|ord)|pw|kennwort|token|api[- ]?key|secret|pin)\b(\s*[:=]?\s*)(\S+)", re.I)
COMMAND = re.compile(r"^\s*(curl|wget|echo|git|npm|npx|cd|ls|sudo|brew|python3?|source|export|ssh|scp|claude)\b|^\s*/\w+\s*$|\|\s*(ba|z)?sh\b")
WORD = re.compile(r"[A-Za-zÄÖÜäöüß]{2,}")

WA_SKIP = re.compile(
    r"Medien ausgeschlossen|Media omitted|omitted>|weggelassen|<Anhang:|<attached:|"
    r"Nachricht wurde gelöscht|message was deleted|Ende-zu-Ende-verschlüsselt|end-to-end encrypted",
    re.I,
)


def fail(msg, code=1):
    print(msg, file=sys.stderr)
    sys.exit(code)


def looks_secret(token):
    t = token.strip(".,;:!?()[]{}\"'„“‚‘-/")
    if len(t) < 8 or not any(c.isdigit() for c in t):
        return False
    classes = sum((
        any(c.islower() for c in t),
        any(c.isupper() for c in t),
        any(not c.isalnum() for c in t),
    ))
    return classes >= 2


class Redactor:
    def __init__(self):
        self.counts = Counter()

    def _sub(self, pattern, label, text):
        text, n = pattern.subn(label, text)
        self.counts[label] += n
        return text

    def __call__(self, text):
        text = SECRET_CONTEXT.sub(self._secret_after_keyword, text)
        text = self._sub(EMAIL, "[mail]", text)
        text = self._sub(URL, "[link]", text)
        text = self._sub(IBAN, "[iban]", text)
        text = PHONE.sub(lambda m: m.group(0) if DATE_LIKE.match(m.group(0).strip()) or
                         sum(c.isdigit() for c in m.group(0)) < 9 else self._count("[telefon]", "[telefon]"), text)
        parts = re.split(r"(\s+)", text)
        for i, part in enumerate(parts):
            if part and not part.isspace() and looks_secret(part):
                parts[i] = "[geheim]"
                self.counts["[geheim]"] += 1
        return "".join(parts)

    def _secret_after_keyword(self, m):
        if any(c in m.group(2) for c in ":=") or looks_secret(m.group(3)):
            return self._count("[geheim]", m.group(1) + m.group(2) + "[geheim]")
        return m.group(0)

    def _count(self, label, value):
        self.counts[label] += 1
        return value


def usable(text):
    if COMMAND.search(text):
        return False
    plain = re.sub(r"\[(mail|link|iban|telefon|geheim)\]", " ", text)
    return len(WORD.findall(plain)) >= 2


def write_blocks(out, blocks, append, redactor, skipped=0):
    out = Path(out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    kept, words = 0, 0
    with open(out, "a" if append else "w", encoding="utf-8") as fh:
        for header, text in blocks:
            text = redactor(text.strip())
            if not usable(text):
                skipped += 1
                continue
            fh.write(f"### {header}\n{text}\n\n")
            kept += 1
            words += len(text.split())
    repl = ", ".join(f"{k} {v}" for k, v in sorted(redactor.counts.items()) if v) or "nichts"
    print(f"{kept} Texte, {words} Wörter → {out}")
    print(f"ersetzt: {repl}; übersprungen (Befehle, nur Links, zu kurz): {skipped}")


def read_blocks(path):
    raw = Path(path).expanduser().read_text(encoding="utf-8")
    blocks, header, lines = [], None, []
    for line in raw.splitlines():
        if line.startswith("### "):
            if header is not None and "\n".join(lines).strip():
                blocks.append((header, "\n".join(lines).strip()))
            header, lines = line[4:].strip(), []
        else:
            lines.append(line)
    if header is not None and "\n".join(lines).strip():
        blocks.append((header, "\n".join(lines).strip()))
    return blocks


def apple_date(value):
    if value is None:
        return ""
    return datetime.fromtimestamp(value + APPLE_EPOCH).strftime("%Y-%m-%d %H:%M")


def wa_snapshot():
    src = WA_DIR / "ChatStorage.sqlite"
    if not src.exists():
        fail("Keine WhatsApp-Datenbank gefunden. Das geht nur mit der WhatsApp-App für macOS. "
             "Alternative: Chat in WhatsApp exportieren und whatsapp-export nutzen.", 2)
    tmp = Path(tempfile.mkdtemp(prefix="adapt-voice-wa-"))
    try:
        for suffix in ("", "-wal", "-shm"):
            f = WA_DIR / f"ChatStorage.sqlite{suffix}"
            if f.exists():
                shutil.copy2(f, tmp / f.name)
    except PermissionError:
        shutil.rmtree(tmp, ignore_errors=True)
        fail("Kein Zugriff auf die WhatsApp-Daten. Das Terminal braucht unter Systemeinstellungen → "
             "Datenschutz & Sicherheit → Festplattenvollzugriff die Freigabe.", 2)
    return sqlite3.connect(tmp / "ChatStorage.sqlite"), tmp


def cmd_whatsapp_chats(args):
    con, tmp = wa_snapshot()
    try:
        rows = con.execute(
            """SELECT s.Z_PK, COALESCE(s.ZPARTNERNAME, '?'), s.ZSESSIONTYPE,
                      SUM(CASE WHEN m.ZISFROMME = 1 AND m.ZMESSAGETYPE IN (0, 7) AND m.ZTEXT IS NOT NULL THEN 1 ELSE 0 END),
                      MAX(m.ZMESSAGEDATE)
               FROM ZWACHATSESSION s JOIN ZWAMESSAGE m ON m.ZCHATSESSION = s.Z_PK
               GROUP BY s.Z_PK ORDER BY 4 DESC LIMIT ?""",
            (args.limit,),
        ).fetchall()
    finally:
        con.close()
        shutil.rmtree(tmp, ignore_errors=True)
    print("id\tchat\tart\teigene Nachrichten\tzuletzt")
    for pk, name, kind, own, last in rows:
        print(f"{pk}\t{name}\t{'Gruppe' if kind == 1 else 'Einzel'}\t{own}\t{apple_date(last)[:10]}")


def cmd_whatsapp(args):
    ids = [int(x) for x in args.chats.split(",") if x.strip()]
    since = None
    if args.since:
        since = datetime.strptime(args.since, "%Y-%m-%d").timestamp() - APPLE_EPOCH
    con, tmp = wa_snapshot()
    try:
        query = f"""SELECT m.ZTEXT, m.ZMESSAGEDATE, m.ZCHATSESSION FROM ZWAMESSAGE m
                    WHERE m.ZISFROMME = 1 AND m.ZMESSAGETYPE IN (0, 7) AND m.ZTEXT IS NOT NULL
                    AND m.ZCHATSESSION IN ({",".join("?" * len(ids))})
                    {"AND m.ZMESSAGEDATE >= ?" if since is not None else ""}
                    ORDER BY m.ZMESSAGEDATE DESC LIMIT ?"""
        params = ids + ([since] if since is not None else []) + [args.max]
        rows = con.execute(query, params).fetchall()
    finally:
        con.close()
        shutil.rmtree(tmp, ignore_errors=True)
    label = {pk: f"Chat {i + 1}" for i, pk in enumerate(ids)}
    blocks = [(f"WhatsApp · {label[chat]} · {apple_date(ts)}", text) for text, ts, chat in reversed(rows)]
    write_blocks(args.out, blocks, args.append, Redactor())


EXPORT_LINE = re.compile(
    r"^‎?\[?(\d{1,2}[./]\d{1,2}[./]\d{2,4}),?\s+(\d{1,2}:\d{2}(?::\d{2})?)(?:\s*[AaPp]\.?[Mm]\.?)?\]?\s*(?:-\s*)?"
    r"([^:\n]{1,60}):\s?(.*)$"
)


def parse_export(path):
    messages = []
    for line in Path(path).expanduser().read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.replace("‎", "").replace(" ", " ")
        m = EXPORT_LINE.match(line)
        if m:
            messages.append([m.group(3).strip(), f"{m.group(1)} {m.group(2)}", m.group(4)])
        elif messages:
            messages[-1][2] += "\n" + line
    return messages


def cmd_whatsapp_export(args):
    messages = parse_export(args.file)
    if not messages:
        fail("Keine Nachrichten erkannt. Ist das ein WhatsApp-Export als .txt?", 2)
    if args.senders:
        for name, n in Counter(m[0] for m in messages).most_common():
            print(f"{n}\t{name}")
        return
    if not args.me or not args.out:
        fail("Bitte --me NAME und --out DATEI angeben, oder zuerst --senders.")
    own = [m for m in messages if m[0] == args.me and not WA_SKIP.search(m[2])]
    if not own:
        fail(f"Keine Nachrichten von „{args.me}“. Mit --senders siehst du die Namen im Export.", 2)
    blocks = [(f"WhatsApp-Export · {stamp}", text) for _, stamp, text in own]
    write_blocks(args.out, blocks, args.append, Redactor())


SENT_MAILBOX = re.compile(
    r"^(sent messages|sent mail|sent items|sent|gesendet|gesendete objekte|gesendete elemente|gesendete nachrichten)\.mbox$",
    re.I,
)
QUOTE_START = re.compile(
    r"^\s*(?:am|on)\s.{3,200}?(?:schrieb|wrote)[^\n]*:\s*$|^-{2,}\s*(?:original|ursprüngliche)|^\s*(?:von|from):\s.+$|^>",
    re.I | re.M,
)


def mail_body(msg):
    part = msg.get_body(preferencelist=("plain", "html"))
    if part is None:
        return ""
    text = part.get_content()
    if part.get_content_type() == "text/html":
        text = re.sub(r"(?is)<(script|style).*?</\1>", " ", text)
        text = re.sub(r"(?i)<br\s*/?>|</p>|</div>", "\n", text)
        text = re.sub(r"<[^>]+>", " ", text)
    m = QUOTE_START.search(text)
    if m and m.start() > 0:
        text = text[: m.start()]
    text = re.split(r"\n--\s*\n", text)[0]
    return re.sub(r"\n{3,}", "\n\n", text).strip()


ALL_MAILBOX = re.compile(r"^(all mail|alle nachrichten)\.mbox$", re.I)


def cmd_mail(args):
    root = Path.home() / "Library/Mail"
    senders = [a.strip().lower() for a in (args.sender or "").split(",") if a.strip()]
    files = []
    try:
        for mbox in root.glob("V*/**/*.mbox"):
            if SENT_MAILBOX.match(mbox.name) or (senders and ALL_MAILBOX.match(mbox.name)):
                files += list(mbox.rglob("*.emlx"))
    except PermissionError:
        fail("Kein Zugriff auf ~/Library/Mail. Das Terminal braucht unter Systemeinstellungen → "
             "Datenschutz & Sicherheit → Festplattenvollzugriff die Freigabe. Alternative: ein paar gesendete "
             "Mails als Text speichern und files nutzen.", 2)
    if not files:
        fail("Keine gesendeten Mails in Apple Mail gefunden. Bei Gmail liegen sie nur in „All Mail“: "
             "dann mit --from <deine Adresse> erneut aufrufen.", 2)
    files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
    blocks, skipped, seen = [], 0, set()
    for f in files:
        if len(blocks) >= args.max:
            break
        try:
            data = f.read_bytes()
            first, rest = data.split(b"\n", 1)
            raw = rest[: int(first.strip())]
            if senders:
                head = email.message_from_bytes(raw.split(b"\r\n\r\n", 1)[0].split(b"\n\n", 1)[0],
                                                policy=email.policy.default)
                if not any(s in str(head.get("From", "")).lower() for s in senders):
                    continue
                mid = str(head.get("Message-ID", f.name))
                if mid in seen:
                    continue
                seen.add(mid)
            msg = email.message_from_bytes(raw, policy=email.policy.default)
            body = mail_body(msg)
        except (ValueError, LookupError, PermissionError, UnicodeError):
            skipped += 1
            continue
        if body:
            date = msg.get("Date", "")
            try:
                date = email.utils.parsedate_to_datetime(date).strftime("%Y-%m-%d %H:%M")
            except (TypeError, ValueError, IndexError):
                pass
            blocks.append((f"Mail · {date}", body))
    write_blocks(args.out, blocks, args.append, Redactor(), skipped)


def read_linkedin_csv(path, wanted):
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    start = next((i for i, l in enumerate(lines) if any(w.lower() in l.lower() for w in wanted)), None)
    if start is None:
        return []
    return list(csv.DictReader(lines[start:]))


def column(row, *names):
    lower = {k.lower().strip(): v for k, v in row.items() if k}
    for n in names:
        if n.lower() in lower:
            return lower[n.lower()] or ""
    return ""


def cmd_linkedin(args):
    folder = Path(args.folder).expanduser()
    if not folder.is_dir():
        fail(f"{folder} ist kein Ordner. Bitte den LinkedIn-Export vorher entpacken.", 2)
    blocks = []
    for f in folder.rglob("*.csv"):
        name = f.name.lower()
        if name == "shares.csv":
            for row in read_linkedin_csv(f, ["ShareCommentary"]):
                blocks.append((f"LinkedIn-Beitrag · {column(row, 'Date')}", column(row, "ShareCommentary")))
        elif name == "comments.csv":
            for row in read_linkedin_csv(f, ["Message"]):
                blocks.append((f"LinkedIn-Kommentar · {column(row, 'Date')}", column(row, "Message")))
        elif name == "messages.csv" and args.me:
            for row in read_linkedin_csv(f, ["CONTENT"]):
                if column(row, "FROM").strip() == args.me:
                    blocks.append((f"LinkedIn-Nachricht · {column(row, 'DATE')}", column(row, "CONTENT")))
    if not blocks:
        fail("Keine Beiträge, Kommentare oder Nachrichten gefunden (Shares.csv, Comments.csv, messages.csv).", 2)
    write_blocks(args.out, [(h, re.sub(r"<[^>]+>", " ", t)) for h, t in blocks if t.strip()], args.append, Redactor())


def cmd_files(args):
    blocks = []
    for p in args.paths:
        path = Path(p).expanduser()
        if path.suffix.lower() not in (".txt", ".md"):
            fail(f"{path.name}: bitte vorher in .txt umwandeln (pandoc oder textutil).", 2)
        text = path.read_text(encoding="utf-8", errors="replace")
        if args.per_file:
            blocks.append((f"Datei · {path.name}", text))
        else:
            for i, part in enumerate(re.split(r"\n\s*\n", text)):
                if part.strip():
                    blocks.append((f"Datei · {path.name} · Absatz {i + 1}", part))
    write_blocks(args.out, blocks, args.append, Redactor())


def cmd_split(args):
    path = Path(args.file).expanduser()
    blocks = read_blocks(path)
    n = len(blocks)
    train_path = path.with_name(path.stem + ".train.txt")
    hold_path = path.with_name(path.stem + ".holdout.txt")
    if n < 25:
        train_path.write_text("".join(f"### {h}\n{t}\n\n" for h, t in blocks), encoding="utf-8")
        print(f"Nur {n} Texte, zu wenige für einen Stil-Test (ab 25). Alle {n} → {train_path}")
        return
    k = max(args.min, round(n * args.holdout))
    order = list(range(n))
    random.Random(args.seed).shuffle(order)
    hold = sorted(order[:k])
    train = sorted(order[k:])
    train_path.write_text("".join(f"### {blocks[i][0]}\n{blocks[i][1]}\n\n" for i in train), encoding="utf-8")
    hold_path.write_text("".join(f"### {blocks[i][0]}\n{blocks[i][1]}\n\n" for i in hold), encoding="utf-8")
    print(f"{len(train)} Texte fürs Profil → {train_path}")
    print(f"{len(hold)} Texte zurückgehalten für den Stil-Test → {hold_path}")


def main():
    p = argparse.ArgumentParser(description="Stilproben sammeln (utils:adapt-voice)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("whatsapp-chats")
    s.add_argument("--limit", type=int, default=20)
    s.set_defaults(fn=cmd_whatsapp_chats)

    s = sub.add_parser("whatsapp")
    s.add_argument("--chats", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--since")
    s.add_argument("--max", type=int, default=300)
    s.add_argument("--append", action="store_true")
    s.set_defaults(fn=cmd_whatsapp)

    s = sub.add_parser("whatsapp-export")
    s.add_argument("file")
    s.add_argument("--senders", action="store_true")
    s.add_argument("--me")
    s.add_argument("--out")
    s.add_argument("--append", action="store_true")
    s.set_defaults(fn=cmd_whatsapp_export)

    s = sub.add_parser("mail")
    s.add_argument("--out", required=True)
    s.add_argument("--max", type=int, default=100)
    s.add_argument("--from", dest="sender", help="eigene Absenderadresse(n), kommagetrennt; nötig bei Gmail")
    s.add_argument("--append", action="store_true")
    s.set_defaults(fn=cmd_mail)

    s = sub.add_parser("linkedin")
    s.add_argument("folder")
    s.add_argument("--out", required=True)
    s.add_argument("--me")
    s.add_argument("--append", action="store_true")
    s.set_defaults(fn=cmd_linkedin)

    s = sub.add_parser("files")
    s.add_argument("paths", nargs="+")
    s.add_argument("--out", required=True)
    s.add_argument("--per-file", action="store_true")
    s.add_argument("--append", action="store_true")
    s.set_defaults(fn=cmd_files)

    s = sub.add_parser("split")
    s.add_argument("file")
    s.add_argument("--holdout", type=float, default=0.2)
    s.add_argument("--min", type=int, default=5)
    s.add_argument("--seed", type=int, default=1)
    s.set_defaults(fn=cmd_split)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
