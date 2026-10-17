#!/usr/bin/env bash
# zig build ci: every script deploy/box.sh copies to the box is committed, and every
# bin/*.sh those scripts call is one box.sh copies. 17 Oct: box.sh listed
# backup-serve.sh before it was committed, and two deploys failed at the scp. Runs from
# the repo root (pre-push: a clean checkout of the pushed commit)
set -euo pipefail

line=$(grep -E '^\s*local scripts="[^"]+"' deploy/box.sh) \
    || { echo "check-deploy: no 'local scripts=\"...\"' line in deploy/box.sh"; exit 1; }
read -ra scripts <<< "$(sed -E 's/.*scripts="([^"]+)".*/\1/' <<< "$line")"
(( ${#scripts[@]} )) || { echo "check-deploy: box.sh's script list is empty"; exit 1; }
bad=0
for s in "${scripts[@]}"; do
    if ! git ls-files --error-unmatch "deploy/$s" > /dev/null 2>&1; then
        echo "check-deploy: box.sh copies deploy/$s, which is not committed"
        bad=1
    fi
done
for s in "${scripts[@]}"; do
    [[ -f "deploy/$s" ]] || continue
    # The box's bin/ only: %h/ml/bin/ paths are the gpu-box's
    while read -r called; do
        [[ " ${scripts[*]} " == *" $called "* ]] && continue
        echo "check-deploy: deploy/$s calls bin/$called, which box.sh doesn't copy"
        bad=1
    done < <(grep -oE '(^|[^/a-z])bin/[a-z0-9-]+\.sh' "deploy/$s" | sed -E 's/.*bin\///' | sort -u)
done
exit "$bad"
