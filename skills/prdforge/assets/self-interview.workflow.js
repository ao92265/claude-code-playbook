export const meta = {
  name: 'prdforge-self-interview',
  description: 'Self-interviewing PRD generator v3: scout the repo and any input documents, fan out interviewer personas that ask AND answer their own questions, synthesize a spec-grade PRD (IDs, MoSCoW, Given/When/Then, decisions, sized releases), critique and revise it, then render HTML + markdown + prompt + JSON and score it with the prd-review linter.',
  phases: [
    { title: 'Scout', detail: 'gather repo facts (brownfield only)' },
    { title: 'Interview', detail: 'personas generate + answer their own questions' },
    { title: 'Synthesize', detail: 'merge interviews into one PRD model' },
    { title: 'Critique', detail: 'adversarial review of the draft PRD' },
    { title: 'Revise', detail: 'apply critic findings' },
    { title: 'Render', detail: 'write JSON, render HTML + markdown + prompt deterministically, lint' },
    { title: 'Verify', detail: 'one fix pass if the linter score is under 85' },
  ],
}

// ---- inputs (from the skill's main loop via Workflow `args`) ----
// Normalize: args should be an object, but if the caller stringified it (a common
// mistake the Workflow docs warn about) it arrives as JSON text: parse it back.
let INPUT = args
if (typeof INPUT === 'string') { try { INPUT = JSON.parse(INPUT) } catch (e) { INPUT = {} } }
INPUT = INPUT || {}

const idea = INPUT.idea || 'Unspecified idea: infer intent and flag heavily as open questions.'
const brownfield = !!INPUT.brownfield
const outDir = INPUT.outDir || 'plans'
const slug = INPUT.slug || 'prdforge-untitled'
// This script cannot introspect its own location (no __dirname/import.meta.url
// in this sandbox), so it never guesses a path here: the caller (SKILL.md)
// knows its own base directory and must pass an absolute templatePath via args.
// If it doesn't, render falls back to generating structure from the PRD contract
// instead of trying to Read a path that may not exist on this install.
const templatePath = INPUT.templatePath || null
// v3: deterministic renderer + optional prd-review linter (absolute paths from SKILL.md).
const rendererPath = INPUT.rendererPath || null
const lintPath = INPUT.lintPath || null
// v3: optional input documents (absolute paths) whose facts and demand evidence feed the PRD,
// and the date (the script cannot call Date) for the document-control block.
const inputs = Array.isArray(INPUT.inputs) ? INPUT.inputs.filter(Boolean) : []
const today = INPUT.date || 'undated'
const LINT_FLOOR = 85

// the user, 24 Sep 2026: "full always". Every run is deep; a quick/balanced request is logged and ignored.
const requestedMode = String(INPUT.mode || '').toLowerCase()
const mode = 'deep'
if (requestedMode && requestedMode !== 'deep') log(`mode "${requestedMode}" requested; prdforge always runs deep`)
const useCritic = mode !== 'quick'
const rounds = mode === 'deep' ? 2 : 1
log(`prdforge v3: mode=${mode}, brownfield=${brownfield}, inputs=${inputs.length}, critic=${useCritic}, rounds=${rounds}, slug=${slug}`)

// ---- schemas ----
const INTERVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    lens: { type: 'string' },
    qa: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          q: { type: 'string' },
          a: { type: 'string' },
          confidence: { type: 'number', description: '0..1 confidence in the self-answer' },
          evidence: { type: 'string', enum: ['Code', 'Doc', 'Demo', 'Assumption', 'Unknown'], description: 'what the answer rests on' },
        },
        required: ['q', 'a', 'confidence', 'evidence'],
      },
    },
    assumptions: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' }, description: 'answers under ~0.6 confidence: surface to the user' },
    risks: { type: 'array', items: { type: 'string' } },
  },
  required: ['lens', 'qa', 'assumptions', 'openQuestions', 'risks'],
}

const S = { type: 'string' }
const SA = { type: 'array', items: { type: 'string' } }
const B = { type: 'boolean' }
const obj = (props, desc) => ({
  type: 'object', additionalProperties: false, properties: props, required: Object.keys(props),
  ...(desc ? { description: desc } : {}),
})
const arr = (props, desc) => ({ type: 'array', items: obj(props), ...(desc ? { description: desc } : {}) })
const LEVEL = { type: 'string', enum: ['low', 'medium', 'high'] }

const OPEN_QUESTION = obj({
  id: { type: 'string', description: 'Q-n' },
  question: { type: 'string', description: 'a crisp decision the user must make' },
  confidence: { type: 'number', description: '0..1: how confident prdforge is in the default it assumed' },
  why: { type: 'string', description: 'why this is unresolved / what hinges on it' },
  owner: { type: 'string', description: 'a ROLE (Product, Legal, Architecture), never an invented person' },
  blocks: { type: 'array', items: { type: 'string' }, description: 'requirement / goal / NFR IDs this blocks; [] if none' },
  neededBy: { type: 'string', description: 'the release, gate or design step by which it must close' },
})

const PRD_SCHEMA = obj({
  docControl: obj({ version: S, status: S, owner: S, date: S, mode: S, inputs: SA }),
  title: S,
  summary: S,
  readiness: obj({
    score: { type: 'number', description: '0-100; overwritten deterministically' },
    label: S,
    rationale: S,
  }),
  contestable: { type: 'array', items: S, description: '2-4 judgements a reviewer should argue rather than inherit (release order, scope cut, a deferral)' },
  problem: S,
  users: arr({ user: S, need: S, priority: S }),
  goals: arr({ id: S, goal: S, metric: S, baseline: S, baselineMeasured: B, target: S, measuredBy: S, source: S }, 'G-n; outcomes, never implementation'),
  nonGoals: arr({ id: S, text: S, rationale: S, returns: S }, 'NG-n; returns = when it comes back, or "Not planned"'),
  context: { type: 'string', description: 'current state; evidence-tag every claim and number ([Code] file:line, [Doc: name], [Assumption], [Unknown]); units on every number' },
  glossary: arr({ term: S, meaning: S }),
  constraints: arr({ id: S, constraint: S, source: S }, 'DA-n cross-cutting data / authorisation constraints; [] if none'),
  legacyRules: arr({ id: S, rule: S, fileLine: S, class: { type: 'string', enum: ['Preserve', 'Decide'] } }, 'brownfield: behaviour rules requirements trace to; [] when greenfield'),
  requirements: obj({
    functional: arr({
      id: { type: 'string', description: 'FR-<AREA>-n, stable' },
      area: S,
      priority: { type: 'string', enum: ['Must', 'Should', 'Could', "Won't"] },
      title: S,
      statement: { type: 'string', description: 'ONE capability, observable, no technology names' },
      acceptance: arr({ given: S, when: S, then: S }, '>=1 scenario for every priority; Musts also carry a denied, empty or already-done case'),
      trace: { type: 'array', items: S, description: 'legacy rule IDs, input-doc references or demand evidence; [] if none' },
      source: { type: 'string', description: 'persona lens or input document that produced it' },
      singleSource: { type: 'boolean', description: 'true when it rests on ONE answer below 0.6 confidence' },
    }),
    nonFunctional: arr({
      id: { type: 'string', description: 'NFR-n' },
      requirement: S,
      target: { type: 'string', description: 'number + unit + condition' },
      measuredBy: S,
      baselineMeasured: B,
      source: S,
    }),
  }),
  releases: arr({
    name: S, contents: S,
    size: { type: 'string', description: 'S / M / L plus a person-week range, e.g. "M (3-5 person-weeks)"' },
    sizeBasis: { type: 'string', description: 'what the estimate rests on; say "estimate, unvalidated" when it is a guess' },
    unblocks: S,
  }, 'ordered; every release sized'),
  gates: arr({ gate: S, passes: S, fails: S, failureAction: S, call: { type: 'string', description: 'role that makes the kill call' } }, 'deep mode: 2-4 gates; [] otherwise'),
  dependencyChains: arr({ chain: S, consequence: S }),
  prioritisationRule: { type: 'string', description: 'the explicit rule that decides priority, naming its evidence, or "No demand evidence supplied; priority is prdforge judgement" ' },
  decisions: arr({ id: S, question: S, decision: S, why: S, tradeOff: S, status: { type: 'string', enum: ['Closed', 'Provisional', 'Open'] } }, 'D-n; every persona disagreement lands here'),
  assumptions: arr({ id: S, text: S, source: S }, 'A-n'),
  openQuestions: { type: 'array', items: OPEN_QUESTION },
  risks: arr({ id: S, title: S, likelihood: LEVEL, impact: LEVEL, mitigation: { type: 'string', description: 'concrete; ideally becomes a test or gate' }, owner: S }, 'R-n'),
  testStrategy: arr({ group: S, provenBy: S }, 'requirement group (by ID range) -> the test layer that proves it'),
  definitionOfDone: S,
  verification: { type: 'array', items: S },
  implementationSpec: obj({ context: S, objective: S, boundaries: S, validation: S }),
  diagrams: arr({
    kind: { type: 'string', enum: ['system', 'flow', 'delivery', 'risk', 'state'], description: 'system = context view, flow = main user flow or sequence, delivery = releases and gates, risk or state = optional 4th' },
    chapter: { type: 'string', enum: ['context', 'problem', 'functional', 'releases', 'gates', 'risks'], description: 'the chapter the figure sits in: system -> context, flow -> functional, delivery -> releases, risk or state -> risks' },
    label: { type: 'string', description: 'accessible name, one short phrase' },
    caption: { type: 'string', description: '1-2 plain sentences shown under the figure: what to notice, citing IDs' },
    mermaid: { type: 'string', description: 'mermaid source: flowchart, sequenceDiagram or stateDiagram-v2; flowchart node labels in double quotes, no styling or classDef, no click, max about 14 nodes' },
  }, 'REQUIRED, 3 or 4: one system, one flow, one delivery; a risk or state view is optional'),
})

const CRITIQUE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          severity: { type: 'string', enum: ['low', 'med', 'high'] },
          type: { type: 'string', description: 'fabrication | scope-creep | unverifiable | vague-goal | missing-risk | missing-nongoal | bundled | missing-acceptance | missing-id | module-level-parity | no-unit | untagged-figure | unsized-scope | unmeasured-target | unbounded | silent-conflict | other' },
          section: { type: 'string' },
          issue: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['severity', 'type', 'section', 'issue', 'fix'],
      },
    },
    verdict: { type: 'string' },
  },
  required: ['findings', 'verdict'],
}

const RENDER_SCHEMA = obj({
  htmlPath: S, mdPath: S, promptPath: S, jsonPath: S,
  ok: { type: 'boolean', description: 'true only if render_prd.py exited 0' },
  lintScore: { type: 'number', description: 'prd-review total, or -1 if the linter did not run' },
  lintFindings: SA,
  issues: SA,
})

// ---- personas ----
const P = {
  product: { key: 'product', lens: 'Product / user', focus: 'Who is this for, what problem does it solve, what evidence of demand exists (who asked, deals lost, tickets) and what rule should decide priority, what does success look like as metric + baseline + target, what is explicitly out of scope and when it returns, what is the smallest version that delivers value.' },
  technical: { key: 'technical', lens: 'Technical / architecture', focus: 'How should this be built, what is the data and authorisation model, which existing behaviour rules must survive (name them, with file:line), integration points, sequencing into releases and a rough size for each (S/M/L, person-weeks), what existing patterns to reuse, the primary failure modes.' },
  edge: { key: 'edge', lens: 'Edge cases & failure', focus: 'Unhappy paths, input validation, concurrency, security (authz/authn/secrets/injection), performance and scale limits, what breaks at 10x load, rollback story.' },
  skeptic: { key: 'skeptic', lens: 'Contrarian / scope', focus: 'Challenge the scope. What is over-built? Which release is too big for its time box? What is the riskiest assumption? Which targets are asserted rather than measured? Which judgements should be argued rather than inherited? What is the simplest defensible version?' },
  integration: { key: 'integration', lens: 'Integration / data', focus: 'Upstream/downstream systems, migrations, backward compatibility, contracts/schemas, data lifecycle, idempotency.' },
  operations: { key: 'operations', lens: 'Operations / lifecycle', focus: 'Observability, metrics/logs/alerts, deployment, feature-flagging, on-call burden, cost, maintenance, docs.' },
}
let personas
if (mode === 'quick') personas = [P.product, P.skeptic]
else if (mode === 'balanced') personas = [P.product, P.technical, P.edge, P.skeptic]
else personas = [P.product, P.technical, P.edge, P.skeptic, P.integration, P.operations]

// ---- helpers ----
// Strip secret-shaped values so brownfield Scout output can never leak keys/tokens
// into the persisted, shareable HTML/JSON artifacts.
function redact(s) {
  if (!s) return s
  return s
    .replace(/\b(?:sk|pk|rk)-[A-Za-z0-9]{16,}\b/g, '[REDACTED-KEY]')
    .replace(/\bgh[posru]_[A-Za-z0-9]{20,}\b/g, '[REDACTED-TOKEN]')
    .replace(/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g, '[REDACTED-SLACK]')
    .replace(/\bAKIA[0-9A-Z]{16}\b/g, '[REDACTED-AWS]')
    .replace(/\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b/g, '[REDACTED-JWT]')
    .replace(/(?:password|passwd|secret|token|api[_-]?key)(\s*[:=]\s*)(['"]?)[^\s'"]{6,}\2/gi, 'credential$1[REDACTED]')
    .replace(/\b[a-z][a-z0-9+.-]*:\/\/[^\s/@]+:[^\s/@]+@/gi, '[REDACTED-CREDS]@')
}

// Deterministic readiness score: reproducible across runs, and structurally honest:
// never "Build-ready" (score OR label) while open questions or unmitigated high risks
// remain, and never "Build-ready" from a quick-mode run (limited coverage).
function computeReadiness(p, rawConfidencePct, runMode) {
  const mc = (rawConfidencePct == null ? 50 : rawConfidencePct) / 100
  const oq = (p.openQuestions || []).length
  // v3: a risk counts as "high" when impact is high and likelihood is not low (was severity === 'high').
  const highRisks = (p.risks || []).filter((r) => r.impact === 'high' && r.likelihood !== 'low').length
  let score = Math.round(100 * mc)
  score -= Math.min(oq * 5, 30)
  score -= highRisks * 6
  score = Math.max(0, Math.min(100, score))
  const honestyCapped = oq > 0 || highRisks > 0
  const quickCapped = runMode === 'quick'
  if (honestyCapped) score = Math.min(score, 89) // never green with unknowns
  if (quickCapped) score = Math.min(score, 70) // quick has limited coverage
  let label = score >= 70 ? 'Build-ready' : score >= 40 ? 'Shaping' : 'Exploratory'
  // The score cap above stops just short of "Build-ready" territory (89, or
  // exactly 70 in quick mode) but doesn't stop the >=70 label threshold from
  // still reading "Build-ready": cap the label the same way the score is capped.
  if ((honestyCapped || quickCapped) && label === 'Build-ready') label = 'Shaping'
  return { score, label }
}

// ---- Phase 1: Scout (brownfield only) ----
phase('Scout')
let repoFacts = ''
if (brownfield) {
  repoFacts = await agent(
    `Explore the codebase relevant to this task and extract the facts a planner needs to design: "${idea}".\n` +
    `If the idea names a specific path, focus there. Return two lists, concise bullets only, no prose preamble.\n` +
    `FACTS (max ~25), each citing file:line: relevant existing files/modules, current behavior, conventions/patterns to reuse, integration points, constraints, and anything that would change the design. Give every count a unit and say it came from a static read.\n` +
    `RULES (max ~60): the specific behaviour rules a rebuild or change must not silently drop, below module level (e.g. "version number assigned at authorisation, not draft", "round 2 opens only when round 1 completes"). ` +
    `Format each as "<AREA>-<n> | <rule> | <file:line> | Preserve or Decide". Say at the end that the list is capped and not exhaustive.\n` +
    `If nothing relevant exists, say so plainly.`,
    { label: 'scout', phase: 'Scout', agentType: 'Explore' }
  )
  const before = repoFacts.length
  repoFacts = redact(repoFacts)
  if (repoFacts.length !== before) log('Scout output redacted: secret-shaped values stripped before they reach the PRD.')
} else {
  log('Greenfield: skipping repo Scout; personas reason from the idea (and any input documents).')
}
if (inputs.length) {
  const docFacts = await agent(
    `Read these input documents in full: ${inputs.join(', ')}.\n` +
    `Extract what a planner needs for: "${idea}". Return concise bullets only, each tagged [Doc: <file name>]: requirements or asks (keep any IDs they carry), ` +
    `demand evidence (who asked, deals lost, tenders, tickets, with numbers and units exactly as written), constraints, decisions already taken, disagreements between documents, and figures with their units. ` +
    `Quote numbers exactly; if a number has no unit or no source in the document, say so. No prose preamble.`,
    { label: 'scout:inputs', phase: 'Scout', agentType: 'Explore' }
  )
  repoFacts = (repoFacts ? repoFacts + '\n\n' : '') + 'INPUT DOCUMENTS:\n' + redact(docFacts || '')
}

// ---- Phase 2: Interview (fan-out) ----
phase('Interview')
function interviewPrompt(p, round, priorOpen) {
  return (
    `You are self-interviewing to build a PRD for:\n"${idea}"\n\n` +
    `LENS: ${p.lens}\nFocus on: ${p.focus}\n\n` +
    (repoFacts ? `Repo facts (ground every answer in these; cite file:line):\n${repoFacts}\n\n` : `This is greenfield (no codebase yet).\n\n`) +
    (round === 2 && priorOpen ? `This is round 2. Re-attack these still-open questions specifically and resolve what you can:\n${priorOpen}\n\n` : '') +
    `Do this: (1) generate the sharp questions a senior planner asks in this lens; (2) ANSWER each one yourself with the single most defensible decision/assumption; ` +
    `(3) attach a confidence 0..1 and an evidence tag (Code, Doc, Demo, Assumption, Unknown) to each answer; give every number a unit; (4) any answer below ~0.6 confidence goes into openQuestions phrased as a crisp decision the user should make; ` +
    `(5) list concrete risks. Be specific and opinionated: pick a default rather than hedging. Set "lens" to "${p.lens}".`
  )
}

let interviews = (await parallel(
  personas.map((p) => () =>
    agent(interviewPrompt(p, 1, null), { label: `interview:${p.key}`, phase: 'Interview', schema: INTERVIEW_SCHEMA })
  )
)).filter(Boolean)

if (rounds === 2) {
  const stillOpen = interviews.flatMap((i) => i.openQuestions || [])
  if (stillOpen.length) {
    const priorOpen = stillOpen.map((q, n) => `${n + 1}. ${q}`).join('\n')
    const round2 = (await parallel(
      personas.map((p) => () =>
        agent(interviewPrompt(p, 2, priorOpen), { label: `interview2:${p.key}`, phase: 'Interview', schema: INTERVIEW_SCHEMA })
      )
    )).filter(Boolean)
    interviews = interviews.concat(round2)
  }
}

// deterministic confidence signal from the data personas already produced
const allConf = interviews.flatMap((i) => (i.qa || []).map((x) => x.confidence)).filter((n) => typeof n === 'number')
const rawConfidence = allConf.length ? Math.round((allConf.reduce((a, b) => a + b, 0) / allConf.length) * 100) : null
log(`mean self-answer confidence: ${rawConfidence == null ? 'n/a' : rawConfidence + '%'} across ${allConf.length} answers`)

// ---- Phase 3: Synthesize ----
phase('Synthesize')
const synthPrompt =
  `Synthesize these self-interviews into ONE coherent PRD model. Resolve conflicts between lenses, dedupe assumptions and open questions, and keep only decisions a reasonable reviewer would accept.\n\n` +
  `Idea: "${idea}"\n` +
  (repoFacts ? `Repo facts:\n${repoFacts}\n\n` : `Greenfield (no codebase).\n\n`) +
  `Mean self-answer confidence across all interviews: ${rawConfidence == null ? 'n/a' : rawConfidence + '%'}: use this to calibrate the readiness score (do not just echo it).\n\n` +
  `Interviews (JSON):\n${JSON.stringify(interviews)}\n\n` +
  `Document control: version "0.1", status "Draft. Not reviewed by a human.", owner "Unassigned", date "${today}", mode "${mode}", inputs ${JSON.stringify(inputs)}.\n\n` +
  `Rules (the PRD is judged by a PRD linter and a reviewer, so every rule is load-bearing):\n` +
  `1. IDs everywhere and stable: FR-<AREA>-n, NFR-n, G-n, NG-n, DA-n, D-n, Q-n, R-n, A-n.\n` +
  `2. Every functional requirement is ONE capability (split anything joined by "and" that would be built or tested separately), carries a MoSCoW priority, and names no technology. ` +
  `Every requirement, whatever its priority, has at least one Given/When/Then scenario; each Must also has a denied, empty or already-done scenario.\n` +
  `3. Goals are outcomes with metric, baseline, target and measuredBy. If the baseline was not measured, set baselineMeasured=false, say so in the baseline, and add an open question asking for the measurement.\n` +
  `4. NFRs carry a number, a unit, a condition and a measuredBy; baselineMeasured=false unless a real measurement is cited.\n` +
  `5. Every figure in context, goals and NFRs carries a unit and an evidence tag ([Code] file:line, [Doc: name], [Demo], [Assumption], [Unknown]). Never invent a number to fill a field; write "[Unknown]" and raise an open question.\n` +
  `6. No unbounded scope words ("any module", "all data", "everything"): name the list.\n` +
  `7. Releases: order them, size each one (S/M/L plus a person-week range and what the estimate rests on) and say what each unblocks. An unsized or unsizeable release gets an open question.\n` +
  `8. ${repoFacts && /RULES/.test(repoFacts) ? 'Carry the Scout RULES into legacyRules (keep their IDs) and make requirements cite them in trace. Parity asserted at module level only is a defect.' : 'legacyRules = [] unless repo facts list behaviour rules.'}\n` +
  `9. When lenses disagree, do NOT silently pick: record a decision (question, decision, why, trade-off, status). Name the prioritisation rule explicitly, citing its evidence; if no demand evidence was supplied, say so and add an open question.\n` +
  `10. Open questions: id, question, confidence (how sure you are of the default you assumed), why, owner (a ROLE, never an invented person), blocks (IDs), neededBy.\n` +
  `11. Risks: likelihood and impact rated separately (low/medium/high), a mitigation that becomes a test or a gate where possible, an owner role.\n` +
  `12. ${mode === 'deep' ? 'Gates: 2-4, each with what passes, what fails, a pre-written failure action and the role that makes the kill call.' : 'gates = [] (only deep mode writes gates).'}\n` +
  `13. testStrategy maps each requirement group (by ID range) to the test layer that proves it; definitionOfDone is one sentence.\n` +
  `14. contestable: 2-4 judgements in this PRD a reviewer should argue rather than inherit.\n` +
  `15. singleSource=true on any requirement resting on one answer below 0.6 confidence. source names the lens or input document.\n` +
  `16. Plain words: no "several", "various", "some", "many", "multiple", "easy", "intuitive", "seamless", "robust", "scalable", "fast" (give the number), "in order to", "be able to". No em or en dashes.\n` +
  `17. readiness = { score 0-100, label, rationale } (score is recomputed later; write the rationale). implementationSpec: context (files + behavior + constraints), objective (outcome), boundaries (what must NOT change + paths off-limits), validation (exact command + expected result + the acceptance IDs it proves).\n` +
  `18. diagrams: at least 3 and at most 4 mermaid diagrams, each drawn from facts already in this PRD (no new scope): kind "system" in chapter "context" (the parts and what flows between them), ` +
  `kind "flow" in chapter "functional" (the main user flow or a sequence, naming FR IDs in node labels where they fit), kind "delivery" in chapter "releases" (releases in order with the gates between them and each failure route). ` +
  `A 4th, kind "risk" or "state" in chapter "risks", only if it shows something the tables cannot. Use flowchart, sequenceDiagram or stateDiagram-v2; in flowcharts put every node label in double quotes (sequence and state labels stay plain text, quotes would show); ` +
  `no styling, classDef, click or links; about 14 nodes at most. Caption = 1-2 plain sentences on what the reader should notice.`
let prd = await agent(synthPrompt, { label: 'synthesize', phase: 'Synthesize', schema: PRD_SCHEMA })

// ---- Phase 3.5: Critique + Revise (skipped in quick mode) ----
if (useCritic) {
  phase('Critique')
  const critique = await agent(
    `Adversarially review this draft PRD. You are the reviewer lane: do NOT rewrite it, find what is wrong with it.\n\n` +
    (repoFacts ? `Repo facts (ground truth):\n${repoFacts}\n\n` : `Greenfield (no codebase).\n\n`) +
    `Draft PRD (JSON):\n${JSON.stringify(prd)}\n\n` +
    `Hunt specifically for: fabricated or uncited facts (claims not supported by the idea or repo facts); scope creep (anything beyond the smallest valuable version that isn't justified); ` +
    `unverifiable success/verification criteria ("works well", no command); vague goals that describe code shape instead of an outcome; missing high-impact risks; missing obvious non-goals; ` +
    `bundled requirements (two capabilities in one); requirements missing an ID, a priority or acceptance scenarios; parity asserted at module level when repo rules exist; numbers with no unit or no evidence tag; ` +
    `releases with no size; targets whose baseline was never measured but are not marked provisional; unbounded scope words ("any module"); lens disagreements resolved silently instead of recorded as a decision. ` +
    `Return findings as { severity (low/med/high), type, section, issue, fix } and a one-line verdict. Be specific and cite the section. If the PRD is solid, return few or no findings: do not invent problems.`,
    { label: 'critique', phase: 'Critique', schema: CRITIQUE_SCHEMA }
  )
  const serious = (critique.findings || []).filter((f) => f.severity === 'high' || f.severity === 'med')
  log(`critic: ${(critique.findings || []).length} findings (${serious.length} med/high). Verdict: ${critique.verdict}`)
  if (serious.length) {
    phase('Revise')
    prd = await agent(
      `Apply these review findings to the PRD and return the corrected PRD (same schema). Fix every med/high finding; ` +
      `apply low findings where cheap. Do not introduce new scope. Keep what was already good.\n\n` +
      `Findings (JSON):\n${JSON.stringify(serious)}\n\n` +
      `Current PRD (JSON):\n${JSON.stringify(prd)}`,
      { label: 'revise', phase: 'Revise', schema: PRD_SCHEMA }
    )
  } else {
    log('No med/high findings: keeping the draft PRD as final.')
  }
}

// deterministic, reproducible readiness: overwrite the LLM's score/label, keep its rationale
const r = computeReadiness(prd, rawConfidence, mode)
prd.readiness = {
  score: r.score,
  label: r.label,
  rationale: (prd.readiness && prd.readiness.rationale) || 'Computed from self-answer confidence, open questions, and high risks.',
}
log(`readiness: ${r.score}/100 (${r.label})`)

// ---- Phase 4: Render (deterministic) ----
// The render agent only writes the JSON and runs render_prd.py; the script builds the HTML,
// markdown and prompt from it, self-checks the HTML, and runs the prd-review linter.
const jsonPath = `${outDir}/${slug}-prd.json`
function renderPrompt(model) {
  return (
    `Run \`mkdir -p ${outDir}\`. Then write the PRD JSON below, byte for byte and pretty-printed, to ${jsonPath} (use the Write tool; do not summarise or edit it).\n` +
    (rendererPath && templatePath
      ? `Then run: python3 "${rendererPath}" --json "${jsonPath}" --template "${templatePath}"${lintPath ? ` --lint "${lintPath}"` : ''}\n` +
        `It prints one JSON line {htmlPath, mdPath, promptPath, checks, lint}. Report ok=true only if it exited 0. lintScore = lint.total (-1 if absent or null), lintFindings = lint.findings, issues = the checks list if not "ok".\n`
      : `rendererPath or templatePath was not provided: build ${outDir}/${slug}-prd.html (self-contained, inline CSS/JS, no external resources) and ${outDir}/${slug}-prd.md and ${outDir}/${slug}-prompt.md yourself from the section list in references/prd-contract.md. lintScore = -1.\n`) +
    `\nPRD (JSON):\n${JSON.stringify(model)}\n\n` +
    `Return { htmlPath, mdPath, promptPath, jsonPath, ok, lintScore, lintFindings, issues }. Do not summarise the PRD.`
  )
}
phase('Render')
let render = await agent(renderPrompt(prd), { label: 'render', phase: 'Render', model: 'sonnet', schema: RENDER_SCHEMA })
log(`render: ok=${render && render.ok} lint=${render && render.lintScore}`)

// ---- Phase 5: Verify (one fix pass, driven by the linter AND every renderer check) ----
phase('Verify')
let lintScore = render && render.lintScore >= 0 ? render.lintScore : null
// every failed render check goes to the fix pass (diagrams, dashes, external refs, anything),
// and a render that failed without naming a check still gets one
const renderIssues = ((render && render.issues) || []).map(String)
if (render && !render.ok && !renderIssues.length) renderIssues.push('renderer exited non-zero without naming a check')
if ((lintScore != null && lintScore < LINT_FLOOR) || renderIssues.length) {
  log(`lint ${lintScore}, renderer issues ${renderIssues.length}: one targeted fix pass`)
  prd = await agent(
    `${lintScore != null ? `The prd-review linter scored this PRD ${lintScore}/100` : 'The PRD was not linted'}${renderIssues.length ? ' and the renderer rejected it' : ''}. Fix what these findings name and return the corrected PRD (same schema). ` +
    `Do not add scope; do not remove requirements; keep IDs stable. Never use em or en dashes in any text.\n\nLinter findings:\n${((render && render.lintFindings) || []).join('\n') || 'none'}\n\nRenderer issues:\n${renderIssues.join('\n') || 'none'}\n\nCurrent PRD (JSON):\n${JSON.stringify(prd)}`,
    { label: 'lint-fix', phase: 'Verify', schema: PRD_SCHEMA }
  )
  const r2 = computeReadiness(prd, rawConfidence, mode)
  prd.readiness = { score: r2.score, label: r2.label, rationale: (prd.readiness && prd.readiness.rationale) || '' }
  render = await agent(renderPrompt(prd), { label: 'render2', phase: 'Verify', model: 'sonnet', schema: RENDER_SCHEMA })
  lintScore = render && render.lintScore >= 0 ? render.lintScore : null
  log(`after fix: lint=${lintScore}`)
}
const htmlPath = (render && render.htmlPath) || `${outDir}/${slug}-prd.html`
const mdPath = (render && render.mdPath) || `${outDir}/${slug}-prd.md`
const promptPath = (render && render.promptPath) || `${outDir}/${slug}-prompt.md`

return {
  slug,
  mode,
  outDir,
  htmlPath,
  promptPath,
  jsonPath,
  mdPath,
  readiness: prd.readiness || null,
  lintScore,
  lintFindings: (render && render.lintFindings) || [],
  openQuestions: prd.openQuestions || [],
  verified: !!(render && render.ok),
  summary: prd.summary || '',
  prd,
}
