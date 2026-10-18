#!/usr/bin/env bash
# Deploy events from the Mac (pre-push check, deploy/on-push.sh) for the admin page's
# Deploys tab: queued in .git/meiolol-deploy-events.tsv, appended to the box's
# data/deploys.tsv on the next flush that reaches it, so a deploy that failed before the
# box still shows once it is reachable. Format: docs/hosting.md "Deploy events".
#   deploy/deploy-events.sh add SHA STEP STATUS [DETAIL]
#   deploy/deploy-events.sh flush
set -u
ROOT=${MEIOLOL_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
common=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)
queue=$common/meiolol-deploy-events.tsv
lock=$common/meiolol-deploy-events.lock
host=${MEIOLOL_HOST:-meiolol-cloud}

case "${1:-}" in
    add)
        detail=${5:-}
        detail=${detail//$'\t'/ }
        printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$2" "$3" "$4" "${detail//$'\n'/ }" >> "$queue"
        ;;
    flush)
        [[ -s $queue ]] || exit 0
        # One flush at a time (mkdir is atomic; no flock on macOS); a lock left by a
        # killed flush goes after 5 min
        if ! mkdir "$lock" 2> /dev/null; then
            [[ -n $(find "$lock" -maxdepth 0 -mmin +5 2> /dev/null) ]] || exit 0
            rm -rf "$lock" && mkdir "$lock" 2> /dev/null || exit 0
        fi
        trap 'rmdir "$lock" 2> /dev/null' EXIT
        # Lines added meanwhile go to a fresh queue
        mv "$queue" "$queue.sending"
        # shellcheck disable=SC2016 # expands on the box
        if ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" 'cd ml/meiolol/data &&
            { [ -s deploys.tsv ] || printf "time\tsha\tstep\tstatus\tdetail\n" > deploys.tsv; } &&
            cat >> deploys.tsv' < "$queue.sending"; then
            rm -f "$queue.sending"
        else
            cat "$queue.sending" >> "$queue" && rm -f "$queue.sending"
            exit 1
        fi
        ;;
    *) sed -n '6,7p' "$0"; exit 2 ;;
esac
