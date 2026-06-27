#!/usr/bin/env bash
# PreToolUse guard (matcher: Read|Edit|Write|Bash).
#
# During an active autoresearch run, block access to credential/secret files so an
# unattended loop can't read or leak them. Example files (.env.example etc.) are allowed.
#
# Deny = exit 2 + reason on stderr. Fail-OPEN on any error.

[ -f autoresearch.md ] || exit 0          # only while a loop is active

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
target="$(printf '%s %s' "${fpath:-}" "${cmd:-}" | tr '[:upper:]' '[:lower:]')"

# Allowed example/template files first.
for exc in '.env.example' '.env.sample' '.env.template' '.env.test'; do
  case " $target " in *"$exc"*) exit 0 ;; esac
done

PATTERNS=(
  '.env' '.pem' '.key' '.p12' '.pfx'
  'id_rsa' 'id_ed25519' '.ssh/'
  'credentials.json' 'credentials.yaml' '.aws/credentials'
  'secret' 'api_key' 'apikey'
)
for pat in "${PATTERNS[@]}"; do
  if printf '%s' "$target" | grep -qiF "$pat"; then
    echo "BLOCKED: '$pat' looks like a credential/secret. Access is disabled during autoresearch runs. If this is intentional, run it yourself outside the loop." >&2
    exit 2
  fi
done
exit 0
