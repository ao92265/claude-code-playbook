---
title: GLM on Claude Code (z.AI)
nav_order: 8
parent: Configuration
---
# Running GLM inside Claude Code

Point Claude Code at Z.ai's GLM-5.2 to get a strong coding model at roughly a
sixth of Opus token cost. Two shapes: delegate one subtask to GLM from inside an
Opus session, or run a whole session on GLM. Your default `claude` stays on
Opus either way.

GLM ships an Anthropic-compatible endpoint (`https://api.z.ai/api/anthropic`),
so Claude Code talks to it with no adapter — just the standard
`ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_MODEL` env vars.

---

## Setup

Get a key from Z.ai, then add this block to `~/.zshrc`:

```bash
# === GLM (z.AI) ===
export ZAI_API_KEY="your-zai-key-here"

# Run a WHOLE Claude Code session on GLM (default `claude` stays Opus):
claude-glm() {
  ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic" \
  ANTHROPIC_AUTH_TOKEN="$ZAI_API_KEY" \
  ANTHROPIC_MODEL="glm-5.2" \
  command claude "$@"
}
```

`source ~/.zshrc`, then `claude-glm` launches Claude Code on GLM-5.2. All normal
flags pass through (`claude-glm --resume`, `claude-glm -p "..."`).

Latest model on the key is `glm-5.2` (`glm-4.7` and `glm-4.6` also work). Note:
the "GLM-5.2 free on Cloudflare Workers AI" posts describe a *different* product
— unrelated to a Z.ai key.

---

## Delegating one task to GLM (the useful mode)

You usually don't want to give up Opus. Instead, keep Opus driving and hand GLM
individual self-contained subtasks — cheap grunt work — then use its answer.

Drop this helper at `~/.claude/scripts/glm.sh`:

```bash
#!/bin/zsh
set -e
KEY="${ZAI_API_KEY:?ZAI_API_KEY not set}"
MODEL="glm-5.2"
if [[ "$1" == "-m" ]]; then MODEL="$2"; shift 2; fi
PROMPT="$*"
STDIN=""
if [[ -p /dev/stdin || -f /dev/stdin ]]; then STDIN="$(cat)"; fi
if [[ -n "$STDIN" ]]; then
  FULL=$'--- CONTEXT ---\n'"$STDIN"$'\n--- END CONTEXT ---\n\nTASK: '"$PROMPT"
else
  FULL="$PROMPT"
fi
printf '%s' "$FULL" | jq -Rs --arg m "$MODEL" \
  '{model:$m,max_tokens:4000,messages:[{role:"user",content:.}]}' \
  | curl -s -m 180 https://api.z.ai/api/anthropic/v1/messages \
      -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" -d @- \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["content"][0]["text"]) if "content" in d else sys.exit("GLM error: "+json.dumps(d))'
```

`chmod +x ~/.claude/scripts/glm.sh`, then use it:

```bash
# direct prompt (pass </dev/null in arg-only mode so it doesn't wait on stdin)
glm "write a Python function that merges overlapping intervals" < /dev/null

# pipe a file in as context
cat handler.py | glm "review for bugs, list max 5"

# model override
glm -m glm-4.7 "prompt" < /dev/null
```

Because it's just a shell command, Claude Code (running Opus) can call it itself
mid-session — say "delegate this to GLM" and it runs `glm ...`, then folds the
result back into its work. GLM runs as a *tool inside* the session, not a
replacement for it.

---

## When to reach for GLM

**Good fit**

- Isolated subtasks: boilerplate, one-off codegen, a quick review, a throwaway
  draft, format conversion.
- Bulk or cost-sensitive work where Opus-grade judgement isn't needed.
- A cheap second opinion to compare against Opus.

**Keep on Opus**

- Multi-step orchestration, or anything that leans on your hooks/agents/skills —
  GLM sees none of that, it's raw prompt in, text out.
- Correctness-critical single-shot work. In a small head-to-head, GLM-5.2 matched
  Sonnet 5 on straightforward coding (merge-intervals, a thread-safe LRU cache —
  both correct) but on a bug-diagnosis trap it reached the right insight and then
  hallucinated mid-answer. It also self-identifies as "Gemini." Verify its output.

---

## Limits worth knowing

- You can't route Claude Code's native subagents (the Task tool / `/agent`) to
  GLM — those are Anthropic-model-only, no per-agent endpoint override. The shell
  helper is the only way to reach GLM from inside a session.
- No automatic offloading. You (or Claude, with a stated reason) decide what to
  hand off.
- Treat the key like any secret — env var, not committed.

---

## Quick verification

```bash
glm "reply with exactly: GLM OK" < /dev/null     # -> GLM OK
```

If that returns `GLM OK`, the endpoint, key, and helper are all wired correctly.
