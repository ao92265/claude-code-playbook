---
title: Node API
nav_order: 2
parent: Templates
---
# CLAUDE.md — Node.js API Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your framework, ORM, database, and runtime -->
This is a Node.js API using Express and TypeScript. Database access is through Prisma ORM. All code must be TypeScript with strict mode. Use async/await everywhere — no callbacks.

## REST Conventions

<!-- API design rules -->
- `GET` for reads, `POST` for creates, `PUT` for full updates, `PATCH` for partial updates, `DELETE` for deletions
- URL naming: plural nouns, kebab-case (`/api/user-profiles`, not `/api/getUserProfile`)
- Status codes: 200 (success), 201 (created), 204 (no content), 400 (bad request), 401 (unauthenticated), 403 (forbidden), 404 (not found), 409 (conflict), 422 (validation), 500 (server error)
- All list endpoints must support pagination (`?page=1&limit=20`)
- Consistent response shape: `{ data, meta, error }`

## Middleware Stack

<!-- Middleware ordering -->
Middleware order matters. Follow this sequence:
1. CORS
2. Request logging
3. Body parsing
4. Authentication (JWT validation)
5. Authorization (role/permission checks)
6. Input validation
7. Route handler
8. Error handler (must be last)

## Database

<!-- Database rules -->
- Migrations before seeds — always create a migration for schema changes
- Never use raw SQL without parameterized queries (SQL injection prevention)
- Connection pooling is mandatory for production
- Every query that returns a list must be paginated
- Use transactions for multi-table operations
- Test against the real database, not mocks

## Authentication & Authorization

<!-- Auth patterns -->
- JWT validation on every protected route
- Never log tokens, passwords, or session data
- RBAC (Role-Based Access Control) checks in middleware, not in route handlers
- Token expiry and refresh flow must be implemented
- Rate limit auth endpoints (login, register, password reset)

## Error Handling

<!-- Error handling patterns -->
- Structured error responses: `{ error: { code, message, details } }`
- Never swallow exceptions — catch, log, and re-throw or respond
- 4xx errors = client problem (log at info level)
- 5xx errors = server problem (log at error level with stack trace)
- Global error handler catches unhandled errors — never let Express show raw stack traces
- Use custom error classes that extend Error with a `statusCode` property

## Testing

<!-- Testing approach -->
- Integration tests with a real database (test database, not mocks)
- API contract tests: verify request/response shapes
- Test error paths too — 400s, 401s, 404s, 500s
- Each test suite sets up and tears down its own data
- Never depend on test execution order
- Run tests with: `npm test`

## Performance

<!-- Performance rules -->
- Pagination required on all list endpoints — no unbounded queries
- N+1 query prevention: use `include` / `join` / batch loading
- Set appropriate cache headers for GET endpoints
- Index database columns used in WHERE clauses and JOINs
- Log slow queries (> 100ms) for investigation

## Security

<!-- Security requirements -->
- Input validation on all endpoints (zod, joi, or class-validator)
- Rate limiting on public endpoints
- CORS configured for specific origins, not `*`
- No secrets in logs, responses, or error messages
- Helmet.js (or equivalent) for security headers
- Dependencies audited regularly (`npm audit`)

## Verification

<!-- How to verify work is complete -->
Before claiming API work is done:
1. Run `npx tsc --noEmit` — zero type errors
2. Run `npm test` — all tests pass
3. Test the endpoint manually with curl or httpie
4. Verify error responses for invalid inputs
5. Check that no secrets appear in logs or responses
