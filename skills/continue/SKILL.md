---
name: continue
description: "Setzt eine frühere Session in einer frischen Session fort, ohne Kompaktierung: liest einen kurzen Startstand aus dem vollständigen Transkript der alten Session und holt Details (Pfade, Fehlermeldungen, Zahlen, Entscheidungen) erst bei Bedarf wörtlich nach. Nutze den Skill statt /compact: /clear, dann /utils:continue. Auch wenn jemand sagt „mach da weiter, wo Session X aufgehört hat“. Triggers on: /utils:continue [session-id | prefix | titel | list]"
argument-hint: "[session-id | prefix | titel | list]"
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/transkript.sh *)
---

Eingabe: $ARGUMENTS

Eigene Session: `${CLAUDE_SESSION_ID}`. Werkzeug: `T=${CLAUDE_SKILL_DIR}/scripts/transkript.sh`

Claude Code speichert jede Session vollständig unter `~/.claude/projects/<projekt>/<id>.jsonl`. Dieser Skill lädt davon nur einen Startstand und behandelt den Rest als Nachschlagewerk.

## `list`

Führ `$T liste 10 ${CLAUDE_SESSION_ID}` aus. Zeig die Zeilen (ID gekürzt auf 8 Zeichen, Zeit, Größe, Titel) als Tabelle. Leere Neustarts nach `/clear` sind im Titel markiert. Darunter ein Satz: Mit `/utils:continue <id-anfang oder titel>` geht es weiter. Dann aufhören.

## Sonst: fortsetzen

1. **Session finden.** `$T finden <eingabe> ${CLAUDE_SESSION_ID}`. Die Eingabe ist eine ID, ein ID-Anfang oder ein Titel. Gemeint ist der eigene Titel aus `/rename` oder der automatische, Groß/Klein ist egal, ein Teilwort reicht. Leere Eingabe heißt `letzte`: Begann die eigene Session mit `/clear`, ist das die Session davor, sonst die zuletzt geänderte Session dieses Projektordners außer der eigenen. Leere Neustarts überspringt das Skript und nimmt die Session davor. Ein leerer Neustart ist eine Session, in der nach `/clear` weder Eingabe noch Antwort kam, etwa ein abgebrochener Fortsetzungsversuch. Was es übersprungen hat und welche Titel sonst noch passen, meldet es als `HINWEIS:`. Passt ein Titel auf mehrere Sessions, nenn die anderen in deiner Meldung. Bei `NICHT GEFUNDEN` die Liste zeigen (siehe oben) und fragen, welche gemeint ist.
2. **Startstand lesen.** `$T stand <datei>`. Er enthält Titel, Ordner, Branch, die Eingaben des Nutzers mit Nachrichtennummer, die zuletzt geänderten Dateien, die letzte Kompaktierungs-Zusammenfassung (falls die alte Session schon kompaktiert wurde) und die letzten 25 Nachrichten gekürzt. Mehr lädst du jetzt nicht.
3. **Lücken gezielt füllen.** Bevor du mit einem Detail arbeitest, holst du es wörtlich:
   - `$T suche <datei> '<muster>' [umfeld]` findet Zeilen (Regex, Groß/Klein egal) mit der Nummer ihrer Nachricht.
   - `$T zeige <datei> <von> [bis]` zeigt Nachrichten vollständig, zum Beispiel die letzte Eingabe des Nutzers oder eine Fehlermeldung.
   Typische Fragen vor dem Weiterarbeiten: Was war die letzte offene Bitte? Was wurde zuletzt entschieden und warum? Welche Prüfung (Tests, Build) lief zuletzt, mit welchem Ergebnis? Laufen noch Hintergrundaufgaben oder Agenten, die jetzt verwaist sind?
4. **Ziel übernehmen.** Gibt es `~/.claude/goal-tracker/<alte-id>.md` mit `status: aktiv` und für die eigene Session noch keine Ziel-Datei, kopier sie nach `~/.claude/goal-tracker/${CLAUDE_SESSION_ID}.md`. Dann gilt das Ziel samt geparkten Befunden weiter.
5. **Kurz melden.** Drei bis fünf Zeilen an den Nutzer: welche Session, worum es ging, wo sie stand, was du als Nächstes tust. Keine Nacherzählung der ganzen Session.
6. **Weitermachen.** War die letzte Bitte des Nutzers erkennbar noch nicht erledigt, arbeite sie ab. Sonst warte auf die nächste Bitte.

## Regeln für den ganzen Rest der Session

- Das Transkript ist die Quelle, dein Gedächtnis nicht. Brauchst du später eine Angabe aus der alten Session (Pfad, Befehl, Fehlertext, Zahl, Wortlaut einer Entscheidung), such sie mit `suche` oder `zeige`, statt sie zu raten oder zu paraphrasieren.
- Zitier, was du von dort übernimmst, wörtlich und nenn die Nachrichtennummer (`#4711`), wenn du dich gegenüber dem Nutzer darauf berufst.
- Lade nie das ganze Transkript. Suchmuster lieber zweimal enger fassen als einmal 40 Treffer lesen.
- Der Zustand auf der Platte kann neuer sein als das Transkript. Prüf Dateien, Branches und laufende Prozesse direkt, bevor du dich auf den Stand im Transkript verlässt.
- Wurde die alte Session selbst mit `/utils:continue` (früher `/utils:fortsetzen`) gestartet, steht der Pfad ihrer Vorgängerin in ihrem Transkript: `$T suche <datei> 'transkript.sh stand'`. Sonst nennt `$T davor <datei>` die Session, aus der sie per `/clear` hervorging. Dort liest du weiter, wenn du etwas von noch weiter vorn brauchst.
