#!/usr/bin/env bash
# Prüft GitHub-Repos auf Köder-Merkmale, bevor Dateien daraus geladen werden.
# Liest nur Metadaten und den Dateibaum über die API, lädt keine Datei.
#   repo-check.sh OWNER/REPO [OWNER/REPO ...]
# Je Repo eine Zeile: OK, VERDÄCHTIG oder FEHLER, dahinter die Gründe.
# Exit 0: alle OK. Exit 1: mindestens ein VERDÄCHTIG. Exit 2: mindestens ein FEHLER.
set -euo pipefail

ARCHIVE='\.(zip|exe|dmg|pkg|msi|7z|rar|scr)$'
JUNG_TAGE=365
WENIGE_REPOS=5

ergebnis=0

melde() { # status repo gründe
  echo "$1 $2${3:+: $3}"
  case "$1" in
    FEHLER) ergebnis=2 ;;
    VERDÄCHTIG) [[ $ergebnis -eq 2 ]] || ergebnis=1 ;;
  esac
}

# Ruft die API auf. Bei einem Fehler steht die Meldung in $antwort, ohne das Skript zu beenden.
api() {
  local rc=0
  antwort=$(gh api "$@" 2>&1) || rc=$?
  [[ $rc -eq 0 ]] || antwort=$(tail -1 <<<"$antwort" | sed 's/.*gh: //' | cut -c1-160)
  return $rc
}

pruefe() {
  local repo="$1" voll besitzer name erstellt archive anzahl gruende="" jung original
  local antwort

  api "repos/$repo" || { melde FEHLER "$repo" "$antwort"; return; }
  voll=$(jq -r .full_name <<<"$antwort")
  besitzer=$(jq -r .owner.login <<<"$antwort")
  name=$(jq -r .name <<<"$antwort")
  erstellt=$(jq -r .created_at <<<"$antwort")

  api "repos/$voll/git/trees/HEAD?recursive=1" || { melde FEHLER "$voll" "$antwort"; return; }
  if [[ $(jq -r .truncated <<<"$antwort") == true ]]; then
    melde FEHLER "$voll" "Dateibaum unvollständig, von Hand prüfen"
    return
  fi
  archive=$(jq -r '.tree[] | select(.type=="blob") | .path' <<<"$antwort" | grep -iE "$ARCHIVE" || true)
  if [[ -n "$archive" ]]; then
    anzahl=$(wc -l <<<"$archive" | tr -d ' ')
    gruende="$anzahl Archiv/Installer ($(head -3 <<<"$archive" | paste -sd, - | sed 's/,/, /g'))"
  fi

  api "users/$besitzer" || { melde FEHLER "$voll" "$antwort"; return; }
  jung=$(jq -r --argjson tage "$JUNG_TAGE" --argjson wenige "$WENIGE_REPOS" \
    '((now - (.created_at | fromdateiso8601)) / 86400 < $tage) and (.public_repos <= $wenige)' <<<"$antwort")

  # Die Suche ist knapp bemessen, deshalb nur für junge Konten.
  if [[ "$jung" == true ]]; then
    api -X GET search/repositories -f "q=$name in:name" -f sort=stars -f per_page=100 \
      || { melde FEHLER "$voll" "$antwort"; return; }
    original=$(jq -r --arg n "$name" --arg o "$besitzer" --arg c "$erstellt" '
      [.items[] | select((.name | ascii_downcase) == ($n | ascii_downcase)
        and (.owner.login | ascii_downcase) != ($o | ascii_downcase)
        and .created_at < $c)] | first | .full_name // empty' <<<"$antwort")
    if [[ -n "$original" ]]; then
      gruende="${gruende:+$gruende; }junges Konto mit wenigen Repos, älteres Repo gleichen Namens: $original"
    fi
  fi

  if [[ -n "$gruende" ]]; then melde VERDÄCHTIG "$voll" "$gruende"; else melde OK "$voll"; fi
}

if [[ $# -eq 0 ]]; then
  echo "Aufruf: repo-check.sh OWNER/REPO [OWNER/REPO ...]" >&2
  exit 2
fi
for repo in "$@"; do pruefe "$repo"; done
exit $ergebnis
