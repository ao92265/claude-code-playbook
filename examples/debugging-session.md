# Example: Debugging Session

An annotated session showing the `/debug` skill's scientific method in action.

---

## Context

Users report intermittent 500 errors on the `/api/orders` endpoint. It works most of the time but fails ~5% of requests.

---

## Session Transcript

**User:**
```
Users are getting intermittent 500 errors on GET /api/orders.
It works most of the time but fails about 5% of requests.
The error in logs is: "Cannot read properties of undefined (reading 'email')"
at src/services/order-service.ts:47

Debug this systematically. Don't guess — form hypotheses and test them.
```

> **Pattern: Paste the actual error.** The user includes the error message, file, line number, and frequency. This eliminates the exploration phase.

**Claude:**
```
Let me read the code at the crash site first.
```
*[Reads src/services/order-service.ts:40-55]*

```typescript
// Line 47:
const enrichedOrders = orders.map(order => ({
  ...order,
  customerEmail: order.customer.email,  // <-- crash here
  customerName: order.customer.name,
}));
```

> **Step 1: Reproduce.** Claude reads the exact crash site before forming any hypothesis.

**Claude:**
```
Hypothesis 1: Some orders have a null/undefined customer relationship.
This would happen if:
  a) The customer was deleted but the order remains
  b) The JOIN/include is missing for some query paths
  c) A race condition between order creation and customer lookup

Let me test hypothesis 1a — check for orphaned orders.
```

*[Runs a query to check for orders where customer is null]*

```sql
SELECT COUNT(*) FROM orders WHERE customer_id NOT IN (SELECT id FROM customers);
-- Result: 0
```

> **Pattern: Test, don't guess.** Claude ran a query instead of adding a null check. Hypothesis 1a is refuted with evidence.

**Claude:**
```
No orphaned orders. Refuting 1a.

Testing hypothesis 1b — checking if the query always includes customer.
```

*[Reads the repository call that fetches orders]*
*[Finds two different query paths — one with `.include('customer')` and one without]*

```
Found it. There are two query paths:

1. src/repositories/order-repo.ts:23 — getOrders() — includes customer ✓
2. src/repositories/order-repo.ts:31 — getOrdersByDate() — NO customer include ✗

The date-filtered endpoint uses getOrdersByDate() which doesn't
join the customer table. When the frontend passes a date filter,
it hits the second path and customer is undefined.
```

> **Pattern: Binary search the problem space.** Claude checked both query paths rather than assuming the one at the crash site was the only caller.

**Claude:**
```
Fix: Add .include('customer') to getOrdersByDate().
This is a one-line change.
```

*[Edits src/repositories/order-repo.ts:31 — adds the include]*

**Claude:**
```
Running tests to verify.
```
*[Runs `npm test -- --grep "order"`]*
```
  ✓ getOrders returns orders with customer data (89ms)
  ✓ getOrdersByDate returns orders with customer data (92ms)  // NEW
  ✓ getOrdersByDate filters by date range (45ms)

6 passing (312ms)
```

> **Pattern: Add a test for the bug.** Claude added a test that would have caught this — `getOrdersByDate returns orders with customer data`. This prevents regression.

**Claude:**
```
Root cause: getOrdersByDate() in order-repo.ts was missing the
customer include. When users filtered by date, the code path
skipped the JOIN, leaving customer as undefined.

Fix: Added .include('customer') to getOrdersByDate() (one line).
Added test to verify customer data is present in date-filtered results.
All 6 order tests pass.
```

---

## What Made This Session Work

1. **Error message included** — no time wasted reproducing
2. **Hypotheses were explicit** — each one testable and falsifiable
3. **Evidence over guessing** — SQL query to check orphaned records, code reading to check query paths
4. **Root cause, not symptom** — didn't add a null check at line 47, found the missing JOIN
5. **Regression test added** — this specific bug can never return

## Anti-Patterns Avoided

| Anti-Pattern | What Claude Did Instead |
|:-------------|:-----------------------|
| Adding `order.customer?.email` (band-aid) | Found and fixed the missing JOIN |
| "It might be a race condition" (vague guess) | Tested specific hypotheses with evidence |
| Fixing without understanding | Identified both query paths before changing either |
| No test for the bug | Added a test that specifically covers the failure case |
