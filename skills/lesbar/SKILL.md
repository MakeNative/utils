---
name: lesbar
description: Macht ein langes Markdown-Dokument (Plan, Analyse, Review, Konzept, Protokoll) als HTML-Seite schnell erfassbar — Entscheidungen zuerst, Status sichtbar, Details gefiltert. Offene Fragen werden dabei beantwortbar: Felder in der Seite, ein Klick legt den Antwortblock in die Zwischenablage, Einfügen in die Session startet die Umsetzung. Nutze diesen Skill, wenn jemand sagt „mach das lesbar", „bereite das als HTML auf", „ich will das schnell verstehen", „visualisiere den Plan", „ich will die offenen Fragen direkt beantworten" oder um einen bestehenden Arbeitsplan zum Durchsehen aufzubereiten. Nicht für neue Inhalte — der Skill bereitet auf, was schon geschrieben ist. Triggers on: /utils:lesbar <datei.md>
argument-hint: "<datei.md>"
---

Eingabe: $ARGUMENTS


# lesbar — Dokument zum Durchsehen aufbereiten

Ein Arbeitsdokument wird zweimal gelesen: einmal gründlich beim Schreiben,
danach nur noch im Scan-Modus. Dieser Skill baut die Fassung für den zweiten
Fall.

## Was der Skill NICHT tut

Keine neuen Inhalte erfinden, keine Aussagen abschwächen, nichts weglassen, was
eine Entscheidung oder ein Risiko ist. Die HTML-Fassung ist eine Ansicht des
Dokuments, keine Zusammenfassung mit eigener Meinung. Wenn beim Aufbereiten
auffällt, dass im Quelldokument etwas fehlt oder sich widerspricht: in der
Antwort sagen, nicht still korrigieren.

## Ablauf

1. **Quelle lesen.** Vollständig, nicht nur die Überschriften.
2. **Vier Schichten trennen** (das ist die eigentliche Arbeit):
   - **Entscheidungen** — alles, wo jemand wählen muss, bevor es weitergeht.
     Inklusive der Frage, was blockiert ist, solange die Entscheidung fehlt.
   - **Status** — was ist erledigt, was läuft, was wartet.
   - **Arbeit** — die konkreten Schritte oder Positionen, möglichst als Tabelle.
   - **Kontext** — Begründungen, Hintergrund, Regeln. Gehört nach unten.
3. **Reihenfolge umdrehen, wenn nötig.** Quelldokumente erzählen meist
   chronologisch. Die Ansicht beginnt mit dem, was der Leser *tun* muss:
   Entscheidungen oben, Kontext unten. Nummerierung der Quelle beibehalten,
   damit beide Fassungen vergleichbar bleiben.
4. **HTML schreiben** nach den Bauregeln unten, als Datei neben der Quelle
   (`<name>.html`).
5. **Rückkanal einbauen**, sobald das Dokument offene Entscheidungen oder
   Fragen enthält — siehe „Rückkanal" unten. Die Entscheidungsschicht ist dann
   nicht nur oben, sie ist beantwortbar.
6. **Veröffentlichen anbieten.** Mit dem Artifact-Tool, wenn der Nutzer die
   Seite teilen oder vom Handy lesen will. Vorher `artifact-design` laden.

## Bauregeln

**Oben steht, was zu tun ist.** Die erste Bildschirmseite zeigt offene
Entscheidungen und den Status — nie eine Einleitung. Wer scrollt, will Details;
wer nicht scrollt, hat das Wichtigste gesehen.

**Status gehört in die Form, nicht nur in den Text.** Erledigt, offen,
blockiert, nicht anfassen — jeweils als erkennbares Element (Chip, Randstreifen,
Farbe). Semantische Farben sind vom Akzent getrennt.

**Tabellen bleiben Tabellen.** Datei-Listen, Deltas, Positionen: nicht in
Fließtext auflösen. Jede Tabelle bekommt einen eigenen
`overflow-x: auto`-Container, damit die Seite nie seitlich scrollt. Dateinamen
und Codes in Monospace.

**Kein Dekor, das nichts bedeutet.** Keine Emoji als Abschnittsmarker, keine
Nummerierung, die keine Reihenfolge ist, keine Icons für Stimmung. Wenn ein
Abschnitt eine Nummer trägt, muss die Nummer etwas heißen.

**Zitate bleiben wörtlich.** Sätze, an denen eine Entscheidung hängt (eine
Zusage, eine Definition, eine Regel), werden wörtlich übernommen und als Zitat
ausgewiesen — nicht paraphrasiert.

**Eine Spalte für Text, Breite nur für Tabellen.** Fließtext bei etwa 65–75
Zeichen halten; Tabellen dürfen die volle Breite nutzen.

**Beide Themes.** Palette als Custom Properties auf `:root`, im
`prefers-color-scheme: dark` nur die Tokens neu setzen, zusätzlich
`:root[data-theme="dark"]` und `:root[data-theme="light"]` bedienen. Dazu
`color-scheme` setzen (`light dark` auf `:root`, je `dark`/`light` in den
Theme-Blöcken) — sonst rendert der Browser Ankreuzfelder und Scrollbalken im
dunklen Theme hell, und ein leeres Optionsfeld sieht aus wie ein gewähltes.

**Selbsttragend.** Keine externen Fonts, Skripte oder Bilder — die Seite läuft
offline und unter strenger CSP. Systemschriften statt Webfont-Links.

**`<meta charset="utf-8">` als allererste Zeile.** Ohne sie zeigt die lokal
geöffnete Datei bei Umlauten und Gedankenstrichen Buchstabensalat
(`â€”` statt `—`), weil der Browser ohne Angabe nicht UTF-8 annimmt. Beim
Veröffentlichen wandert die Zeile in den Body und bleibt dort wirkungslos,
aber harmlos — die lokale Datei ist der Hauptfall und braucht sie.

## Rückkanal — offene Fragen beantwortbar machen

Enthält das Dokument offene Entscheidungen, werden sie nicht nur angezeigt,
sondern ausgefüllt: pro Entscheidung die Optionen aus der Quelle als
Auswahl, dazu ein Freitextfeld. Ein Knopf sammelt alles zu einem
Antwortblock und legt ihn in die Zwischenablage. Einfügen in die Session,
Enter — der Agent arbeitet weiter.

**Warum kein echtes „Senden".** Eine veröffentlichte Seite läuft unter einer
CSP, die jeden ausgehenden Request blockiert, und keine Artifact-Capability
schreibt in eine laufende Claude-Code-Session. Die Zwischenablage ist der
kürzeste Weg, der wirklich funktioniert — und der einzige, der auch in der
lokalen Datei ohne Server läuft. Diese Grenze dem Nutzer nennen, nicht
kaschieren.

**Aufbau.** Jede Frage ist ein `fieldset` mit `data-frage="<Kurztitel>"`,
die Optionen sind `radio`-Felder mit demselben `name`, deren `value` der
Optionstext aus der Quelle ist. Dazu ein `textarea` mit
`data-feld="Anmerkung"`. Nichts erfinden: steht in der Quelle nur eine
Frage ohne Optionen, bleibt es beim Freitextfeld. Gibt es eine Empfehlung,
ist sie als solche markiert — aber nicht vorausgewählt.

**Sammeln und ausgeben.** Ein Skript liest die Felder in Dokumentreihenfolge
und baut Markdown: eine Kopfzeile, die Quelle und Stand nennt, je Frage eine
Überschrift mit der gewählten Option und der Anmerkung, am Ende der Satz, was
der Agent als nächstes tun soll (aus dem Plan, nicht erfunden — etwa „bitte ab
Schritt 3 weiterarbeiten"). Unbeantwortete Fragen erscheinen als `— offen`,
damit der Agent nicht rät.

**Zwei Wege, immer beide.** `navigator.clipboard.writeText()` scheitert im
Artifact-Rahmen gelegentlich an der Permissions-Policy — deshalb immer ein
sichtbares `textarea` mit dem fertigen Block als Fallback, vorselektiert.
Zusätzlich gilt: der Block ist immer sichtbar, bevor er kopiert wird. Niemand
soll etwas einfügen, das er nicht gelesen hat.

**Eingaben überleben den Reload.** Zwischenstände in `localStorage` unter
einem Schlüssel aus dem Dateinamen; beim Laden zurückschreiben. Kein
Capability-Bedarf, und ein versehentliches Neuladen kostet keine Arbeit.

**Optional beim Veröffentlichen.** Mit `capabilities: {downloads: true}`
kann die Seite den Block zusätzlich als `ANTWORTEN-<name>.md` speichern.
`await claude.use("downloads")` liefert `null`, wenn die Fähigkeit fehlt —
dann den Knopf gar nicht zeigen. Der Kopierweg bleibt in jedem Fall der
Hauptweg.

**Was der Rückkanal nicht tut.** Keine Frage stellen, die nicht im Dokument
steht. Keine Option hinzufügen, die die Quelle nicht nennt. Keine Vorauswahl,
die eine Entscheidung vorwegnimmt.

## Gestaltung

Der Grundton ist Werkstatt, nicht Marketing: ein Dokument, auf dem gearbeitet
wird. Serifen für Überschriften, wenn die Quelle aus einem Schreib- oder
Buchprojekt stammt; sonst eine saubere Sans. Ein einziger kräftiger Akzent für
„hier musst du ran", alles andere ruhig. Neutrale Töne leicht in Richtung des
Akzents gebogen, damit sie gewählt wirken und nicht geerbt.

Vermeide die verbreiteten KI-Looks: Creme mit Terrakotta, Lila-Blau-Verlauf,
Neon auf Fast-Schwarz, Inter oder Space Grotesk als Standardschrift, alles
zentriert, überall abgerundete Karten mit Akzentstreifen.

## Abschluss

Nach dem Bauen in der Antwort nennen: wo die Datei liegt, welche Entscheidungen
die Ansicht nach oben gezogen hat, und was beim Aufbereiten an Lücken oder
Widersprüchen im Quelldokument aufgefallen ist.

Trägt die Seite einen Rückkanal, dazu in einem Satz den Weg nennen:
ausfüllen, kopieren, in die Session einfügen — und bei welchem Schritt die
Umsetzung dann ansetzt.
