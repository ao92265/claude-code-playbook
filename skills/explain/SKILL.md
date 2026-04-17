---
name: explain
description: >
  Explain a file, function, or concept with layered depth — from high-level overview
  to implementation details. Adapts to the reader's experience level.
  Triggers: "explain", "how does this work", "what does this do", "walk me through".

  Do NOT use this skill for: generating documentation (use a writer), debugging
  (use /analyze), or exploring unfamiliar codebases (use /deep-explore).
metadata:
  user-invocable: true
  slash-command: /explain
  proactive: false
title: "Explain Code"
parent: Skills & Extensibility
---
# Explain Code

Provide a layered explanation that starts simple and goes deeper on request.

## Steps

1. **Identify the target:**
   - Read the file, function, class, or concept the user wants explained
   - If the target is vague ("explain the auth system"), identify the entry point and core files

2. **Layer 1 — One-liner:**
   - Explain what it does in a single sentence
   - Focus on the *what*, not the *how*
   - Example: "This function validates JWT tokens and attaches the decoded user to the request."

3. **Layer 2 — How it works (5-10 lines):**
   - Walk through the high-level flow
   - Name the key steps without implementation details
   - Mention inputs, outputs, and side effects
   - Example: "It extracts the token from the Authorization header, verifies the signature using the secret from env, checks expiration, looks up the user in the database, and attaches them to `req.user`."

4. **Layer 3 — Implementation details (on request):**
   - Walk through the code line by line or block by block
   - Explain *why* specific approaches were chosen
   - Point out error handling, edge cases, and guard clauses
   - Reference related files, types, or functions

5. **Layer 4 — Context and connections (on request):**
   - How this code fits into the larger system
   - What depends on it (callers, consumers)
   - What it depends on (services, libraries, config)
   - Historical context if visible from git blame or comments

6. **Adapt to the reader:**
   - If the user seems experienced: skip basics, focus on non-obvious behavior
   - If the user seems new: use analogies, avoid jargon, explain prerequisites
   - If unclear: default to Layer 2 and offer to go deeper

## Output Format

```
**What it does:** [one-liner]

**How it works:**
1. [step]
2. [step]
3. [step]

**Key details:**
- [non-obvious behavior or edge case]
- [important dependency or assumption]

Want me to go deeper on any part?
```

## Important

- **Start simple, go deep on request.** Don't dump implementation details when the user just wants to understand the purpose.
- **Use the user's language.** If they say "the login thing," use that phrase — don't correct them with "the OAuth2 authentication middleware."
- **Point out the non-obvious.** The obvious parts are already in the code. Explain the *why*, the edge cases, and the gotchas.
- **Be honest about uncertainty.** If the code is unclear or you're guessing at intent, say so.
