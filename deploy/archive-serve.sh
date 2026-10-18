#!/usr/bin/env bash
# On the box: forced command of the gpu-box's archive key in ~/.ssh/authorized_keys
# (docs/data-safety.md "Raw archive"), so that key can do only this. The gpu-box runs
# deploy/archive-pull.sh, which calls: export, list, send NAME, got NAME SHA256, ack NAME,
# forgotten, disk USE (the gpu-box's disk use for deploy/health.sh), report ok|fail
# MESSAGE (each round's outcome, so health.sh can say why acks stopped)
set -euo pipefail
cd "$HOME/ml/meiolol"
out=data/archive-out
read -r cmd arg arg2 _ <<< "${SSH_ORIGINAL_COMMAND:-}"
name() { [[ "$arg" =~ ^raw-[0-9]+-[0-9]+\.db$ ]] || { echo "bad export name" >&2; exit 2; }; }
# What goes to the gpu-box: the export's pack (NAME.zst, raw-export --pack) when there is
# one, else NAME as written
file() { if [[ -f "$out/$arg.zst" ]]; then echo "$out/$arg.zst"; else echo "$out/$arg"; fi; }
case "${cmd:-}" in
    export)
        made=$(nice -n 10 bin/meiolol raw-export --data data --out "$out")
        echo "$made"
        # Packed here, once: -9 is 39% under the export's gzip bodies for ~60 s of one
        # core an hour of exports (docs/data-safety.md "Raw archive"); a failed pack
        # leaves NAME to go as it is.
        # data/archive-packed.log: unix time, name, export bytes, pack bytes, documents
        [[ -n "$made" ]] || exit 0
        if packed=$(nice -n 10 bin/meiolol raw-export --data data --out "$out" --pack "${made%%$'\t'*}" \
            --level 9 2>> data/archive-pack.err); then
            echo "$(date +%s)	$packed" >> data/archive-packed.log
        else
            echo "$(date -u +%FT%TZ) pack of ${made%%$'\t'*} failed: it goes unpacked" >> data/archive-pack.err
        fi
        ;;
    list) exec bin/meiolol raw-export --data data --out "$out" --list ;;
    send) name; exec cat "$(file)" ;;
    got)
        # The gpu-box has NAME: the box's file goes once its sha256 matches. Gone already:
        # a retry, which raw-export settles (received before, or an error)
        name
        [[ "${arg2:-}" =~ ^[0-9a-f]{64}$ ]] || { echo "bad sha256" >&2; exit 2; }
        f=$(file)
        if [[ -f "$f" ]]; then
            sum=$(sha256sum < "$f")
            [[ "${sum%% *}" == "$arg2" ]] || { echo "$arg: sha256 differs from the box's" >&2; exit 1; }
        fi
        sent=$(stat -c %s "$f" 2> /dev/null || echo -)
        # Raw held per day is the export's size, a pack's being about half
        size=$sent
        if [[ "$f" == *.zst ]]; then
            size=$(awk -F '\t' -v n="$arg" '$2 == n { s = $3 } END { print s }' data/archive-packed.log 2> /dev/null)
            [[ -n "$size" ]] || size=$sent
        fi
        bin/meiolol raw-export --data data --out "$out" --received "$arg"
        # Raw per day, for health.sh: how many days of it the disk takes; then bytes sent
        [[ "$sent" == - ]] || echo "$(date +%s) $arg $size $sent" >> data/archive-sent.log
        ;;
    ack)
        name
        nice -n 10 bin/meiolol raw-export --data data --out "$out" --ack "$arg"
        # The prune takes minutes after a backlog, and a long silent ssh from the gpu-box
        # can die ("message authentication code incorrect", 14-17 Oct): detached, one at a
        # time (a skipped one's rows go with the next ack's)
        setsid -f flock -n data/.archive-prune.lock nice -n 10 \
            bin/meiolol raw-export --data data --prune >> data/archive-prune.log 2>&1 < /dev/null
        ;;
    forgotten)
        tmp=$(mktemp)
        bin/meiolol forget --data data --export "$tmp" > /dev/null 2>&1
        cat "$tmp"
        rm -f "$tmp"
        ;;
    status) exec bin/meiolol raw-export --data data --status ;;
    disk)
        [[ "$arg" =~ ^c[0-9]+,wsl[0-9]+,arch([0-9]+|-)$ ]] || { echo "bad disk use" >&2; exit 2; }
        echo "$(date +%s) $arg" > data/gpu-box.disk
        ;;
    report)
        # data/gpu-box.pull: "<time> - ok" or "<time> <failing since> fail MESSAGE". Never
        # evaluated, only shown; printable and short
        msg=$(tr -cd '[:print:]' <<< "${SSH_ORIGINAL_COMMAND#report}" | cut -c1-200)
        msg=${msg# }
        state=data/gpu-box.pull
        now=$(date +%s)
        since=-
        prev=
        read -r _ since prev _ 2> /dev/null < "$state" || true
        case "$msg" in
            ok) echo "$now - ok" > "$state" ;;
            "fail "*)
                [[ "$prev" == fail && "$since" =~ ^[0-9]+$ ]] || since=$now
                echo "$now $since $msg" > "$state"
                ;;
            *) echo "bad report" >&2; exit 2 ;;
        esac
        ;;
    *) echo "archive-serve: export|list|send NAME|got NAME SHA256|ack NAME|forgotten|status|disk USE|report ok|fail MSG" >&2; exit 2 ;;
esac
