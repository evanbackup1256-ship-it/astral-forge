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
