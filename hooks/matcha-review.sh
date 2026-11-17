#!/bin/zsh
# matcha-review - Stop hook. Sends the working diff to Matcha for an
# independent read-only review, in the background, billed to ParentCo rather
# than the subscription. Never blocks the stop, never edits anything.
#
# Findings are not printed here (the turn is already over). They are picked up
# by matcha-surface.sh on the next prompt, so nothing has to be remembered.
exec 2>/dev/null
[[ -n "$CLAUDE_SKIP_HOOKS" && "$CLAUDE_SKIP_HOOKS" == *matcha* ]] && exit 0

STATE="$HOME/.claude/.matcha-review"
mkdir -m 700 -p "$STATE"

CWD="$(pwd)"
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
REPO="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" || exit 0
KEY="$(printf '%s' "$REPO" | shasum | cut -c1-12)"

# Opt-in per repo: the diff leaves the machine, so only repos listed (one
# absolute path per line) in this file are ever sent.
grep -qxF "$REPO" "$HOME/.claude/matcha-review.allow" 2>/dev/null || exit 0

DIFF="$(git -C "$REPO" diff HEAD 2>/dev/null)"
[[ -n "$DIFF" ]] || exit 0

# Never send a diff that holds something that looks like a secret. The whole
# diff goes to the gateway, so removed lines and unchanged context lines count
# too. Only the file header lines are left out.
printf '%s\n' "$DIFF" | grep -vE '^(\+\+\+|---) (a/|b/|/dev/null)' | grep -qiE \
  'AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[abpr]-[A-Za-z0-9-]{10,}|(^|[^A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}|(api[_-]?key|secret|token|passw(or)?d)["'\'' ]*[=:]["'\'' ]*[A-Za-z0-9/+_.-]{16,}' && exit 0

LINES=$(printf '%s' "$DIFF" | wc -l | tr -d ' ')
# Below 15 changed lines there is nothing worth 20p. Above 3000 the prompt
# costs more than the review is worth and the delegate loses the thread.
[[ $LINES -lt 15 || $LINES -gt 3000 ]] && exit 0

HASH="$(printf '%s' "$DIFF" | shasum | cut -c1-16)"
MARK="$(cat "$STATE/$KEY.hash" 2>/dev/null)"
[[ "${MARK%%.*}" == "$HASH" ]] && exit 0

# Daily spend ceiling. A stop hook that fires all day is how a delegate quietly
# runs up a bill nobody authorised.
TODAY="$(date +%Y-%m-%d)"
SPENT_F="$STATE/spend-$TODAY"
[[ -f "$SPENT_F" ]] || echo 0 > "$SPENT_F"
COUNT="$(cat "$SPENT_F")"
CEILING="${MATCHA_REVIEW_DAILY_MAX:-12}"
[[ $COUNT -ge $CEILING ]] && exit 0
echo $((COUNT + 1)) > "$SPENT_F"

# Mark the diff before launching, so stops during a long run do not start the
# same review again. A failed run removes the mark so the next stop retries.
# The mark is "<hash>.<pid>", so each run can tell whether it still owns it.
TOKEN="$HASH.$$"
printf '%s' "$TOKEN" > "$STATE/$KEY.hash"
OUT="$STATE/$KEY.findings"
# Own temp file per run, so two overlapping reviews cannot mix their output.
TMP="$OUT.$$.tmp"
BRANCH="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"

PROMPT="You are a second reviewer on a working diff. Another reviewer has already seen it, so only report what a careful reader would still flag.

Repo: $(basename "$REPO")   Branch: $BRANCH
You can read the surrounding source in this directory for context. Do not suggest edits, do not rewrite code. New files that are not tracked by git yet are not in the diff, so say so if the change seems to depend on one.

Look for: logic that is wrong for a real input, a case the change does not handle, state that can be observed half updated, an assumption the surrounding code does not actually hold, and anything the diff claims in a comment or message that the code does not do.

Ignore: style, naming, formatting, test coverage as a topic, and anything you cannot tie to a concrete failing input.

Output strictly: one line VERDICT, then at most 5 bullets, each naming the input or condition and what breaks. If nothing is worth raising, reply with exactly: CLEAN.

--- DIFF ---
$DIFF"

# Detach fully (stdin, stdout, stderr) so the hook's pipes close at once and the
# Stop hook never waits on the review.
{ nohup "$HOME/.claude/skills/matcha/matcha-run.sh" --dir "$REPO" --tier deep \
  --budget 0.60 --timeout 540 "$PROMPT" > "$TMP" 2>"$OUT.log"; RC=$?; \
  if [[ "$(cat "$STATE/$KEY.hash" 2>/dev/null)" == "$TOKEN" ]]; then \
    if (( RC == 0 )); then mv "$TMP" "$OUT" || rm -f "$STATE/$KEY.hash"; \
    else rm -f "$STATE/$KEY.hash"; fi; \
  fi; \
  rm -f "$TMP"; } </dev/null >/dev/null 2>&1 &
disown 2>/dev/null
exit 0
