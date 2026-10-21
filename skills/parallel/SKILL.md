---
name: parallel
description: "Verteilt eine Aufgabe auf mehrere Agenten, die alle gleichzeitig laufen. Die Hauptsession entscheidet selbst, wie viele Agenten es werden und wer welches Stück bekommt. Fertige Beispiele des Nutzers dienen allen Agenten als Vorlage. Triggers on: /utils:parallel <Aufgabe>"
argument-hint: "<Aufgabe> [Beispiele: <Pfad> …]"
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

## 1a. Beispiele des Nutzers als Vorlage

Prüfe, ob der Nutzer fertige Beispiele nennt: Pfade nach „Beispiel(e):“, Sätze wie „orientier dich an X“ oder Dateien, die er im Gespräch als Muster gezeigt hat. Lies jedes Beispiel selbst, bevor du verteilst.

Gibt es Beispiele:
- **Sie sind die Vorlage für alle Agenten.** Jeder Agent-Prompt nennt die absoluten Pfade der Beispiele und sagt, was er davon übernimmt und was nicht (siehe Schritt 3).
- **Erledigtes fällt raus.** Elemente, für die ein Beispiel schon das Ergebnis ist, verteilst du nicht noch einmal. Sie zählen in der Zusammenfassung trotzdem mit.
- **Keine eigene Probe.** Der Nutzer hat die Beispiele abgenommen, deshalb entfällt 1b. Alle Agenten starten direkt.
- **Ablage nach dem Muster der Beispiele.** Liegen die Beispiele in einem Ordner mit erkennbarem Namensschema (z. B. `zusammenfassungen/01.md`), schreiben die Agenten in denselben Ordner nach demselben Schema. Sonst gilt Schritt 2.
- **Widerspricht ein Beispiel der Aufgabe** (anderes Format, andere Sprache als verlangt), frag einmal kurz nach, welches gilt.

## 1b. Ohne Beispiele: erst testen, dann alle starten (ab 8 Agenten)

Hat der Nutzer keine Beispiele genannt und sind es 8 oder mehr Agenten mit gleichem Prompt, startest du zuerst 2 als Probe. Prüfe deren Ergebnis: Passen Form, Ort und Qualität? Wenn ja, startest du die übrigen und gibst ihnen das gelungene Probeergebnis als Vorlage mit, wie in 1a beschrieben. Du startest sie gemeinsam in einer Nachricht. Wenn nein, korrigierst du den Prompt vorher. So zahlst du einen Fehler im Prompt nur zweimal statt zwanzigmal.

Sag dem Nutzer bei mehr als 10 Agenten in einem Satz, dass der Lauf spürbar Nutzungskontingent verbraucht. Läuft das Limit während des Laufs ab, brechen Hintergrund-Agenten ab. Diese Agenten führst du in der Zusammenfassung als offen auf.

## 2. Ablage anlegen

Sofern 1a keinen Ort vorgibt, legst du einen Ergebnisordner an: `parallel/<kurzer-name>/` im aktuellen Arbeitsverzeichnis (bzw. im Projektordner, wenn es um ein bestimmtes Projekt geht). Jeder Agent bekommt eine eigene Datei darin: `NN-<stichwort>.md`. Zwei Agenten schreiben nie in dieselbe Datei.

Ändern die Agenten Code im selben Git-Repo, starte sie mit `isolation: "worktree"`.

## 3. Alle Agenten in EINER Nachricht starten

Alle Agent-Aufrufe gehören in **eine einzige Antwort**. Ausnahme ist nur die Probe aus 1b, wenn es keine Beispiele gibt. Starte keinen davon später einzeln nach. Nur so laufen sie gleichzeitig.

Jeder Agent-Prompt ist eigenständig, denn der Agent kennt dieses Gespräch nicht. Er enthält:
- **Ziel:** was dieser Agent liefern soll, mit seinem konkreten Stück (Element, Teilthema, Variante).
- **Kontext:** Pfade, Vorgaben und Einschränkungen aus der Aufgabe, vollständig übernommen.
- **Vorlage** (wenn es Beispiele gibt): die absoluten Pfade der Beispiele und diese Regel, wörtlich: „Lies die Beispiele zuerst. Übernimm Aufbau, Länge, Detailtiefe, Ton und Dateiformat. Übernimm keine Inhalte, Formulierungen oder Zahlen daraus. Dein Inhalt kommt nur aus deinem eigenen Stück.“ Bei Varianten-Läufen ergänze: „Weiche inhaltlich bewusst vom Beispiel ab.“
- **Grenzen:** was er nicht tun soll, vor allem nicht die Stücke der anderen Agenten bearbeiten.
- **Ausgabe:** den absoluten Pfad seiner Ergebnisdatei und die gewünschte Form, bei allen Agenten gleich, damit sich die Ergebnisse zusammenführen lassen.
- **Rückmeldung:** eine kurze Antwort an dich (2–3 Sätze, Status und Pfad). Den Inhalt nicht wiederholen.

Wähle `subagent_type` passend zur Aufgabe. Passt kein Spezialagent, nimm `general-purpose`. Alle Agenten bekommen denselben Typ und dasselbe Modell, dann teilen sie sich den Prompt-Cache. Für einfache, mechanische Stücke (zusammenfassen, extrahieren, umformatieren) setzt du `model: "sonnet"` oder `"haiku"`. Das spart viel Kontingent. `description` nennt das Stück, z. B. „Kunde 07 Müller GmbH".

## 4. Warten und zusammenführen

Warte, bis alle Agenten fertig sind. Lies dann die Ergebnisdateien, nicht die Rückmeldungen. Gab es Beispiele, prüfe stichprobenartig, ob Ergebnisse Inhalte aus den Beispielen übernommen haben (gleiche Zahlen, Namen, Sätze). Solche Ergebnisse lässt du einmal mit Hinweis neu erstellen. Fasst die Ergebnisse in `parallel/<kurzer-name>/ZUSAMMENFASSUNG.md` zusammen.

Bei Vergleichs- oder Best-of-N-Läufen gilt: Lege gleiche Ergebnisse zusammen, benenne Widersprüche und empfiehl die beste Variante mit Begründung.

Ist ein Agent gescheitert oder hat er nichts geliefert, starte ihn einmal neu. Scheitert er wieder, führe ihn in der Zusammenfassung als offen auf. Erfinde keinen Ersatzinhalt.

## 5. Bericht

Antworte kurz:
- wie viele Agenten gelaufen sind, wie du aufgeteilt hast und ob Beispiele als Vorlage dienten (ein Satz)
- das Ergebnis in 3–5 Sätzen
- Pfad zur Zusammenfassung
- was offen oder gescheitert ist
