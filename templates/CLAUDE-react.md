# CLAUDE.md — React / Next.js Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your React version, framework, and key dependencies -->
This is a React 18+ TypeScript project using Next.js (App Router). All code must be TypeScript with strict mode enabled. Use functional components exclusively — no class components.

## Component Rules

<!-- Define your component patterns -->
- Functional components only, with explicit return types
- Custom hooks for any shared logic (prefix with `use`)
- No prop drilling past 2 levels — use Context or composition instead
- Colocate component, styles, types, and tests in the same directory
- Export components as named exports, not default exports
- Keep components under 150 lines — extract sub-components when larger

## State Management

<!-- Specify your state management approach -->
- Local state (`useState`) first — don't reach for global state by default
- React Context for app-wide state (auth, theme, locale)
- Only introduce external state management (Zustand, Redux, etc.) if Context becomes unwieldy
- Server state belongs in data fetching layer (React Query / SWR), not component state
- Never store derived data in state — compute it

## Styling

<!-- Choose your approach: Tailwind, CSS Modules, styled-components, etc. -->
- Tailwind CSS for all styling
- Use `cn()` utility for conditional class merging
- No inline styles except for truly dynamic values (e.g., calculated positions)
- Design tokens live in `tailwind.config.ts` — don't hardcode colors or spacing

## Testing

<!-- Testing conventions -->
- React Testing Library for component tests — test behavior, not implementation
- `userEvent` over `fireEvent` (more realistic interaction simulation)
- No snapshot tests — they break on every change and catch nothing
- Test what the user sees: query by role, label, or text, not by class or test-id
- Mock external services only — never mock React hooks or internal modules

## Accessibility

<!-- A11y requirements -->
- Semantic HTML elements (`button`, `nav`, `main`, `section`) over generic `div`
- All interactive elements must be keyboard accessible
- Images require meaningful `alt` text (or `alt=""` for decorative)
- Form inputs must have associated labels
- Color alone must not convey information — use icons or text alongside
- Test with keyboard navigation before marking UI work complete

## Next.js Specifics

<!-- Remove this section if not using Next.js -->
- Prefer Server Components by default — only add `'use client'` when needed (event handlers, hooks, browser APIs)
- Data fetching in Server Components or Route Handlers, not in client components
- Use `loading.tsx` and `error.tsx` for route-level loading/error states
- Dynamic imports (`next/dynamic`) for heavy client-only components
- Environment variables: `NEXT_PUBLIC_` prefix for client-side, plain for server-side only

## Performance

<!-- Performance guidelines -->
- `React.memo` only when profiling shows unnecessary re-renders — not by default
- `useMemo` / `useCallback` only for expensive computations or stable references passed to memoized children
- Avoid premature optimization — measure first
- Lazy load routes and heavy components
- Images through `next/image` (or equivalent optimizer)

## Common Pitfalls

<!-- Things that frequently go wrong -->
- Hydration mismatches: don't use `Date.now()`, `Math.random()`, or `window` in initial render
- Missing cleanup in `useEffect` — always return a cleanup function for subscriptions/timers
- Stale closures in event handlers — use refs for values that change between renders
- Missing `key` props on list items — use stable IDs, never array index
- Modifying state directly (push/splice on arrays) — always create new references

## Verification

<!-- How to verify work is complete -->
Before claiming any UI work is done:
1. Run `npm run build` — zero errors
2. Run `npm test` — all tests pass
3. Check the browser console — zero warnings (especially hydration warnings)
4. Test keyboard navigation on any interactive elements
5. Ask the user to visually confirm the result matches expectations
