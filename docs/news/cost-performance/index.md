---
title: Cost & Performance
parent: News & Research
nav_order: 2
has_children: true
---
# Cost & Performance

Two complementary techniques for controlling Claude Code spend — one on the output side, one on the measurement side — plus the honest pushback on over-claimed retrieval tooling.

## What you'll find here

- **Output compression** — the `caveman` plugin (75% output-token reduction, paper-backed brevity-improves-accuracy claim)
- **Production observability** — Rezvani's OpenTelemetry + Docker Compose stack, the 8 metrics that matter, TRACEPARENT subprocess propagation
- **The honest reframe on retrieval** — Graperoot's 178× headline was satirical; real savings are 50–85%, plus community concerns about vendor trust

## Featured in this category

1. [Cut Claude Code's Output Tokens by 75%]({{ site.baseurl }}/docs/news/caveman-75-percent-tokens/) — two commands, measurable savings
2. [The New Claude Code Monitoring]({{ site.baseurl }}/docs/news/claude-code-monitoring/) — what Rezvani's 7-person team found in 2 weeks of telemetry

## Combined effect

Used together, the caveman plugin (output-side) and the OpenTelemetry stack (measurement-side) typically produce **50-75% token reduction** with visible per-prompt cost attribution. The Graperoot article is worth reading to recalibrate expectations around inflated retrieval-tool marketing.
