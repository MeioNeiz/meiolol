#!/usr/bin/env bash
# Claude Code SessionStart hook (.claude/settings.json): the box's health problems as the
# Mac's watch last saw them (deploy/mac-watch.sh, launchd every 30 min: health.sh over ssh
# plus the Mac mirror; ~/.cache/meiolol-watch/last, its mtime the check's time). Shown to
# Jacob (systemMessage) and to Claude. Silent while all is well. Never waits on ssh: a
# check older than 45 min kicks the watch in the background and says how old it is.
set -u
state=${MEIOLOL_WATCH_STATE:-$HOME/.cache/meiolol-watch}
label=gui/$(id -u)/net.jacob.meiolol-watch
last=$state/last
now=$(date +%s)
loaded=1
launchctl print "$label" > /dev/null 2>&1 || loaded=0

if [[ ! -f "$last" ]]; then
    msg="meiolol box health unknown: the Mac's watch never ran"
else
    age=$(( (now - $(stat -f %m "$last")) / 60 ))
    problems=$(sed 's/^/- /' "$last")
    if (( age >= 120 )); then when="$(( age / 60 )) h ago"; else when="$age min ago"; fi
    kick=
    if (( age > 45 && loaded )); then
        launchctl kickstart "$label" > /dev/null 2>&1 &
        kick=", refreshing in the background"
    fi
    if [[ -n "$problems" ]]; then
        msg="meiolol box health (Mac watch, $when$kick):"$'\n'"$problems"
    elif (( age >= 120 )); then
        msg="meiolol box health: all well $when$kick"
    else
        msg=
    fi
fi
(( loaded )) || msg+="${msg:+$'\n'}the Mac watch is not loaded: deploy/box.sh watch install"
[[ -n "$msg" ]] || exit 0
jq -n --arg m "$msg" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart",
    additionalContext: ($m + "\n(deploy/hooks/claude-box-health.sh; details: deploy/box.sh status)")}}'
