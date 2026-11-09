#!/usr/bin/env bash
# Liest das Transkript einer früheren Claude-Code-Session, ohne es in den Kontext zu kippen.
#   finden [id|präfix|letzte] [eigene-id]   Pfad der Transkript-Datei
#   liste [anzahl] [eigene-id]              letzte Sessions dieses Projekts
#   stand <datei> [letzte-n]                Startstand: Ziel, Wünsche, Dateien, letzte Wortwechsel
#   suche <datei> <muster> [umfeld]         Treffer (Regex, ohne Groß/Klein) mit Nachrichtennummer
#   zeige <datei> <von> [bis]               Nachrichten #von..#bis wörtlich
set -euo pipefail

PROJEKTE="$HOME/.claude/projects"
projektordner() { echo "$PROJEKTE/$(pwd | sed 's#[^A-Za-z0-9]#-#g')"; }

# Flacht die Hauptkette in Klartext ab: eine Kopfzeile "=== #n rolle zeit" je Nachricht.
# Zwischengespeichert je Datei und Änderungszeit.
flach() {
  local datei="$1" mtime cache
  mtime=$(stat -f %m "$datei" 2>/dev/null || stat -c %Y "$datei")
  cache="${TMPDIR:-/tmp}/fortsetzen/$(basename "$datei" .jsonl)-$mtime.txt"
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
      { print }' > "$cache"
  fi
  echo "$cache"
}

case "${1:-}" in
  finden)
    wahl="${2:-letzte}" eigen="${3:-}"
    if [[ -f "$wahl" ]]; then echo "$wahl"; exit 0; fi
    if [[ "$wahl" == "letzte" ]]; then
      treffer=$(ls -t "$(projektordner)"/*.jsonl 2>/dev/null | grep -v "${eigen:-^$}" | head -1 || true)
    else
      treffer=$(ls -t "$PROJEKTE"/*/"$wahl"*.jsonl 2>/dev/null | head -1 || true)
    fi
    [[ -n "$treffer" ]] || { echo "NICHT GEFUNDEN: $wahl" >&2; exit 2; }
    echo "$treffer"
    ;;

  liste)
    anzahl="${2:-10}" eigen="${3:-}"
    ls -t "$(projektordner)"/*.jsonl 2>/dev/null | grep -v "${eigen:-^$}" | head -"$anzahl" | while read -r d; do
      titel=$(jq -r 'select(.type=="custom-title" or .type=="ai-title") | (.customTitle // .aiTitle)' "$d" 2>/dev/null | tail -1)
      printf '%s\t%s\t%s\t%s\n' "$(basename "$d" .jsonl)" "$(date -r "$d" '+%d.%m. %H:%M')" "$(du -h "$d" | cut -f1)" "${titel:--}"
    done
    ;;

  stand)
    datei="$2" letzte="${3:-25}"
    txt=$(flach "$datei")
    echo "## Session $(basename "$datei" .jsonl)"
    jq -r 'select(.type=="custom-title" or .type=="ai-title") | "Titel: \(.customTitle // .aiTitle)"' "$datei" | tail -1
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

  *)
    sed -n '2,7p' "$0"; exit 1 ;;
esac
