---
name: my-voice
description: "Schreibt Chat-Nachrichten, Mails, Antworten auf Fragen oder Fragebögen und Doc-Texte in deinem persönlichen Ton. Der Agent utils:voice-writer liest dein Stilprofil und schreibt den Text, ohne Fakten zu erfinden, eine Prüfung fängt KI-Floskeln ab, und deine Korrekturen landen im Memory, damit der Ton mit jeder Runde genauer wird. Ohne Profil legt der Skill es zuerst aus deinen eigenen Texten an. Nutze ihn, wenn jemand sagt „schreib das in meinem Ton“ oder „antworte so, wie ich schreiben würde“. Triggers on: /utils:my-voice <Auftrag> | learn <Stilproben>"
argument-hint: "<was geschrieben werden soll> | learn <Pfad oder Text>"
---

Eingabe: $ARGUMENTS

Profil: `~/.claude/agent-memory/utils-voice-writer/VOICE.md`. Korrekturen: `MEMORY.md` im selben Ordner. Agent: `utils:voice-writer`.

Du bist der Auftraggeber. Den Text schreibt der Agent. Du sammelst das Material, prüfst das Ergebnis und hältst Korrekturen fest.

## 1. Modus wählen

- Beginnt die Eingabe mit `learn`, mach mit Schritt 5 weiter.
- Sonst wird geschrieben. Fehlt `VOICE.md`, sag in einem Satz, dass es noch kein Profil gibt, und bitte um eigene Texte des Nutzers (Pfade, Chat-Export, eingefügter Text). Leg das Profil mit Schritt 5 an und kehr dann zu Schritt 2 zurück.

## 2. Auftrag sammeln

Der Agent kennt dieses Gespräch nicht. Sammle alles, was er braucht:

- **Kanal:** Chat (WhatsApp, Slack), Mail, Doc, LinkedIn …
- **Empfänger** und Beziehung (Teammitglied, Kundin, Partner) und ungefähre **Länge**
- **Sprache** nur, wenn der Nutzer sie ausdrücklich vorgibt. Im Chat gilt sonst die Sprache des Verlaufs, deshalb gehört die letzte Nachricht des Gegenübers ins Material.
- **Zweck:** was der Text erreichen soll
- **Material:** die Nachricht, auf die geantwortet wird, dazu Fakten, Entscheidungen, Links und Dateien. Alles, was im Text stehen soll, muss hier stehen. Dateien, die der Agent nicht lesen kann (.docx, .pdf), wandelst du vorher in Text um (`pandoc`, `textutil`) und legst sie neben das Log.

Frag nur nach, wenn Kanal, Empfänger oder Zweck sich nicht ableiten lassen, und dann mit einer einzigen Frage.

## 3. Log anlegen und Agent starten

Leg `~/.claude/agents-log/<JJJJ-MM-TT-HHMM>-my-voice.md` an. Darin steht unter `## Auftrag`: Modus `write`, Kanal, Empfänger, Länge, Zweck, die Sprache nur bei ausdrücklichem Wunsch des Nutzers, das Material (als Text oder absolute Pfade) und der Ausgabepfad. Bei Doc-Texten und Fragebögen ist das eine Datei, sonst „nur im Log“.

Starte `utils:voice-writer` mit dem Pfad zum Log und diesem Auftrag: „Lies `## Auftrag` in <Log>, schreib den Text, häng ihn unter `## Voice-Writer` an und antworte im Ergebnisformat deiner Anweisung.“ Warte auf `TEXT FERTIG`. Kommt `KEIN PROFIL`, geh zu Schritt 5.

## 4. Prüfen, zeigen, lernen

Prüf das Ergebnis, bevor du es zeigst, und schreib das Ergebnis unter `## Prüfung` ins Log:

- kein Geviertstrich „—“ und kein Treffer aus der Verbotsliste in `VOICE.md`
- jede Zahl, jeder Name und jede Zusage steht im Material
- die `FRAGLICH`-Punkte des Agenten sind im Text als `[offen: …]` markiert oder unter dem Text aufgeführt

Bei einem Befund startest du den Agenten einmal neu und gibst ihm den Befund mit. Danach zeigst du den Text: kurze Texte direkt im Chat, lange als Pfad, die `FRAGLICH`-Punkte darunter.

Korrigiert der Nutzer den Ton („zu förmlich“, „so würd ich das nie sagen“) oder schreibt er einen Satz selbst um, ergänzt du `## Auftrag` um die Korrektur und startest den Agenten erneut. Er überarbeitet den Text und trägt die Lehre in `MEMORY.md` ein. Eine inhaltliche Korrektur (falscher Fakt) ist keine Stil-Lehre: Die korrigierst du im Material.

Verschick nichts selbst. Abschicken tut der Nutzer.

## 5. Profil anlegen oder ergänzen (`learn`)

1. Stilproben sammeln: Pfade oder eingefügter Text aus der Eingabe. Nur Texte, die der Nutzer selbst geschrieben hat. Bei Chatverläufen filterst du vorher auf seine eigenen Nachrichten. Binärformate wandelst du in Text um und legst ihn neben das Log.
2. Leg das Log an mit `## Auftrag`: Modus `learn` und die absoluten Pfade der Proben.
3. Starte `utils:voice-writer` mit dem Pfad zum Log und warte auf `PROFIL FERTIG`.
4. Zeig dem Nutzer `NEU`, `WIDERSPRUCH` und `GEFILTERT` aus dem Ergebnis. Widersprüche entscheidet der Nutzer, nicht der Agent.

## 6. Bericht

Antworte kurz:

- der Text oder sein Pfad
- die `FRAGLICH`-Punkte
- ob eine Lehre ins Memory ging
- im Modus `learn`: Pfad zum Profil und die wichtigsten neuen Regeln
