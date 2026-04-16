---
title: Multi-Agent Session
nav_order: 4
parent: Examples
---
# Example: Multi-Agent Session

An annotated session showing parallel agent orchestration with model routing and worktree isolation.

---

## Context

Adding a notifications system that needs: a database schema, an API endpoint, a React component, and email integration. Four independent workstreams that can run in parallel.

---

## Session Transcript

**User:**
```
Build a notifications system:
- Database: notifications table with user_id, type, message, read_at, created_at
- API: GET /api/notifications (list), PATCH /api/notifications/:id/read (mark read)
- Frontend: NotificationBell component with dropdown and unread count badge
- Email: send email for high-priority notifications using the existing mailer service

These are independent — parallelize where possible. Cap at 3 agents.
```

> **Pattern: Explicit parallelization guidance.** The user identified the independent workstreams and set the agent cap. This prevents Claude from spawning too many agents and hitting rate limits.

**Claude:**
```
I'll split this into 3 parallel workstreams, then handle email integration
myself since it depends on the API being ready.

Spawning agents:
1. Database + API (Sonnet) — schema migration and both endpoints
2. Frontend component (Sonnet) — NotificationBell with dropdown
3. Email integration (after 1 + 2 complete)
```

> **Pattern: Model routing.** Sonnet for implementation work — the right default. Haiku would be too shallow for multi-file features, Opus would be overkill.

*[Spawns Agent 1: model=sonnet, isolation=worktree]*
```
Agent 1: Create the notifications table migration and implement
GET /api/notifications and PATCH /api/notifications/:id/read.
Follow the existing patterns in src/api/ and db/migrations/.
Run tests when done.
```

*[Spawns Agent 2: model=sonnet, isolation=worktree]*
```
Agent 2: Create a NotificationBell component in src/components/notifications/.
Include: bell icon with unread count badge, dropdown panel showing recent
notifications, mark-as-read on click. Follow existing component patterns.
Run type checker when done.
```

> **Pattern: Worktree isolation.** Each agent works in its own git worktree — no merge conflicts, no stepping on each other's files. The parent merges results after both complete.

**Claude:**
```
Both agents are running. While they work, let me review the existing
mailer service to prepare for the email integration.
```
*[Reads src/services/mailer.ts]*

> **Pattern: Productive waiting.** Instead of blocking on the agents, Claude uses the wait time to prepare for the next step. This overlaps research with execution.

**Claude:**
```
Agent 1 completed:
- Created db/migrations/20240315_notifications.sql
- Implemented GET /api/notifications with pagination
- Implemented PATCH /api/notifications/:id/read
- All API tests passing (12/12)

Agent 2 completed:
- Created src/components/notifications/NotificationBell.tsx
- Created src/components/notifications/NotificationDropdown.tsx
- Added useNotifications hook with polling
- Types clean (tsc --noEmit passed)
```

> **Pattern: Agent result verification.** Claude checks that each agent ran its verification step (tests, type checker) before proceeding.

**Claude:**
```
Now implementing email integration using the existing mailer service.
```
*[Edits src/services/notification-service.ts — adds email dispatch for high-priority notifications]*

**Claude:**
```
Running full test suite to verify everything works together.
```
*[Runs `npm test`]*
```
  Notifications API
    ✓ GET /api/notifications returns user notifications (156ms)
    ✓ GET /api/notifications supports pagination (98ms)
    ✓ PATCH /api/notifications/:id/read marks as read (87ms)
    ✓ PATCH returns 404 for missing notification (45ms)
    ...

  NotificationBell
    ✓ renders unread count badge (23ms)
    ✓ opens dropdown on click (34ms)
    ✓ marks notification as read on click (56ms)
    ...

  Notification Email
    ✓ sends email for high-priority notifications (112ms)
    ✓ skips email for low-priority notifications (15ms)

47 passing (1.2s)
```

**Claude:**
```
Notifications system complete:

Files created/modified:
- db/migrations/20240315_notifications.sql (new)
- src/api/notifications.ts (new — 2 endpoints)
- src/components/notifications/NotificationBell.tsx (new)
- src/components/notifications/NotificationDropdown.tsx (new)
- src/hooks/useNotifications.ts (new)
- src/services/notification-service.ts (modified — email dispatch)

47 tests passing. Types clean. Ready for review.
```

---

## What Made This Session Work

1. **User identified parallel workstreams** — Claude didn't have to guess what's independent
2. **Agent cap was explicit** — 3 agents max prevents rate limit issues
3. **Worktree isolation** — agents can't conflict with each other
4. **Model routing was appropriate** — Sonnet for implementation, not Opus
5. **Sequential dependency was handled** — email waited for API to be ready
6. **Full test suite ran at the end** — integration verification, not just unit tests

## Multi-Agent Safety Rules

| Rule | Why |
|------|-----|
| Cap at 3-4 agents | API rate limits, credential contention |
| Each agent gets its own worktree | Prevents merge conflicts and file overwrites |
| Never `git add -A` in multi-agent | Could stage another agent's work-in-progress |
| Verify combined output | Individual agents pass ≠ system works together |
| Test push credentials first | `gh auth status` before spawning agents that push |
| Parent handles merging | Agents produce work, parent integrates |
