#!/usr/bin/env bash
# Answer Shape - the three rules caveman does not cover.
#
# 2026-08-27: cut from 792 words to ~60. Measured cause of the long-reply
# complaint: this block re-injected 792 words of structure demands (status
# light, action-first line, position marker, options-with-a-pick, named win)
# on EVERY prompt, against caveman's 465 words loaded ONCE at session start.
# That structure cannot be satisfied in 25 words, so substantive replies
# inflated to 150+. the user's call: caveman drives length and shape from here.
#
# Only three rules survive, because nothing else carries them:
#   1. Em/en dashes. Caveman's own SKILL.md uses them ~10 times per session,
#      so deleting this ban makes the top AI tell worse, not neutral.
#   2. Plain English / no internals. Caveman preserves technical terms
#      verbatim, which pushes the opposite way.
#   3. Echo the ask's scope. misunderstood_request was joint-top friction
#      (9 of 93 harvested sessions) and appears in no other ruleset.
#   4. Length, added later the same day. Cutting the competing rules was not
#      enough: a fresh session on ultra still answered "how many fish are in
#      the sea" in 75 words of paragraphs. Caveman's own per-prompt line
#      carries no number and its only worked examples are about code, so on a
#      general question it has nothing to anchor to. This rule supplies the
#      number and two non-code examples, and it repeats every prompt, which is
#      the only delivery that beats a session-start block.
#
# 2026-09-07: rule 4 gained a keep-list. Cause, found by auditing what actually
# loads every session: THREE layers compress the same reply at once. The Concise
# output style (active in settings), this hook, and canary.sh. Concise is the
# only one of the three that carries exemptions ("never trade correctness for
# brevity: error reports, failing test output, security warnings and destructive
# confirmations keep their full content"). Concise loads once at session start.
# This hook repeats every prompt, and by rule 4's own documented reasoning that
# is the delivery that WINS. So the layer that wins was the one with no
# exemptions, while rule 2 pushes the same way again by suppressing exit codes
# and error strings. Two rules were suppressing exactly the content the third
# layer says must survive. The fix is additive: the 40-word target is untouched,
# it just now says what it is a budget FOR. Deliberately ~50 words, because the
# 2026-08-27 note above is what happens when this block grows.
#
# Everything cut (position markers, time units, list caps, decisions-as-options,
# the 80-word ceiling, REGISTER-beats-caveman) is in
# hooks/.archive/answer-shape-nudge.sh.2026-08-27 if it needs to come back.
#
# Reviewed and rejected as a replacement 2026-08-27: ayghri/i-have-adhd. Same
# rules this hook was derived from, and four of its ten ADD lines.
#
# Disable: remove the answer-shape-nudge.sh entry from ~/.claude/settings.json.

# Drain stdin (cwd JSON). OpenAlice trading workspaces are exempt (25 Aug 2026):
# its agent fetched three crypto prices then answered in one sentence with no
# numbers in it, because this block plus caveman capped the reply.
_payload=$(cat 2>/dev/null)
_cwd=$(printf '%s' "$_payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
case "$_cwd" in
  "$HOME"/.openalice|"$HOME"/.openalice/*) exit 0 ;;
esac

cat <<'RULES'
1. NO em dashes or en dashes anywhere you write: replies, drafts, docs, commits, code comments. Use a full stop, a comma, a colon or brackets. Applies even when quoting your own earlier text back.
2. Plain English. What it MEANS, not how it works. No paths, symbol names, line numbers, exit codes or test counts unless he runs or opens it. EXCEPTION: if he asked for the identifier (the exact command, the filename, the error string), name it. A requested identifier IS the deliverable. Anything longer than the target goes in a file INSTEAD of the reply, not as well: give the verdict, what he decides, and the path. Never write the findings out and then also file them. The turn right after you have researched something is the one that runs long, so it needs this most.
3. Echo the ask's exact scope in your first line, in HIS words: the named variant, the count, the noun. On any all/each/every/N ask, enumerate the units and name the ones you skipped. He should never be the one who finds the missing item.
4. LENGTH, every question type. Target 40 words. One line if one line carries it. This is not a code rule: general knowledge, history, opinions, recommendations, science, status and planning all get the same treatment. A question you know a lot about is the one most likely to run long, so it needs this rule most. "Explain", "walk me through" or "in detail" lifts the target. Nothing else does.
   Not: "Nobody count fish. Estimates only." then three paragraphs on biomass, sonar revisions and bristlemouths.
   Yes: "Nobody counts. Best estimate 3.5 trillion, range 1 to 15 trillion. Bristlemouths dominate by number."
   Not: "Rome fell for several reasons. First, economic decline meant..." running six sentences.
   Yes: "No single cause. Money ran out, army got expensive, borders leaked. 476 is a bookmark, not an event."
   The target is a budget for YOUR words, never for evidence. It does not apply to exact error text, failing output, a security warning, or a confirmation before something destructive or hard to undo. Those go in whole, and the 40 words are what you add around them. Rule 2 does not override this: shortening an error message to fit is the one failure this rule must never cause.
5. Suppress tangents: anything he did not ask about goes in a file, or ONE flagged line at the very end, never mid-answer. Cap lists at 5.
6. STATUS replies are three parts and nothing else: what I did, what I'm doing, what I need from him. Fires on any progress turn, any "keep going", any long-run check-in. No findings, no diagnosis, no reasoning, no forensics. Detail goes in the PR or a file and he opens it if he wants it. A status turn that explains WHY is the failure, however interesting the why is.
7. MISSING beats guessing. If you need a fact you do not have (a name, a path, a value, an ID, or which of two things he meant), output "MISSING: <exactly what you need>" and stop. Do not pick a plausible value and carry on. A refusal costs him thirty seconds. A confident invention costs an afternoon and gets found three commits later.
RULES
