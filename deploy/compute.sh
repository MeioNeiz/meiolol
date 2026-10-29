#!/usr/bin/env bash
# Load and queues on both hosts in one view: the Mac's load, swap, build slots
# (deploy/slots.sh) and zig compiles, naming those no slot holds; the gpu-box's League,
# load, builds (deploy/remote-build.sh) and lab slots (deploy/lab-run.sh); and where
# test, test-ui and ci would go now (deploy/place.sh). docs/compute.md
#   deploy/compute.sh [status]
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/place.sh"
slots_dir=${MEIOLOL_SLOTS_DIR:-$HOME/.cache/meiolol-slots}

mac() {
    local load cores swap used=0 waits=0 f b
    load=$(sysctl -n vm.loadavg | awk '{ print $2 }')
    cores=$(sysctl -n hw.ncpu)
    swap=$(sysctl -n vm.swapusage | sed -E 's/.*used = ([0-9.]+)M.*/\1/' | awk '{ printf "%.1f", $1 / 1024 }')
    for f in "$slots_dir"/held/*; do
        [[ -e $f ]] || continue
        b=${f##*/}
        kill -0 "${b%%-*}" 2> /dev/null || continue
        b=${b#*-}
        used=$((used + ${b%%-*}))
    done
    for f in "$slots_dir"/wait/*; do [[ -e $f ]] && waits=$((waits + 1)); done
    printf 'mac      load %s/%s  swap %s GB  slots %s/%s held, %s waiting  ' \
        "$load" "$cores" "$swap" "$used" "${MEIOLOL_SLOTS:-6}" "$waits"
    # Compiler processes and test binaries; outside = no slot holder among its ancestors,
    # named by the command that started the build
    ls "$slots_dir"/held 2> /dev/null | cut -d- -f1 > "${TMPDIR:-/tmp}/compute-held.$$"
    ps -axo pid=,ppid=,args= | awk -v heldf="${TMPDIR:-/tmp}/compute-held.$$" '
        BEGIN { while ((getline h < heldf) > 0) held[h] = 1 }
        { pid = $1; parent[pid] = $2; $1 = $2 = ""; args[pid] = substr($0, 3) }
        END {
            for (p in args) {
                a = args[p]
                if (a !~ /zig build-(exe|obj|lib) |\/\.zig-cache\/o\/[0-9a-f]+\/test /) continue
                n++; inside = 0; name = ""
                for (q = parent[p]; q > 1; q = parent[q]) {
                    if (q in held) inside = 1
                    # zig build execs its runner (maker build): its parent says who
                    if (name == "" && args[q] !~ /maker build/) {
                        name = args[q]; gsub(/[^ ]*\//, "", name); sub(/^(ba)?sh /, "", name)
                        name = substr(name, 1, 40); gsub(/ /, "_", name)
                    }
                }
                if (!inside) { out++; names[name == "" ? "?" : name]++ }
            }
            printf "zig compiles %d", n
            if (out) {
                printf " (%d outside slots:", out
                for (k in names) printf " %s x%d", k, names[k]
                printf ")"
            }
            print ""
        }'
    rm -f "${TMPDIR:-/tmp}/compute-held.$$"
}

status() {
    local st k
    mac
    st=$(probe) || st=unreachable
    if [[ $st == unreachable ]]; then
        echo "gpu-box  unreachable (asleep, off or WSL down)"
    else
        awk '
            $1 == "league" { league = $2 } $1 == "load" { load = $2 "/" $3 } $1 == "mem" { mem = $2 }
            $1 == "watcher" { watcher = $2 } $1 == "build" { build = $2 "/" $3 " held, " $4 " waiting" }
            $1 == "lab" { lab = lab sprintf(" %s %s/%s, %s queued", $2, $3, $4, $5) }
            $1 == "job" { jobs = jobs sprintf("\n         build slot %s: %s s, %s", $3, $4, substr($0, index($0, $5))) }
            END {
                printf "gpu-box  up  League %s  watcher %s  load %s  mem free %s GB  builds %s  lab%s%s\n",
                    league, watcher, load, mem, build, lab, jobs
            }' <<< "$st"
    fi
    [[ -f $PLACE_OFF ]] && echo "         gpu-box builds off (deploy/place.sh on)"
    for k in test ci test-ui; do printf 'placing  %-8s -> %s\n' "$k" "$(place "$k" "$st")"; done
}

case ${1:-status} in
    status) status ;;
    *) . "$ROOT/deploy/lib.sh"; usage_of "$0" >&2; exit 2 ;;
esac
