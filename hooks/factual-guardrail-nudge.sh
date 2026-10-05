#!/usr/bin/env bash
# UserPromptSubmit hook — nudge cite-or-omit on factual / research-shaped prompts.
#
# Why: ~/.claude/CLAUDE.md carries the <factual_guardrails> rules, but they sit
# far up the context and get down-weighted on a long turn. When the *incoming*
# prompt looks like a fact task (summarise, explain, fact-check, research...),
# this re-injects the three guardrails right next to the request so they bind.
#
# Non-blocking by design: there is no reliable way for a hook to parse "is this
# claim cited", and a Stop-hook scan of the reply would be high false-positive.
# So this only NUDGES — stdout is added to context, the model still decides.
# Silent on non-factual prompts. Always exits 0.
set -uo pipefail

input=$(cat 2>/dev/null || true)
prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)
[ -z "$prompt" ] && exit 0

# Factual / research intent. Case-insensitive.
pattern='summari[sz]e|what does|what is|according to|explain|is it true|fact.?check|look up|research|cite|sources?|claims?|verify that|how does|when did|who (is|was|wrote)'

if printf '%s' "$prompt" | grep -qiE "$pattern"; then
  echo "Factual/research task detected — apply <factual_guardrails>:"
  echo "  • every claim must HAVE a source you actually opened (file:line, doc, URL); uncitable → drop"
  echo "  • quote the source verbatim before you summarise"
  echo "  • insufficient context → say \"I don't know\", don't guess"
  echo "  • HOW it surfaces obeys REGISTER: name the source in plain English"
  echo "    (\"checked the GitHub API\", \"the config still lists it\") — raw paths/line"
  echo "    numbers only when the user will open them. Having the source is mandatory;"
  echo "    printing its coordinates is not. These two rules do not conflict."
fi

exit 0
