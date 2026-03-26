# Legacy Modernization with Claude Code

How to use Claude Code to understand, refactor, and incrementally modernize legacy codebases without big-bang rewrites.

---

## Why AI Changes the Equation

Legacy modernization has always failed for the same reason: the hardest part isn't writing new code — it's understanding the old code. Claude Code's 1M token context window can hold entire legacy modules, and its reasoning capabilities can map out dependencies, identify patterns, and explain business logic that no one on the team remembers writing.

**What AI does well in modernization:**
- Understanding legacy code faster than reading it manually
- Identifying patterns and extracting implicit business rules
- Mechanical code translation (language/framework upgrades)
- Incremental refactoring with test generation
- Documentation generation for undocumented systems

**What AI does NOT replace:**
- Architectural decisions about what to modernize and in what order
- Business stakeholder sign-off on behavior changes
- Performance testing under production-like load
- Domain knowledge about why the code works the way it does

---

## The Incremental Approach

Big-bang rewrites fail. The proven strategy is incremental modernization — small, verified changes that keep the system working at every step.

```
Legacy System
    ↓ (understand)
Documented Legacy System
    ↓ (test)
Documented + Tested Legacy System
    ↓ (refactor incrementally)
Modernized System
```

Each step is independently valuable. You can stop at any point and still have a better system than you started with.

---

## Phase 1: Understand

Before changing anything, use Claude Code to understand what exists.

### Map the Codebase

```
Load the module into context and create a dependency map:

"Read all files in src/legacy-auth/ and produce:
1. A dependency graph (what calls what)
2. A list of all external integrations (APIs, databases, file systems)
3. Business rules embedded in the code (validation, calculations, branching logic)
4. Known risks (hardcoded values, missing error handling, security concerns)

Output as a markdown document. Do not modify any code."
```

### Generate Missing Documentation

```
"Read src/legacy-auth/session-manager.js and write documentation:
1. What this module does (purpose, responsibilities)
2. Public API (functions, parameters, return values)
3. Side effects (database writes, file I/O, external calls)
4. Implicit assumptions (expected environment, required state)

Write the documentation as a comment block at the top of the file.
Do not change any code."
```

### Identify Technical Debt Hotspots

```
"Analyse src/legacy-auth/ and rank files by technical debt severity:
- Duplicated logic
- Missing error handling
- Hardcoded configuration
- Functions over 100 lines
- Circular dependencies
- Dead code

Output as a prioritised table with file, issue, severity, and estimated effort."
```

---

## Phase 2: Test

Before refactoring, add tests that lock in current behaviour. This is your safety net.

### Generate Characterisation Tests

```
"Read src/legacy-auth/session-manager.js and write characterisation tests
that capture the current behaviour — including edge cases and error paths.

These tests should PASS against the current code as-is. We're documenting
behaviour, not asserting correctness. If the code has a bug, the test
should expect the buggy behaviour (add a comment noting it).

Use [your test framework]. Do not modify the source code."
```

### Identify Untestable Code

```
"Read src/legacy-auth/session-manager.js and identify code that is
difficult to test:
- Global state dependencies
- Hardcoded external URLs or file paths
- Functions that mix I/O with business logic
- Tightly coupled modules

For each, suggest the minimum change needed to make it testable.
Do not apply any changes yet."
```

---

## Phase 3: Refactor Incrementally

With tests in place, make small, verified changes. Each change should:
- Keep all existing tests passing
- Be independently committable
- Not change external behaviour

### Extract Business Rules

```
"In src/legacy-auth/session-manager.js, the validation logic between
lines 142-198 mixes business rules with database calls.

Extract the pure business rules into a separate function that takes
inputs and returns a result — no side effects. Keep the database calls
in the original function. All existing tests must still pass."
```

### Replace Deprecated Patterns

```
"In src/legacy-auth/, replace all callback-based async patterns with
async/await. Change one file at a time. After each file:
1. Run existing tests
2. Verify no behaviour change
3. Commit before moving to the next file"
```

### Upgrade Dependencies

```
"The project uses [old-library@2.x]. Upgrade to [new-library@5.x].
1. Read the migration guide for breaking changes
2. Update the import/require statements
3. Adapt API calls to the new interface
4. Run tests after each file change
Do not upgrade unrelated dependencies."
```

---

## Phase 4: Translate (Language/Framework Migration)

For migrations between languages or frameworks (e.g., jQuery → React, Java → Kotlin, Express → Fastify):

### Module-by-Module Translation

```
"Translate src/legacy-auth/session-manager.js from Express middleware
to a Fastify plugin.

Rules:
- Preserve all business logic exactly
- Map Express patterns to Fastify equivalents (req/res → request/reply)
- Keep the same test assertions — only change the test setup
- Document any behavioural differences between Express and Fastify
  that affect this module"
```

### Strangler Fig Pattern

The safest migration pattern: run old and new side by side, routing traffic gradually.

```
Step 1: New module handles 0% of traffic (exists but unused)
Step 2: Route 5% of traffic to new module, monitor for errors
Step 3: Gradually increase to 100% over days/weeks
Step 4: Remove old module when confident

Claude Code helps with Steps 1 and 4: building the new module and
removing the old one. Steps 2-3 are infrastructure decisions.
```

---

## CLAUDE.md Template for Modernization

```markdown
## Legacy Modernization Rules

We are incrementally modernizing [module/system name].

Rules:
- Never change external behaviour without explicit approval
- All existing tests must pass after every change
- One refactoring step per session — do not combine unrelated changes
- If you discover a bug in legacy code, document it but do not fix it
  unless that is the current task
- Generate characterisation tests before refactoring untested code
- Commit after each successful change with message format:
  "refactor(legacy): [what changed] [why]"
```

---

## Cost and Time Estimates

| Activity | Claude Code Time | Manual Time | Cost (Sonnet) |
|:---------|:---------------:|:----------:|:-------------:|
| Map a 5K-line module | 15-30 min | 2-4 hours | $0.30-0.80 |
| Generate characterisation tests | 30-60 min | 4-8 hours | $0.50-1.50 |
| Extract business rules (per function) | 10-20 min | 1-2 hours | $0.15-0.40 |
| Translate module (language migration) | 30-60 min | 1-3 days | $0.50-2.00 |
| Full module modernization | 2-4 hours | 1-3 weeks | $3-10 |

**ROI:** A single module modernization typically saves 5-15 developer-days. At $75/hour, that's $3,000-9,000 in developer time vs $3-10 in Claude Code costs.

---

## What Works and What Doesn't

| Task | Effectiveness | Notes |
|:-----|:------------:|:------|
| Code understanding and mapping | Excellent | Claude's biggest strength — 1M context handles entire modules |
| Characterisation test generation | Good | Catches most paths; may miss deeply hidden edge cases |
| Mechanical refactoring (rename, extract, inline) | Excellent | Pattern-following with test verification |
| Language/framework translation | Good | ~85% accuracy; review boundary cases carefully |
| Dependency upgrades | Good | Best when migration guides exist |
| Architecture decisions | Poor | Claude can propose options; humans must decide |
| Performance optimization | Medium | Can identify hotspots but needs profiling data to validate |
| Business rule extraction | Good | But always validate with domain experts |

---

## Common Pitfalls

1. **Don't skip characterisation tests.** Refactoring without tests is flying blind. Claude can generate them quickly — there's no excuse to skip this step.

2. **Don't let Claude "improve" things.** Legacy code often has subtle reasons for being the way it is. Instruct Claude to preserve behaviour, not optimise it.

3. **Don't modernize everything at once.** Pick the highest-value module (most bugs, most changes, most developer pain) and do that first. Prove the approach before scaling.

4. **Don't trust translations blindly.** Language migration introduces subtle differences (floating point, string encoding, null handling). Always have characterisation tests in both the old and new versions.

5. **Don't forget the database.** Code modernization without schema modernization creates a mismatch. Plan database changes separately.
