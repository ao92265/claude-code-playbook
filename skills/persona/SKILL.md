---
name: persona
description: Local persona bank / "how should I reply" advisor. Given a message someone sent you, retrieves what you know about that person and suggests how to respond. Also imports chat history and builds/refreshes a person's profile. Triggers "/persona", "how should I respond to", "how do I reply to", "X said this to me", "what do I say to", "add this to <person>'s persona", "build persona for", "import chat for".
---

# persona — local persona bank + reply advisor

Wraps the local `mindmirror` CLI. Everything stays on this machine. LLM enrichment is opt-in only.

## Fixed invocation
Always run the CLI via the repo venv with a pinned data dir, so all personas live in ONE place. Set two shell vars and use them SEPARATELY (do NOT bundle args into `$MM` — zsh treats the whole string as one filename and fails with exit 127):

```
MM=~/Repos/mindmirror/.venv/bin/mm
D=~/Repos/mindmirror/data
# then e.g.:  $MM --data-dir $D ask "<person>" "<message>"
```

If `.venv/bin/mm` is missing, fall back to:
`cd ~/Repos/mindmirror && python -m mindmirror.cli --data-dir ~/Repos/mindmirror/data ...`

## What the user usually wants → what to run

### 1. "How should I respond to <person>? They said: <message>"  (the main use)
```
$MM --data-dir $D ask "<person>" "<their message>"
```
Prints a read of what they mean, then what has reached that person before and what has not,
each with the quotes it was drawn from. Relay it back plainly. Where the person has no deep
read yet it falls back to 3 generic response options built from word counts: say so, and offer
`deepread` (step 3b) rather than passing the counted version off as a read of them.
- Each finding prints as the claim plus the quotes behind it. Add `--full` for the paragraphs
  in between, which is where the reasoning and the "this is wrong if" line live. Reach for it
  when the user pushes back on a finding or asks why it says that.
- If it errors "no persona card": run `build` first (step 3), then retry.
- Add `--llm` ONLY if the user explicitly asks for a Claude-enriched deeper read (sends that person's context to the API — say so before doing it).

### 2. Add a single line to a person's history
```
$MM --data-dir $D add "<person>" --speaker "<who said it>" --text "<the message>"
```

### 3. Build / refresh a person's profile (do this after importing or adding messages)
```
$MM --data-dir $D build "<person>"
```

### 4. Import a chat export
```
$MM --data-dir $D import "<person>" --whatsapp /path/to/export.txt
# or --data-dir $D import "<person>" --imessage /path/to/transcript.txt   (custom "[ts] speaker: text" format)
```
After import, always run `build` (step 3) before `ask`.

### 3b. Read a person properly, rather than counting their words  (the deep read)
`build` is a word counter. It is instant, local and free, and its idea of what someone
cares about is their most frequent nouns. `deepread` sends the whole stored history to a
model once and writes back findings that carry the quotes they rest on, each one checked
against the stored message it came from.

```
$MM --data-dir $D deepread "<person>"            # free. Says what it would read, sends nothing
$MM --data-dir $D deepread "<person>" --spend    # the real one. Minutes, and a subscription call
```

Run the free pass first and read the numbers out. If the history is short, or nearly all
one person talking, say so before spending: a confident read of very little is the
failure that looks like insight.

- Costs a Claude subscription call, not money. No API key is involved.
- Defaults to the most recent 15,000 messages so a long archive stays to minutes. `--all`
  reads everything. Whatever it left out, it says so.
- Needs the chatreport engine at `~/Repos/chatreport`, or `CHATREPORT_HOME` pointing at it.
- Watch the drop rate it prints at the end. Around 2% is healthy. A quarter means
  something systemic and is worth raising rather than shrugging at.
- `ask` picks it up automatically afterwards and leads with it. Nothing else to run.
- Re-run it after a big import. It is a snapshot, and it stamps the date it was taken.

### 4b. Import straight from the WhatsApp desktop store (no export needed)
Reads the live macOS `ChatStorage.sqlite` directly — pulls a full 1:1 history in one shot. Local, read-only (copies the DB before reading, never touches the original).
```
$MM --data-dir $D list-whatsapp --match "<name>"          # find the exact chat name + msg count
$MM --data-dir $D import "<person>" --from-whatsapp "<chat name>"
$MM --data-dir $D build "<person>"
```
Only works for 1:1 chats (groups are excluded). Media-only messages are skipped. Your own messages are labelled "You"; add `--wa-db PATH` to override the store location. Outlook has NO equivalent — New Outlook keeps no local mailbox, so email must come via `add`/paste.

## Rules
- Default is local-only. Never pass `--llm` unless the user asks — and warn first, since it sends that person's data to Claude.
- These are real people. Don't editorialise or moralise; just relay the advisor output.
- If unsure who the "person" key should be, ask the user for the name to file it under (names are normalised, so be consistent).
- Typical first-time flow for a new person: `import` (or several `add`), then `build`,
  then `deepread --spend` if the history is worth reading properly, then `ask`.
- `deepread` is a different tool from `--llm`. `--llm` enriches the word counts. `deepread`
  replaces the counting with a reading and checks every quote. Prefer it.
