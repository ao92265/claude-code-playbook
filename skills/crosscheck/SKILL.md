---
name: crosscheck
description: Read one source twice with two independent readers, then reconcile into a single spec where every line is labelled confirmed, single-source or conflict. Explicit invoke only: /crosscheck.
effort: high
---

# crosscheck

Two independent readings of one source, reconciled into one document where **every line
carries a label**. The disagreements become the review queue. Everything else is already
settled.

The value is the labelling, not the reading. A crosscheck that outputs an unlabelled summary
has failed.

## The rule that makes it work

**The readers must not see each other.** Reader B never receives reader A's output, and
neither is told what the other found. The moment one reading is contaminated by the other,
agreement stops being evidence and the whole thing is just a summary with extra steps.

## Steps

1. **Identify the source and confirm both readers can reach it.** If only one can, stop and
   say so. One reading is not a crosscheck.

2. **Take reading A and reading B independently**, using two different readers. Pick from
   what is actually installed:
   - **Preferred second reader: `codex`.** Different model, fetches its own sources.
     Invoke as `codex exec --skip-git-repo-check "..."` (it refuses to run outside a git
     repo without that flag). Allow a couple of minutes.
   - Video or talk: `/watch` (frames plus transcript) as the other reader.
   - Text, PR, doc: a Claude subagent with no shared context, or `copilot`.
   - **Do not use `gemini` on this machine.** The key is quota-exhausted: trivial prompts
     return, but any real fetch-and-read task dies on `429 RESOURCE_EXHAUSTED` after eight
     silent retries. Verified 18 Aug 2026.

   Ask both for the same thing in the same shape, so the outputs are comparable.
   Start the slower reader first and take the other reading while it runs.

3. **Reconcile line by line.** Every claim gets exactly one label:
   - `[confirmed]` both readers stated it
   - `[single-source: A]` or `[single-source: B]` only one reader saw it
   - `[conflict]` they disagree. Show both claims verbatim, side by side.

4. **Put the conflicts first.** Open with the conflict list as a numbered review queue, then
   the full labelled spec below it. The human reads the top and stops.

5. **Never resolve a conflict yourself.** Picking a side is the one thing this skill exists
   to hand back. State both readings and move on.

## Output shape

```
## Review queue (N conflicts)
1. [conflict] Reader A: "runs on port 4000". Reader B: "runs on port 8080".

## Spec
- [confirmed] Installs via Homebrew.
- [single-source: B] Needs Python 3.12 or newer.
- [conflict] see queue item 1
```

## Common issues

- **Everything comes back `[confirmed]`.** Usually means the readings were not independent,
  or both readers were the same model. Check what actually ran before trusting it.
- **A reader fails or returns nothing.** Say so and stop. Do not quietly fall back to one
  reading and present it as a crosscheck.
- **Huge single-source list from one reader.** That reader saw more of the source (full video
  vs captions only). Say which, so the imbalance is not read as disagreement.
- **Wording differs but the meaning matches.** That is `[confirmed]`, not `[conflict]`.
  Conflicts are contradictions of fact, not of phrasing.
