#!/bin/sh
# Claude Code PostToolUse hook (.claude/settings.json): tells a long-running session to
# hand over as its context fills. Once at 25%, then at 33% and every 5% past it. Reads
# the used % the statusline records per session (field 1 of
# ~/.claude/cache/context/<session id>); silent without it and in subagents, which can't
# hand over.
# Test: deploy/hooks/claude-context-nag.sh --test
if [ "${1:-}" = --test ]; then
    self=$0
    fails=0
    HOME=$(mktemp -d)
    export HOME
    mkdir -p "$HOME/.claude/cache/context"
    at() {
        printf '%s\t1000000\n' "$1" >"$HOME/.claude/cache/context/s1"
        echo "{\"session_id\":\"s1\"$2}" | "$self" | jq -r '.hookSpecificOutput.additionalContext // empty' | cut -c1-20
    }
    check() {
        got=$(at "$2" "${3:-}")
        case $got in
            "$1"*) ;;
            *) echo "at $2: want '$1' got '$got'"; fails=1 ;;
        esac
        [ -n "$1" ] || [ -z "$got" ] || { echo "at $2: want nothing got '$got'"; fails=1; }
    }
    check "" 20
    check "Context at 26%" 26
    check "" 27
    check "" 30 ',"agent_id":"a1"'
    check "Context at 34%: han" 34
    check "" 36
    check "Context at 38%: han" 38
    check "" 39
    rm -rf "$HOME"
    [ $fails = 0 ] && echo "all pass"
    exit $fails
fi

in=$(cat)
[ -z "$(printf '%s' "$in" | jq -r '.agent_id // empty')" ] || exit 0
sid=$(printf '%s' "$in" | jq -r '.session_id // empty')
[ -n "$sid" ] && [ -r "$HOME/.claude/cache/context/$sid" ] || exit 0
pct=$(cut -f1 "$HOME/.claude/cache/context/$sid")
case $pct in '' | *[!0-9]*) exit 0 ;; esac
[ "$pct" -ge 25 ] || exit 0

# level: 25, then 33, 38, 43...; each said once
if [ "$pct" -lt 33 ]; then level=25; else level=$((33 + (pct - 33) / 5 * 5)); fi
state="$HOME/.claude/cache/context-nag"
mkdir -p "$state" 2>/dev/null
last=$(cat "$state/$sid" 2>/dev/null)
[ "${last:-0}" -lt "$level" ] || exit 0
echo "$level" >"$state/$sid"

if [ "$level" = 25 ]; then
    msg="Context at $pct%. Long sessions get worse from here: at the next natural break \
(step committed, state in notes) hand over with the fleet skill, cc-handover --new (the \
successor keeps your name). Carry on past it only when a restart costs more than it saves, \
such as mid-debug with what you know not yet written down."
else
    msg="Context at $pct%: hand over now. Write the state to your notes, then \
cc-handover --new (fleet skill). Carry on only for a concrete reason, and say it in your \
next reply."
fi
jq -n --arg m "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $m}}'
