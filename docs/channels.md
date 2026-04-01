# Claude Code Channels

Channels turns a running Claude Code session into a reachable service — messages sent from your phone arrive in the session, Claude does work, and replies come back to your phone. Shipped March 20, 2026 as a research preview.

---

## Table of Contents

- [What Are Channels](#what-are-channels)
- [Quick Start](#quick-start)
- [Telegram Setup](#telegram-setup)
- [Discord Setup](#discord-setup)
- [iMessage Setup (macOS)](#imessage-setup-macos)
- [Fakechat Demo](#fakechat-demo)
- [Running Multiple Channels](#running-multiple-channels)
- [Permission Relay](#permission-relay)
- [Security Model](#security-model)
- [Channels vs OpenClaw](#channels-vs-openclaw)
- [Limitations](#limitations)
- [When to Use / When Not to Use](#when-to-use--when-not-to-use)

---

## What Are Channels

Channels exposes your active Claude Code session as an MCP server that external messaging services can reach. The flow is:

```
Phone (Telegram / Discord)
        ↓
  MCP Channel server
        ↓
  Running claude --channels session
        ↓
  Claude does work (edits files, runs tests, queries APIs)
        ↓
  Reply back to your phone
```

This is not a background daemon or a hosted service. Channels only works while a `claude --channels` session is actively running on your machine. When you close the terminal, the channel closes.

**Why it matters for enterprise teams:** You can hand off a long-running task to Claude before a meeting, then check in from your phone and get a status update — or redirect the work — without returning to your laptop.

---

## Prerequisites

- Claude Code **v2.1.80+** (`claude --version`)
- **Bun** runtime installed (`bun --version`; install from [bun.sh](https://bun.sh)) — required for plugin scripts
- **claude.ai authentication** — API keys and Console auth are NOT supported. Requires a Pro, Max, Team, or Enterprise subscription.
- Team/Enterprise: an admin must enable `channelsEnabled` in managed settings first

---

## Quick Start

Channels are distributed as **plugins** from the `claude-plugins-official` marketplace. The workflow is: install plugin → configure credentials → pair your account → start with `--channels`.

```bash
# 1. Install a channel plugin
/plugin install telegram@claude-plugins-official
/reload-plugins

# 2. Configure (inside a Claude Code session)
/telegram:configure <your-bot-token>

# 3. Restart with channels enabled
claude --channels plugin:telegram@claude-plugins-official
```

The `--channels` flag is **per-session and opt-in**. Having the plugin installed isn't enough — you must explicitly pass it via `--channels` every time.

**Estimated setup time:** ~25 minutes from zero to receiving Telegram messages.

---

## Telegram Setup

**Prerequisites:** A Telegram account and `@BotFather` access.

### 1. Create a bot

Open `@BotFather` in Telegram, send `/newbot`, follow prompts. Copy the bot token.

### 2. Install and configure the plugin

```
/plugin install telegram@claude-plugins-official
/reload-plugins
/telegram:configure <your-bot-token>
```

Token is saved to `~/.claude/channels/telegram/.env`. Alternatively set `TELEGRAM_BOT_TOKEN` in your shell environment.

### 3. Start the session with channels

```bash
claude --channels plugin:telegram@claude-plugins-official
```

### 4. Pair your account

Send any message to your bot on Telegram. It replies with a **pairing code**. Back in Claude Code:

```
/telegram:access pair <code>
/telegram:access policy allowlist
```

Your Telegram user ID is now on the sender allowlist. Messages from anyone else are silently dropped.

### 5. Test it

Send a message from Telegram → Claude picks it up, does work, replies back to Telegram. You see the inbound message and reply tool call in your terminal.

---

## Discord Setup

**Prerequisites:** A Discord server you control and a [Developer Portal](https://discord.com/developers/applications) account.

### 1. Create a Discord application and bot

1. Go to discord.com/developers/applications → New Application → name it
2. Bot tab → copy the token
3. **Critical:** Under Privileged Gateway Intents, enable **Message Content Intent** — without this the bot connects but reads nothing
4. OAuth2 → URL Generator: select `bot` scope + View Channels, Send Messages, Send Messages in Threads, Read Message History, Attach Files, Add Reactions
5. Open the generated URL to invite the bot to your server

### 2. Install and configure

```
/plugin install discord@claude-plugins-official
/reload-plugins
/discord:configure <your-bot-token>
```

Token saved to `~/.claude/channels/discord/.env`. Alternatively set `DISCORD_BOT_TOKEN`.

### 3. Start and pair

```bash
claude --channels plugin:discord@claude-plugins-official
```

DM your bot on Discord — it replies with a pairing code:

```
/discord:access pair <code>
/discord:access policy allowlist
```

---

## iMessage Setup (macOS)

iMessage is a first-party channel plugin available on macOS only. It reads `~/Library/Messages/chat.db` directly and sends via AppleScript.

### 1. Install

```
/plugin install imessage@claude-plugins-official
```

### 2. Start

```bash
claude --channels plugin:imessage@claude-plugins-official
```

### 3. Grant permissions

macOS will prompt for **Full Disk Access** for your terminal. If the prompt doesn't appear, go to System Settings → Privacy & Security → Full Disk Access and add your terminal manually.

### 4. Pair

Text yourself from any device on your Apple ID — self-messages bypass access control automatically. To allow other contacts:

```
/imessage:access allow +15551234567
```

---

## Fakechat Demo

Fakechat is a localhost web UI that simulates a messaging client — no external account needed.

```bash
/plugin install fakechat@claude-plugins-official
claude --channels plugin:fakechat@claude-plugins-official

# Opens http://localhost:8787 in your browser
# Type messages in the UI; Claude responds in the same thread
```

Use fakechat to:

- Verify your session responds before touching external services
- Demo the Channels workflow to stakeholders without sharing credentials
- Test custom prompts and task delegation patterns offline

---

## Running Multiple Channels

You can enable multiple channels simultaneously:

```bash
claude --channels plugin:telegram@claude-plugins-official plugin:discord@claude-plugins-official
```

All channels feed into the same session. Claude sees the source platform in the `<channel source="telegram">` or `<channel source="discord">` tag and replies via the correct platform's reply tool.

---

## Permission Relay

> *Added in v2.1.81*

The biggest limitation of Channels was that tool approval prompts would silently pause the session when you were away. Permission relay fixes this.

Official Telegram and Discord plugins (v2.1.81+) can **forward tool approval prompts to your phone**. When Claude hits a Bash, Write, or Edit approval, you see it in Telegram/Discord and reply `yes <id>` or `no <id>`. Claude Code applies the verdict immediately.

The local terminal dialog stays open too — **first answer wins** (phone or terminal).

**What's covered:** Bash, Write, Edit approvals.
**What's NOT covered:** Project trust dialogs, MCP consent dialogs.

This transforms Channels from "cool demo" to "genuinely usable for remote agent management" — you can approve operations from your phone without needing `--dangerously-skip-permissions`.

---

## Security Model

### Sender allowlists

Only explicitly listed senders can interact with the session. Any message from an unlisted chat ID or channel ID is dropped without acknowledgment. There is no "accept unknown senders" mode.

```json
{
  "channels": {
    "telegram": {
      "allowedChatIds": [111111111, 222222222]
    }
  }
}
```

### Per-session opt-in

Channels is not active by default. It requires the explicit `--channels` flag on each session start. A session started without `--channels` is not reachable externally under any circumstances.

### Enterprise controls

For teams on Claude Code Enterprise, administrators can:

- Disable Channels org-wide via policy
- Restrict which integrations (Telegram, Discord) are permitted
- Require audit logging of all inbound channel messages

### What Channels does not do

- It does not store message history outside the active session context
- It does not authenticate to external services on your behalf — you provide credentials
- It does not expose a public internet endpoint — the MCP server binds to localhost only; your messaging integration must be able to reach it (typically via a local tunnel or VPN if needed)

---

## Channels vs OpenClaw

OpenClaw was a popular third-party tool for remote Claude Code control. Channels directly replaces it with first-party support and a significantly different security posture.

| | Channels | OpenClaw |
|---|---|---|
| **Maintained by** | Anthropic | Community (+ NVIDIA NemoClaw for enterprise) |
| **Setup time** | ~25 minutes | ~45-60 minutes |
| **Platforms** | 3 (Telegram, Discord, iMessage) + fakechat | 25+ |
| **Security model** | Built-in allowlists, per-session opt-in | Manual config, historically insecure defaults |
| **Exposed instances** | N/A (no inbound ports) | 135,000+ publicly exposed instances documented |
| **Subscription token blocking** | Not affected (uses claude.ai auth) | Broke when Anthropic rate-limited subscription tokens |
| **Permission relay** | Yes (v2.1.81+ — approve from phone) | No |
| **Code execution** | Native (full Claude Code session) | None (LLM plumbing only) |
| **Model diversity** | Claude only | Model-agnostic (local models, Mistral, GPT, etc.) |
| **Always-on daemon** | No (run in tmux) | Yes (built-in) |
| **Enterprise policy controls** | Yes (`channelsEnabled`, `allowedChannelPlugins`) | NemoClaw adds guardrails |
| **Fakechat / local demo** | Yes | No |
| **Cost** | Included with Claude Code | Free + any model |

**Migration from OpenClaw:** If your team is running OpenClaw, switch to Channels. The security exposure from 135k+ publicly accessible instances is a real risk. Channels gives you the same core workflow with Anthropic's security model built in and no subscription token concerns.

---

## Limitations

- **Requires an active session.** Channels is not a daemon. If your laptop sleeps or the terminal closes, the channel drops. Messages sent to a Telegram bot while offline are lost; Discord may queue and replay when the bot reconnects. **Workaround:** Run in tmux/screen for persistence (`tmux new -s claude && claude --channels ...`).
- **No wake-from-sleep.** Claude cannot start itself when a message arrives. You must start the session before delegating work.
- **Permission prompts can block.** When Claude hits a tool approval prompt while you're away, the session pauses. Use permission relay (v2.1.81+) to approve from your phone, or `--dangerously-skip-permissions` in trusted/isolated environments only.
- **claude.ai auth required.** API keys and Anthropic Console auth are NOT supported. Channels requires a paid claude.ai account (Pro, Max, Team, or Enterprise).
- **Research preview allowlist.** The `--channels` flag only accepts plugins from Anthropic's curated allowlist (`claude-plugins-official`) or your org's `allowedChannelPlugins` list. Custom channels must use `--dangerously-load-development-channels server:<name>` for local testing. Custom channels cannot be used in production until submitted to the official marketplace.
- **No cross-channel session unification.** Multiple channels feed into one session, but there's no built-in routing of different conversations to different agents. Each channel shares the same context.
- **3 platforms (research preview).** Telegram, Discord, and iMessage (macOS only). Everything else requires building a custom channel plugin. Compare: OpenClaw supports 25+.
- **Protocol may change.** The `--channels` flag syntax and the underlying protocol contract may change before general availability.

---

## When to Use / When Not to Use

### Good fits

- **Async task delegation:** Start a long-running task (migration, analysis, test run) and check in from your phone while in meetings
- **On-call support:** Give a teammate a read-only Telegram bot that can query Claude for system status without touching the codebase directly
- **Remote pair programming:** Review Claude's progress from a mobile device and redirect it without returning to your desk
- **Demo environments:** Use fakechat to show stakeholders how agent-driven workflows look before committing to a full external integration

### Poor fits

- **Unattended automation:** If you need Claude to run overnight without supervision, use a scheduled CI job or a persistent agent platform — not Channels, which requires an active session
- **Multi-user access:** Channels is a single-session tool. If multiple people need concurrent access to the same Claude session, that is outside its design scope
- **High-volume messaging:** Channels is designed for occasional command-and-control messages, not high-throughput event processing
- **Public-facing chatbots:** The allowlist model is designed for a small number of trusted senders. It is not a chatbot platform

---

*Related: [MCP Servers Guide](mcp-servers.md) · [Workflows](workflows.md) · [Enterprise Governance](enterprise-governance.md)*
