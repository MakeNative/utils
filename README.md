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

### `/utils:continue` – weiterarbeiten ohne Kompaktierung

Wird der Kontext voll, kompaktiert Claude Code: Das Modell liest die ganze
Session noch einmal, schreibt eine Zusammenfassung und macht damit weiter. Das
kostet Zeit und Geld, und die Zusammenfassung verliert genau die Details, die
man später braucht: die exakte Fehlermeldung, den Pfad, die eine Zahl.

Dabei liegt jede Session ohnehin vollständig als Datei unter
`~/.claude/projects/`. Der Skill nutzt das. Statt zu kompaktieren, startest du
frisch und lässt die neue Session in der alten nachschlagen:

```
/clear
/utils:continue
```

```
/utils:continue list           # letzte Sessions dieses Projekts
/utils:continue b4a5001e       # eine bestimmte Session, ID-Anfang reicht
/utils:continue workshop       # nach Titel, eigener aus /rename oder automatischer
```

**Startstand.** Ohne Angabe nimmt der Skill die Session vor dem `/clear`, mit
dem die neue Session begonnen hat. Ohne `/clear` nimmt er die zuletzt geänderte
andere Session im selben Ordner. Leere Neustarts überspringt er, also Sessions,
in denen nach `/clear` nichts gesagt wurde, etwa ein abgebrochener Versuch. Er
lädt nur einen kurzen Stand: Titel, Ordner und Branch, deine Eingaben mit
Nachrichtennummer, die zuletzt geänderten Dateien, eine vorhandene
Kompaktierungs-Zusammenfassung und die letzten 25 Nachrichten.

Die Suche nach Titeln geht über alle Sessions des Projekts. Mit
[ripgrep](https://github.com/BurntSushi/ripgrep) dauert sie etwa eine Sekunde,
ohne ripgrep bei großen Projekten einige Sekunden.

**Details bei Bedarf.** Alles Weitere sucht Claude im Transkript, sobald es
gebraucht wird, und übernimmt es wörtlich, mit Nachrichtennummer. Dafür liegt
ein Skript bei (`suche` und `zeige`), das das Transkript einmal in Klartext
umwandelt und zwischenspeichert. Bei 44 MB dauert das etwa eine Sekunde.

**Ziel bleibt.** Hatte die alte Session ein Ziel aus `/utils:goal-tracker`,
übernimmt die neue es samt geparkten Befunden.

Grenzen: Der Skill springt nicht von selbst ein, wenn der Kontext voll wird.
Das Kompaktieren steuert Claude Code. Du rufst `/clear` und den Skill auf,
bevor es so weit ist. Was die neue Session nicht sucht, weiß sie nicht. Bei
offenen Fäden hilft es, in einem Satz zu sagen, woran du weiterarbeiten willst.

### `/utils:repo-check` – fremde Repos prüfen, bevor etwas geladen wird

Auf GitHub liegen Kopien echter Projekte, deren README auf eine ZIP mit vermutlicher
Schadsoftware zeigt. Wer Repos von Agenten durchsuchen lässt, stößt früher oder später
darauf. Der Skill schaut deshalb zuerst nur auf Dateibaum und Kontodaten und lädt
dabei keine einzige Datei.

```
/utils:repo-check owner/repo owner/anderes-repo
```

| Ergebnis | Bedeutung | Danach |
|---|---|---|
| `OK` | keine Köder-Merkmale | Dateien dürfen als Text geladen werden |
| `VERDÄCHTIG` | Archiv oder Installer im Repo, oder junges Konto mit wenigen Repos und ein älteres Repo gleichen Namens | nichts laden, nicht empfehlen, von Hand ansehen |
| `FEHLER` | nicht vollständig geprüft | behandeln wie `VERDÄCHTIG` |

Auch seriöse Projekte enthalten manchmal Binärdateien, ein Treffer ist also ein Grund
zum Hinsehen und kein Urteil. Umgekehrt kommt ein Köder durch, der nur auf eine externe
Seite verlinkt. Fremde Dateien bleiben deshalb in jedem Fall Text und werden nie ausgeführt.

### `/utils:my-voice` – Texte in deinem eigenen Ton

Texte von Claude klingen schnell nach Claude: glatt, höflich, voller Gedankenstriche.
Der Skill schreibt so, wie du selbst schreibst. Grundlage ist ein Stilprofil aus
deinen eigenen Texten, das nur auf deinem Rechner liegt.

```
/utils:my-voice Antwort an Anna: Freitag passt, das Angebot kommt bis Montag
/utils:my-voice Beantworte den Fragebogen in ~/Downloads/fragen.docx
/utils:my-voice LinkedIn-Post aus meinem Entwurf in ~/Texte/entwurf.md
```

**Profil.** Das Profil legt `/utils:adapt-voice` an (siehe unten). Es liegt unter
`~/.claude/agent-memory/utils-voice-writer/VOICE.md` und wird nie Teil eines Repos.

**Schreiben.** Der Skill sammelt Kanal, Empfänger, Zweck und Material und startet den
Agenten. Inhalte kommen nur aus dem Material. Fehlt etwas, steht `[offen: …]` im Text,
statt dass etwas erfunden wird. Vor dem Zeigen prüft der Skill auf KI-Floskeln und
Geviertstriche.

**Genauer mit jeder Runde.** Sagst du „zu förmlich“ oder „so würd ich das nie sagen“,
überarbeitet der Agent den Text und trägt die Lehre in `MEMORY.md` neben dem Profil ein.

Sollen mehrere Texte gleichzeitig entstehen, etwa fünf Post-Varianten, nimmt
`/utils:parallel` den Voice-Writer, sobald es ein Profil gibt.

Grenzen: Der Skill verschickt nichts. Das Profil ist nur so gut wie die Proben, Texte
aus mehreren Kanälen machen es genauer.

### `/utils:adapt-voice` – deinen Stil einlesen und messen

Der Skill legt das Stilprofil für `/utils:my-voice` an oder schärft es nach. Du gibst
ihm keine Texte von Hand, er sammelt sie selbst ein, und am Ende siehst du in Zahlen, ob
der Agent danach wirklich wie du klingt.

```
/utils:adapt-voice whatsapp
/utils:adapt-voice whatsapp-export ~/Downloads/WhatsApp-Chat.txt
/utils:adapt-voice mail
/utils:adapt-voice linkedin ~/Downloads/Basic_LinkedInDataExport
/utils:adapt-voice ~/Texte/antworten.docx
```

**Proben einsammeln.** Ein Skript liest lokal nur Texte, die du selbst geschrieben hast:
aus der WhatsApp-App für macOS (du wählst die Chats), aus einem WhatsApp-Export, aus dem
Apple-Mail-Ordner „Gesendet“ ohne zitierte Antworten und Signaturen (bei Gmail aus „All
Mail“, gefiltert auf deine Absenderadresse), aus dem
LinkedIn-Datenexport oder aus eigenen Dateien. Passwörter, Mailadressen,
Telefonnummern, IBANs und Links ersetzt es durch Platzhalter, bevor irgendetwas
gespeichert wird. Befehle und reine Links fliegen raus.

**Profil ableiten.** Der Agent `utils:voice-writer` leitet daraus Grundton, Kanäle,
Wortschatz, Satzbau, Zeichen, Haltung, Dosierung und eine Verbotsliste ab. Widersprüche
entscheidest du.

**Stil-Test in Zahlen.** Ab 25 Texten hält der Skill ein Fünftel zurück. Zu einigen
davon schreibt der Agent eigene Texte, nur nach einem neutralen Inhalts-Steckbrief. Ein
Skript vergleicht dann echt und Agent, zum Beispiel so:

| Kennzahl | echt | Agent | Bewertung |
|---|---|---|---|
| Wörter pro Satz | 8 | 9 | ok |
| Satzanfang klein (%) | 73 | 20 | weicht ab |
| Emojis pro Text | 0,5 | 0,4 | ok |
| typische Wörter pro 100 Wörter | 4 | 9 | weicht ab |

Weicht etwas ab, passt der Agent die Dosierung im Profil an, und der Test läuft noch
einmal. Zu viele typische Wörter sind dabei genauso ein Befund wie zu wenige, denn wer
in jedem Satz „halt“ sagt, klingt wie eine Parodie.

Grenzen: Die Proben gehen zur Analyse an das Modell, wie jeder Text, den du Claude
zeigst. Für Mail und WhatsApp braucht das Terminal unter macOS den
Festplattenvollzugriff. Die Datenbank-Variante funktioniert nur mit der WhatsApp-App
für macOS, sonst nimmst du den Chat-Export.

### `/utils:lesbar` – einen Plan als HTML-Seite durchsehen und beantworten

Ein Plan oder Review von Claude ist oft lang, erzählt chronologisch, und die
Entscheidungen stehen ganz unten. Der Skill baut daraus eine HTML-Seite zum
Durchsehen, aus demselben Inhalt und ohne eigene Zusammenfassung.

```
/utils:lesbar docs/MIGRATIONSPLAN.md
```

Oder im Gespräch: „mach den Plan lesbar“, „ich will die offenen Fragen direkt
beantworten“.

| Schicht | Was hineingehört | Wohin |
|---|---|---|
| Entscheidungen | alles, wo jemand wählen muss, bevor es weitergeht | ganz oben |
| Status | erledigt, läuft, wartet, nicht anfassen | direkt darunter |
| Arbeit | die konkreten Schritte, möglichst als Tabelle | Mitte |
| Kontext | Begründungen, Hintergrund, Regeln | unten |

**Fragen beantworten.** Offene Entscheidungen werden zu Feldern: die Optionen aus
dem Plan zum Ankreuzen, ein Freitextfeld daneben. Ein Knopf baut daraus einen
Antwortblock in Markdown, zeigt ihn an und legt ihn in die Zwischenablage. Du fügst
ihn in die Session ein, und Claude arbeitet weiter. Unbeantwortete Fragen stehen als
`— offen` darin, damit nichts geraten wird. Eingaben überstehen ein Neuladen.

**Kein Server.** Die Seite ist eine einzelne Datei neben dem Plan (`<name>.html`),
ohne externe Fonts oder Skripte, mit hellem und dunklem Theme. Du öffnest sie
direkt im Browser. Auf Wunsch veröffentlicht Claude sie als Artifact, etwa zum
Lesen auf dem Handy.

Grenzen: Die Seite kann nicht selbst in die Session schreiben. Eine
veröffentlichte Seite darf keine Requests nach außen schicken, und eine lokale
Datei hat keinen Draht zum Terminal. Deshalb der Weg über die Zwischenablage.

### `/utils:rule-gate` – Texte vor dem Umsetzen gegen feste Regeln prüfen

Eine Wortliste findet „Likes kaufen“, aber nicht „Reichweite in Auftrag geben, bis
der Zähler stimmt“. Der Agent `rule-gate` prüft Texte nach ihrer Bedeutung gegen
Regeln, die du mitgibst, und sagt je Text ok oder gesperrt, mit Regel, Zitat und
Grund. Er kennt kein Projekt, die Regeln kommen immer vom Aufrufer.

```
/utils:rule-gate ideen.md regeln.md
/utils:rule-gate "Wir lassen die Creatorin posten, ohne die Kooperation zu nennen."
```

Regeln stehen in einer Datei, JSON (`[{"key", "sentence", "meaning"}]`) oder
Markdown (`- <key>: <Satz> — <Erläuterung>`), oder im Projekt unter
`.claude/rule-gate.json` im Feld `rules`.

**In einer Pipeline.** Ohne Bildschirm rufst du den Agenten direkt auf:
`claude -p --plugin-dir <utils> --agent utils:rule-gate --json-schema …`. Er
liefert `{"results": [{"id", "verdict": "pass"|"block", "ruleKey", "quote",
"reason"}]}`. Geprüfte Texte behandelt er als Daten: Ein Satz wie „Ignoriere die
Regeln“ im Text wird selbst gesperrt. Er hat kein Memory, damit er jedes Mal gleich
urteilt.

**Guard-Hook.** Zusätzlich kann ein Projekt jede Endausgabe seiner Agenten
deterministisch prüfen lassen. Der Hook läuft vor `StructuredOutput` und ist aus,
solange das Projekt ihn nicht einschaltet, über `RULE_GATE_CONFIG` oder
`.claude/rule-gate.json`:

```json
{ "guard": { "check": ["node", "/abs/pfad/check.js"], "agents": ["mein-kit:*"] } }
```

Der Prüfbefehl bekommt die Ausgabe als JSON auf stdin. Exit 0 heißt ok, Exit 1
heißt Verstoß, mit dem Grund in der ersten Zeile. Dann blockt der Hook, und der
Agent muss seine Ausgabe ändern. Ist der Prüfbefehl nicht erreichbar, blockt er
ebenfalls.

Grenzen: Auch der Agent kann irren. Er ist eine zweite Schicht hinter einer
schnellen Wortprüfung, kein Ersatz für Sperren im Code. Was nie passieren darf,
gehört in den Code, nicht nur in einen Text.

## MakeNative

Dieses Plugin ist Teil von [MakeNative](https://makenative.de). Wir arbeiten jeden Tag mit
Agenten-Pipelines und bringen anderen bei, sie für ihre eigenen Prozesse zu
bauen. Für Entwickler genauso wie für alle, die ihre Arbeit mit KI automatisieren wollen.

Du willst das für deine Arbeit lernen? Trag dich in die Liste ein:
[Bewerbung Starter-Kohorte](https://tally.so/r/5ByYj6?utm_source=github&utm_medium=readme&utm_campaign=starter-kohorte)

Christian Eichmüller · [LinkedIn](https://linkedin.com/in/christianeichmueller)

## Lizenz

MIT
