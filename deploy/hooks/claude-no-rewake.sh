#!/bin/sh
# Claude Code PreToolUse hook on SendMessage (.claude/settings.json): refuses messages to
# subagents, which rewake a finished agent. Jacob never wants that. Blocks a name or id
# this session's subagents/*.meta.json records, or an agent-id shape; everything else is a
# session (cc-peers here, Remote Control ones on the gpu-box), which cc-peers can't list.
# Exit 2 blocks the call, stderr goes back to Claude.
# Test: deploy/hooks/claude-no-rewake.sh --test
if [ "${1:-}" = --test ]; then
    self=$0
    fails=0
    tmp=$(mktemp -d)
    mkdir -p "$tmp/s1/subagents"
    echo '{"name":"search","finished":true}' >"$tmp/s1/subagents/agent-a1b2c3d4e5f6a7b8c.meta.json"
    echo '{"finished":true}' >"$tmp/s1/subagents/agent-a99887766554433221.meta.json"
    send() {
        jq -n --arg t "$1" --arg p "$tmp/s1.jsonl" '{transcript_path: $p, tool_input: {to: $t}}' |
            "$self" 2>/dev/null
    }
    peer=$(cc-peers --tsv 2>/dev/null | cut -f1 | head -1)
    for t in main parent uds:/tmp/cc-socks/1.sock "$peer" "$peer [3fa9c1]" pc-rctest \
        champion-curves-explained; do
        [ -n "$t" ] || continue
        send "$t" || { echo "want 0: $t"; fails=1; }
    done
    for t in search a1b2c3d4e5f6a7b8c a99887766554433221 a273faa3b80dfda2e; do
        send "$t"
        [ $? = 2 ] || { echo "want 2: $t"; fails=1; }
    done
    rm -rf "$tmp"
    [ $fails = 0 ] && echo "all pass"
    exit $fails
fi

input=$(cat)
to=$(printf '%s' "$input" | jq -r '.tool_input.to // empty')
case $to in
    main | parent | uds:*) exit 0 ;;
esac
name=${to%% \[*}
block() {
    echo "Blocked: \"$to\" is $1, so this would rewake it." \
        "Never rewake agents: spawn a fresh Agent, or do the work yourself." >&2
    exit 2
}
if printf '%s' "$name" | grep -qE '^a[0-9a-f]{15,}$'; then
    block "an agent id"
fi
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
dir=${transcript%.jsonl}/subagents
if [ -n "$transcript" ] && [ -d "$dir" ]; then
    [ -e "$dir/agent-$name.meta.json" ] && block "a subagent of this session"
    for m in "$dir"/*.meta.json; do
        [ -e "$m" ] || continue
        [ "$(jq -r '.name // empty' "$m")" = "$name" ] && block "a subagent of this session"
    done
fi
exit 0
