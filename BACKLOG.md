# Backlog

The next 10 improvements, most useful first. Written 14 Nov 2026 from an overnight review.

1. **Merge the open overnight branches.** Five branches wait for review: link and privacy fixes, the last-10-commits review fixes, doc claim and skill header fixes, hook behaviour tests, and the Matcha lane pull request. Merge them in that order to keep conflicts small.
2. **Fix the session timer that never resets.** The referee script counts wall-clock time across idle gaps, so a session used yesterday is paused at once. Needs a state change and tests.
3. **Match handoffs by exact folder.** The session rotation script matches by substring, so one project folder can pick up another's handoff (for example `foo` and `foo-bar`).
4. **Use exact tmux targets in the reaper.** `tmux kill-session -t` matches by prefix. Use `-t "=name"` at all four call sites, with a tmux test.
5. **Finish hook test coverage.** Behaviour tests now cover part of the hooks. Add tests for the rest, or record in the coverage file why a hook cannot be tested offline.
6. **Update the hook smoke test.** It still tests old hook names and fails on a fresh install.
7. **Add "do not use for" lines to 18 skills.** Their descriptions lack a negative trigger or trigger phrases, so they can fire on the wrong request.
8. **Say plainly how gates behave.** The guard hooks guide says gates "block", but most block once and then stand down. Change the docs or the hooks so they agree.
9. **Ship or remove the PR review poster.** The PR review sweep script calls a poster script that the repo does not include.
10. **Lift a pause when its file is deleted.** The referee keeps a session paused after its pause file is removed.
