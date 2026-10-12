#!/usr/bin/env bash
# Starts a lab agent (docs/lab-agent.md, brief docs/lab-brief.md): a headless Claude
# Code session working in its own campaign dir outside the checkout. It may read the
# repo, edit only its campaign, and run only deploy/lab-exp.sh (never `final`). No spend
# cap (Jacob, 2026-10-12): it runs until the brief's stop rule. Log: <campaign>/agent.log
#
#   deploy/lab-agent.sh start CAMPAIGN TARGET [FOCUS]   new campaign, agent in background
#   deploy/lab-agent.sh prompt CAMPAIGN TARGET [FOCUS]  print the start message only
#   deploy/lab-agent.sh settings CAMPAIGN               print the session's permissions
#
# Env: LAB_CANDS (campaign dirs, ~/ml/agent), LAB_AGENT_FROM (starting candidate, team), LAB_AGENT_MODEL (default model when unset),
# plus lab-exp.sh's LAB_* settings. Cost, measured 2026-10-12: $1.09 for a 4-run probe
# (36 turns, 12 min); per run it grows with the session's context
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export LAB_CANDS=${LAB_CANDS:-$HOME/ml/agent}
# 3c-team: campaigns start from what's known, not from champion-role means
FROM=${LAB_AGENT_FROM:-team}

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
# every file-writing tool). Checked 2026-10-12 with a headless session told to try each:
# repo writes and edits, git, ssh and `final` denied; campaign writes, reads and
# lab-exp.sh allowed
settings() {
    local dir=$1
    cat <<EOF
{
  "env": { "LAB_CANDS": "$LAB_CANDS" },
  "permissions": {
    "allow": [
      "Bash($ROOT/deploy/lab-exp.sh *)",
      "Read",
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
        model=()
        [[ -n "${LAB_AGENT_MODEL:-}" ]] && model=(--model "$LAB_AGENT_MODEL")
        (cd "$dir" && nohup claude -p "$(prompt "$campaign" "$target" "$focus")" \
            --settings "$dir/agent-settings.json" --permission-mode acceptEdits \
            --add-dir "$ROOT" ${model[@]+"${model[@]}"} \
            > agent.log 2>&1 < /dev/null &)
        echo "agent started on $campaign ($target), log $dir/agent.log"
        ;;
    *) sed -n '7,9p' "$0"; exit 2 ;;
esac
