#!/usr/bin/env bash
# zig build ci: every script and unit deploy/box.sh copies to the box is committed, every
# unit that runs in ~/ml/meiolol is one it copies, and every bin/*.sh those scripts and
# units call is one it copies. 17 Oct: box.sh listed
# backup-serve.sh before it was committed, and two deploys failed at the scp. Runs from
# the repo root (pre-push: a clean checkout of the pushed commit)
set -euo pipefail

# The value of box.sh's `local NAME="..."` line, as words
list() {
    local line
    line=$(grep -E "^\s*local $1=\"[^\"]+\"" deploy/box.sh) \
        || { echo "check-deploy: no 'local $1=\"...\"' line in deploy/box.sh" >&2; return 1; }
    sed -E "s/.*$1=\"([^\"]+)\".*/\1/" <<< "$line"
}
read -ra scripts <<< "$(list scripts)"
read -ra units <<< "$(list units)"
(( ${#scripts[@]} )) || { echo "check-deploy: box.sh's script list is empty"; exit 1; }
(( ${#units[@]} )) || { echo "check-deploy: box.sh's unit list is empty"; exit 1; }
bad=0
for s in "${scripts[@]}"; do
    if ! git ls-files --error-unmatch "deploy/$s" > /dev/null 2>&1; then
        echo "check-deploy: box.sh copies deploy/$s, which is not committed"
        bad=1
    fi
done
for u in "${units[@]}"; do
    if ! git ls-files --error-unmatch "deploy/systemd/$u" > /dev/null 2>&1; then
        echo "check-deploy: box.sh copies deploy/systemd/$u, which is not committed"
        bad=1
    fi
done
# The box's units are those that run in ~/ml/meiolol; the gpu-box's and jomify's don't
for f in deploy/systemd/*; do
    grep -q '%h/ml/meiolol' "$f" || continue
    [[ " ${units[*]} " == *" ${f##*/} "* ]] && continue
    echo "check-deploy: $f runs in ~/ml/meiolol but box.sh doesn't copy it"
    bad=1
done
paths=()
for s in "${scripts[@]}"; do paths+=("deploy/$s"); done
for u in "${units[@]}"; do paths+=("deploy/systemd/$u"); done
for f in "${paths[@]}"; do
    [[ -f "$f" ]] || continue
    # The box's bin/ only: %h/ml/bin/ paths are the gpu-box's
    while read -r called; do
        [[ " ${scripts[*]} " == *" $called "* ]] && continue
        echo "check-deploy: $f calls bin/$called, which box.sh doesn't copy"
        bad=1
    done < <(grep -oE '(^|[^/a-z]|ml/meiolol/)bin/[a-z0-9-]+\.sh' "$f" | sed -E 's/.*bin\///' | sort -u)
done
exit "$bad"
