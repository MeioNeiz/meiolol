#!/usr/bin/env bash
# Starts a lab agent (docs/lab-agent.md, brief docs/lab-brief.md): a headless Claude
# Code session working in its own campaign dir outside the checkout. It may read the
# repo (not .env or data/), edit only its campaign, and run only deploy/lab-exp.sh (never
# `final`). No spend cap (Jacob, 2026-10-12): it runs until the brief's stop rule, or at
# most LAB_AGENT_MAX_RUNS runs (default 150, five times the brief's 30-run stop rule; empty
# for none), after which lab-exp.sh tells it to stop and report. Log: <campaign>/agent.log
#
#   deploy/lab-agent.sh start CAMPAIGN TARGET [FOCUS]   new campaign, agent in background
#   deploy/lab-agent.sh prompt CAMPAIGN TARGET [FOCUS]  print the start message only
#   deploy/lab-agent.sh settings CAMPAIGN               print the session's permissions
#
# Env: LAB_CANDS (campaign dirs, ~/ml/agent), LAB_AGENT_FROM (starting candidate, team2),
# LAB_AGENT_MODEL (default model when unset), LAB_AGENT_MAX_RUNS (150), LAB_AGENT_MAX_USD
# (claude --max-budget-usd; unset: none), plus lab-exp.sh's LAB_* settings. Cost, measured
# 2026-10-12: $1.09 for a 4-run probe (36 turns, 12 min); per run it grows with context
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export LAB_CANDS=${LAB_CANDS:-$HOME/ml/agent}
# 3c-team2: campaigns start from what's known, not from champion-role means
FROM=${LAB_AGENT_FROM:-team2}
MAX_RUNS=${LAB_AGENT_MAX_RUNS-150}

prompt() {
    local campaign=$1 target=$2 focus=${3:-}
    cat <<EOF
Read $ROOT/docs/lab-brief.md and follow it. Campaign: $campaign (your working directory,
$LAB_CANDS/$campaign). Target: $target. Run tool: $ROOT/deploy/lab-exp.sh.
${focus:+Focus for this campaign: $focus.}
Start with diagnose on $target, then work the loop until you stop. End with a short
report: confirmed hypotheses with run ids, what you parked, and why you stopped.
EOF
}

# Permissions for the agent session (absolute path rules start with //; Edit rules cover
# every file-writing tool, Read rules Grep and Glob too). Reads: the repo and the
# campaign only, never .env (the Riot key), data/ (snapshots hold the test labels) or
# ~/.ssh. The session loads no user settings (Jacob's allow vault, cc-peers, wezterm) and
# no MCP servers, and runs in dontAsk: whatever these rules don't allow is refused. No
# --add-dir or acceptEdits: both let file commands (cp, mv, rm) run unasked in the shared
# checkout. Checked 2026-10-13 with a headless session told to try each: Read, Write,
# Edit, cp, cat, wc, grep and find on .env, data/ and ~/.ssh, repo writes, vault, mkdir
# and env-prefixed lab-exp.sh denied; repo and campaign reads, campaign edits and
# lab-exp.sh allowed. Jacob's model and session settings (model, effort, compaction,
# language, memory) are carried over, nothing else
settings() {
    local dir=$1 carried
    carried=$(jq -c '{model, effortLevel, modelSettings, autoCompactEnabled, language,
        autoMemoryEnabled} | with_entries(select(.value != null))' \
        ~/.claude/settings.json 2>/dev/null || echo '{}')
    jq --argjson carried "$carried" '$carried + .' <<EOF
{
  "env": { "LAB_CANDS": "$LAB_CANDS", "LAB_MAX_RUNS": "$MAX_RUNS" },
  "permissions": {
    "allow": [
      "Bash($ROOT/deploy/lab-exp.sh *)",
      "Read(/$ROOT/**)",
      "Read(/$dir/**)",
      "Edit(/$dir/**)"
    ],
    "deny": [
      "Bash($ROOT/deploy/lab-exp.sh final*)",
      "Bash($ROOT/deploy/lab-exp.sh preds*)",
      "Bash(git *)",
      "Bash(ssh *)",
      "Bash(scp *)",
      "Bash(rsync *)",
      "Bash(curl *)",
      "Edit(/$ROOT/**)",
      "Read(/$ROOT/.env*)",
      "Read(/$ROOT/data/**)",
      "Read(~/.ssh/**)",
      "WebFetch",
      "WebSearch"
    ]
  }
}
EOF
}

cmd=${1:-}
if [[ "$cmd" == settings && $# == 2 ]]; then settings "$LAB_CANDS/$2"; exit 0; fi
(( $# >= 3 )) || { sed -n '7,9p' "$0"; exit 2; }
campaign=$2 target=$3 focus=${4:-}
case "$cmd" in
    prompt) prompt "$campaign" "$target" "$focus" ;;
    start)
        "$ROOT/deploy/lab-exp.sh" new "$campaign" "$FROM"
        dir=$LAB_CANDS/$campaign
        settings "$dir" > "$dir/agent-settings.json"
        flags=()
        [[ -n "${LAB_AGENT_MODEL:-}" ]] && flags=(--model "$LAB_AGENT_MODEL")
        [[ -n "${LAB_AGENT_MAX_USD:-}" ]] && flags+=(--max-budget-usd "$LAB_AGENT_MAX_USD")
        # Redirect the whole subshell and exec: a subshell left waiting on claude keeps
        # the caller's stdout open, so a caller reading it (a pipe, a Claude Bash call)
        # hangs until the campaign ends
        (cd "$dir" && exec nohup claude -p "$(prompt "$campaign" "$target" "$focus")" \
            --settings "$dir/agent-settings.json" --setting-sources "" --strict-mcp-config \
            --permission-mode dontAsk ${flags[@]+"${flags[@]}"}) \
            > "$dir/agent.log" 2>&1 < /dev/null &
        echo "agent started on $campaign ($target), log $dir/agent.log"
        ;;
    *) sed -n '7,9p' "$0"; exit 2 ;;
esac
