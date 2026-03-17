# Step 2: Your First Session (30 minutes)

## Start Claude Code

Navigate to your project directory and start a session:

```bash
cd /path/to/your/project
claude
```

Claude reads your CLAUDE.md automatically. You should see the session start.

## Exercise 1: Environment Check (5 min)

Type:

```
/check-env
```

This validates your development environment. Review the output:
- Are all required services running?
- Any port conflicts?
- GitHub credentials working?
- Node.js / Python / Go version correct?

**Fix any issues it finds before continuing.**

## Exercise 2: Understand Code (5 min)

Pick a file in your project and ask Claude to explain it:

```
/explain src/services/user-service.ts
```

Notice how Claude gives a one-liner first, then goes deeper. You can ask "go deeper on the authentication part" to drill in.

## Exercise 3: Fix a Real Bug (10 min)

Find a small bug or failing test and fix it. Use this prompt format:

```
This test fails with "[paste exact error]" when [describe condition].
Fix it. Only modify files in [directory]. Don't change the test.
```

**Key things to notice:**
- Claude reads the relevant files before making changes
- The `ts-check.sh` hook runs automatically after each edit
- Claude runs tests to verify the fix before claiming done

## Exercise 4: Session Handoff (5 min)

End your session by writing a handoff:

```
/handoff
```

This creates `SESSION_NOTES.md` with what was done, what's left, and any gotchas. Open the file and read it — this is what the next person (or your next session) would see.

## Exercise 5: Context Management (5 min)

Check your context usage:

```
/context
```

Try these commands:
- `/compact` — Compress the conversation (use at 50% context)
- `/clear` — Wipe context for a new task (use when switching tasks)

## What You Learned

1. **`/check-env`** catches environment issues before they waste your time
2. **`/explain`** gives layered explanations adapted to your needs
3. **Hooks run automatically** — you don't need to remember to type-check
4. **`/handoff`** creates structured session summaries for continuity
5. **Context management** (`/compact`, `/clear`) keeps Claude sharp

---

**Next: [03-daily-workflow.md](03-daily-workflow.md)** — The daily pattern
