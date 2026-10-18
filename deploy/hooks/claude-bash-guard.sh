#!/bin/sh
# Claude Code PreToolUse hook on Bash (.claude/settings.json): refuses commands that fail
# in zsh before they run, with the fixed form. Exit 2 blocks the call, stderr goes back
# to Claude. Rules, on unquoted words only (quotes, \ escapes, comments, heredoc bodies
# skipped):
# - glob in --include=/--exclude=/--exclude-dir= or after find -name/-path: zsh expands
#   it or fails "no matches found"
# - * or ? in a URL: same failure
# - $VAR as the command when VAR was set to a string with a space in the same command:
#   zsh doesn't split it, "command not found"
# Test: deploy/hooks/claude-bash-guard.sh --test
# shellcheck disable=SC2016 # test commands hold literal $VAR on purpose
if [ "${1:-}" = --test ]; then
    self=$0
    fails=0
    check() {
        want=$1
        shift
        printf '%s' "$1" | jq -Rs '{tool_input: {command: .}}' | "$self" 2>/dev/null
        got=$?
        if [ "$got" != "$want" ]; then
            echo "want $want got $got: $1"
            fails=1
        fi
    }
    check 2 'grep -rn foo src --include=*.zig'
    check 2 'cd x; grep -rln "a b" src --exclude-dir=.zig* | head'
    check 2 'find . -name *.zig -newer x'
    check 2 'josearch lead https://example.com/?p=325 "why"'
    check 2 'J="ssh -i k host"; $J ls'
    check 2 'X="a b"
${X} c'
    check 0 "grep -rn foo src --include='*.zig'"
    check 0 'grep -rn foo src --include="*.zig" --include=\*.md'
    check 0 'find . -name "*.zig"'
    check 0 'ls src/*.zig deploy/*.sh'
    check 0 'curl -s "https://example.com/?p=1"'
    check 0 'S=/tmp/x; $S/run.sh; echo "--include=*.zig"'
    check 0 '# grep --include=*.zig is wrong
true'
    check 0 "python3 - <<'EOF'
print('--include=*.zig https://x/?a')
EOF
echo done"
    check 0 'echo "n: $(curl -s "https://x.com/ids?q=$q" | wc -l) $((1 + 2))"'
    check 2 'echo "$(curl -s https://x.com/ids?q=1)"'
    check 0 'git log --oneline -3'
    check 0 'J=x; $J'
    [ $fails = 0 ] && echo "all pass"
    exit $fails
fi

cmd=$(jq -r '.tool_input.command // empty')
case $cmd in
    *--include=* | *--exclude* | *-name* | *-path* | *://* | *'$'*) ;;
    *) exit 0 ;;
esac
msg=$(printf '%s' "$cmd" | awk '
function unq(s) { gsub(/["'\''\\]/, "", s); return s }
function endword(   name, val) {
    if (w == "") return
    if (glob && w ~ /^--(include|exclude|exclude-dir)=/) {
        val = unq(w); sub(/^[^=]*=/, "", val)
        out = out sprintf("unquoted glob in %s: zsh expands it; write %s'\''%s'\''\n", \
            w, substr(w, 1, index(w, "=")), val)
    } else if (glob && prev ~ /^-(i?name|i?path|i?wholename)$/) {
        out = out sprintf("unquoted glob after %s: write %s '\''%s'\''\n", prev, prev, unq(w))
    } else if (glob && w ~ /:\/\//) {
        out = out sprintf("unquoted * or ? in URL %s: zsh fails \"no matches found\"; " \
            "quote it: '\''%s'\''\n", w, unq(w))
    }
    if (cmdpos && w ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
        name = substr(w, 1, index(w, "=") - 1)
        spacey[name] = spaced
        cmdpos = 2
    } else if (cmdpos && w ~ /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/) {
        name = w; gsub(/[${}]/, "", name)
        if (spacey[name])
            out = out sprintf("%s as a command: zsh does not split variables, so \"%s\" " \
                "runs as one word; write the command out (or use an ssh alias)\n", w, name)
    }
    prev = unq(w)
    w = ""; glob = 0; spaced = 0
    if (cmdpos == 2) cmdpos = 1; else cmdpos = 0
}
{ text = text $0 "\n" }
END {
    n = length(text); q = 0; cmdpos = 1; hd = ""
    for (i = 1; i <= n; i++) {
        c = substr(text, i, 1)
        if (q == 1) { w = w c; if (c == "'\''") q = 0; else if (c == " ") spaced = 1; continue }
        # $( ) inside double quotes has its own quoting: scan it as a fresh command
        if (c == "$" && substr(text, i + 1, 1) == "(") {
            endword(); sp++; st[sp] = q; pd[sp] = 0; q = 0; cmdpos = 1; i++
            continue
        }
        if (q == 2) {
            w = w c
            if (c == "\\") { i++; w = w substr(text, i, 1) }
            else if (c == "\"") q = 0
            else if (c == " ") spaced = 1
            continue
        }
        if (c == "\\") { i++; w = w c substr(text, i, 1); continue }
        if (c == "'\''") { q = 1; w = w c; continue }
        if (c == "\"") { q = 2; w = w c; continue }
        if (c == "#" && w == "") {
            while (i <= n && substr(text, i, 1) != "\n") i++
            i--; continue
        }
        if (c == "<" && substr(text, i, 2) == "<<" && substr(text, i, 3) != "<<<") {
            endword()
            rest = substr(text, i + 2)
            if (match(rest, /^-?[ \t]*['\''"]?[A-Za-z_0-9]+/)) {
                hd = substr(rest, 1, RLENGTH); gsub(/^-?[ \t]*['\''"]?/, "", hd)
                i += 1 + RLENGTH
                if (substr(text, i + 1, 1) ~ /['\''"]/) i++
            } else i++
            continue
        }
        if (c == " " || c == "\t") { endword(); continue }
        if (sp > 0 && c == "(") pd[sp]++
        if (sp > 0 && c == ")" && pd[sp]-- == 0) { endword(); q = st[sp--]; continue }
        if (c == "\n" || c == ";" || c == "&" || c == "|" || c == "(" || c == ")") {
            endword(); cmdpos = 1
            if (c == "\n" && hd != "") {
                # skip the heredoc body up to its terminator line
                while (i < n) {
                    j = index(substr(text, i + 1), "\n")
                    if (j == 0) { i = n; break }
                    line = substr(text, i + 1, j - 1); i += j
                    sub(/^\t+/, "", line)
                    if (line == hd) break
                }
                hd = ""
            }
            continue
        }
        if (c == "<" || c == ">") { endword(); continue }
        if (c == "*" || c == "?" || c == "[") glob = 1
        w = w c
    }
    endword()
    printf "%s", out
}')
[ -z "$msg" ] && exit 0
printf 'bash guard (deploy/hooks/claude-bash-guard.sh):\n%s\n' "$msg" >&2
exit 2
