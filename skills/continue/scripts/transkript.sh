#!/usr/bin/env bash
# Liest das Transkript einer früheren Claude-Code-Session, ohne es in den Kontext zu kippen.
#   finden [id|präfix|titel|letzte] [eigene-id]   Pfad der Transkript-Datei, leere Neustarts übersprungen
#   liste [anzahl] [eigene-id]              letzte Sessions dieses Projekts
#   stand <datei> [letzte-n]                Startstand: Ziel, Wünsche, Dateien, letzte Wortwechsel
#   suche <datei> <muster> [umfeld]         Treffer (Regex, ohne Groß/Klein) mit Nachrichtennummer
#   zeige <datei> <von> [bis]               Nachrichten #von..#bis wörtlich
#   davor <datei>                           Session, aus der <datei> per /clear hervorging
set -euo pipefail

PROJEKTE="$HOME/.claude/projects"
projektordner() { echo "$PROJEKTE/$(pwd | sed 's#[^A-Za-z0-9]#-#g')"; }
if stat -f %m / >/dev/null 2>&1; then
  aenderungen() { stat -f '%m %N' "$@"; }
else
  aenderungen() { stat -c '%Y %n' "$@"; }
fi
aenderung() { aenderungen "$1" | cut -d' ' -f1; }
hinweis() { echo "HINWEIS: $*" >&2; }
kurz() { basename "$1" .jsonl | cut -c1-8; }

# Zeilen einer Datei mit einem der festen Texte; ripgrep, wenn vorhanden, sonst grep.
zeilen() {
  local datei="$1" muster=() t; shift
  for t in "$@"; do muster+=(-e "$t"); done
  if command -v rg >/dev/null 2>&1; then
    rg -N -F -a --no-messages "${muster[@]}" "$datei" || true
  else
    LC_ALL=C grep -h -F "${muster[@]}" "$datei" || true
  fi
}

# Dasselbe über alle Sessions eines Ordners (tiefe 1) oder aller Projekte (tiefe 2), als "pfad:zeile".
fundstellen() {
  local ordner="$1" tiefe="$2" muster=() t; shift 2
  for t in "$@"; do muster+=(-e "$t"); done
  if command -v rg >/dev/null 2>&1; then
    rg -H -N -F -a --no-heading --no-messages --no-ignore --max-depth "$tiefe" -g '*.jsonl' "${muster[@]}" "$ordner" || true
  else
    find "$ordner" -mindepth "$tiefe" -maxdepth "$tiefe" -name '*.jsonl' -print0 2>/dev/null \
      | xargs -0 env LC_ALL=C grep -H -F "${muster[@]}" 2>/dev/null || true
  fi
}

# Eigener Titel aus /rename vor dem automatischen.
titel() {
  zeilen "$1" '{"type":"custom-title"' '{"type":"ai-title"' \
    | jq -n -r '[inputs] | (map(select(.type=="custom-title")) | last | .customTitle) // (last | .aiTitle) // empty' 2>/dev/null || true
}

# Erster Zeitstempel als Epoch-Sekunden.
beginn() {
  jq -n -r 'first(inputs | .timestamp? // empty) | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601' "$1" 2>/dev/null || true
}

nach_clear() {
  local erste
  erste=$(jq -n -r 'first(inputs | select(.type=="user" and (.isMeta|not)) | .message.content | if type=="string" then . else "" end)' "$1" 2>/dev/null || true)
  [[ "$erste" == *"<command-name>/clear</command-name>"* ]]
}

# Hat jemand etwas gesagt: eine echte Eingabe (kein Befehl, kein Abbruch) oder eine Textantwort?
gesagt() {
  [[ -n "$(jq -n -r 'first(inputs
      | select((.type=="user" or .type=="assistant") and (.isMeta|not) and (.isSidechain|not) and (.isApiErrorMessage|not))
      | . as $z | .message.content
      | (if type=="string" then . else ([.[]? | select(.type=="text") | .text] | join("")) end)
      | select(test("\\S"))
      | select($z.type=="assistant" or ((startswith("<") or startswith("[Request interrupted")) | not))
      | "ja")' "$1" 2>/dev/null || true)" ]]
}

# Nach /clear begonnen und nichts gesagt, zum Beispiel ein abgebrochener Fortsetzungsversuch.
leer() { nach_clear "$1" && ! gesagt "$1"; }

# Die Session, die im Moment des /clear zuletzt geschrieben wurde. Beim /clear wandert der eigene Titel mit:
# Hat die Kandidatin ihn nicht, gilt die zuletzt davor begonnene Session mit diesem Titel.
vorgaenger() {
  local datei="$1" ordner t0 marke zeit g s beste="" bestes=0
  nach_clear "$datei" || return 0
  ordner=$(dirname "$datei")
  t0=$(beginn "$datei"); [[ -n "$t0" ]] || return 0
  marke=$(head -5 "$datei" | jq -n -c 'first(inputs | select(.type=="custom-title") | .customTitle)' 2>/dev/null || true)
  zeit=$(aenderungen "$ordner"/*.jsonl 2>/dev/null | awk -v t0="$t0" -v selbst="$datei" '
    { pfad = substr($0, index($0, " ") + 1); d = t0 - $1 }
    pfad != selbst && d >= 0 && d <= 5 && (beste == "" || d < abstand) { abstand = d; beste = pfad }
    END { print beste }' || true)
  if [[ -n "$zeit" ]] && { [[ -z "$marke" ]] || LC_ALL=C grep -q -F "\"customTitle\":$marke" "$zeit"; }; then
    echo "$zeit"; return 0
  fi
  if [[ -n "$marke" ]]; then
    while IFS= read -r g; do
      [[ "$g" == "$datei" ]] && continue
      s=$(beginn "$g"); [[ -n "$s" ]] || continue
      if (( s < t0 && s > bestes )); then bestes=$s beste=$g; fi
    done < <(fundstellen "$ordner" 1 "\"customTitle\":$marke" | sed 's/:{.*//' | sort -u)
  fi
  echo "${beste:-$zeit}"
}

# Sessions, deren Name (eigener Titel, Agentenname, automatischer Titel) die Eingabe enthält, Groß/Klein egal.
# Erst dieser Projektordner, dann alle. Gleicher Name vor Teilwort, dann die zuletzt geänderte; leere Neustarts zuletzt.
nach_titel() {
  local wahl="$1" eigen="$2" ordner tiefe zeilen="" voll echte rang pfad name anzahl
  for ordner in "$(projektordner)" "$PROJEKTE"; do
    if [[ "$ordner" == "$PROJEKTE" ]]; then tiefe=2; else tiefe=1; fi
    zeilen=$(fundstellen "$ordner" "$tiefe" '{"type":"custom-title"' '{"type":"agent-name"' '{"type":"ai-title"' \
      | LC_ALL=C grep -i -F -- "$wahl" \
      | jq -R -r --arg w "$wahl" '
          index(":{") as $i | (.[$i+1:] | fromjson? // empty) as $o
          | ($o.customTitle // $o.agentName // $o.aiTitle // empty) as $t
          | select($t | ascii_downcase | contains($w | ascii_downcase))
          | "\(if ($t | ascii_downcase) == ($w | ascii_downcase) then 0 else 1 end)\t\(.[:$i])\t\($t)"' 2>/dev/null \
      | grep -v -F "/$eigen.jsonl" | sort -u || true)
    [[ -n "$zeilen" ]] && break
  done
  [[ -n "$zeilen" ]] || return 0
  voll=$(printf '%s\n' "$zeilen" | while IFS=$'\t' read -r rang pfad name; do
      if leer "$pfad"; then rang=$((rang + 2)); fi
      printf '%s\t%s\t%s\t%s\n' "$rang" "$(aenderung "$pfad")" "$pfad" "$name"
    done | sort -t$'\t' -k1,1n -k2,2nr | awk -F'\t' '!s[$3]++')
  echte=$(printf '%s\n' "$voll" | awk -F'\t' '$1 < 2')
  [[ -n "$echte" ]] && voll="$echte"
  anzahl=$(printf '%s\n' "$voll" | awk 'END { print NR }')
  if (( anzahl > 1 )); then
    hinweis "„${wahl}“ passt auf $anzahl Sessions, genommen die zuletzt geänderte. Weitere: $(printf '%s\n' "$voll" \
      | awk -F'\t' 'NR>1 && NR<=6 { n=split($3, p, "/"); printf "%s%s %s", (NR>2 ? ", " : ""), substr(p[n], 1, 8), $4 }')"
  fi
  printf '%s\n' "$voll" | awk -F'\t' 'NR==1 { print $3 }'
}

# Flacht die Hauptkette in Klartext ab: eine Kopfzeile "=== #n rolle zeit" je Nachricht.
# Zeilen, die nur so aussehen (Ausgaben dieses Skripts in der alten Session), werden eingerückt.
# Zwischengespeichert je Datei und Änderungszeit.
flach() {
  local datei="$1" mtime cache
  mtime=$(aenderung "$datei")
  cache="${TMPDIR:-/tmp}/fortsetzen/v2/$(basename "$datei" .jsonl)-$mtime.txt"
  if [[ ! -s "$cache" ]]; then
    mkdir -p "$(dirname "$cache")"
    jq -r '
      select((.type=="user" or .type=="assistant") and (.isSidechain|not))
      | . as $z
      | (if (.message.content|type)=="string" then [{type:"text",text:.message.content}] else .message.content end)
      | map(
          if .type=="text" then .text
          elif .type=="tool_use" then "[werkzeug:\(.name)] \(.input|tojson|.[0:3000])"
          elif .type=="tool_result" then
            "[ergebnis\(if .is_error then ":FEHLER" else "" end)] " +
            ((if (.content|type)=="string" then .content
              else ([.content[]? | select(.type=="text") | .text] | join("\n")) end) | .[0:6000])
          elif .type=="image" then "[bild]"
          else empty end)
      | select(length>0)
      | "\u0001\($z.type)\u0001\($z.timestamp // "")\u0001\(if $z.isCompactSummary then "zusammenfassung" elif $z.isMeta then "meta" else "" end)\n" + join("\n")
    ' "$datei" | awk '
      /^\001/ { split($0, f, "\001"); n++; r=f[2]; if (f[4]!="") r=r "/" f[4]; print "=== #" n " " r " " f[3]; next }
      /^=== #/ { print "  " $0; next }
      { print }' > "$cache"
  fi
  echo "$cache"
}

case "${1:-}" in
  finden)
    wahl="${2:-letzte}" eigen="${3:-}" treffer=""
    if [[ -f "$wahl" ]]; then
      treffer="$wahl"
    elif [[ "$wahl" == "letzte" ]]; then
      eigene=""
      [[ -n "$eigen" ]] && eigene=$(ls "$PROJEKTE"/*/"$eigen".jsonl 2>/dev/null | awk 'NR==1' || true)
      [[ -n "$eigene" ]] && treffer=$(vorgaenger "$eigene")
      if [[ -n "$treffer" ]]; then
        hinweis "Die eigene Session begann mit /clear, genommen die Session davor: $(kurz "$treffer")"
      else
        treffer=$(ls -t "$(projektordner)"/*.jsonl 2>/dev/null | grep -v "${eigen:-^$}" | awk 'NR==1' || true)
      fi
    else
      treffer=$(ls -t "$PROJEKTE"/*/"$wahl"*.jsonl 2>/dev/null | awk 'NR==1' || true)
      [[ -n "$treffer" ]] || treffer=$(nach_titel "$wahl" "$eigen")
    fi
    [[ -n "$treffer" ]] || { echo "NICHT GEFUNDEN: $wahl" >&2; exit 2; }
    schritte=0
    while leer "$treffer" && (( schritte < 10 )); do
      davor=$(vorgaenger "$treffer")
      if [[ -z "$davor" ]]; then
        hinweis "$(kurz "$treffer") ist ein leerer Neustart nach /clear, die Session davor ist nicht zu finden"
        break
      fi
      hinweis "$(kurz "$treffer") ist ein leerer Neustart nach /clear, weiter mit der Session davor: $(kurz "$davor")"
      treffer="$davor" schritte=$((schritte + 1))
    done
    echo "$treffer"
    ;;

  liste)
    anzahl="${2:-10}" eigen="${3:-}"
    ls -t "$(projektordner)"/*.jsonl 2>/dev/null | grep -v "${eigen:-^$}" | head -"$anzahl" | while read -r d; do
      t=$(titel "$d")
      if leer "$d"; then t="${t:--} · leerer Neustart nach /clear"; fi
      printf '%s\t%s\t%s\t%s\n' "$(basename "$d" .jsonl)" "$(date -r "$d" '+%d.%m. %H:%M')" "$(du -h "$d" | cut -f1)" "${t:--}"
    done
    ;;

  stand)
    datei="$2" letzte="${3:-25}"
    txt=$(flach "$datei")
    echo "## Session $(basename "$datei" .jsonl)"
    t=$(titel "$datei"); [[ -z "$t" ]] || echo "Titel: $t"
    jq -r 'select(.type=="user") | "Ordner: \(.cwd)  Branch: \(.gitBranch // "-")  zuletzt: \(.timestamp)"' "$datei" | tail -1
    echo "Nachrichten: $(grep -c '^=== #' "$txt")   Transkript: $datei"
    echo
    echo "## Eingaben des Nutzers (Nummer: Anfang)"
    # Echte Eingaben: user-Nachrichten ohne Meta, ohne Werkzeugergebnis, nicht mit < beginnend.
    awk '/^=== #[0-9]+ user /{ if ($3=="user") { k=$2; getline; if ($0 !~ /^(<|\[ergebnis|\[bild\]$)/ && length($0)>0) print k ": " substr($0,1,240) } }' "$txt" \
      | awk '{a[NR]=$0} END{for(i=1;i<=NR;i++) if (NR<=40 || i<=5 || i>NR-30) print a[i]; else if (i==6) print "… " NR-35 " weitere, mit suche/zeige holen"}'
    echo
    echo "## Geänderte Dateien (zuletzt zuerst)"
    grep -oE '^\[werkzeug:(Edit|Write|MultiEdit|NotebookEdit)\] \{"(file_path|notebook_path)":"[^"]+' "$txt" \
      | sed -E 's/.*":"//' | awk '{a[NR]=$0} END{for(i=NR;i>0;i--)print a[i]}' | awk '!s[$0]++' | head -30 || true
    echo
    zus=$(grep -n '^=== #[0-9]* user/zusammenfassung' "$txt" | tail -1 | cut -d: -f1 || true)
    if [[ -n "$zus" ]]; then
      echo "## Letzte Kompaktierungs-Zusammenfassung (ab Zeile $zus der Klartextdatei, gekürzt)"
      tail -n +"$zus" "$txt" | sed -n '2,/^=== #/p' | sed '$d' | head -60
      echo
    fi
    echo "## Letzte $letzte Nachrichten (je gekürzt)"
    gesamt=$(grep -c '^=== #' "$txt")
    awk -v ab=$((gesamt - letzte + 1)) '
      /^=== #/ { n++; zeilen=0 }
      n>=ab { if (/^=== #/ || zeilen<12) print; else if (zeilen==12) print "  …"; zeilen++ }' "$txt" | cut -c1-400
    ;;

  suche)
    datei="$2" muster="$3" umfeld="${4:-3}"
    txt=$(flach "$datei")
    # Jede Trefferzeile mit der Nummer ihrer Nachricht.
    awk -v m="$muster" -v u="$umfeld" '
      BEGIN { ml=tolower(m) }
      /^=== #/ { kopf=$0; next }
      { z[NR]=$0; k[NR]=kopf }
      tolower($0) ~ ml { treffer[++t]=NR }
      END {
        if (!t) { print "KEINE TREFFER"; exit }
        for (i=1;i<=t && i<=40;i++) {
          r=treffer[i]; if (k[r]!=letzter) { print "\n" k[r]; letzter=k[r] }
          for (j=r-u;j<=r+u;j++) if ((j in z) && !(j in gezeigt)) { gezeigt[j]=1; print (j==r?"» ":"  ") substr(z[j],1,500) }
        }
        if (t>40) print "\n… " t-40 " weitere Treffer, Muster enger fassen"
      }' "$txt"
    ;;

  zeige)
    datei="$2" von="$3" bis="${4:-$3}"
    txt=$(flach "$datei")
    awk -v a="$von" -v b="$bis" '/^=== #/ { n=substr($2,2)+0 } n>=a && n<=b' "$txt" | head -800
    ;;

  davor)
    davor=$(vorgaenger "$2")
    [[ -n "$davor" ]] || { echo "KEINE SESSION DAVOR: $(kurz "$2") begann nicht mit /clear, oder die Session davor ist nicht zu finden" >&2; exit 2; }
    echo "$davor"
    ;;

  *)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
