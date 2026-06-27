# Hardening (Ryan's fork)

This fork adds safety on top of `drivelineresearch/autoresearch-claude-code` for
unattended, cross-repo, overnight runs. Two parts: changes that are **already live**,
and **opt-in PreToolUse guards** that need a one-time wiring + a restart to verify.

## Already live (in SKILL.md + the context hook)

- **Safe discard.** The discard path no longer runs a blanket `git clean -fd` (which
  deletes the user's untracked source/harness/scorer). It does a scoped
  `git restore --source=HEAD --staged --worktree -- .` and removes only files an
  experiment created. Precondition: a clean/committed working tree before looping.
- **Fit-check gate** at setup (objective number / fast loop / editable asset / a
  tripwire + a visual checkpoint for proxy metrics).
- **Loop rules:** never edit OR read the scorer/metric; per-instance floor (no kept
  change may regress any case below its archived best); stop budget; `.autoresearch-off`
  kill switch.
- **Loop-state not committed**, and the UserPromptSubmit context hook is **branch-gated**
  to `autoresearch/*` so a synced `autoresearch.md` can't re-arm the loop elsewhere.

## Opt-in PreToolUse guards (`hooks/guard/`) — wire once, verify on restart

These are mechanical enforcement (prose in SKILL.md is advisory; these are teeth). All
three are **gated to active runs** (no-op unless `autoresearch.md` exists in cwd),
**fail-open** (never block on their own error), and **deny via exit code 2 + stderr**.
Unit-tested with sample payloads; CC invocation must be confirmed after a restart.

| guard | matcher | blocks |
|-------|---------|--------|
| `scorer-guard.sh` | Read,Edit,Write,Glob,Grep,Bash | reading/editing locked scorer files (see `.autoresearch-locked`) |
| `dangerous-cmd-block.sh` | Bash | force-push, `reset --hard`, `git clean -f/-d/-x`, `branch -D`, `rm -rf /~.` |
| `privacy-block.sh` | Read,Edit,Write,Bash | `.env`/`.pem`/`.key`/`id_rsa`/`.ssh/`/`credentials`/`api_key` (allows `*.example`) |

`scorer-guard.sh` reads a per-repo **`.autoresearch-locked`** file (one path/substring
per line, e.g. `eval/evaluate.py`). The loop's setup should write it; absent = no-op.

### Wiring (skills-dir + manual model — what this machine uses)

Add to `~/.claude/settings.json` under `hooks.PreToolUse` (merge into the array), then
restart Claude Code. Do NOT also enable this repo as a plugin, or hooks double-fire.

```json
"PreToolUse": [
  { "matcher": "Read|Edit|Write|Glob|Grep|Bash",
    "hooks": [{"type":"command","command":"/Users/ryanhouchin/Code/tools/autoresearch-claude-code/hooks/guard/scorer-guard.sh","timeout":10}] },
  { "matcher": "Read|Edit|Write|Bash",
    "hooks": [{"type":"command","command":"/Users/ryanhouchin/Code/tools/autoresearch-claude-code/hooks/guard/privacy-block.sh","timeout":10}] },
  { "matcher": "Bash",
    "hooks": [{"type":"command","command":"/Users/ryanhouchin/Code/tools/autoresearch-claude-code/hooks/guard/dangerous-cmd-block.sh","timeout":10}] }
]
```

(Plugin users get the same wiring automatically from `hooks/hooks.json`.)

### Verify after restart

In a throwaway dir: `touch autoresearch.md && echo 'eval/evaluate.py' > .autoresearch-locked`,
then ask Claude to read `eval/evaluate.py` (should be denied) and to read a normal file
(should work). Remove `autoresearch.md` and confirm the deny disappears (gate works).

## Still deferred

- A private marketplace + SHA pin — only once a second skill exists or studio/laptop
  drift bites. Forking already preserves edits; the pin is redundant until then.
- Periodic `git fetch upstream && merge` — the fork is permanent; budget light upkeep.
