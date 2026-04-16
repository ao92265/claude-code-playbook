---
title: Full-Stack
nav_order: 4
parent: Templates
---
# CLAUDE.md — Full-Stack Monorepo

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Describe your monorepo structure -->
This is a full-stack TypeScript monorepo. Structure:
- `packages/shared/` — Shared types, utilities, and validation schemas
- `apps/api/` — Backend API (Express/Fastify + Prisma)
- `apps/web/` — Frontend (React/Next.js)

Package manager: pnpm (with workspaces). All packages use TypeScript strict mode.

## Shared Types

<!-- How types are shared between frontend and backend -->
- `packages/shared/` is the single source of truth for types used by both frontend and backend
- API request/response types, validation schemas, and enums live here
- Never duplicate types between apps — import from shared
- When changing shared types, verify both apps still compile

## API Contracts

<!-- Rules for API changes -->
- API changes require both backend and frontend updates in the same PR
- If the API response shape changes, update the shared type first, then both consumers
- Use versioned endpoints (`/api/v1/`) for breaking changes
- Document all endpoints with request/response types in shared package

## Build Order

<!-- Build dependency chain -->
Build in this order — shared libs first, then consumers:
1. `packages/shared` — shared types and utilities
2. `apps/api` — backend (depends on shared)
3. `apps/web` — frontend (depends on shared)

```bash
pnpm --filter shared build && pnpm --filter api build && pnpm --filter web build
# Or: pnpm build (if workspace scripts are configured)
```

## Database

<!-- Database rules for monorepo -->
- Migrations live in `apps/api/` only — never run migrations from the frontend
- Seed data lives alongside migrations
- Schema changes require a migration — never modify the database directly
- Use transactions for multi-table operations
- Test against a real database, not mocks

## Environment Variables

<!-- Environment management across services -->
- Each app has its own `.env` file (`apps/api/.env`, `apps/web/.env`)
- Document all required variables in each app's `.env.example`
- Shared/common variables (e.g., API URL) should be consistent across apps
- Never commit `.env` files — `.env.example` only
- Frontend variables must be prefixed appropriately (`NEXT_PUBLIC_`, `VITE_`, etc.)

## Testing Strategy

<!-- Testing across the monorepo -->
- **Unit tests** per package: `packages/shared`, `apps/api`, `apps/web` each have their own test suite
- **Integration tests** for the API: test endpoints with a real database
- **E2E tests** for critical user flows: login, core CRUD operations, checkout/payment
- Run all tests: `pnpm test` (workspace-level)
- Run specific: `pnpm --filter api test`

## Cross-App Changes

<!-- Rules for changes that span multiple apps -->
- Type changes: update `packages/shared` first, then update consumers
- API endpoint changes: update backend, update shared types, update frontend — in that order
- Always run the full monorepo build after cross-app changes to catch type errors
- PR descriptions must list which apps are affected

## Deployment

<!-- Deployment coordination -->
- If API response shape changes: deploy backend first, then frontend
- If frontend consumes a new endpoint: deploy backend first, then frontend
- If changes are independent: deploy in any order
- Use feature flags for gradual rollout of breaking changes
- Verify the deployed version matches the build (check health endpoint)

## Verification

<!-- How to verify work is complete -->
Before claiming work is done:
1. Run `pnpm build` from the root — all packages build successfully
2. Run `pnpm test` from the root — all test suites pass
3. Run `pnpm tsc --noEmit` per app — zero type errors across the workspace
4. If cross-app changes: verify the API contract is consistent
5. For UI changes: ask the user to visually confirm
