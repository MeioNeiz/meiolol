# shellcheck shell=bash
# Helpers for the Mac-side scripts: `. "$(dirname "$0")/lib.sh"`. Not copied to the box,
# the gpu-box or jomify: scripts that run there stay self-contained

# Prints FILE's usage block: its header's lines from the first "#   deploy/" on, while
# they start "#   ". Printing lines by number (sed -n '8,20p') went stale as headers grew
usage_of() {
    awk '/^#   deploy\// { on = 1 } on && !/^#   / { exit } on { print substr($0, 3) }' "$1"
}

# A launchd agent from deploy/PLIST (its Label is the file name without .plist). Booted
# out first: bootstrap fails (error 5) on an agent already loaded
launchd_install() {
    local plist=$1
    launchctl bootout "gui/$(id -u)/${plist%.plist}" 2> /dev/null || true
    cp "$(dirname "${BASH_SOURCE[0]}")/$plist" ~/Library/LaunchAgents/
    launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/"$plist"
}

launchd_uninstall() {
    launchctl bootout "gui/$(id -u)/${1%.plist}" || true
    rm -f ~/Library/LaunchAgents/"$1"
}

# A name that goes into shell commands and paths on a host (a run, campaign or snapshot):
# letters, digits, _ . - and no ..
name_ok() { [[ "$1" =~ ^[A-Za-z0-9_.-]+$ && "$1" != *..* ]]; }

# The meiolol binary for the lab tools (`meiolol lab-place`, `lab-sweep`: src/labtools),
# built from committed HEAD, not the working tree, where other sessions' half-written
# files would break or change it. Kept by HEAD's hashes of src/labtools (std only) and
# the command glue around it, so a commit elsewhere in src doesn't rebuild it. Prints its
# path; the build's output goes to zig-out/lab-tools/build.log
lab_tools() {
    local root base key dir bin stage zig=zig
    root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
    # The main checkout's, also from deploy/lab-exp.sh's temp worktrees
    base=$(dirname "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")
    key=$(git -C "$root" rev-parse HEAD:src/labtools HEAD:src/cmd/lab.zig HEAD:src/main.zig \
        | shasum | cut -c1-16) || return 1
    dir=$base/zig-out/lab-tools
    bin=$dir/meiolol-$key
    [[ -x "$bin" ]] && { echo "$bin"; return; }
    [[ -x "$HOME/.local/bin/zig" ]] && zig=$HOME/.local/bin/zig
    mkdir -p "$dir"
    # Not on stderr: lab-run.sh reads lab-place's stderr as its answer
    { echo "building the lab tools ($key) from HEAD, ~30 s" > /dev/tty; } 2> /dev/null || true
    stage=$(mktemp -d)
    git -C "$root" archive HEAD -- src build.zig build.zig.zon | tar -x -C "$stage"
    ln -s "$base/zig-pkg" "$stage/zig-pkg"
    if ! (cd "$stage" && "$zig" build backend --prefix "$stage/out" --cache-dir "$base/.zig-cache") \
        > "$dir/build.log" 2>&1; then
        rm -rf "$stage"
        echo "lab tools: zig build failed at HEAD, see $dir/build.log" >&2
        return 1
    fi
    # Two at once both build; each renames its own copy over the other, the same binary
    cp "$stage/out/bin/meiolol" "$bin.$$" && mv -f "$bin.$$" "$bin"
    rm -rf "$stage"
    find "$dir" -name 'meiolol-*' ! -name "meiolol-$key" -mtime +7 -delete
    echo "$bin"
}
