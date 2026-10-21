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

#### Mit eigenen Beispielen (empfohlen)

Am besten erledigst du ein oder zwei Fälle selbst und gibst sie als Vorlage mit:

```
/utils:parallel Fass alle PDFs in ~/Belege/Oktober zusammen. Beispiele: ~/Belege/Oktober/zusammenfassungen/01.md und 02.md
```

Dann gilt:

- Jeder Agent liest deine Beispiele und übernimmt **Aufbau, Länge, Detailtiefe, Ton und
  Format**, aber **keine Inhalte, Formulierungen oder Zahlen** daraus.
- Fälle, die du schon erledigt hast, verteilt der Skill nicht noch einmal.
- Die eigene Probe entfällt, weil du das Ergebnis schon abgenommen hast.
- Die Ergebnisse landen neben deinen Beispielen, im gleichen Namensschema.
- Am Ende prüft der Skill stichprobenartig, ob ein Agent Inhalte aus den Beispielen
  abgeschrieben hat.

#### Weitere Regeln

Dazu die Regeln, die sich in Anthropics Doku und in der Praxis bewährt haben:

- **Alle in einer Nachricht.** Nur dann laufen die Agenten wirklich gleichzeitig.
- **Eine Datei pro Agent** unter `parallel/<name>/`. Kein Agent überschreibt den anderen.
- **Erst testen.** Ohne eigene Beispiele laufen ab 8 Agenten zuerst zwei als Probe.
  Ihr Ergebnis wird dann zur Vorlage für den Rest. So zahlst du einen Fehler im Prompt
  zweimal statt zwanzigmal.
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

### `/utils:goal-tracker` – eine Session bei ihrem Ziel halten

Nach einer Weile driftet Claude gern ab: Hier ein Bug, dort ein Aufräumen, und
das eigentliche Ziel rückt aus dem Blick. Mit fünf oder mehr offenen Terminals
fällt das oft erst spät auf. Der Skill gibt jeder Session ein festes Ziel, das
außerhalb des Gesprächs liegt und deshalb auch eine Kompaktierung übersteht.

```
/utils:goal-tracker Login-Tests in test/auth grün bekommen
/utils:goal-tracker list
/utils:goal-tracker done
/utils:goal-tracker statusline
```

**Ziel setzen.** Der Skill macht aus deiner Beschreibung einen messbaren
Endzustand, eine Prüfung, einen Scope und eine Liste dessen, was nicht
dazugehört. Nachfragen kommen nur, wenn sich etwas nicht ableiten lässt. Das
Ergebnis landet in `~/.claude/goal-tracker/<session-id>.md`. Dazu gibt er eine fertige
Zeile für das eingebaute `/goal` aus. Du fügst sie ein, und ab dann prüft ein
eigenes Modell nach jedem Turn, ob das Ziel erreicht ist und der Scope
eingehalten wurde.

**Nebenbefunde parken.** Was Claude außerhalb des Scopes findet, bearbeitet es
nicht, sondern notiert es als Zeile unter `## Geparkt` in der Ziel-Datei. Mit
`/utils:goal-tracker done` wird aus jedem geparkten Befund ein Startprompt für eine
eigene neue Session.

**Ziel bleibt im Kontext.** Zwei Hooks laufen automatisch, sobald das Plugin
installiert ist:

- Nach Start, Resume und Kompaktierung lädt ein `SessionStart`-Hook die
  Ziel-Datei frisch in den Kontext.
- Bei jedem Prompt hängt ein `UserPromptSubmit`-Hook eine Zeile mit Ziel und
  Scope an. Hat die Session noch keinen eigenen Namen, bekommt sie den Namen
  aus dem Ziel.

Sessions ohne Ziel-Datei bleiben unberührt.

**Alle Terminals im Blick.** `/utils:goal-tracker list` zeigt die Ziele aller offenen
Sessions in einer Tabelle, mit Projekt und Anzahl geparkter Befunde. Welche
davon gerade auf dich wartet, zeigt `claude agents`.
`/utils:goal-tracker statusline` trägt eine Statusline ein, die in jedem Terminal Name,
Ziel, geparkte Befunde und Kontextfüllung zeigt:

```
[auth-tests] ◎ Login-Tests grün | geparkt: 1 | ctx 42%
```

Eine vorhandene Statusline ersetzt der Skill nur nach Rückfrage. Nach einem
Plugin-Update führst du den Befehl einmal erneut aus.

Grenzen: Ein Skill kann `/goal` nicht selbst setzen, deshalb das Einfügen.
`/clear`, `/fork` und `/branch` starten eine neue Session-ID. Die neue Session
hat also erst wieder ein Ziel, wenn du eins setzt.

## MakeNative

Dieses Plugin ist Teil von [MakeNative](https://makenative.de). Wir arbeiten jeden Tag mit
Agenten-Pipelines und bringen anderen bei, sie für ihre eigenen Prozesse zu
bauen. Für Entwickler genauso wie für alle, die ihre Arbeit mit KI automatisieren wollen.

Du willst das für deine Arbeit lernen? Trag dich in die Liste ein:
[Bewerbung Starter-Kohorte](https://tally.so/r/5ByYj6?utm_source=github&utm_medium=readme&utm_campaign=starter-kohorte)

Christian Eichmüller · [LinkedIn](https://linkedin.com/in/christianeichmueller)

## Lizenz

MIT
