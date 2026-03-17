---
name: git-cleanup
description: >
  Clean up stale git branches, prune remotes, and tidy repository state.
  Removes merged branches and shows orphaned work.
  Triggers: "git cleanup", "clean branches", "prune branches", "tidy git".

  Do NOT use this skill for: resolving merge conflicts, rebasing, or any
  destructive operations on unmerged work.
metadata:
  user-invocable: true
  slash-command: /git-cleanup
  proactive: false
---

# Git Cleanup

Tidy up your git repository by removing stale branches and pruning remotes.

## Steps

1. **Survey current state:**
   - `git branch -a` — list all local and remote branches
   - `git remote prune origin --dry-run` — show stale remote references
   - Count: local branches, remote branches, stale references

2. **Identify merged branches:**
   - `git branch --merged main` — local branches already merged into main
   - Exclude: main, master, develop, and the current branch
   - List candidates for deletion with their last commit date

3. **Identify stale branches:**
   - Find branches with no commits in the last 90 days
   - Show the last commit message and author for each
   - Mark as "safe to delete" or "review needed"

4. **Show the plan:**
   - List branches to delete (merged + stale)
   - List branches to keep (unmerged with recent activity)
   - List branches that need human review
   - **ASK the user for confirmation before deleting anything**

5. **Execute cleanup (with permission):**
   - Delete confirmed local branches: `git branch -d <branch>`
   - Prune stale remote references: `git remote prune origin`
   - Only use `-D` (force delete) if the user explicitly approves for unmerged branches

6. **Post-cleanup report:**
   - Branches deleted: X local, Y remote references pruned
   - Branches kept: Z
   - Disk space recovered (if significant): `git gc --aggressive` suggestion

## Important

- **NEVER delete unmerged branches without explicit user approval.**
- **NEVER force-delete (`-D`) without confirmation** — unmerged work could be lost.
- **Don't touch main, master, or develop branches.**
- **Show what will be deleted before doing it** — cleanup is easier to review than to undo.
- **Remote branch deletion requires extra confirmation** — `git push origin --delete` affects others.
