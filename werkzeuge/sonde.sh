#!/usr/bin/env bash
# Startet eine Sonde und bricht ab, wenn ein Skript nicht lädt.
#
# Godot beendet sich nicht, wenn das Skript einer Szene einen Parsefehler hat:
# die Szene wird geladen, der Knoten steht da, _ready() läuft nie — und damit
# auch kein get_tree().quit(). Headless dreht die Hauptschleife dann bis zum
# Zeitlimit. Ein falsch gesetztes Anführungszeichen hat so acht Minuten
# gekostet, und die Ausgabe war leer, weil tail erst am Ende schreibt.
#
# --check-only hilft nicht: es kennt die Autoloads nicht, meldet deshalb auch
# heile Skripte als fehlerhaft und liefert ohnehin immer Exit 0.
#
# Deshalb dieser Wachhund. Er liest die Ausgabe mit, schlägt bei der ersten
# Fehlermeldung des Skriptladers zu und nennt sie.
#
#   werkzeuge/sonde.sh <Szene ohne Endung> [Argumente der Sonde …]
#   SONDE_ZEIT=900 werkzeuge/sonde.sh Realismussonde 12

set -uo pipefail

if [ $# -lt 1 ]; then
	echo "Aufruf: werkzeuge/sonde.sh <Szene> [Argumente …]" >&2
	exit 2
fi

SZENE="$1"; shift
GODOT="${GODOT:-/root/bin/godot}"
ZEIT="${SONDE_ZEIT:-900}"
PROJEKT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp)"
# Rauschen, das der Renderer ohne Fenster erzeugt und das nichts bedeutet.
RAUSCHEN='Parameter "m" is null|mesh_get_surface_count|All audio drivers failed|2D MSAA is not yet supported'
# Meldungen, nach denen die Sonde nie mehr etwas sagen wird.
TOEDLICH='Parse Error|Failed to load script|Compilation failed|Invalid call|Script inherits from native type'

trap 'rm -f "$LOG"' EXIT

timeout "$ZEIT" "$GODOT" --headless --path "$PROJEKT" "res://werkzeuge/${SZENE}.tscn" ${1+-- "$@"} \
	>"$LOG" 2>&1 &
GODOT_PID=$!

gefunden=""
while kill -0 "$GODOT_PID" 2>/dev/null; do
	if grep -Eq "$TOEDLICH" "$LOG"; then
		gefunden="ja"
		kill "$GODOT_PID" 2>/dev/null
		break
	fi
	sleep 1
done
wait "$GODOT_PID"
CODE=$?

grep -Ev "$RAUSCHEN" "$LOG" | grep -v '^\s*at: '

if [ -n "$gefunden" ]; then
	echo ""
	echo "— $SZENE abgebrochen: ein Skript ließ sich nicht laden. —"
	exit 1
fi
if [ "$CODE" -eq 124 ]; then
	echo ""
	echo "— $SZENE hat das Zeitlimit von ${ZEIT}s erreicht. —"
	exit 124
fi
exit "$CODE"
