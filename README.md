# utils

Kleine Helfer für den Alltag mit Claude Code, als Plugin gebündelt.

## Installation

```
/plugin marketplace add MakeNative/utils
/plugin install utils@utils
```

## Skills

### `/utils:parallel` – eine Aufgabe auf mehrere Agenten verteilen

Claude Code kann bis zu 20 Agenten gleichzeitig laufen lassen. Allerdings nur,
wenn die Hauptsession alle in **einer** Antwort startet. Ohne ausdrückliche
Anweisung arbeitet Claude die Aufgabe oft trotzdem nacheinander ab. Der Skill
legt das Vorgehen fest.

```
/utils:parallel Fass jedes PDF in ~/Belege/Oktober zusammen
/utils:parallel Recherchiere Förderprogramme für KI-Weiterbildung 2026
/utils:parallel Schreib Headline-Varianten für unsere Landingpage
```

Die Anzahl gibst du nicht vor. Die Hauptsession wählt sie nach der Art der
Aufgabe:

| Aufgabe | Aufteilung |
|---|---|
| Feste Liste (Dateien, Kunden, Kapitel) | ein Agent pro Element, höchstens 20, sonst gebündelt |
| Recherche oder Analyse | ein Agent pro Teilthema, meist 3–6 |
| Varianten zum Vergleichen | 3–5 Agenten, jeder mit eigenem Ansatz |
| Zahl in der Aufgabe („20-mal“) | genau diese Zahl |
| Nicht sinnvoll teilbar | kein Fan-out, ein Agent erledigt es |

Dazu die Regeln, die sich in Anthropics Doku und in der Praxis bewährt haben:

- **Alle in einer Nachricht.** Nur dann laufen die Agenten wirklich gleichzeitig.
- **Eine Datei pro Agent** unter `parallel/<name>/`. Kein Agent überschreibt den anderen.
- **Erst testen.** Ab 8 Agenten laufen zuerst zwei als Probe. So zahlst du einen
  Fehler im Prompt zweimal statt zwanzigmal.
- **Eigenständige Prompts.** Jeder Agent bekommt Ziel, Kontext, Grenzen und das
  Ausgabeformat, denn er kennt das Gespräch nicht.
- **Gleiches Modell für alle.** Dann teilen sich die Agenten den Prompt-Cache.
  Einfache Stücke laufen auf einem günstigeren Modell.
- **Worktrees bei Code.** Ändern die Agenten Code im selben Repo, arbeitet jeder in seinem eigenen Worktree.
- **Zusammenführen aus den Dateien.** Am Ende entsteht eine `ZUSAMMENFASSUNG.md`.
  Gescheiterte Agenten werden einmal neu gestartet, danach als offen aufgeführt.
- **Hinweis auf den Verbrauch.** Parallele Agenten verbrauchen das Kontingent
  entsprechend schneller. Ab mehr als 10 Agenten weist der Skill darauf hin.

Für eine Codeänderung über viele Dateien (Umbenennen, Migration) ist das
eingebaute `/batch` von Claude Code besser. Der Skill schlägt es dann vor.

## MakeNative

Dieses Plugin ist Teil von [MakeNative](https://makenative.de). Wir arbeiten jeden Tag mit
Agenten-Pipelines und bringen anderen bei, sie für ihre eigenen Prozesse zu
bauen. Für Entwickler genauso wie für alle, die ihre Arbeit mit KI automatisieren wollen.

Du willst das für deine Arbeit lernen? Trag dich in die Liste ein:
[Bewerbung Starter-Kohorte](https://tally.so/r/5ByYj6?utm_source=github&utm_medium=readme&utm_campaign=starter-kohorte)

Christian Eichmüller · [LinkedIn](https://linkedin.com/in/christianeichmueller)

## Lizenz

MIT
