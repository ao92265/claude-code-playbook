---
name: imagegen
description: Generate or edit images from a text prompt using Google Gemini image models through the ParentCo Matcha gateway, saving the image to disk and showing it. Use when the user says "generate an image", "make me an image", "draw", "create a picture", "nano banana", "generate a logo/icon/illustration/mockup image", "/imagegen", or asks to edit, restyle, or extend an image file they point at. Handles aspect ratio, model choice, multi-reference image editing, and iterative refinement. Do NOT use for diagrams (use design-system-diagrams or hand-drawn-diagrams), for charts of data (use dataviz), or for reading and describing an existing image (just use the Read tool).
---

# Image generation via Matcha

Generates images with Gemini image models, billed through the user's ParentCo Matcha
account. No separate Google API key is involved: the script reads the Matcha key
from the macOS keychain, the same one `claude-matcha` and `matcha` use.

## Generating an image

```
scripts/gen-image.sh -o OUTPUT.jpg "the prompt"
```

Options:

- `-a` aspect ratio. `1:1` (default), `4:3`, `3:4`, `16:9`, `9:16`.
- `-m` model. `gemini-3.1-flash-image` (default, best quality) or
  `gemini-2.5-flash-image` (older, cheaper).
- `-i` an existing image to edit or use as a reference. Repeat the flag for
  several references.
- `-o` where to save. Required.

Gemini returns JPEG, so the script corrects the extension for you and prints
the path it actually wrote. Use that printed path, not the one you passed.
It exits non-zero with a message on failure.

## How to run it

1. **Pick the output path before generating.** Save into the user's working
   directory if the image belongs to the project they are in, otherwise into the
   session scratchpad directory. Use a descriptive filename, not `image.png`.
2. **Write a real prompt, not the user's words verbatim.** Gemini image models
   reward specificity: name the subject, the composition, the lighting, the
   medium or style, and what should be excluded. A one-line user request should
   become two or three sentences of prompt. Do not invent brand names, real
   people, or logos the user did not ask for.
3. **Run the script**, then **Read the file it printed** so you can actually see
   what came back. Never describe an image you have not looked at.
4. **Show the user the path** and say in one line what you produced. If the
   result misses something the user asked for, say so rather than presenting it
   as correct.

## Editing an existing image

Pass the source with `-i` and describe the change, not the whole scene:

```
scripts/gen-image.sh -i original.jpg -o restyled.jpg "make the background a deep navy, keep the subject unchanged"
```

Multiple `-i` flags let the model use several references at once, for example a
subject image plus a style image.

## Iterating

When the user asks for a change, generate a **new file** rather than
overwriting, so earlier versions survive. Number them (`poster-1.jpg`,
`poster-2.jpg`). Feed the previous version back in with `-i` when the change is
a tweak rather than a fresh idea.

## Cost and privacy

Every generation is billed to the ParentCo Matcha account per token, so do not
fire off speculative batches. Generate one, look at it, then iterate. Prompts
and any input images leave the machine for a ParentCo-run gateway, so treat this
as work-visible rather than private.

## Common issues

- **"key not in keychain"** — the Matcha key is missing. Re-add it with
  `security add-generic-password -a "$USER" -s matcha-api-key -w '<key>' -U`.
- **"missing ~/.claude/matcha.env"** — the Matcha setup is not installed on this
  machine. That file holds the gateway URL.
- **"no image returned"** followed by model text — the model refused or a safety
  filter fired. The text explains why. Rewrite the prompt rather than retrying
  it unchanged.
- **Hangs for minutes** — Matcha reports upstream errors as HTTP 500 and clients
  retry them. If a call stalls, cancel it and check the model name is one of the
  two listed above.
- **"Unable to process input image"** — the file passed to `-i` is missing or
  is not a real image. Check the path exists before retrying.
- **Aspect ratio ignored** — only the five listed ratios are supported. Anything
  else is silently dropped.
