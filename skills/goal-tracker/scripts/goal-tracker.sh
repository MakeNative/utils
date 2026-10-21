#!/bin/bash
# Gemeinsames Skript für /utils:goal-tracker.
#   goal-tracker.sh kontext     SessionStart-Hook: Ziel-Datei der Session in den Kontext
#   goal-tracker.sh anker       UserPromptSubmit-Hook: Zielzeile + Session-Name
#   goal-tracker.sh statusline  Statusline: Name, Ziel, geparkte Befunde, Kontext
#   goal-tracker.sh list        Übersicht über die Ziele aller Sessions
#   goal-tracker.sh install-statusline   Statusline in ~/.claude/settings.json eintragen
# Ziel-Dateien liegen zentral in ~/.claude/goal-tracker/<session_id>.md, damit alle
# Terminals in einer Liste stehen, auch wenn mehrere im selben Repo laufen.

dir="${GOAL_TRACKER_DIR:-$HOME/.claude/goal-tracker}"
eingabe=""

# Liest ein flaches Feld aus der JSON-Eingabe (ohne jq-Abhängigkeit).
feld() {
  printf '%s' "$eingabe" | tr '\n' ' ' | sed -n "s/.*\"$1\" *: *\"\([^\"]*\)\".*/\1/p" | head -n 1
}

# Liest einen Eintrag aus dem Kopf der Ziel-Datei.
kopf() {
  sed -n '/^---$/,/^---$/p' "$2" | sed -n "s/^$1: *//p" | head -n 1
}

titel()   { sed -n 's/^# Ziel: *//p' "$1" | head -n 1; }
scope()   { sed -n 's/^\*\*Scope:\*\* *//p' "$1" | head -n 1; }
geparkt() { sed -n '/^## Geparkt/,$p' "$1" | grep -c '^- .' ; }

aktive_datei() {
  local f="$dir/$1.md"
  [ -n "$1" ] && [ -f "$f" ] && [ "$(kopf status "$f")" = "aktiv" ] && echo "$f"
}

case "$1" in
  kontext)
    eingabe=$(cat)
    f=$(aktive_datei "$(feld session_id)") || exit 0
    echo "Für diese Session ist mit /utils:goal-tracker ein Ziel festgelegt. Ziel-Datei: $f"
    echo
    sed -n '/^# Ziel/,$p' "$f"
    echo
    echo "Befunde außerhalb des Scopes werden in dieser Session nicht bearbeitet, sondern als eine Zeile unter „## Geparkt“ in der Ziel-Datei notiert (Datei oder Stelle, Befund, warum relevant)."
    ;;

  anker)
    eingabe=$(cat)
    f=$(aktive_datei "$(feld session_id)") || exit 0
    name=$(kopf name "$f")
    text="Session-Ziel: $(titel "$f"). Scope: $(scope "$f"). Nebenbefunde gehören unter „## Geparkt“ in $f."
    titel_json=""
    # Nur benennen, wenn die Session noch keinen eigenen Namen hat.
    if [ -n "$name" ] && [ -z "$(feld session_title)" ]; then
      titel_json=", \"sessionTitle\": \"$name\""
    fi
    text=${text//\\/\\\\}; text=${text//\"/\\\"}
    printf '{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "%s"%s}}\n' "$text" "$titel_json"
    ;;

  statusline)
    eingabe=$(cat)
    name=$(feld session_name)
    ctx=$(printf '%s' "$eingabe" | tr '\n' ' ' | sed -n 's/.*"used_percentage" *: *\([0-9]*\).*/\1/p' | head -n 1)
    f=$(aktive_datei "$(feld session_id)")
    if [ -n "$f" ]; then
      echo "[${name:-$(kopf name "$f")}] ◎ $(titel "$f") | geparkt: $(geparkt "$f") | ctx ${ctx:-0}%"
    else
      echo "[${name:-unbenannt}] kein Ziel – /utils:goal-tracker | ctx ${ctx:-0}%"
    fi
    ;;

  list)
    shopt -s nullglob
    dateien=("$dir"/*.md)
    n=0
    for f in "${dateien[@]}"; do
      [ "$(kopf status "$f")" = "aktiv" ] || continue
      n=$((n + 1))
      printf '%s\t%s\t%s\t%s\t%s\n' "$(kopf name "$f")" "$(titel "$f")" "$(geparkt "$f")" "$(kopf projekt "$f")" "$(kopf gesetzt "$f")"
    done
    [ "$n" -eq 0 ] && echo "Keine aktiven Ziele in $dir."
    exit 0
    ;;

  install-statusline)
    ziel="$HOME/.claude/goal-tracker.sh"
    cp "$0" "$ziel" && chmod +x "$ziel"
    settings="$HOME/.claude/settings.json"
    [ -f "$settings" ] || echo '{}' > "$settings"
    if command -v jq >/dev/null && [ "$(jq -r '.statusLine // empty' "$settings")" != "" ] && [ "$2" != "--ersetzen" ]; then
      echo "VORHANDEN: $(jq -c '.statusLine' "$settings")"
      exit 3
    fi
    command -v jq >/dev/null || { echo "jq fehlt, bitte statusLine von Hand eintragen."; exit 4; }
    tmp=$(mktemp)
    jq --arg c "$ziel statusline" '.statusLine = {type: "command", command: $c, padding: 0}' "$settings" > "$tmp" && mv "$tmp" "$settings"
    echo "OK: statusLine zeigt jetzt $ziel statusline"
    ;;

  *)
    echo "Aufruf: goal-tracker.sh kontext|anker|statusline|list|install-statusline" >&2
    exit 1
    ;;
esac
