---
name: adapt-voice
description: "Legt dein Stilprofil für /utils:my-voice an oder schärft es nach. Sammelt deine eigenen Texte lokal ein (WhatsApp-App für macOS, WhatsApp-Export, Apple Mail „Gesendet“, LinkedIn-Datenexport, eigene Dateien), entfernt Passwörter, Mailadressen, Telefonnummern und Links, lässt den Agenten utils:voice-writer daraus das Profil ableiten und prüft mit einem Stil-Test in Zahlen, ob der Agent danach wirklich wie du klingt. Nutze den Skill, wenn jemand sagt „lern meinen Stil“ oder „hier sind Texte von mir“. Triggers on: /utils:adapt-voice [whatsapp | whatsapp-export <datei> | mail | linkedin <ordner> | <pfad> …]"
argument-hint: "[whatsapp | whatsapp-export <datei> | mail | linkedin <ordner> | <pfad> …]"
allowed-tools: Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/collect.py *), Bash(python3 -I ${CLAUDE_SKILL_DIR}/scripts/style_metrics.py *)
---

Eingabe: $ARGUMENTS

Werkzeuge: `C=${CLAUDE_SKILL_DIR}/scripts/collect.py` (Proben sammeln, aufteilen) und `M=${CLAUDE_SKILL_DIR}/scripts/style_metrics.py` (Stil-Test). Aufruf immer mit `python3 -I`.

Profil: `~/.claude/agent-memory/utils-voice-writer/VOICE.md`, daneben `MEMORY.md` und der Ordner `samples/` für die Proben. Laufordner: `~/.claude/agents-log/<JJJJ-MM-TT-HHMM>-adapt-voice/` mit dem Log `log.md`.

Du sammelst die Proben und misst. Das Profil schreibt der Agent `utils:voice-writer` im Modus `learn`.

## 1. Quellen klären

Nennt die Eingabe keine Quelle, frag einmal, welche Quellen genommen werden sollen. Zur Auswahl stehen WhatsApp (App für macOS), WhatsApp-Export (.txt), Apple Mail „Gesendet“, LinkedIn-Datenexport sowie eigene Dateien oder eingefügter Text. Mehrere Quellen sind gut, denn jeder Kanal hat seinen eigenen Ton.

Sag vor dem ersten Lesen in zwei Sätzen, was passiert: Das Skript liest lokal nur die Texte, die der Nutzer selbst geschrieben hat, und ersetzt Passwörter, Mailadressen, Telefonnummern und Links durch Platzhalter. Danach gehen die Proben zur Analyse an das Modell, wie jeder andere Text, den man Claude zeigt.

## 2. Proben sammeln

Alles landet in `<lauf>/proben.txt`. Ab der zweiten Quelle hängst du mit `--append` an.

- **WhatsApp (App für macOS):** `python3 -I $C whatsapp-chats` zeigt die Chats mit der Zahl eigener Nachrichten. Zeig die Tabelle und frag, welche Chats rein sollen. Am besten sind Chats mit verschiedenen Leuten, privat und beruflich, wenn er beide Töne will. Dann `python3 -I $C whatsapp --chats <id,id> --out <lauf>/proben.txt`.
- **WhatsApp-Export:** `python3 -I $C whatsapp-export <datei> --senders` zeigt die Namen. Frag, welcher davon der Nutzer ist, dann `--me "<Name>" --out …`.
- **Mail:** `python3 -I $C mail --max 100 --out …`. Bei Gmail liegen gesendete Mails nur in „All Mail“, dann frag nach der eigenen Absenderadresse und ruf es mit `--from <adresse>` auf (mehrere kommagetrennt). Meldet das Skript fehlenden Zugriff, gib den Hinweis aus der Meldung weiter und biete die anderen Quellen an.
- **LinkedIn:** Der Export kommt aus LinkedIn unter Einstellungen → Datenschutz → Kopie deiner Daten und muss entpackt sein. `python3 -I $C linkedin <ordner> --out …`, mit `--me "<Vorname Nachname>"` kommen auch eigene Direktnachrichten dazu.
- **Dateien oder Text:** .docx und .pdf wandelst du vorher in .txt um (`pandoc`, `textutil`). Eingefügten Text speicherst du als Datei im Laufordner. Dann `python3 -I $C files <pfade> --out …`, mit `--per-file`, wenn jede Datei ein einzelner Text ist.

Lies danach die Ausgabe des Skripts (Anzahl Texte, Wörter, Ersetzungen). Unter etwa 30 Texten oder 1.500 Wörtern sagst du, dass das Profil grob wird, und fragst nach einer weiteren Quelle.

Geh die Proben kurz durch. Nimm Texte heraus, die der Nutzer nicht selbst formuliert hat, zum Beispiel weitergeleitete Anleitungen, eingefügte KI-Texte oder Zitate. Steht noch ein Passwort oder eine Zugangsangabe drin, die das Skript übersehen hat, ersetz sie durch `[geheim]`.

## 3. Aufteilen

`python3 -I $C split <lauf>/proben.txt` legt `proben.train.txt` und, ab 25 Texten, `proben.holdout.txt` an. Die zurückgehaltenen Texte sieht der Agent nicht, an ihnen misst der Stil-Test. Bei weniger als 25 Texten entfällt der Test, das sagst du dem Nutzer.

## 4. Profil ableiten

1. Kopier `proben.train.txt` nach `~/.claude/agent-memory/utils-voice-writer/samples/<JJJJ-MM-TT>-<quelle>.txt`. So stehen die Proben für spätere Läufe bereit.
2. Leg `<lauf>/log.md` an. Unter `## Auftrag` steht Modus `learn`, der absolute Pfad der Proben und der Hinweis: „Je Text gibt es eine Kopfzeile `### Quelle · Kontext · Datum`. Platzhalter wie `[link]` oder `[geheim]` sind entfernte Daten, keine Stilmerkmale.“
3. Starte `utils:voice-writer` mit: „Lies `## Auftrag` in <log>, leite das Profil ab, häng dein Ergebnis unter `## Voice-Writer` an und antworte im Ergebnisformat deiner Anweisung.“ Warte auf `PROFIL FERTIG`.
4. Zeig `NEU`, `WIDERSPRUCH` und `GEFILTERT`. Widersprüche entscheidet der Nutzer. Seine Entscheidung trägst du in `VOICE.md` ein.

## 5. Stil-Test

Nur, wenn es `proben.holdout.txt` gibt.

1. Schreib für bis zu 8 der zurückgehaltenen Texte je einen Inhalts-Steckbrief in `<lauf>/test-auftrag.md`: Kanal, Empfänger, Sprache des Verlaufs und den Inhalt in eigenen, neutralen Worten. Übernimm keine Formulierung aus dem echten Text, sonst misst der Test nur das Abschreiben.
2. Ergänze `log.md` um einen zweiten Auftrag: Modus `write`, „Schreib zu jedem Steckbrief in <lauf>/test-auftrag.md einen eigenen Text, jeden unter einer Zeile `### Text <n>`, in die Datei <lauf>/test-agent.txt.“ Starte `utils:voice-writer` damit und warte auf `TEXT FERTIG`.
3. Leg die echten Texte zu genau diesen Steckbriefen als `<lauf>/test-echt.txt` ab und miss: `python3 -I $M compare <lauf>/test-echt.txt <lauf>/test-agent.txt --reference <lauf>/proben.train.txt`.
4. Zeig die Tabelle und das Ergebnis.
   - `trägt`: fertig.
   - `fast` oder `nachschärfen`: Starte den Agenten noch einmal im Modus `learn` und gib ihm die Tabelle mit. Er passt die Dosierung in `VOICE.md` an, zum Beispiel wie oft er klein anfängt oder Emojis setzt. Danach testest du ein zweites Mal. Mehr als zwei Runden machst du nicht. Weicht es dann immer noch ab, nennst du die Kennzahlen und fragst den Nutzer, ob ihm das wichtig ist.

Trägt der Test, frag, ob die zurückgehaltenen Texte jetzt auch ins Profil sollen. Wenn ja, läuft ein letzter `learn`-Lauf mit `proben.holdout.txt`.

## 6. Bericht

Antworte kurz:

- Quellen und Zahl der Texte, was ersetzt oder herausgenommen wurde
- Pfad zum Profil und die wichtigsten Regeln daraus
- die Tabelle des Stil-Tests mit Ergebnis, oder warum er entfiel
- Hinweis: Geschrieben wird mit `/utils:my-voice`
