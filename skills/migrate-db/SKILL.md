---
name: migrate-db
description: >
  Safe database migration workflow with backup verification, dry-run, and rollback plan.
  Triggers: "migrate database", "run migration", "db migration", "schema change".

  Do NOT use this skill for: writing queries, debugging query performance, or
  designing schemas from scratch. Only for executing schema migrations safely.
metadata:
  user-invocable: true
  slash-command: /migrate-db
  proactive: false
title: "Safe Database Migration"
parent: Skills & Extensibility
---
# Safe Database Migration

Execute database schema migrations with safety checks at every step.

## Steps

1. **Pre-flight checks:**
   - Verify database connection: test credentials and connectivity
   - Confirm target database and environment (dev/staging/prod)
   - Check for pending migrations: list unapplied migrations
   - Verify no other migrations are currently running
   - **ASK the user to confirm the target environment before proceeding**

2. **Review the migration:**
   - Read the migration file(s) to understand what changes will be made
   - Identify destructive operations: DROP TABLE, DROP COLUMN, ALTER TYPE
   - Flag any operations that will lock tables for extended periods
   - Check for data migrations vs. schema-only changes
   - Estimate impact: how many rows affected, expected duration

3. **Backup verification:**
   - Confirm a recent backup exists (ask the user)
   - For production: require explicit confirmation that backup was taken within the last hour
   - For dev/staging: note that backup is recommended but not blocking
   - Record the current schema state: `pg_dump --schema-only` or equivalent

4. **Dry run (if supported):**
   - Run migration with `--dry-run` or `--pretend` flag if available
   - For SQL migrations: wrap in a transaction and ROLLBACK
   - Review the dry-run output for unexpected changes
   - Confirm output matches expected behavior

5. **Execute the migration:**
   - Run the migration command
   - Monitor output for errors
   - If migration fails partway: DO NOT retry automatically — report the state and ask the user

6. **Post-migration verification:**
   - Run schema diff to confirm changes match expectations
   - Execute smoke test queries to verify data integrity
   - Check that the application can connect and basic operations work
   - Run the application's test suite against the migrated database

7. **Document the rollback plan:**
   - Write the exact commands needed to reverse the migration
   - If migration is irreversible (data deletion), document what was lost
   - Save rollback steps to a file for reference

## Important

- **NEVER run migrations on production without explicit user confirmation.**
- **NEVER auto-retry failed migrations.** Partial migrations leave the database in an inconsistent state.
- **Always verify the target environment.** A migration meant for dev running on prod is catastrophic.
- **Destructive operations get extra scrutiny.** DROP and DELETE are irreversible even with backups.
- **If in doubt, stop and ask.** A delayed migration is better than a broken database.
