#!/usr/bin/env bash
# PreToolUse guard (matcher: Bash).
#
# During an active autoresearch run, block destructive shell commands that could wipe
# the user's work or rewrite history unattended. Normal `git push` is allowed; only
# force-push and hard-destructive ops are blocked. The patched discard path uses
# `git restore --source=HEAD ... -- .` (NOT `git clean`), so blocking `git clean` here
# does not break the loop.
#
# Deny = exit 2 + reason on stderr. Fail-OPEN on any error.

[ -f autoresearch.md ] || exit 0          # only while a loop is active

payload="$(cat 2>/dev/null || true)"
{
  read -r tool
  read -r cmd
} < <(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or {}
    print(d.get("tool_name", ""))
    print((ti.get("command") or "").replace("\n", " "))
except Exception:
    pass
' 2>/dev/null)

[ "${tool:-}" = "Bash" ] || exit 0
[ -n "${cmd:-}" ] || exit 0

PATTERNS=(
  'git push --force' 'git push -f' 'push --force' 'push -f'
  'git reset --hard' 'reset --hard'
  'git clean -f' 'git clean -d' 'git clean -x'
  'git branch -D'
  'rm -rf /' 'rm -rf ~' 'rm -rf .' 'rm -fr '
)
for pat in "${PATTERNS[@]}"; do
  if printf '%s' "$cmd" | grep -qiF "$pat"; then
    echo "BLOCKED: destructive command '$pat' is disabled during autoresearch runs. If you must discard an experiment, revert tracked edits with 'git restore --source=HEAD --staged --worktree -- <files>' and delete only the file(s) this experiment created." >&2
    exit 2
  fi
done
exit 0
