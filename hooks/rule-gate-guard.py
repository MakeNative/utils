#!/usr/bin/env python3
"""Guard-Hook für /utils:rule-gate: prüft die Endausgabe von Agenten deterministisch.

Läuft als PreToolUse auf `StructuredOutput`, also auf die Endausgabe einer Rolle,
die headless mit `--json-schema` läuft. Ohne Konfiguration tut er nichts.

Eingeschaltet wird er je Projekt:
  1. Umgebungsvariable RULE_GATE_CONFIG mit dem Pfad zu einer JSON-Datei, oder
  2. `.claude/rule-gate.json` im Projekt (CLAUDE_PROJECT_DIR, sonst cwd der Eingabe).

Inhalt (nur das Feld `guard` zählt hier):
  {"guard": {"check": ["node", "/abs/pfad/check.js"], "agents": ["marketing-kit:*"]}}

`check` ist der Prüfbefehl des Projekts. Er bekommt die Ausgabe der Rolle als JSON
auf stdin. Exit 0 heißt ok, Exit 1 heißt Verstoß, die erste Zeile von stdout ist
der Grund. `agents` ist freiwillig: Muster für `agent_type`. Fehlt `agent_type` in
der Eingabe (Hauptkontext mit --agent), gilt die Prüfung trotzdem.

Bei Verstoß blockt der Hook mit dem Grund, die Rolle muss ihre Ausgabe ändern. Ist
der Prüfbefehl nicht erreichbar oder antwortet anders, blockt er ebenfalls: Eine
eingeschaltete Schranke lässt im Zweifel nichts durch.
"""
import fnmatch
import json
import os
import subprocess
import sys

CHECK_TIMEOUT_SECONDS = 20
UNREACHABLE = "Die Regelprüfung ist nicht erreichbar, deshalb geht diese Ausgabe nicht durch."


def allow():
    sys.exit(0)


def block(reason):
    print(f"Regelprüfung: {reason}", file=sys.stderr)
    sys.exit(2)


def config_path(hook_input):
    explicit = os.environ.get("RULE_GATE_CONFIG")
    if explicit:
        return explicit
    project = os.environ.get("CLAUDE_PROJECT_DIR") or hook_input.get("cwd") or ""
    candidate = os.path.join(project, ".claude", "rule-gate.json")
    return candidate if project and os.path.isfile(candidate) else None


def load_guard(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle).get("guard")
    except (OSError, ValueError, AttributeError):
        block(UNREACHABLE)


def applies_to(guard, agent_type):
    patterns = guard.get("agents")
    if not patterns or not agent_type:
        return True
    return any(fnmatch.fnmatch(agent_type, pattern) for pattern in patterns)


def run_check(command, payload):
    try:
        done = subprocess.run(
            command,
            input=json.dumps(payload, ensure_ascii=False),
            capture_output=True,
            text=True,
            timeout=CHECK_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.SubprocessError):
        block(UNREACHABLE)
    if done.returncode == 0:
        allow()
    if done.returncode == 1:
        reason = (done.stdout.strip().splitlines() or ["Die Ausgabe verstößt gegen eine Regel."])[0]
        block(f"{reason} Ändere deine Ausgabe so, dass sie die Regel einhält.")
    block(UNREACHABLE)


def main():
    try:
        hook_input = json.load(sys.stdin)
    except ValueError:
        allow()
    if hook_input.get("tool_name") != "StructuredOutput":
        allow()
    path = config_path(hook_input)
    if path is None:
        allow()
    guard = load_guard(path)
    if not guard:
        allow()
    command = guard.get("check")
    if not isinstance(command, list) or not command or not all(isinstance(part, str) for part in command):
        block(UNREACHABLE)
    if not applies_to(guard, hook_input.get("agent_type") or ""):
        allow()
    run_check(command, hook_input.get("tool_input"))


if __name__ == "__main__":
    main()
