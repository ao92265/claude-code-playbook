# Code Container — Docker Sandboxing for Autonomous Claude Code Work

Code Container is a lightweight Docker wrapper that gives Claude Code full root and network access inside an isolated container — eliminating the constant permission approval interruptions that slow down autonomous agent work, without putting your actual machine at risk.

> **Install:** `npm install -g code-container`

---

## The Problem It Solves

Running Claude Code in autonomous mode on a real codebase triggers 40+ permission approvals per session: every shell command, every file write, every package install. This defeats the purpose of autonomous agent work — you spend more time approving than reviewing.

The two common workarounds both have downsides:

- **Auto Mode** (`claude --dangerously-skip-permissions`) — removes all guardrails on your actual machine. A runaway agent or prompt injection can delete files, exfiltrate secrets, or corrupt your environment.
- **`disallowedTools`** — restricts what the agent can do, which limits effectiveness for complex tasks.

Code Container takes a third path: give the agent full permissions, but inside a container. The worst case is a destroyed container, not a destroyed machine.

---

## Quick Start

```bash
# Install globally
npm install -g code-container

# Run Claude Code inside a container (from your project directory)
code-container

# That's it — Claude Code starts with full permissions inside the container
```

The container starts in ~300ms. Your project directory is mounted at the same path inside the container, so all relative paths work as expected.

---

## How It Works

```
Your Machine                          Container
─────────────────────────────────     ──────────────────────────────────
~/my-project/          ──mount──>     ~/my-project/   (read/write)
~/.claude/             ──mount──>     ~/.claude/      (read-only)
                                      root access     ✓
                                      network access  ✓
                                      apt / npm / pip ✓
```

Key design decisions:

**Project directory is mounted read/write.** Changes Claude makes inside the container are reflected on your machine immediately — this is intentional. The point is to do real work, not a dry run. You review and commit as usual.

**`~/.claude` is mounted read-only.** Your conversations, memory, settings, and credentials persist and are visible inside the container. The agent can use your existing Claude config without re-authentication. It cannot modify your global config.

**Root inside the container.** The agent can install packages (`apt-get`, `npm`, `pip`), modify system paths, run any command — all the things that would require `sudo` or a permission approval on your real machine. Inside the container, none of that requires approval.

**Isolated process namespace.** Processes inside the container cannot see or interact with processes on your host machine.

---

## Configuration

Code Container reads a `.code-container.json` file in your project root if present:

```json
{
  "image": "node:20",
  "mounts": [
    "~/.ssh:/root/.ssh:ro"
  ],
  "env": [
    "DATABASE_URL",
    "OPENAI_API_KEY"
  ],
  "network": "bridge"
}
```

| Option | Default | Description |
|:-------|:--------|:------------|
| `image` | `ubuntu:22.04` | Base Docker image |
| `mounts` | `[]` | Additional volume mounts (same syntax as `docker -v`) |
| `env` | `[]` | Host environment variables to pass through to container |
| `network` | `bridge` | Docker network mode (`bridge`, `host`, `none`) |

**Passing credentials:** Use the `env` array to forward API keys and database URLs. They are passed as environment variables, not written to disk inside the container.

**Custom images:** If your project needs specific runtimes (Python 3.12, Java 21, a specific Node version), specify the image. Any public Docker Hub image works.

---

## When to Use Code Container vs Other Approaches

| Scenario | Recommended Approach |
|:---------|:--------------------|
| Autonomous agent doing large refactors | **Code Container** |
| Autonomous agent running installs, builds, tests | **Code Container** |
| Quick interactive session, you're watching | Auto Mode (`--dangerously-skip-permissions`) |
| Shared team machine / CI environment | Auto Mode with scoped permissions |
| Read-only analysis, no writes needed | `disallowedTools: [Bash, Write, Edit]` |
| Sensitive repo, must prevent exfiltration | `network: none` + `disallowedTools` |

**Code Container vs Auto Mode:**

Auto Mode removes permission prompts but runs directly on your machine. One bad session — a runaway loop, a prompt injection, a misunderstood instruction — can cause real damage. Code Container adds a hard boundary: the agent has full freedom inside the container, and that freedom cannot escape to your host.

Use Auto Mode when you're actively supervising and want the fastest path. Use Code Container when you're going async — running a long task and coming back later to review results.

**Code Container vs `disallowedTools`:**

`disallowedTools` limits the agent. Code Container liberates the agent safely. For tasks that genuinely need shell access, file writes, and package management, `disallowedTools` forces you to choose between capability and safety. Code Container removes the tradeoff.

---

## Supported Agents

Code Container works with:

- **Claude Code** — primary use case
- **Codex** (`openai/codex`) — same mount behavior
- **OpenCode** — community-supported

The container exposes the same environment to any agent CLI that runs inside it.

---

## Limitations

**Does not protect against prompt injection.** If malicious content in a file or web page instructs the agent to exfiltrate data, the agent has network access inside the container and could comply. Container isolation stops host damage, not LLM-level manipulation. For high-sensitivity work, combine Code Container with `network: none`.

**Project changes are immediate.** Because the project directory is mounted (not copied), the agent's file writes land on your machine in real time. This is a feature for normal use, but means you should review changes before committing — same discipline as any autonomous agent session.

**Docker required.** Code Container requires Docker Desktop (Mac/Windows) or Docker Engine (Linux). It does not work on machines where Docker is unavailable or where the Docker socket is restricted by policy.

**Container is ephemeral.** Anything installed inside the container (packages, system tools) is lost when the session ends. Use the `image` config to bake in dependencies your agent consistently needs.

---

*See also: [permissions.md](permissions.md) — full permissions model | [workflows.md](workflows.md) — deciding when to use autonomous mode*
