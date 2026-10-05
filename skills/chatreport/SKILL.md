---
name: chatreport
description: Turn a WhatsApp chat export into a finished report about the relationship, then talk through what it found. Explicit invoke only: /chatreport.
---

# chatreport: a chat export in, a finished report out

Wraps the one-shot instrument in `~/Repos/chatreport`. Reads an export, sends it to a
model once, checks every quote back against the conversation, and renders a page.

Costs nothing beyond the user's Claude subscription. There is no API key and none is needed.

## The two passes, always in this order

The free pass never sends anything. Run it first, every time, and read the numbers out
loud before spending anything.

```
cd ~/Repos/chatreport
PYTHONPATH=src .venv/bin/python -m tools.report_once "<export>"
```

It prints how many messages it read, how many a person actually typed, what share of
the lines parsed, and whether it worked out the date order or guessed.

**Stop and say so if the parse rate is under 95%.** A message in five being invisible
explains a thin report far better than the writing does, and it is worth fixing before
spending a run rather than after reading a disappointing one.

Then the real pass:

```
mkdir -p ~/Documents/chat-reports
PYTHONPATH=src .venv/bin/python -m tools.report_once "<export>" --spend \
  > ~/Documents/chat-reports/<name>-<date>.html
```

Name the file after the other person and the day, so a folder of these stays readable.
Open it with `open`, and say plainly what it found before he has read it.

A long archive can take several minutes. Say so rather than leaving him watching a
blank terminal.

## What to read back to him afterwards

The run prints two numbers at the end that matter more than they look:

- **how many findings survived.** Findings are dropped when the model breaks a rule or
  cites a quote that does not check out, and the dropped ones are listed with reasons.
- **the drop rate.** Under about 2% is healthy. Near or above 5% means something
  systemic: usually the model losing track of dates in a long archive. Tell him the
  number and flag it if it is high, because that is the failure that looks like weak
  writing and is not.

## Rules

- **Exports only.** This reads a file he deliberately exported. It never reaches into
  the live WhatsApp store, which is a deliberate line in that repo and not an oversight.
  If he wants a chat he has not exported, that is what `/persona` is for.
- **Two people only.** Group chats are refused by the parser, with a readable reason.
  Pass the reason on rather than trying to work around it.
- **The report is written for both of them.** It is not a dossier on the other person
  and no line in it is meant to arm one against the other. If he wants a private read of
  one person, that is `/persona`, which is a different tool with different rules.
- **The raw chat never touches the disk.** It is read out of the zip into memory. Only
  the rendered page gets written, and it lives in `~/Documents/chat-reports`, which is
  outside any repo. Do not write it into the chatreport repo: that tree has a guard
  against exactly this, and it will fail the build.
- **WhatsApp exports "Without media".** A loose `.txt` also works. If he hands over a
  zip with media in it, it still works, the media is simply ignored.

## When it goes wrong

- `the export was refused`. Not a readable archive. The code in brackets says which
  way, and the sentence is written to be passed on as-is.
- `this cannot be read as a conversation`. Usually a group chat, sometimes a text file
  that is not a chat. The parser already explains it in a sentence.
- `the subscription could not answer`. The Claude Code command line could not run. The
  reason follows on the same line: not logged in, no such command, or the run took too
  long. All are fixable in a minute.
- Findings dropped for `more than 3 quotes` or `body under 200 characters` are the model
  breaking house rules. A couple is normal. A page of them means the writing brief and
  the checker have drifted apart, which is worth raising rather than shrugging at.
