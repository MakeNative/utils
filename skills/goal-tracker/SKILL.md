---
name: goal-tracker
description: "Legt das Ziel einer Session fest und hält sie daran: Ziel-Datei mit Endzustand, Prüfung und Scope, fertige /goal-Zeile, Nebenbefunde werden geparkt statt erledigt. Hooks laden das Ziel nach Kompaktierung und Resume neu. `list` zeigt die Ziele aller offenen Sessions. Triggers on: /utils:goal-tracker <Ziel> | list | done | statusline"
argument-hint: "<Ziel> | list | done | statusline"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/goal-tracker.sh *)
---

Eingabe: $ARGUMENTS

Ziel-Datei dieser Session: `~/.claude/goal-tracker/${CLAUDE_SESSION_ID}.md`

Lies die Eingabe und mach genau einen der folgenden Fälle.

## Leer: aktuelles Ziel zeigen

Gibt es die Ziel-Datei mit `status: aktiv`, zeig Ziel, Fertig-wenn, Scope und die geparkten Befunde in wenigen Zeilen. Sonst sag in einem Satz, dass kein Ziel gesetzt ist und wie man eins setzt (`/utils:goal-tracker <Ziel>`).

## `list`: alle Sessions im Überblick

Führ `${CLAUDE_SKILL_DIR}/scripts/goal-tracker.sh list` aus. Jede Zeile ist tab-getrennt: Name, Ziel, Anzahl geparkt, Projekt, gesetzt am. Zeig das als Tabelle. Kürz Projektpfade auf den letzten Ordner. Darunter ein Satz: Ob eine Session gerade auf Eingabe wartet, zeigt `claude agents`.

## `done`: Ziel abschließen

1. Setz in der Ziel-Datei `status: aktiv` auf `status: erreicht`.
2. Gibt es geparkte Befunde, mach aus jedem einen Startprompt für eine eigene neue Session: ein Codeblock je Befund mit `claude -n <kurzer-name>` und darunter der Prompt in einem Satz, inklusive der Datei oder Stelle aus dem Befund. Sonst ein Satz, dass nichts geparkt war.
3. Erinnere in einem Satz daran, ein noch aktives `/goal` mit `/goal clear` zu beenden.

## `statusline`: Statusline einrichten

Führ `${CLAUDE_SKILL_DIR}/scripts/goal-tracker.sh install-statusline` aus.
- `OK: …` → sag, dass die Statusline ab dem nächsten Prompt Name, Ziel, Anzahl geparkt und Kontextfüllung zeigt, in allen Sessions.
- `VORHANDEN: …` (Exit 3) → zeig die vorhandene Statusline und frag, ob sie ersetzt werden soll. Nur bei Ja: dasselbe Kommando mit `--ersetzen` am Ende.
- Nach einem Plugin-Update muss der Befehl einmal erneut laufen, weil die Statusline eine Kopie des Skripts nutzt.

## Sonst: Ziel festlegen

Die Eingabe beschreibt das Ziel. Ist für diese Session schon ein Ziel aktiv, zeig es und frag einmal, ob das neue es ersetzt.

### 1. Ziel ausarbeiten

Leite aus der Eingabe, dem bisherigen Gespräch und dem Projekt diese Felder ab. Schau dafür kurz ins Projekt (Testbefehl, Ordnerstruktur, Branch), damit Prüfung und Scope konkret werden:

- **Titel:** das Ziel in höchstens 60 Zeichen.
- **Name:** 1–3 Wörter in kebab-case, wird zum Session-Namen (`auth-tests`, `angebot-meso`).
- **Fertig, wenn:** ein messbarer Endzustand. Ein Testergebnis, ein Exit-Code, eine Datei mit bestimmtem Inhalt, eine leere Liste. Nicht „ist verbessert“.
- **Prüfung:** wie Claude den Endzustand im Gespräch belegt, z. B. „`npm test -- test/auth` endet mit 0“ oder „Datei X enthält Abschnitte A, B, C“.
- **Scope:** die Pfade oder Gegenstände, die geändert werden dürfen.
- **Nicht dazu:** was naheliegt, aber ausdrücklich nicht in diese Session gehört.

Frag nur, was sich nicht ableiten lässt, in **einer** Rückfrage mit höchstens drei Punkten. Meist fehlt nur der messbare Endzustand. Alles andere schlägst du selbst vor.

### 2. Ziel-Datei schreiben

Schreib `~/.claude/goal-tracker/${CLAUDE_SESSION_ID}.md` genau in diesem Aufbau. Die Hooks und die Statusline lesen die Zeilen `name:`, `status:`, `# Ziel:`, `**Scope:**` und den Abschnitt `## Geparkt`, deshalb diese Schreibweise beibehalten:

```markdown
---
session: ${CLAUDE_SESSION_ID}
name: <name>
projekt: <absoluter Projektpfad>
gesetzt: <JJJJ-MM-TT HH:MM>
status: aktiv
---
# Ziel: <Titel>

**Fertig, wenn:** <Endzustand>
**Prüfung:** <Prüfung>
**Scope:** <Scope>
**Nicht dazu:** <Nicht dazu>

## Geparkt
```

### 3. /goal-Zeile ausgeben

Das eingebaute `/goal` prüft nach jedem Turn mit einem eigenen Modell, ob das Ziel erreicht ist, und lässt Claude bis dahin weiterarbeiten. Ein Skill kann es nicht selbst setzen, deshalb gibst du die Zeile zum Einfügen aus, in einem einzigen Codeblock, höchstens 4.000 Zeichen:

```
/goal <Fertig, wenn>. Beleg: <Prüfung>, Ausgabe sichtbar im Verlauf. Scope: am Ende zeigt `git diff --stat` nur Änderungen in <Scope>; Befunde außerhalb stehen unter „## Geparkt“ in ~/.claude/goal-tracker/${CLAUDE_SESSION_ID}.md statt bearbeitet zu sein. Oder stopp nach 30 Turns.
```

Ist das Projekt kein Git-Repo, ersetze `git diff --stat` durch „eine Liste aller geänderten Dateien“.

### 4. Antwort

Kurz:
- Titel und Fertig-wenn (je eine Zeile)
- der Codeblock mit der `/goal`-Zeile und der Hinweis „einfügen und abschicken, dann läuft die Session los“
- ein Satz: der Session-Name wird beim nächsten Prompt gesetzt, falls die Session noch keinen eigenen hat

## Regel für die ganze Session

Stößt du bei der Arbeit auf etwas außerhalb des Scopes (Bug, Aufräumbedarf, Idee, fehlende Doku), bearbeitest du es nicht. Du hängst eine Zeile unter `## Geparkt` an: `- <Datei oder Stelle>: <Befund> – <warum relevant>`. Dann arbeitest du am Ziel weiter. Will der Nutzer etwas Geparktes doch sofort, tut er das ausdrücklich.
