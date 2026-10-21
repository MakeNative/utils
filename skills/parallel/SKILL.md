---
name: parallel
description: "Verteilt eine Aufgabe auf mehrere Agenten, die alle gleichzeitig laufen. Die Hauptsession entscheidet selbst, wie viele Agenten es werden und wer welches Stück bekommt. Triggers on: /utils:parallel <Aufgabe>"
argument-hint: "<Aufgabe>"
disable-model-invocation: true
---

Du bist der Verteiler. Du zerlegst die Aufgabe, startest alle Agenten **gleichzeitig** und fasst am Ende zusammen. Die eigentliche Arbeit machst du nicht selbst.

Aufgabe: $ARGUMENTS

## 1. Aufteilen

Entscheide selbst, wie viele Agenten die Aufgabe braucht. Frag nicht nach der Anzahl.

- **Feste Liste** (Dateien, Kunden, Kapitel, URLs, Belege …): ein Agent pro Element. Ermittle die Liste vorher selbst (ls, glob, lesen). Bei mehr als 20 Elementen bündelst du sie, sodass es höchstens 20 Agenten werden.
- **Eine Frage aus mehreren Blickwinkeln** (Recherche, Analyse, Review): ein Agent pro Teilthema oder Perspektive, typischerweise 3–6. Die Teilthemen dürfen sich nicht überschneiden.
- **Dieselbe Aufgabe mehrfach, um die Ergebnisse zu vergleichen** (Varianten, Entwürfe, Best-of-N): 3–5 Agenten. Bitte jeden ausdrücklich um einen eigenen Ansatz, sonst liefern alle fast dasselbe.
- **Nennt die Aufgabe eine Zahl** („20-mal", „für alle 12 Kunden"), gilt diese Zahl.
- **Lässt sich nichts sinnvoll aufteilen,** sag das in einem Satz und erledige die Aufgabe ohne Verteilung.

Frag nur nach, wenn die Aufgabe selbst unklar ist, nicht wegen der Aufteilung.

Grenzen:
- **Höchstens 20 Agenten gleichzeitig.** Claude Code lässt standardmäßig nicht mehr zu (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`). Der 21. Start scheitert, statt zu warten. Bei mehr Elementen bündeln.
- **Lohnt sich nicht bei** kleinen Aufgaben, eng verzahnten Schritten oder Arbeit, die denselben Kontext braucht. Dann ist ein einzelner Agent besser und billiger.
- **Eine Codeänderung über viele Dateien im selben Repo** (Umbenennen, Migration) übernimmt das eingebaute `/batch` besser. Schlag es vor, statt hier selbst zu verteilen.

## 1b. Erst testen, dann alle starten (ab 8 Agenten)

Ab 8 Agenten mit gleichem Prompt startest du zuerst 2 als Probe. Prüfe deren Ergebnis: Passen Form, Ort und Qualität? Wenn ja, startest du die übrigen gemeinsam in einer Nachricht. Wenn nein, korrigierst du den Prompt vorher. So zahlst du einen Fehler im Prompt nur zweimal statt zwanzigmal.

Sag dem Nutzer bei mehr als 10 Agenten in einem Satz, dass der Lauf spürbar Nutzungskontingent verbraucht. Läuft das Limit während des Laufs ab, brechen Hintergrund-Agenten ab. Diese Agenten führst du in der Zusammenfassung als offen auf.

## 2. Ablage anlegen

Lege einen Ergebnisordner an: `parallel/<kurzer-name>/` im aktuellen Arbeitsverzeichnis (bzw. im Projektordner, wenn es um ein bestimmtes Projekt geht). Jeder Agent bekommt eine eigene Datei darin: `NN-<stichwort>.md`. Zwei Agenten schreiben nie in dieselbe Datei.

Ändern die Agenten Code im selben Git-Repo, starte sie mit `isolation: "worktree"`.

## 3. Alle Agenten in EINER Nachricht starten

Alle Agent-Aufrufe gehören in **eine einzige Antwort**. Ausnahme ist nur die Probe aus 1b. Starte keinen davon später einzeln nach. Nur so laufen sie gleichzeitig.

Jeder Agent-Prompt ist eigenständig, denn der Agent kennt dieses Gespräch nicht. Er enthält:
- **Ziel:** was dieser Agent liefern soll, mit seinem konkreten Stück (Element, Teilthema, Variante).
- **Kontext:** Pfade, Vorgaben und Einschränkungen aus der Aufgabe, vollständig übernommen.
- **Grenzen:** was er nicht tun soll, vor allem nicht die Stücke der anderen Agenten bearbeiten.
- **Ausgabe:** den absoluten Pfad seiner Ergebnisdatei und die gewünschte Form, bei allen Agenten gleich, damit sich die Ergebnisse zusammenführen lassen.
- **Rückmeldung:** eine kurze Antwort an dich (2–3 Sätze, Status und Pfad). Den Inhalt nicht wiederholen.

Wähle `subagent_type` passend zur Aufgabe. Passt kein Spezialagent, nimm `general-purpose`. Alle Agenten bekommen denselben Typ und dasselbe Modell, dann teilen sie sich den Prompt-Cache. Für einfache, mechanische Stücke (zusammenfassen, extrahieren, umformatieren) setzt du `model: "sonnet"` oder `"haiku"`. Das spart viel Kontingent. `description` nennt das Stück, z. B. „Kunde 07 Müller GmbH".

## 4. Warten und zusammenführen

Warte, bis alle Agenten fertig sind. Lies dann die Ergebnisdateien, nicht die Rückmeldungen. Fasst die Ergebnisse in `parallel/<kurzer-name>/ZUSAMMENFASSUNG.md` zusammen.

Bei Vergleichs- oder Best-of-N-Läufen gilt: Lege gleiche Ergebnisse zusammen, benenne Widersprüche und empfiehl die beste Variante mit Begründung.

Ist ein Agent gescheitert oder hat er nichts geliefert, starte ihn einmal neu. Scheitert er wieder, führe ihn in der Zusammenfassung als offen auf. Erfinde keinen Ersatzinhalt.

## 5. Bericht

Antworte kurz:
- wie viele Agenten gelaufen sind und wie du aufgeteilt hast (ein Satz)
- das Ergebnis in 3–5 Sätzen
- Pfad zur Zusammenfassung
- was offen oder gescheitert ist
