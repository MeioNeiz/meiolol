#!/usr/bin/env bash
# The box as a ci host (deploy/ci-run.sh, remote-build.sh --host box): its tools and
# what each run cost production. Layout on the box, all on / (~/ml is Megatron's):
# ~/meiolol-ci/ tools (zig, node, shellcheck; git from apt), repo.git, tree (the fixed
# tree), cache (emptied past 5 GB), global (zig's), jobs/ID, runs.tsv. docs/hosting.md
# "Builds on the box".
#   deploy/box-ci.sh install     git (apt, sudo), then the pinned tools; idempotent
#   deploy/box-ci.sh runs [N]    the last N runs (default 10): time, CPU, memory, the
#                                crawler's and web loop's pressure (5 min before / during,
#                                % of time stalled), site round samples, disk
#   deploy/box-ci.sh report [N]  the crawler per minute during each of the last N runs vs
#                                the 10 min before: matches, regional slot %, commits s
#   deploy/box-ci.sh disk        free on /, the ci dir's parts
set -euo pipefail
HOST=${BOX_HOST:-essex-vm}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/deploy/lib.sh"
ZIG=0.17.0
NODE=v24.22.2
SHELLCHECK=v0.11.0

case ${1-} in
    install)
        if ! ssh "$HOST" 'command -v git > /dev/null'; then
            echo "box-ci: apt-get install git"
            # sudo reads the password from stdin; never on screen
            vault get meiolol/essex-vm SUDO_PASSWORD \
                | ssh "$HOST" "sudo -S -p '' DEBIAN_FRONTEND=noninteractive apt-get install -y -q git > /dev/null"
        fi
        # shellcheck disable=SC2087 # expands here on purpose: the versions
        ssh "$HOST" bash -s << EOF
set -euo pipefail
c=\$HOME/meiolol-ci
mkdir -p \$c/tools/bin \$c/cache \$c/global \$c/jobs
cd \$c/tools
get() { [[ -e \$1 ]] && return 0; echo "box-ci: \$1"; curl -fsSL "\$2" | tar -xJ; }
get zig-x86_64-linux-$ZIG https://ziglang.org/download/$ZIG/zig-x86_64-linux-$ZIG.tar.xz
get node-$NODE-linux-x64 https://nodejs.org/dist/$NODE/node-$NODE-linux-x64.tar.xz
get shellcheck-$SHELLCHECK https://github.com/koalaman/shellcheck/releases/download/$SHELLCHECK/shellcheck-$SHELLCHECK.linux.x86_64.tar.xz
ln -sfn ../zig-x86_64-linux-$ZIG/zig bin/zig
ln -sfn ../node-$NODE-linux-x64/bin/node bin/node
ln -sfn ../shellcheck-$SHELLCHECK/shellcheck bin/shellcheck
[[ -d \$c/repo.git ]] || git init -q --bare \$c/repo.git
mkdir -p \$c/repo.git/meiolol-wasm-sizes
echo "box-ci: zig \$(bin/zig version), node \$(bin/node --version), shellcheck" \
    "\$(bin/shellcheck --version | awk '/^version/ { print \$2 }'), \$(git --version)," \
    "\$(du -sh . | cut -f1) of tools, \$(df -h --output=avail / | tail -n 1 | tr -d ' ') free on /"
EOF
        ;;
    runs)
        ssh "$HOST" "{ head -n 1 meiolol-ci/runs.tsv; tail -n +2 meiolol-ci/runs.tsv | tail -n ${2:-10}; } | column -t -s \$'\t'"
        ;;
    report)
        # crawl.log: per minute, "NNNm" per region (matches since start; a restart resets),
        # "time %, slot/..." with each region's slot % first, "writer commits N.Ns"
        # shellcheck disable=SC2016 # expands on the box
        ssh "$HOST" "n=${2:-5}"' bash -s' << 'EOF'
log=ml/meiolol/data/crawl.log
tail -n +2 meiolol-ci/runs.tsv | tail -n "$n" | while IFS=$'\t' read -r start sha code wall _; do
    s=$(date -d "$start" '+%F %T')
    b=$(date -d "$start 10 min ago" '+%F %T')
    e=$(date -d "$start $wall sec" '+%F %T')
    tail -n 50000 "$log" | awk -v b="$b" -v s="$s" -v e="$e" -v sha="$sha" -v code="$code" -v wall="$wall" '
        { t = $1 " " $2; w = t < b ? "" : t < s ? "before" : t <= e ? "during" : "" }
        w == "" { next }
        / matches\/day / {
            m = 0; for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+m$/) m += $i + 0
            if (last[w] != "" && m >= last[w]) { dm[w] += m - last[w]; nm[w]++ }
            last[w] = m
        }
        /time %, slot/ {
            split($0, parts, " \\| ")
            for (r = 2; r <= 5; r++) { split(parts[r], f, " "); slot[w] += f[2]; ns[w]++ }
            if (match($0, /writer commits [0-9.]+s/)) { cm[w] += substr($0, RSTART + 15, RLENGTH - 16); nc[w]++ }
        }
        function avg(a, n, w) { return n[w] ? sprintf("%.1f", a[w] / n[w]) : "?" }
        END {
            printf "%s %s exit %s %ss | matches/min %s -> %s | slot%% %s -> %s | commits s/min %s -> %s\n",
                s, sha, code, wall, avg(dm, nm, "before"), avg(dm, nm, "during"),
                avg(slot, ns, "before"), avg(slot, ns, "during"), avg(cm, nc, "before"), avg(cm, nc, "during")
        }'
done
EOF
        ;;
    disk)
        ssh "$HOST" 'df -h / | tail -n 1; du -sh meiolol-ci/* 2> /dev/null'
        ;;
    *) usage_of "$0" >&2; exit 2 ;;
esac
