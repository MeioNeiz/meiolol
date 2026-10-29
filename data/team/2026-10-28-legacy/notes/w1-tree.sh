#!/bin/sh
# notes/w1-tree.sh MINE_DIR CMD PATH...: HEAD + the working tree's PATHS (edits, new
# files) in the clean tree .git/meiolol-build/w1, then MINE_DIR's build.zig, root.zig
# (src/site/ui/root.zig) and pipeline_test.zig over the shared ones if present, then CMD
# there, e.g. 'zig build test --cache-dir "$root/.zig-cache"' or 'zig build backend
# --prefix /abs/out --cache-dir "$root/.zig-cache"'
mine=$1 cmd=$2
shift 2
root=$(git rev-parse --show-toplevel)
exec "$root/deploy/slots.sh" 1 "$root/deploy/build-tree.sh" w1 "$(git rev-parse HEAD)" sh -c '
    root=$1 mine=$2 cmd=$3
    shift 3
    tree=$(pwd)
    git -C "$root" diff --binary HEAD -- "$@" | git apply --allow-empty || exit 1
    git -C "$root" ls-files -z --others --exclude-standard -- "$@" \
        | (cd "$root" && xargs -0 -I{} rsync -R {} "$tree/")
    [ ! -f "$mine/build.zig" ] || cp "$mine/build.zig" build.zig
    [ ! -f "$mine/root.zig" ] || cp "$mine/root.zig" src/site/ui/root.zig
    [ ! -f "$mine/pipeline_test.zig" ] || cp "$mine/pipeline_test.zig" src/pipeline_test.zig
    eval "$cmd"' _ "$root" "$mine" "$cmd" "$@"
