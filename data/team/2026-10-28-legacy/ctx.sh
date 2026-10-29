#!/bin/bash
# Context in use per session: the last assistant turn with nonzero input + cache tokens
P=~/.claude/projects/-Users-jacobmaschler-personal-meiolol
for n in "$@"; do
  id=$(cc-roster 2>/dev/null | awk -F'\t' -v n="$n" '$2==n{print $1}')
  f=$P/$id.jsonl
  [ -f "$f" ] || { echo "$n ?"; continue; }
  tac "$f" | grep '"usage"' | head -50 | dpy -c "
import sys,json
for l in sys.stdin:
    u=json.loads(l).get('message',{}).get('usage') or {}
    t=u.get('input_tokens',0)+u.get('cache_read_input_tokens',0)+u.get('cache_creation_input_tokens',0)
    if t: print('$n', round(t/1000),'k'); break"
done
