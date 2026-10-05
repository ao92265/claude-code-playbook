#!/usr/bin/env bash
# Per-reply status light + per-project canary.
# Emits an instruction telling Claude to lead every reply with a traffic-light
# self-assessment, and to append this project's canary emoji when the reply or
# session is long. Always-on (fires every prompt).
#
#   Status light (always, first char of reply):
#     🟢 confident AND verified · 🟡 one of the two missing · 🔴 neither / a failure
#   Canary (additional, after the light, only when long):
#     🐤 = tripwire marker; if it silently drops in a long loop, context has
#     rotted -> clear and bootstrap from handoff.
# Disable: remove the canary.sh entry from ~/.claude/settings.json.

# Drain stdin (cwd JSON) so the hook doesn't block; not otherwise needed.
cat >/dev/null 2>&1

echo "Begin every reply with a status light: 🟢 = confident AND verified · 🟡 = one of the two missing (unverified, or caveats/assumptions) · 🔴 = neither, or something failed. Append the canary 🐤 right after the light when the reply is long (multi-section / many steps) OR you are deep in a long session or loop. Example: 🟢🐤 long verified reply, 🟡 short reply with a caveat."
