# PROJECT [CODENAME]

## [One-line product descriptor]

### [Scope line: what moves from where to where, or which system is replaced]

**Executive Summary**

[Author name]
[Role, programme, business unit]
[Country]

[Second author name]
[Role, secondment or reporting line]
[Country]

[Month Year]
Classification: [Internal / Commercial in Confidence]

\newpage

## Financial Summary

[Two to three sentences: what was delivered, in what elapsed time, with what team size, versus what benchmark. State the multiple.]

[Two to three sentences: blended rate per developer-month applied to both scenarios, total delivery cost, benchmark cost range, saving in absolute terms and as a percentage. Monthly tooling cost.]

### Team, Duration and Cost Comparison

| Approach | Team | Duration | Total Delivery Cost |
|---|---|---|---|
| Traditional (Benchmark) | [n developers] | [n months] | [range] |
| AI-Assisted (Actual) | [n developers] | [n weeks, with dates] | [actual, approximate] |
| Savings | [multiple] | [multiple] | [absolute and percentage] |

> **Cost assumption.** [Blended rate per developer-month, applied to both scenarios. What the AI-assisted total includes (personnel plus named tooling). Anything excluded as a customer-side operating cost.]

> **Provenance of the benchmark.** [COCOMO II, internal benchmark against comparable projects, or the client's own estimate. Say which.]

### Time Investment Analysis

| Phase | Traditional Estimate | AI-Assisted Actual |
|---|---|---|
| Requirements and Analysis | [weeks] | [actual] |
| Design, PRD and Implementation Plan | [weeks] | [actual] |
| Foundation (repo, API, frontend, database, CI) | [weeks] | [actual] |
| [Core feature block] | [weeks] | [actual] |
| [Second feature block] | [weeks] | [actual] |
| Quality Polish and Hardening | [weeks] | [actual] |
| Testing and QA | Separate QA phase | Continuous (included) |
| Documentation | Separate phase | Generated alongside code |
| TOTAL | [total] | [total] |

> **A note on the elapsed time.** [Holidays, late secondments, environment access delays. Explaining lost time strengthens the number.]

\newpage

## Part 1: Project Overview

### What is [Codename]?

[Three to five sentences: what it does, who operates it, what it replaces, how it is deployed and why.]

![[Caption for the primary working screen]](primary-screen.png)

### The Problem We Solved

- [Pain point one, quantified]
- [Pain point two, quantified]
- [Structural or data-model problem that makes the work hard, not just tedious]
- [Typical cost or effort per customer or per project]
- [Commercial consequence]

### Our Solution

- [The central design idea in one line]
- [Deployment and platform fact]
- [Frontend fact with concrete counts]
- [The pipeline or workflow that carries the main use case]
- [How AI is governed inside the product, or "AI was the build engine only; the product calls no model at runtime"]
- [The data-integrity or auditability property a reviewer would ask about]

## Part 2: Scale of Work Completed

Figures captured from the repository on [date]. The product is approximately [n] percent complete. The remaining [n] percent covers [remaining scope], itemised in Part 10.

| Metric | Value | Industry Context |
|---|---|---|
| Total Lines of Production Code | [n] | [size comparison a non-engineer can picture] |
| Backend [language] | [n] | [across n production files] |
| Frontend [language] | [n] | [framework and build tool] |
| Total Commits | [n] | [start date, average per day] |
| Pull Requests | [n] | [percent with independent human review before merge] |
| Issues Tracked | [n] | [structure of the backlog] |
| Database Migrations | [n] | [versioned schema evolution] |
| API Endpoints | [n] | [API style] |
| Frontend Components | [n] | [reusable building blocks] |
| Frontend Pages | [n] | [full application screens] |
| Backend Test Cases | [n] | [unit and integration approach] |
| Frontend Test Assertions | [n] | [across n test files, tooling] |
| Documentation Lines | [n] | [what the documentation covers] |

## Part 3: Technical Architecture

### Backend Architecture

| Component | Technology | Why This Choice |
|---|---|---|
| Runtime | [platform and version] | [operational justification] |
| API Style | [style] | [justification] |
| Data Access | [technology] | [justification] |
| Database | [engine and version] | [justification] |
| Logging | [library and format] | [justification] |
| Security | [library] | [hashing or token strategy] |

### Frontend Architecture

| Component | Technology | Why This Choice |
|---|---|---|
| Framework | [framework and version] | [justification] |
| Language | [language and version] | [justification] |
| Build Tool | [tool] | [justification] |
| Component Library | [library] | [justification] |
| Styling | [approach] | [justification] |
| Routing | [library] | [number of routes] |

### AI Runtime Architecture

[Delete this subsection and its table if the product calls no model at runtime, and say so in one sentence in Part 4.]

| Component | Technology | Why This Choice |
|---|---|---|
| Gateway | [gateway] | [key management and policy centralisation] |
| Reasoning Model | [model] | [tasks it is used for] |
| Bulk Model | [model] | [cost multiple versus the reasoning model] |
| Concurrency | [worker range and retry policy] | [rate limits respected] |

### Infrastructure

| Component | Technology |
|---|---|
| Containerisation | [technology and composed services] |
| Staging | [environment and its purpose] |
| CI/CD | [pipeline and what runs on each push] |
| Code Quality | [linters, analysers] |
| Integration Testing | [real dependencies or mocks] |
| End-to-End Testing | [tool and coverage] |

## Part 4: The AI Approach

### AI for Building the Product

**Engine:** [tool and licence type]

[What the tool did across the lifecycle, how work was structured, the independent human review rate, merged PR count and elapsed period.]

### AI Inside the Product

**Engine:** [gateway or provider, and what it fronts]

[One paragraph.]

- [Where keys live]
- [How a provider or model swap is performed]
- [How cost is routed and measured]

### Key AI-Design Decisions

| Criterion | Decision | Rationale |
|---|---|---|
| Security | [decision] | [what it protects] |
| Cost | [decision] | [how it is measured] |
| Speed | [decision] | [quantified improvement] |
| Reliability | [decision] | [failure mode it handles] |
| Flexibility | [decision] | [lock-in avoided] |
| Quality | [decision] | [how the model was selected] |

## Part 5: Security and Integration

### Deployment Model

[Where it runs, what data crosses which boundary, which regulatory expectation that satisfies.]

### Security Layers

| Layer | Implementation |
|---|---|
| Authentication | [mechanism] |
| Authorisation | [permission model and where enforced] |
| AI Traffic | [routing, any direct external calls] |
| Rate Limiting | [where applied] |
| Upload Safety | [caps] |
| Correlation | [correlation ID propagation] |
| Audit Trail | [what is recorded on every change] |
| Provenance | [field-level source labels] |

### [The Human-in-the-Loop Rule, or equivalent control]

[The rule, where it is enforced, how AI suggestions are surfaced.]

## Part 6: Core Features

### 1. [Primary workflow or pipeline]

[One paragraph plus the stages in order.]

### 2. [Domain model or dependency structure]

[What it does, how it is enforced, why it matters.]

### 3. [AI-powered capability, or the next major feature]

[What it does, how it is enforced, why it matters.]

### 4. [Review or approval workflow]

[What it does, how it is enforced, why it matters.]

### 5. [Provenance or data-quality feature]

[What it does, how it is enforced, why it matters.]

### 6. [Audit trail]

[What it does, how it is enforced, why it matters.]

### 7. [Export, integration or reporting]

[What it does, how it is enforced, why it matters.]

## Part 7: The Invisible Excellence

### Testing

[n] automated test cases across [n] test files, with [integration testing approach].

| Layer | Location | Assertions / Cases |
|---|---|---|
| Backend unit | [path] | [n] |
| Backend integration | [path] | [real dependency approach] |
| Frontend | [tooling] | [n across n files] |
| End-to-end | [tool and path] | [coverage] |

### Code Quality

- [Type-safety settings]
- [Linting and static analysis]
- [Review rule and independent human review rate]

### Observability

- [Logging format and correlation]
- [Cost or usage dashboard, if AI runs at runtime]
- [Tracing]

### Documentation

Approximately [n] lines of developer and product documentation, generated alongside code rather than as a separate phase. Key artefacts include [three or four with line counts]. See the Appendix.

## Part 8: Challenges and Mitigations

### Technical

#### [Challenge one: the quality or accuracy failure]

[The problem in numbers. Root cause. The fix, and whether it was a prompt change or a new boundary between deterministic code and the model. Result against target.]

#### [Challenge two: a reliability or integration failure]

[Symptom, silent failure mode, mitigation and new instrumentation.]

#### [Challenge three: performance at scale]

[Workload size, observed time, cause, quantified improvement.]

#### [Platform or vendor gaps]

[What works, which specific capability would improve fit.]

### Organisational

#### [Distribution, time zones or working conditions]

[Where each person worked, synchronous time, disruptions, how the workflow absorbed them.]

#### [Knowledge gaps at kickoff]

[What each person did not know, how long it took to close, what closed it.]

#### [Scope or requirements uncertainty]

[What was undefined, the decision taken, whether it paid off.]

## Part 9: Value Delivered

### Internal Delivery Savings

| Item | Traditional | With [Codename] (Actual) |
|---|---|---|
| Team size | [n] | [n] |
| Elapsed duration | [months] | [weeks] |
| Personnel cost | [range] | [actual] |
| Tooling cost | [baseline] | [actual] |
| Runtime AI cost | Not applicable | [per unit, customer-side, or none] |
| External partners | [typical] | [used] |
| Total delivery cost | [range] | [actual, percentage saving] |

### Customer-Side Value

| Process | Before | After | Improvement |
|---|---|---|---|
| [Specialist effort per project] | [baseline] | [new] | [saving] |
| [Data quality] | [baseline] | [new] | [what it enables] |
| [Safety or correctness property] | [baseline] | [new] | [why safer] |
| [Onboarding a new source or customer] | [baseline] | [new] | [time saved] |

### Commercial Value Case

The value case presented at [forum and date] estimates approximately [figure] per year, driven by:

- [Monetised customer effort reduction, figure and horizon]
- [Additional projects per year, figure and horizon]
- [Competitive differentiation in tenders]

### Risk Reduction

- [Safety]
- [Regulatory]
- [Security]
- [Vendor lock-in]
- [Knowledge]

## Part 10: Next Steps

### Remaining [n] Percent of Scope

- [Deliverable, owner, target period]
- [Deliverable, owner, target period]
- [Customer pilots or onboardings]
- [Remaining test coverage]

### First User Feedback

[Two or three sentences, the environment it came from, whether it agrees with the measured results.]

## Appendix: Documentation Inventory

Key documents in the repository, by size. Figures are line counts.

| Document | Lines | Purpose |
|---|---|---|
| [document] | [n] | [purpose] |

### Additional Resources (within the repository)

- [Agent context files]
- [Presentation decks with dates]
- [Kickoff material]

Document Version: 1.0
Last Updated: [Month Year]
