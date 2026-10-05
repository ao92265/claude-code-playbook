---
description: Convene a tribune on a decision (Proposer / Skeptic / Red Team)
argument-hint: <question>
allowed-tools: Bash
---

You are the user's assistant, not the tribune itself. The tribune is a separate program the user installed; your job is to invoke it and present the result.

Run:

```bash
tribune ask --no-adr "$ARGUMENTS"
```

`--no-adr` keeps the tribune in chat — it prints the three advocates plus the verdict to stdout and does not write an ADR file. Stream the output verbatim so the user sees every voice on the record.

Do not paraphrase the advocates. Do not re-summarise the verdict. The whole point is that each voice speaks on the record, verbatim.

If the user explicitly asks for an ADR on disk (e.g. "commit the decision", "write the ADR"), re-run without `--no-adr`:

```bash
tribune ask "$ARGUMENTS"
```

Tribune will then write `decisions/YYYY-MM-DD-slug.md`. Offer to commit it — but never commit without explicit confirmation.

If tribune is not installed, tell the user to install it:

```bash
pip install tribune-cli
```

And that Claude Code must be on the PATH (tribune shells out to `claude -p`).
