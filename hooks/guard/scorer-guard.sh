#!/usr/bin/env bash
# PreToolUse guard (matcher: Read|Edit|Write|Glob|Grep|Bash).
#
# During an active autoresearch run, deny reading OR editing the locked scorer/
# verifier files. The metric must not be edited (no moving goalposts) and must not be
# read (agents reverse-engineer verifiers they can merely see). The loop edits only the
# in-scope asset.
#
# Per-repo config: a `.autoresearch-locked` file in the repo root, one path/substring
# per line (e.g. `eval/evaluate.py`). Lines starting with `#` are comments.
#
# Deny = exit 2 + reason on stderr. Fail-OPEN on any error (never block legit work).

[ -f autoresearch.md ] || exit 0          # only while a loop is active
[ -f .autoresearch-locked ] || exit 0     # nothing declared locked here

payload="$(cat 2>/dev/null || true)"
{
  read -r tool
  read -r fpath
  read -r cmd
} < <(printf '%s' "$payload" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get("tool_input") or {}
    print(d.get("tool_name", ""))
    print(ti.get("file_path") or ti.get("path") or "")
    print((ti.get("command") or "").replace("\n", " "))
except Exception:
    pass
' 2>/dev/null)

[ -n "${tool:-}" ] || exit 0
target="${fpath:-} ${cmd:-}"

while IFS= read -r pat || [ -n "$pat" ]; do
  [ -n "$pat" ] || continue
  case "$pat" in \#*) continue ;; esac
  if printf '%s' "$target" | grep -qiF "$pat"; then
    echo "BLOCKED: '$pat' is a locked scorer/verifier path. The autoresearch loop must not read or edit it — do not change the metric and do not reverse-engineer it. Edit only the in-scope asset file(s)." >&2
    exit 2
  fi
done < .autoresearch-locked
exit 0
