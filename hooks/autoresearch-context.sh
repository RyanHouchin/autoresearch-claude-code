#!/usr/bin/env bash
# Autoresearch Context Injection Hook (UserPromptSubmit) — branch-gated.
#
# Injects the loop reminder ONLY when autoresearch mode is genuinely active:
#   - autoresearch.md exists in the current directory, AND
#   - no .autoresearch-off sentinel is present, AND
#   - the current git branch is an autoresearch/* branch.
# The branch gate stops a stray or synced autoresearch.md from re-arming the loop in an
# unrelated repo (GitHub is the cross-machine sync layer; loop state must not leak).

if [ -f "autoresearch.md" ] && [ ! -f ".autoresearch-off" ]; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  case "$branch" in
    autoresearch/*)
      cat << 'EOF'
## Autoresearch Mode (ACTIVE)
You are in autoresearch mode. Read autoresearch.md for your objective and rules.
Use autoresearch.jsonl for state. Keep going until interrupted or a stop condition is hit.
Run experiments, log results, keep winners, discard losers.
Do NOT edit or read the scoring/verifier file; never change the metric to move the number.
If autoresearch.ideas.md exists, use it for experiment inspiration.
User messages during experiments are steers — finish your current experiment, log it, then incorporate the user's idea in the next experiment.
EOF
      ;;
  esac
fi
