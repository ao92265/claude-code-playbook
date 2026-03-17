---
name: perf-check
description: >
  Performance investigation workflow: profile, identify bottlenecks, and optimize
  with measurable before/after results. Prevents premature optimization.
  Triggers: "perf check", "performance", "slow", "optimize", "bottleneck".

  Do NOT use this skill for: general code quality (use /code-review), fixing bugs
  (use /debug), or micro-optimizations that don't matter.
metadata:
  user-invocable: true
  slash-command: /perf-check
  proactive: false
---

# Performance Investigation

Systematic approach to finding and fixing performance issues. Profile first, optimize second.

## Steps

1. **Define the problem:**
   - What's slow? (endpoint, page load, build, test suite, query)
   - How slow is it? Get a baseline measurement
   - What's the target? (e.g., "API response under 200ms")
   - When did it start? (recent regression vs. always slow)

2. **Profile before optimizing:**
   - **Node.js**: `--prof` flag, `clinic.js`, or `0x` for flamegraphs
   - **Frontend**: Chrome DevTools Performance tab, Lighthouse
   - **Database**: `EXPLAIN ANALYZE` on slow queries
   - **General**: time the operation with `console.time()` or equivalent
   - Record the baseline numbers precisely

3. **Identify the bottleneck:**
   - Where is time actually being spent? (CPU, I/O, network, database)
   - Is it a single slow operation or death by a thousand cuts?
   - Look for: N+1 queries, missing indexes, unnecessary re-renders, blocking I/O, large payloads

4. **Prioritize fixes:**
   - Fix the biggest bottleneck first — often one fix solves 80% of the problem
   - Estimate effort vs. impact for each potential fix
   - Don't optimize things that aren't in the hot path

5. **Implement the fix:**
   - Make ONE change at a time
   - Common fixes: add database index, add caching, reduce payload, batch queries, lazy load, debounce
   - Keep the code readable — clever optimizations that nobody can understand aren't worth it

6. **Measure after:**
   - Run the same profile/benchmark as step 2
   - Compare before/after numbers precisely
   - Did it meet the target? If not, go back to step 3

7. **Document the result:**
   - What was the bottleneck?
   - What was the fix?
   - Before/after numbers
   - Any trade-offs made (memory vs. speed, complexity vs. performance)

## Important

- **Profile before optimizing.** Guessing at bottlenecks wastes time on the wrong thing.
- **Measure before AND after.** "It feels faster" is not evidence. Numbers are evidence.
- **One change at a time.** Multiple simultaneous changes make it impossible to know what helped.
- **Don't optimize prematurely.** If it's fast enough, leave it alone.
- **Readability > cleverness.** A 10% speedup that makes code unreadable isn't worth it unless you're in a hot loop.
