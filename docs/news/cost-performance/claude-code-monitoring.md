---
title: The New Claude Code Monitoring
parent: Cost & Performance
grand_parent: News & Research
nav_order: 2
permalink: /docs/news/claude-code-monitoring/
---
# The New Claude Code Monitoring — What Our Team Data Revealed

**Source:** Reza Rezvani, [The New Claude Code Monitoring: What Our Team Data Revealed](https://alirezarezvani.medium.com/the-new-claude-code-monitoring-what-our-team-data-revealed-e7f0424d738f) (Medium, 2026-04-11, 9 min read)

## Key takeaways

- **Claude Code ships with OpenTelemetry instrumentation built-in** — opt-in, off by default.
- **Cache-read ratio is the single best indicator of configuration health.** Rezvani's 7-person team: 3 devs at 60%+ cache ratio, 4 below 15%, same codebase.
- **Adoption data destroys gut-feel.** 2 engineers generated 80% of sessions; 3 had essentially stopped after month one.
- Production stack: **OpenTelemetry Collector + Prometheus + Grafana** via Docker Compose.
- **TRACEPARENT propagation (beta)** — every Bash subprocess inherits W3C trace context.
- Solo-dev shortcut: Grafana Cloud free tier accepts OTLP directly.

## The opening insight

> "The first number that stopped me was not the cost. It was cache efficiency. After two weeks of running OpenTelemetry on our seven-person engineering team, the dashboard showed that three of our developers were getting 60 percent or higher cache read ratios on their Claude Code sessions. The other four were below 15 percent. Same codebase. Same subscription plan. Same CLAUDE.md file checked into the repo. The only difference was how they structured their prompts — and without monitoring, I would never have known."

## Why team monitoring is non-optional

Three problems surface the moment more than two people use Claude Code on the same codebase:

1. **Token burn without visibility.** API billing accumulates silently. Max subscriptions hit rate limits at unpredictable moments.
2. **Cache efficiency blindness.** Cache read tokens cost ~90% less than fresh input tokens. Your CLAUDE.md structure, your project layout, your prompt patterns all influence cache reuse. Without metrics, you're guessing.
3. **The adoption gap.** Self-reported usage is almost always wrong. Only telemetry tells you who's actually using Claude Code.

## 10-minute proof-of-concept

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1              # required; disabled by default
export OTEL_METRICS_EXPORTER=console
export OTEL_LOGS_EXPORTER=console
export OTEL_METRIC_EXPORT_INTERVAL=10000           # 10s feedback
claude
```

Within 10 seconds, raw metric output scrolls through your terminal — session counts, token usage by type, cost per API call, model identifier. Output is noisy but answers the critical question: **is Claude Code actually emitting telemetry?**

## Production stack (Docker Compose)

Three components: Claude Code → OTel Collector (OTLP receive, Prometheus scrape endpoint) → Prometheus (scrape + 90-day retention) → Grafana.

```yaml
version: '3.8'
services:
  otel-collector:
    image: otel/opentelemetry-collector:0.99.0
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./config/otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8889:8889"   # Prometheus scrape endpoint
  prometheus:
    image: prom/prometheus:v3.8.0
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=90d"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports: ["9090:9090"]
  grafana:
    image: grafana/grafana:11.0.0
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=changeme
    ports: ["3000:3000"]
```

**Team managed-settings config:**

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://collector.your-company.com:4317"
  }
}
```

**Solo-dev shortcut:** Grafana Cloud free tier accepts OTLP directly. Skip the collector entirely.

## The 8 metrics ranked

### Track from day one

1. **`claude_code.cost.usage`** (by `model`) — catches teams running Sonnet where Haiku would suffice.
2. **`claude_code.token.usage`** (by `type`: input/output/cache_read/cache_creation) — **cache-read ratio is the single best health indicator.**
3. **`claude_code.active_time.total`** (split by `user` keyboard vs `cli` tool execution) — Claude-working vs developer-waiting.

### After baseline

4. **`claude_code.session.count` per user** — real adoption trends.
5. **`claude_code.commit.count`** + **`pull_request.count`** — connect usage to tangible output.
6. **`claude_code.code_edit_tool.decision`** — accept vs reject. **High reject rate = CLAUDE.md needs work.**

## The 5 events worth watching

- **`api_error`** — fires only after all retries exhausted. Terminal failure, not transient blip.
- **`tool_result`** — `duration_ms` and `success` fields surface slow/failing tools before they become patterns.
- **`prompt.id`** — every event from one prompt shares this ID. The difference between *"we spent $4.20 today"* and *"this specific prompt about refactoring auth cost $0.87 across 3 API calls."*

## Traces (beta) — TRACEPARENT propagation

```bash
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
export OTEL_TRACES_EXPORTER=otlp
```

Every Bash subprocess Claude Code spawns **receives a `TRACEPARENT` environment variable** with W3C trace context. If subprocesses (build scripts, test runners, deployment pipelines) emit their own OTel spans, they auto-attach to the same trace.

> "End-to-end visibility from prompt to production. For teams running Claude Code in CI/CD via `claude-code-action`, this is the path to answering questions like: *'That automated PR review took 45 seconds — where did the time go?'* The trace will show you."

## Honest limitations

1. **Delta vs cumulative temporality.** Claude Code defaults to delta. **VictoriaMetrics silently drops delta metrics with no error.** If data disappears: `OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative`. Cost Rezvani 2 hours of debugging.
2. **Cardinality explosion at scale.** `session.id` in every metric works at 7 people, not 50+. Set `OTEL_METRICS_INCLUDE_SESSION_ID=false` for large teams.
3. **Cost metrics are approximations.** Directional only. Reference Anthropic Console / Bedrock / Vertex dashboards for actual invoicing.
4. **No prompt content by default.** Right privacy default. Opt in with `OTEL_LOG_USER_PROMPTS=1` only after careful thought on a shared backend.
5. **The dashboard is the hard 10%.** Getting telemetry flowing is easy; building meaningful PromQL queries is where teams stall. Clone Anthropic's reference dashboard rather than building from scratch.

## Related Playbook pages

- [Cost & Observability]({{ site.baseurl }}/docs/cost-and-observability/) — full OpenTelemetry stack reference + caveman pairing
- [Opus 4.7 Reference]({{ site.baseurl }}/docs/opus-4-7/) — why xhigh default means monitoring matters more
- [BMad Autonomous Development]({{ site.baseurl }}/docs/bmad/) — pair telemetry with /bad to track subagent spend
