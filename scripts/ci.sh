#!/usr/bin/env bash
# Astral Forge CI: compile the TypeScript sources, then run every check one at a time.
#
#   scripts/ci.sh                 compile + every scripts/verify_*.luau + lint_locale
#   scripts/ci.sh locale boot     compile + only checks whose name contains "locale" or "boot"
#   SKIP_COMPILE=1 scripts/ci.sh  reuse the current out/ (after a manual `npx rbxtsc`)
#
# Each check runs in its own `lune run` process with a timeout (TEST_TIMEOUT, default 300s).
# Lune's harness can stall when the machine is very busy, so a timed-out check is retried once
# before it counts as a failure. Exit code is non-zero when the compile reports errors or any
# check fails; a summary with timings is printed at the end and written to ci-report.txt.
set -u
cd "$(dirname "$0")/.."

TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
COMPILE_TIMEOUT="${COMPILE_TIMEOUT:-1800}"
REPORT="ci-report.txt"
: > "$REPORT"

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

for tool in npx lune; do
	command -v "$tool" >/dev/null 2>&1 || { log "ci: $tool is not on PATH"; exit 2; }
done

if [ "${SKIP_COMPILE:-0}" != "1" ]; then
	log "== compile (rbxtsc)"
	start=$(date +%s)
	compile_out=$(timeout "$COMPILE_TIMEOUT" npx rbxtsc 2>&1)
	status=$?
	printf '%s\n' "$compile_out" > rbxtsc-ci.txt
	errors=$(printf '%s\n' "$compile_out" | grep -c ' error TS' || true)
	log "   rbxtsc exit=$status errors=$errors ($(( $(date +%s) - start ))s, full output in rbxtsc-ci.txt)"
	if [ "$status" -ne 0 ] || [ "$errors" -ne 0 ]; then
		printf '%s\n' "$compile_out" | grep ' error TS' | head -40 | tee -a "$REPORT"
		log "ci: compile failed"
		exit 1
	fi
fi

# UI art guard: the revamp art is uploaded as Decals; GuiObjects must draw it through art()
# (Shared/UiArt), and the experience icon decal is never drawn in-game.
log "== ui art guard"
art_bad=$(grep -rnE '"rbxassetid://(74290074754222)"' src || true)
for id in $(grep -oE '^\s*"[0-9]{8,}":' src/Shared/AstralForge/Shared/UiArt.ts | tr -dc '0-9\n'); do
	art_bad="$art_bad$(grep -rn "rbxassetid://$id" src --include=*.ts --include=*.tsx | grep -v 'Shared/UiArt.ts' | grep -v "art(\"rbxassetid://$id\")" || true)"
done
if [ -n "$art_bad" ]; then
	printf '%s\n' "$art_bad" | tee -a "$REPORT"
	log "ci: decal art referenced as an image (wrap it in art())"
	exit 1
fi
log "   ok"

# Old-style guard: pre-revamp palette values (67a49bfd ForgeTheme) and the old 14px card radius
# must not come back into the client UI; use Palette tokens and radius 18 (IconTile glyph tiles aside).
log "== old style guard"
old_rgb='11,\s*12,\s*18|110,\s*112,\s*138|112,\s*164,\s*240|116,\s*210,\s*152|120,\s*214,\s*170|138,\s*90,\s*34|16,\s*17,\s*25|170,\s*146,\s*240|178,\s*172,\s*182|19,\s*20,\s*29|200,\s*210,\s*232|218,\s*209,\s*194|23,\s*24,\s*34|232,\s*122,\s*172|236,\s*182,\s*92|238,\s*116,\s*100|242,\s*176,\s*72|246,\s*104,\s*72|246,\s*238,\s*224|32,\s*33,\s*46|47,\s*48,\s*65|60,\s*62,\s*82|8,\s*9,\s*14|96,\s*206,\s*222'
style_bad=$(grep -rnE "(fromRGB|rgb)\\(($old_rgb)\\)" src/Client || true)
style_bad="$style_bad$(grep -rnE 'radius=\{14\}|radius: 14\b|cardRadius: 14' src/Client | grep -v IconTile || true)"
style_bad="$style_bad$(grep -nE '^\s*lg: 14,' src/Client/AstralForge/CoreKit/theme.ts || true)"
if [ -n "$style_bad" ]; then
	printf '%s\n' "$style_bad" | tee -a "$REPORT"
	log "ci: old UI style tokens found"
	exit 1
fi
log "   ok"

# Import cycle guard: roblox-ts aborts the whole require chain on a circular top-level import
# ("Failed to import! Detected a circular dependency chain"), so any cycle in out/ fails CI.
log "== import cycle guard"
cycle_out=$(node scripts/check_import_cycles.js out 2>&1)
status=$?
printf '%s\n' "$cycle_out" | tee -a "$REPORT"
if [ "$status" -ne 0 ]; then
	log "ci: circular imports found"
	exit 1
fi

checks=()
for file in scripts/verify_*.luau scripts/lint_locale.luau; do
	name=$(basename "$file" .luau)
	[ "$name" = "verify_project" ] && continue # the in-process suite; CI runs members separately
	if [ "$#" -gt 0 ]; then
		keep=0
		for filter in "$@"; do
			case "$name" in *"$filter"*) keep=1 ;; esac
		done
		[ "$keep" -eq 1 ] || continue
	fi
	checks+=("$file")
done

pass=0
fail=0
failed=()
for file in "${checks[@]}"; do
	name=$(basename "$file" .luau)
	for attempt in 1 2; do
		start=$(date +%s)
		output=$(timeout "$TEST_TIMEOUT" lune run "$file" 2>&1)
		status=$?
		took=$(( $(date +%s) - start ))
		[ "$status" -eq 124 ] && [ "$attempt" -eq 1 ] && { log "   $name timed out after ${took}s, retrying"; continue; }
		break
	done
	if [ "$status" -eq 0 ]; then
		pass=$((pass + 1))
		log "ok   $name (${took}s)"
	else
		fail=$((fail + 1))
		failed+=("$name")
		log "FAIL $name (exit $status, ${took}s)"
		printf '%s\n' "$output" | tail -15 | sed 's/^/     /' | tee -a "$REPORT"
	fi
done

log ""
log "== $pass passed, $fail failed of ${#checks[@]}"
if [ "$fail" -gt 0 ]; then
	log "failed: ${failed[*]}"
	exit 1
fi
