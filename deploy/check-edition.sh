#!/usr/bin/env bash
# The public desktop exe holds no private-edition module (docs/plan/app.md "Two
# editions"): `zig build ci` on Debug builds, deploy/desktop-release.sh on the release
# ones. The names are the paths dvui's @src() leaves in the exe for each module whose
# widgets are compiled in, so the private exe must hold every one, or the check proves
# nothing. Runs from the repo root.
# Usage: deploy/check-edition.sh PUBLIC_EXE PRIVATE_EXE
set -euo pipefail

public=$1
private=$2
for exe in "$public" "$private"; do
    [[ -s $exe ]] || { echo "check-edition: no exe at $exe" >&2; exit 1; }
done
bad=0
for f in src/desktop/private/*.zig; do
    name=${f#src/}
    if ! grep -aqF "$name" "$private"; then
        echo "check-edition: $name not in the private exe: a module it no longer compiles in, or the check went blind" >&2
        bad=1
    fi
done
if found=$(grep -aoE 'desktop/private/[A-Za-z0-9_/]+\.zig' "$public" | sort -u) && [[ -n $found ]]; then
    echo "check-edition: the public exe holds private modules (gate them with widgets.private_code):" >&2
    echo "$found" >&2
    bad=1
fi
exit "$bad"
