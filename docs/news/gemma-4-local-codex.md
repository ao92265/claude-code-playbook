---
title: I ran Gemma 4 as a local model in Codex CLI
parent: News & Research
nav_order: 6
---
# I ran Gemma 4 as a local model in Codex CLI

**Source:** Daniel Vaughan, [I ran Gemma 4 as a local model in Codex CLI](https://medium.com/google-cloud/i-ran-gemma-4-as-a-local-model-in-codex-cli-7fda754dc0d4) (Medium / Google Cloud Community, 2026-04-13, 7 min read)

## Key takeaways

- **Gemma 3 scored 6.6% on tau2-bench function-calling. Gemma 4 scores 86.4%.** The gap that makes local agentic coding practical.
- **Apple Silicon:** do NOT use Ollama with Gemma 4 — two bugs block it. Use llama.cpp with `--jinja`.
- **NVIDIA:** vLLM fails (PyTorch ABI mismatch), llama.cpp from source rejected by Codex CLI — **Ollama v0.20.5 is the first path that works**.
- On the same task, GPT-5.4 cloud finished in 65s first-try. Mac 26B MoE finished in 4m 42s with 10 tool calls. GB10 31B Dense finished in 7m with 3 tool calls.
- **Token speed doesn't dominate: first-pass reliability matters more.** Mac was 5.1× faster at generation but only 30% faster end-to-end.
- **Hybrid workflow:** `codex --profile local` for iteration / privacy-sensitive work; cloud default for complex.

## Why local, why now

Three drivers pushing Vaughan (and others) toward local:

1. **Cost** — heavy Codex CLI runs add up, multiple parallel sessions compound
2. **Privacy** — some codebases can't leave the machine
3. **Resilience** — cloud APIs throttle, go down, change pricing. Local runs.

The previous blocker was **function calling**. Gemma 3: 6.6% on tau2-bench. 93 failures out of 100. Not a foundation for anything agentic. Gemma 4: 86.4%. Broken → works.

## Hardware tested

- **Mac M4 Pro, 24 GB** — ran 26B MoE variant, llama.cpp, Q4_K_M quantisation
- **Dell GB10, 128 GB unified (NVIDIA Blackwell)** — ran 31B Dense variant, Ollama v0.20.5
- **Cloud baseline** — GPT-5.4 with high reasoning effort

Both local machines configured as custom model providers in Codex CLI `config.toml` with `wire_api = "responses"`.

## Mac setup (what broke)

### Ollama failed — two bugs

- **v0.20.3 streaming bug** routes Gemma 4's tool-call responses to the wrong field (reasoning output instead of `tool_calls` array)
- **Flash Attention freeze** hangs Ollama on any prompt longer than ~500 tokens with Gemma 4 on Apple Silicon
- Codex CLI's system prompt alone is ~**27,000 tokens** — the request starts ingesting and then nothing useful happens

### llama.cpp worked — the six load-bearing flags

```bash
brew install llama.cpp

llama-server \
  -m /path/to/gemma-4-26B-A4B-it-Q4_K_M.gguf \
  --port 1234 -ngl 99 -c 32768 -np 1 --jinja \
  -ctk q8_0 -ctv q8_0
```

| Flag | Why it matters on 24 GB |
|:--|:--|
| `-np 1` | Single slot. Multiple slots multiply KV cache memory. |
| `-ctk q8_0 -ctv q8_0` | Quantises KV cache (940 MB → 499 MB) |
| `--jinja` | Required for Gemma 4's tool-calling template |
| `-c 32768` | Context. System prompt needs ≥27K. |
| `-m` with direct path | **Avoid `-hf`** which silently downloads a 1.1 GB vision projector causing OOM |

Codex CLI config needs `web_search = "disabled"` — Codex sends a `web_search_preview` tool type that llama.cpp rejects.

## NVIDIA GB10 setup

- **vLLM failed.** v0.19.0 compiled against PyTorch 2.10.0; only CUDA-enabled PyTorch for aarch64 Blackwell (compute capability sm_121) is 2.11.0+cu128. Different ABI. ImportError.
- **llama.cpp from source** compiled fine but Codex CLI's `wire_api = "responses"` sends non-function tool types llama.cpp rejects.
- **Ollama v0.20.5 worked.** The Apple Silicon streaming bug did not reproduce on NVIDIA.

```bash
ollama pull gemma4:31b
# SSH tunnel if remote (Codex --oss checks only localhost):
ssh -L 11434:localhost:11434 user@gb10-host
codex --oss -m gemma4:31b
```

Text generation and tool calling both worked on first attempt.

**Setup time:** Mac took most of an afternoon. GB10 took about an hour, most of it waiting for model downloads.

## The benchmark

Same task through `codex exec --full-auto`: write a `parse_csv_summary` Python function with error handling + tests + run them. Single practical spot check, not statistically robust.

| Config | Result | Time | Tool calls | Code quality |
|:--|:--|:--|:--|:--|
| **GPT-5.4 cloud** | 5/5 first try | 65 s | — | Type-hinted, clean exception chaining, boolean detection, helper function |
| **GB10 31B Dense** | 5/5 first try | 7 min | 3 | Functional, no type hints/boolean detection, solid error handling, no dead code |
| **Mac 26B MoE** | 5/5 eventually | 4m 42s | 10 | Dead code left in; test file took 5 attempts — heredoc failures like `filerypt` instead of `file_path`, `encoding=' 'utf-8'` with rogue space |

## The speed surprise

Both machines have **273 GB/s LPDDR5X memory bandwidth**. Mac generates tokens **5.1× faster** than GB10.

Vaughan did not expect this. The explanation is the Mixture of Experts architecture:

- Token generation is memory-bandwidth limited
- **31B Dense** reads all 31.2B params per token (~17.4 GB through 273 GB/s → 10 tok/s)
- **26B MoE** activates only 3.8B per token (~1.9 GB through 273 GB/s → 52 tok/s)

Same pipe, vastly different payload. MoE sparse activation dominates memory-bandwidth-limited generation.

Prompt processing surprise too: Mac held its own vs Blackwell GPU — 531 tok/s vs 548 tok/s at 8K context.

## What changed Vaughan's mind

> "I went into this assuming token speed would dominate the experience. On this task, it did not. The Mac generated tokens 5.1 times faster. It still finished only 30 per cent sooner (4m 42s versus 6m 59s). The time went into retries: ten tool calls instead of three, five failed test writes and dead code the model did not clean up. The GB10's slower model got it right first time."

> "The cloud model made the same point more sharply. It was fastest, used the fewest tokens and needed no repair pass. Five out of five in 65 seconds. For this workflow, first-pass reliability mattered more than raw generation speed."

## The author's honest caveat

- This is a 24 GB / Q4_K_M / Codex CLI harness result — not a universal verdict on Gemma 4 on Apple Silicon
- Has not rerun at a higher quant on a roomier Apple Silicon machine; expects that to matter

## The hybrid workflow

> "I can see how a hybrid approach might be useful. `codex --profile local` for iteration and privacy-sensitive work. Default cloud for anything complex. Codex CLI's profile system makes switching a single flag."

## Specific tips that will save you time

- **Apple Silicon:** Ollama not usable with Gemma 4 for this workload. Use llama.cpp with `--jinja`. Set `web_search = "disabled"`. Use `-m` with direct GGUF path, not `-hf`. Context 32,768 (Codex system prompt needs ≥27K). Quantise KV cache with `-ctk q8_0 -ctv q8_0`.
- **NVIDIA GB10:** Ollama v0.20.5 is the first path that worked reliably. `codex --oss -m gemma4:31b`. Tunnel port 11434 via SSH for remote.
- **Set `stream_idle_timeout_ms` to at least 1,800,000.** A single tool-call cycle took 1m 39s on the Mac. Default timeout kills sessions before the model finishes thinking.
- **Pin your llama.cpp version.** A reported 3.3× speed regression between builds means benchmarks can change overnight.

## Configuration baseline (for reproducibility)

- Date run: **2026-04-12**
- Codex CLI v0.120.0
- Mac: llama.cpp ggml 0.9.11 (build 8680), gemma-4-26B-A4B-it Q4_K_M
- GB10: Ollama v0.20.5, gemma-4-31B-it Q4_K_M
- Cloud: GPT-5.4 high reasoning effort

## Related Playbook pages

- [Local Models]({{ site.baseurl }}/docs/local-models/) — Gemma 4 setup reference with the hybrid workflow pattern
- [Multi-Model Orchestration]({{ site.baseurl }}/docs/multi-model-orchestration/) — combining local and cloud
- [Regulated AI]({{ site.baseurl }}/docs/regulated-ai/) — when local inference is a compliance win
