#!/usr/bin/env bash
# ExecStopPost of a user unit (deploy/systemd meiolol-crawl): why it stopped, as one line
# in LOG and the journal. systemd gives the outcome (SERVICE_RESULT, EXIT_CODE,
# EXIT_STATUS). `systemctl stop|restart` waits for the stop, so its caller is still there
# to name, with its parents and ssh client (admin page, box.sh over ssh, a deploy). With
# none, the signal came from outside systemd: kill, or the OOM killer (journalctl -k)
#   why-stopped.sh UNIT LOG
set -u
unit=$1 log=$2
# A pid's command line, then its parents', up to init
chain() {
    local p=$1 args out=
    while [[ "$p" =~ ^[0-9]+$ ]] && (( p > 1 )); do
        args=$(tr '\0\n' '  ' < "/proc/$p/cmdline" 2> /dev/null) || break
        args=${args% }
        out+="${out:+ < }${args:0:160}"
        p=$(awk '/^PPid:/ { print $2 }' "/proc/$p/status" 2> /dev/null)
    done
    echo "$out"
}
by=
for pid in $(pgrep -u "$(id -u)" -x systemctl); do
    tr '\0' ' ' < "/proc/$pid/cmdline" 2> /dev/null \
        | grep -qE " (stop|restart|try-restart|disable|kill) .*${unit%.service}( |\.service|$)" \
        || continue
    from=$(tr '\0' '\n' < "/proc/$pid/environ" 2> /dev/null | sed -n 's/^SSH_CLIENT=\([^ ]*\).*/\1/p')
    by+="${by:+; }$(chain "$pid")${from:+ (ssh from $from)}"
done
if [[ -z "$by" ]]; then
    case $(systemctl is-system-running 2> /dev/null) in
        stopping) by="the system shutting down" ;;
        *) by="no systemctl caller: a signal from outside systemd (kill, OOM: journalctl -k)" ;;
    esac
fi
line="$(date -u '+%F %T') info: $unit stopped: ${SERVICE_RESULT:-?}, ${EXIT_CODE:-?} ${EXIT_STATUS:-?}; by ${by:0:600}"
echo "$line"
echo "$line" >> "$log"
