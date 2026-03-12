# CLAUDE.md Template

<!--
  This is a template CLAUDE.md for your project. Claude reads this file automatically
  at the start of every session. Customize each section for your project's needs.

  Delete these HTML comments once you've filled in your project details.
-->

## Project Basics

<!-- Describe your project's primary language, module system, and any critical setup info -->
This is a TypeScript project. All code changes should be in TypeScript unless explicitly told otherwise. Always verify imports use the correct module system (ESM vs CJS) for the target project.

## UI/Frontend

<!-- If your project has a frontend, include visual verification rules -->
When making UI/visual changes, ask the user to confirm the result matches their expectations before moving on. Never assume visual fidelity from code alone. Use screenshot tools when available to verify layout, colors, and spacing.

## General Workflow

<!-- Define how Claude should approach different types of work -->
When fixing bugs, implement and verify the fix directly rather than filing GitHub issues or spending extended time planning. Bias toward action over investigation.

## Agent Usage

<!-- Set limits on parallel agent usage to avoid rate limits -->
When spawning sub-agents for parallel work, limit to 3-4 agents maximum to avoid API rate limits and credential issues. Verify push credentials before starting parallel branch work.

## Token Efficiency

<!-- Token management rules for cost-effective sessions -->
Use low reasoning effort by default to conserve token limits. Only escalate to medium/high when stuck on a genuinely hard debugging or architectural problem.

When spawning teammates or sub-agents via the Task tool:
- Use `model: "sonnet"` for implementation work (writing code, editing files)
- Use `model: "haiku"` for simple tasks (file searches, formatting, boilerplate)
- Reserve `model: "opus"` only for complex architectural decisions, difficult debugging, or team lead coordination
- Prefer fewer, well-scoped agents over many parallel agents — each agent burns tokens independently

## Change Philosophy

<!-- Prevent over-engineering and scope creep -->
Make the smallest change that works. Follow existing patterns in the codebase. Don't refactor surrounding code, add abstractions, or "improve" things beyond what was asked. Three similar lines are better than a premature abstraction.

## Verification

<!-- Ensure Claude always verifies before claiming done -->
Always verify work end-to-end before reporting success — run the actual test, build, or workflow. Don't assume correctness from code analysis alone. If verification fails, keep working; never claim done with failing tests or partial implementation.

## Lessons Tracking

<!-- Build institutional knowledge from mistakes -->
When a mistake leads to a fix, record it in `tasks/lessons.md` in the project root (create if missing). Format: `- **[date] Problem**: description -> **Fix**: what worked`. This builds project-specific institutional knowledge.

## Communication Rules

<!-- Prevent Claude from blaming the user's environment -->
Never assume the user's environment, configuration, or setup is wrong. Always check the actual state of files, configs, and services before suggesting the issue is on the user's side.

## Claude Configuration

<!-- Rules for editing Claude's own config files -->
When working with ~/.claude/settings.json, spinnerVerbs must be an array of strings (not objects). MCP server configs must match the exact expected schema. Always validate JSON format after editing settings files.

## Output Conventions

<!-- How Claude should produce output artifacts -->
When producing documents, amendments, or reports, always output them as proper files (not inline text) unless explicitly asked for inline output.

## Dev Environment & Deployment

<!-- Pre-flight checks before starting services -->
Before starting dev servers or Docker containers, check for port conflicts, existing running containers, and correct environment variables/passwords. For cloud deployments, verify the tier supports the required features before attempting deployment.

## Language & Build

<!-- Build and type checking rules -->
This workspace is primarily TypeScript. Use proper TypeScript types, interfaces, and ensure type compatibility across modules. Always run the build/compile step after multi-file changes to catch type errors early.

## Git & GitHub Rules

<!-- Safety rules for version control -->
Do not push code to GitHub or create PRs without explicit user permission. Do not perform any destructive or irreversible operations (repo creation, branch force-push, deployment) without asking first.

## Lessons Learned

<!--
  Add project-specific lessons here as they're discovered. Format:
  - **Pattern name**: Description of what went wrong and how to prevent it.
-->
- **Feedback loops**: Any automated function that both produces and scans the same resource (comments, messages, events) must exclude its own output from detection to prevent infinite loops.
- **Emergency disables**: When emergency-disabling functions, track exactly what was disabled. Re-enable and verify all functions after the fix deploys.
