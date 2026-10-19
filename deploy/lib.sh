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
