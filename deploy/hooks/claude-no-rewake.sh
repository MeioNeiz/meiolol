#!/bin/sh
# Claude Code PreToolUse hook on SendMessage (.claude/settings.json): refuses messages to
# subagents, which rewake a finished agent. Jacob never wants that. Allowed: a subagent
# to its parent (main, parent), and other sessions (team runs): a uds: socket or a name
# cc-peers lists. Exit 2 blocks the call, stderr goes back to Claude.
# Test: deploy/hooks/claude-no-rewake.sh --test
if [ "${1:-}" = --test ]; then
    self=$0
    fails=0
    peer=$(cc-peers --tsv 2>/dev/null | cut -f1 | head -1)
    for t in main parent uds:/tmp/cc-socks/1.sock "$peer" "$peer [3fa9c1]"; do
        [ -n "$t" ] || continue
        jq -n --arg t "$t" '{tool_input: {to: $t}}' | "$self" 2>/dev/null ||
            { echo "want 0: $t"; fails=1; }
    done
    for t in a273faa3b80dfda2e search champion-curves-explained meiolol-zz; do
        jq -n --arg t "$t" '{tool_input: {to: $t}}' | "$self" 2>/dev/null
        [ $? = 2 ] || { echo "want 2: $t"; fails=1; }
    done
    [ $fails = 0 ] && echo "all pass"
    exit $fails
fi

to=$(jq -r '.tool_input.to // empty')
case $to in
    main | parent | uds:*) exit 0 ;;
esac
name=${to%% \[*}
if [ -n "$name" ] && cc-peers --tsv 2>/dev/null | cut -f1 | grep -qxF "$name"; then
    exit 0
fi
echo "Blocked: \"$to\" is not a live session (cc-peers), so this would rewake a subagent." \
    "Never rewake agents: spawn a fresh Agent, or do the work yourself." >&2
exit 2
