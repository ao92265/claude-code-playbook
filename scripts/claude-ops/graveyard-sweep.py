#!/usr/bin/env python3
"""Graveyard sweep — the two things that go quiet on their own.

Section A, NOT RUNNING: every scheduled job on this machine, checked for whether
it has actually fired inside its own period. Daydream sat dead for five weeks
behind a silent `exit 0`; Standing Orders was silently absent for two days after
the Mac wipe. Nothing told him either time.

Section B, NOT LANDED: work that is finished but never collected — unsent drafts,
unpushed branches, unsigned decisions, calls never held. That state is already
written down in the memory corpus and nothing ever reads it back to him.

Delivery is Telegram, because a thing he has to open is a thing he abandons.
Falls back to a macOS notification if the bot is unreachable.

Auth follows the standing-orders.py pattern: the judge model uses the long-lived
OAuth token from the macOS keychain (service: daydream-oauth). The Telegram token
is read from assistant-bot's .env at run time and NEVER copied under ~/.claude, which
is backed up to git and OneDrive.

Read-only against the memory corpus. It never writes MEMORY.md — that index is
shared by every live session and a wholesale write deletes other sessions' entries.

Usage:  graveyard-sweep.py [--dry-run] [--no-telegram] [--section a|b|both]
"""
import argparse, datetime, fcntl, hashlib, json, os, plistlib, re, subprocess, sys, urllib.parse, urllib.request

HOME = os.path.expanduser("~")
CFG = os.path.join(HOME, ".claude")
DIR = os.path.join(CFG, "graveyard")
LOG = os.path.join(DIR, "log.jsonl")
HEARTBEAT = os.path.join(DIR, "heartbeat")
REPORT = os.path.join(DIR, "report.md")
MEMDIR = os.path.join(CFG, "projects", "-Users-you", "memory")
AGENTS = os.path.join(HOME, "Library", "LaunchAgents")
NANOCLAW_ENV = os.path.join(HOME, "Repos", "assistant-bot", ".env")
JUDGE_MODEL = "haiku"
STALE_FACTOR = 2.5          # a job is stale once it has missed 2.5 of its own periods
MAX_LANDED = 5              # he reads five lines, not fifteen

# Jobs that are not launchd — hook-driven or daemon-driven — with the file that
# proves they ran and the period they are supposed to run at, in seconds.
# Jobs that stamp their own heartbeat. Better evidence than a log mtime, because a
# log can be written by a run that then crashed.
HEARTBEATS = {
    "com.example.claude-standing-orders": os.path.join(CFG, "standing-orders", "heartbeat"),
    "com.example.claude-run-referee": os.path.join(CFG, "run-referee", "heartbeat"),
}

EXTRA_JOBS = {
    "daydream (Stop hook)": (os.path.join(CFG, "state", "daydream-last.ts"), 86400),
}

# Section C: repo state nobody is watching — stale worktrees and orphaned
# branches. Report-only, same posture as Sections A and B: this script never
# deletes a worktree or a branch, it only names candidates.
REPOS_DIR = os.path.join(HOME, "Repos")
STALE_WORKTREE_DAYS = 14
STALE_BRANCH_DAYS = 30


def now():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")


def log_event(ev):
    ev["ts"] = now()
    os.makedirs(DIR, exist_ok=True)
    with open(LOG, "a") as f:
        f.write(json.dumps(ev) + "\n")


def notify(title, body):
    try:
        subprocess.run(["osascript", "-e",
                        'display notification "{}" with title "{}"'.format(
                            body.replace("\\", "").replace('"', "'")[:180],
                            title.replace('"', "'"))],
                       timeout=10, capture_output=True)
    except Exception:
        pass


def keychain_token():
    r = subprocess.run(["security", "find-generic-password", "-a", os.environ.get("USER", ""),
                        "-s", "daydream-oauth", "-w"], capture_output=True, text=True, timeout=15)
    return r.stdout.strip() if r.returncode == 0 else ""


# --------------------------------------------------------------------------
# Section A: what is not running
# --------------------------------------------------------------------------
def period_seconds(pl):
    """How often this job is meant to fire, from its own plist. None = on demand."""
    if "StartInterval" in pl:
        return int(pl["StartInterval"])
    sci = pl.get("StartCalendarInterval")
    if sci is None:
        return None
    entries = sci if isinstance(sci, list) else [sci]
    # Weekday pinned -> weekly. Day pinned -> monthly. Hour pinned -> daily.
    # Only Minute pinned -> hourly. Several entries -> the shortest gap wins.
    per = []
    for e in entries:
        if "Weekday" in e:
            per.append(604800)
        elif "Day" in e:
            per.append(2592000)
        elif "Hour" in e:
            per.append(86400)
        else:
            per.append(3600)
    base = min(per)
    return base // len(entries) if len(entries) > 1 else base


def evidence_paths(pl):
    """Every file that would be touched if this job actually ran."""
    out = []
    for k in ("StandardOutPath", "StandardErrorPath"):
        if pl.get(k):
            out.append(pl[k])
    # Many of these jobs redirect inside the command itself, so mine the argv too.
    argv = " ".join(pl.get("ProgramArguments", []) or [])
    out += re.findall(r">>?\s*(\S+\.log)", argv)
    return [os.path.expanduser(p) for p in out]


def human(seconds):
    if seconds < 90:
        return f"{seconds:.0f} seconds"
    if seconds < 5400:
        return f"{seconds/60:.0f} minutes"
    if seconds < 172800:
        return f"{seconds/3600:.1f} hours"
    return f"{seconds/86400:.1f} days"


def loaded_labels():
    r = subprocess.run(["launchctl", "list"], capture_output=True, text=True, timeout=20)
    labels = {}
    for line in r.stdout.splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) >= 3:
            labels[parts[2].strip()] = parts[1].strip()
    return labels


def job_runs(label):
    """Run count and last exit code straight from launchd.

    This is the only trustworthy liveness signal. A log file's mtime is not:
    a job that runs every minute and prints nothing on a quiet cycle leaves a
    log that looks 36 days dead while launchd has run it 20,000 times. That
    exact false positive is why this function exists.
    """
    r = subprocess.run(["launchctl", "print", f"gui/{os.getuid()}/{label}"],
                       capture_output=True, text=True, timeout=20)
    if r.returncode != 0:
        return None, None
    runs = exit_code = None
    for line in r.stdout.splitlines():
        line = line.strip()
        if line.startswith("runs =") and runs is None:
            try:
                runs = int(line.split("=", 1)[1].strip())
            except ValueError:
                pass
        elif line.startswith("last exit code =") and exit_code is None:
            exit_code = line.split("=", 1)[1].strip()
    return runs, exit_code


def load_state():
    path = os.path.join(DIR, "state.json")
    if os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            pass
    return {}


def save_state(st):
    path = os.path.join(DIR, "state.json")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(st, f, indent=1)
    os.replace(tmp, path)


def friendly(label):
    """A job's label as a person would say it: com.example.claude-standing-orders
    becomes "standing orders". Telegram never shows the raw label."""
    name = re.sub(r"^com\.(you|assistant-bot)\.?", "", label)
    name = re.sub(r"^claude-", "", name)
    name = re.sub(r"\s*\(.*?\)", "", name)
    return re.sub(r"[-_.]+", " ", name).strip() or label


def check_jobs():
    """Return (stale, ok, first_run). Each stale entry is a (technical, plain)
    pair: the technical line goes to the report on disk, the plain line to
    Telegram.

    Liveness comes from launchd's own run counter, compared against the count
    recorded by the previous sweep. On the very first sweep there is no baseline,
    so it only reports the things that are unambiguous: not loaded, never run, or
    exiting non-zero. Everything else is baselined and judged from next time.
    """
    loaded = loaded_labels()
    state = load_state()
    prev = state.get("jobs", {})
    fresh = {}
    stale, ok = [], []
    now_ts = datetime.datetime.now().timestamp()
    first_run = not prev

    for fn in sorted(f for f in os.listdir(AGENTS) if f.endswith(".plist")):
        label = fn[:-len(".plist")]
        if not (label.startswith("com.example.") or label.startswith("com.assistant-bot")):
            continue
        try:
            with open(os.path.join(AGENTS, fn), "rb") as f:
                pl = plistlib.load(f)
        except Exception as e:
            stale.append((f"{label}: plist will not parse ({e})",
                          f"{friendly(label)}: its settings file is broken, so it cannot run"))
            continue

        if label not in loaded:
            stale.append((f"{label}: installed but NOT loaded into launchd",
                          f"{friendly(label)}: set up but switched off, so it is not running"))
            continue

        runs, exit_code = job_runs(label)
        per = period_seconds(pl)
        if runs is None:
            stale.append((f"{label}: loaded, but launchd will not report on it",
                          f"{friendly(label)}: switched on, but the Mac will not say whether it ran"))
            continue

        fresh[label] = {"runs": runs, "seen": now_ts}

        if runs == 0:
            stale.append((f"{label}: loaded but has never run once",
                          f"{friendly(label)}: switched on but has never run once"))
            continue
        if exit_code not in (None, "0"):
            # A long-lived daemon has no period; a high run count there means
            # launchd has been restarting it, not that it ran on schedule.
            shape = f"restarted {runs} times" if per is None else f"{runs} runs"
            stale.append((f"{label}: {shape}, last exit code {exit_code}",
                          f"{friendly(label)}: keeps failing when it runs"))
            continue
        if per is None:
            ok.append(f"{label}: on demand, {runs} runs, nothing to check")
            continue

        was = prev.get(label)
        if not was:
            ok.append(f"{label}: {runs} runs, baselined for next sweep")
            continue

        elapsed = now_ts - was.get("seen", now_ts)
        expected = elapsed / per
        gained = runs - was.get("runs", runs)
        # Allow a wide margin: laptops sleep, and a job that fired even once in
        # the window is alive. Only a job that gained NOTHING while it should
        # have fired at least twice is worth waking him for.
        if expected >= 2 and gained == 0:
            stale.append((f"{label}: has not fired once in {human(elapsed)}, "
                          f"expected about {expected:.0f} times",
                          f"{friendly(label)}: has not run at all in {human(elapsed)}, "
                          f"though it should have run about {expected:.0f} times"))
        else:
            ok.append(f"{label}: {gained} runs in the last {human(elapsed)}")

    for name, (path, per) in EXTRA_JOBS.items():
        if not os.path.exists(path):
            stale.append((f"{name}: has never run (no trace on disk)",
                          f"{friendly(name)}: has never run"))
            continue
        age = now_ts - os.path.getmtime(path)
        if age > per * STALE_FACTOR:
            stale.append((f"{name}: last ran {human(age)} ago, expected daily",
                          f"{friendly(name)}: last ran {human(age)} ago, but should run every day"))
        else:
            ok.append(f"{name}: last ran {human(age)} ago")

    state["jobs"] = fresh
    save_state(state)
    return stale, ok, first_run


# --------------------------------------------------------------------------
# Section B: what is not landed
# --------------------------------------------------------------------------
LANDED_PROMPT = """You are reading one man's memory corpus. Every file is one fact
about his work.

Find the items that are FINISHED BUT NOT COLLECTED. Specifically:
- a draft written and never sent
- a branch or commits never pushed, a PR never opened
- a decision named as needed and never made
- a call, reply or handover named as owed and never done
- a thing blocked only on him doing one small manual step

Ignore anything that is merely in progress, planned, or done. Ignore gotchas,
technical notes and lessons. The test is: he already paid for this and never
collected it.

Write your answer as a JSON array to the file named at the end of this prompt,
using the Write tool. Write nothing else anywhere. Do not summarise what you did.

Asking for the array as your reply text does not work here: this machine's global
config injects a status light and a preamble into every reply, so the array has to
land in a file. Each element:
{"what": "<=14 words, plain English, no file paths>",
 "who_or_what_it_waits_on": "<=8 words",
 "since": "YYYY-MM-DD or best guess from the text",
 "cost_if_ignored": "<=12 words"}

At most 12 elements, most stalled first. If nothing qualifies, write [].

MEMORY CORPUS:
"""


def scrub(text):
    """Strip emails and long digit runs before the corpus goes to a child claude.

    paste-guard fires on the child process too, and the memory corpus carries
    several real addresses. Scrubbing is the right fix rather than disabling the
    guard: an address carries no signal about whether a piece of work landed.
    """
    text = re.sub(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", "<email>", text)
    text = re.sub(r"\b\d{9,}\b", "<number>", text)
    return text


def read_corpus(limit_chars=140000):
    chunks = []
    for fn in sorted(os.listdir(MEMDIR)):
        if not fn.endswith(".md") or fn == "MEMORY.md":
            continue
        try:
            with open(os.path.join(MEMDIR, fn)) as f:
                body = f.read()
        except Exception:
            continue
        chunks.append(f"\n=== {fn} ===\n{body}")
    return scrub("".join(chunks))[:limit_chars]


def find_not_landed(token):
    out = os.path.join(DIR, "not-landed.json")
    if os.path.exists(out):
        os.remove(out)
    prompt = LANDED_PROMPT + read_corpus() + f"\n\nWRITE THE JSON ARRAY TO: {out}\n"
    env = dict(os.environ, CLAUDE_CODE_OAUTH_TOKEN=token, DISABLE_OMC="1",
               CLAUDE_DISABLE_HOOKS="1", GRAVEYARD_CHILD="1")
    r = subprocess.run(["claude", "--print", "--model", JUDGE_MODEL,
                        "--permission-mode", "bypassPermissions",
                        "--add-dir", DIR],
                       input=prompt, env=env, capture_output=True, text=True, timeout=300)
    if not os.path.exists(out):
        raise ValueError(f"judge wrote no file (exit {r.returncode}): {r.stdout.strip()[:200]}")
    with open(out) as f:
        raw = f.read()
    a, b = raw.find("["), raw.rfind("]")
    if a == -1 or b == -1:
        raise ValueError(f"judge file holds no JSON array: {raw[:200]}")
    items = json.loads(raw[a:b + 1])

    def staleness(it):
        try:
            return (datetime.date.today() - datetime.date.fromisoformat(it.get("since", ""))).days
        except Exception:
            return 0
    return sorted(items, key=staleness, reverse=True)


# --------------------------------------------------------------------------
# Section C: stale worktrees and orphaned branches
# --------------------------------------------------------------------------
def git_repos(base):
    """Top-level dirs under base that are git repos (has a .git entry)."""
    out = []
    try:
        entries = sorted(os.listdir(base))
    except Exception:
        return out
    for name in entries:
        path = os.path.join(base, name)
        if os.path.isdir(path) and os.path.exists(os.path.join(path, ".git")):
            out.append(path)
    return out


def run_git(args, cwd, timeout=8):
    try:
        r = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""


def stale_worktrees(repos):
    now_ts = datetime.datetime.now().timestamp()
    findings = []
    for repo in repos:
        out = run_git(["worktree", "list", "--porcelain"], repo, timeout=8)
        if not out:
            continue
        paths = [ln.split(" ", 1)[1] for ln in out.splitlines() if ln.startswith("worktree ")]
        for wt in paths:
            if os.path.normpath(wt) == os.path.normpath(repo):
                continue  # the main checkout, not a worktree
            last_commit = run_git(["log", "-1", "--format=%ct"], wt, timeout=8).strip()
            try:
                age = (now_ts - int(last_commit)) / 86400
            except ValueError:
                head = os.path.join(wt, ".git")
                age = (now_ts - os.path.getmtime(head)) / 86400 if os.path.exists(head) else None
            if age is not None and age >= STALE_WORKTREE_DAYS:
                findings.append(f"{os.path.basename(repo)}: worktree {wt} idle {age:.0f} days")
    return findings


def orphaned_branches(repos):
    """One `for-each-ref` call per repo — a per-branch `git log` call here does
    not scale past a handful of repos (83 repos x N branches each spawned a
    process per branch and made the sweep take minutes)."""
    now_ts = datetime.datetime.now().timestamp()
    findings = []
    for repo in repos:
        out = run_git(["for-each-ref", "--format=%(refname:short)\t%(upstream)\t%(committerdate:unix)",
                       "refs/heads/"], repo, timeout=8)
        if not out:
            continue
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) != 3:
                continue
            branch, upstream, committer_ts = parts
            if upstream.strip():
                continue  # has a tracking ref
            try:
                age = (now_ts - int(committer_ts)) / 86400
            except ValueError:
                continue
            if age >= STALE_BRANCH_DAYS:
                findings.append(f"{os.path.basename(repo)}: branch '{branch}' no upstream, "
                                f"last commit {age:.0f} days ago")
    return findings


def check_repo_state():
    """Report-only, never deletes anything. Section C of the sweep."""
    repos = git_repos(REPOS_DIR)
    findings = stale_worktrees(repos) + orphaned_branches(repos)
    return findings


# --------------------------------------------------------------------------
# Delivery
# --------------------------------------------------------------------------
def telegram_creds():
    """Read the bot token from assistant-bot's .env. Never cached under ~/.claude."""
    if not os.path.exists(NANOCLAW_ENV):
        return None, None
    tok = chat = None
    with open(NANOCLAW_ENV) as f:
        for line in f:
            if line.startswith("TELEGRAM_BOT_TOKEN="):
                tok = line.split("=", 1)[1].strip().strip("\"'")
            elif line.startswith("TELEGRAM_ALLOWED_USER_IDS="):
                chat = line.split("=", 1)[1].strip().strip("\"'").split(",")[0]
    return tok, chat


SENT = os.path.join(DIR, "telegram-sent.json")


def already_sent_today(text):
    """Once-a-day cap per identical message. One alert elsewhere once went out
    113 times; this keeps a rerun or a stuck scheduler from doing the same."""
    try:
        with open(SENT) as f:
            st = json.load(f)
    except Exception:
        return False
    key = hashlib.sha256(text.encode()).hexdigest()[:16]
    return st.get(key) == datetime.date.today().isoformat()


def mark_sent(text):
    today = datetime.date.today().isoformat()
    try:
        with open(SENT) as f:
            st = json.load(f)
    except Exception:
        st = {}
    st = {k: v for k, v in st.items() if v == today}
    st[hashlib.sha256(text.encode()).hexdigest()[:16]] = today
    tmp = SENT + ".tmp"
    with open(tmp, "w") as f:
        json.dump(st, f)
    os.replace(tmp, SENT)


def send_telegram(text):
    """One short-lived request. GlobalProtect kills any TCP connection at about
    60 seconds of age, so never hold one open or reuse it."""
    tok, chat = telegram_creds()
    if not tok or not chat:
        return False, "no telegram credentials"
    data = urllib.parse.urlencode({"chat_id": chat, "text": text[:4000],
                                   "disable_web_page_preview": "true"}).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{tok}/sendMessage", data=data)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return json.load(r).get("ok", False), ""
    except Exception as e:
        return False, str(e)[:200]


CODEX_SESSIONS = os.path.join(HOME, ".codex", "sessions")
CODEX_LOW_WEEK = 20         # paid monthly; fewer runs than this a week means it has gone quiet


def codex_usage():
    """Codex runs this week and last week, counted from its own session files."""
    today = datetime.date.today()
    this_start, last_start = today - datetime.timedelta(days=7), today - datetime.timedelta(days=14)
    this_week = last_week = 0
    for root, _, files in os.walk(CODEX_SESSIONS):
        for f in files:
            if not (f.startswith("rollout-") and f.endswith(".jsonl")):
                continue
            try:
                day = datetime.date.fromisoformat(f[8:18])
            except ValueError:
                continue
            if day > this_start:
                this_week += 1
            elif day > last_start:
                last_week += 1
    return this_week, last_week


def compose(stale, landed, first_run=False, sections="both", repo_state=None, codex=None):
    """The Telegram message. Plain English for a non-technical reader: what
    happened and whether the user has to do anything. No job labels, paths, branch
    names or exit codes; those live in the report on disk."""
    act = False
    lines = [f"Weekly check-up, {datetime.date.today().strftime('%A %-d %B')}"]
    lines.append("")
    lines.append("Background jobs that have stopped")
    if sections == "b":
        lines.append("- Not checked this time.")
    elif stale:
        act = True
        lines += [f"- {plain}" for _, plain in stale]
    elif first_run:
        lines.append("- This is the first check, so it is only taking a starting count. "
                     "From next week it can tell you if anything has stopped.")
    else:
        lines.append("- None. Everything that runs on a timer has run when it should.")
    lines.append("")
    lines.append("Finished work you never followed up")
    if sections == "a":
        lines.append("- Not checked this time.")
    elif landed:
        act = True
        for it in landed[:MAX_LANDED]:
            lines.append(f"- {it.get('what','?')} (waiting on {it.get('who_or_what_it_waits_on','?')}, "
                         f"since {it.get('since','?')})")
        if len(landed) > MAX_LANDED:
            lines.append(f"- Plus {len(landed)-MAX_LANDED} more.")
    else:
        lines.append("- None. Nothing finished is sitting forgotten.")
    if codex is not None:
        this_week, last_week = codex
        lines.append("")
        lines.append("Codex, the second-opinion coding helper")
        note = ", which is low, so it may have dropped out of use" if this_week < CODEX_LOW_WEEK else ""
        lines.append(f"- Used {this_week} times this week and {last_week} times last week{note}.")
    if repo_state:
        act = True
        lines.append("")
        lines.append("Old unfinished code lying around")
        lines.append(f"- {len(repo_state)} old copies or side branches of your code projects have "
                     "not been touched in weeks. Nothing was deleted.")
    lines.append("")
    if act:
        lines.append("When you're free, ask Claude to go through this week's check-up with you.")
    else:
        lines.append("Nothing for you to do.")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print, do not send")
    ap.add_argument("--no-telegram", action="store_true")
    ap.add_argument("--section", choices=["a", "b", "both"], default="both")
    a = ap.parse_args()

    os.makedirs(DIR, exist_ok=True)
    lock = open(os.path.join(DIR, ".lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log_event({"event": "skipped", "reason": "previous run still active"})
        return 0

    stale, ok, first_run = ([], [], False)
    if a.section in ("a", "both"):
        stale, ok, first_run = check_jobs()

    repo_state = []
    if a.section in ("a", "both"):
        try:
            repo_state = check_repo_state()
        except Exception as e:
            log_event({"event": "error", "section": "repo-state", "error": str(e)[:500]})

    landed = []
    if a.section in ("b", "both"):
        token = keychain_token()
        if not token:
            notify("Weekly check-up", "Part of the check-up was skipped because a saved login is missing. Ask Claude to fix it.")
            log_event({"event": "dormant", "reason": "no keychain token"})
        else:
            try:
                landed = find_not_landed(token)
            except Exception as e:
                log_event({"event": "error", "section": "not-landed", "error": str(e)[:500]})
                notify("Weekly check-up", "Part of the check-up failed. Ask Claude to look at it.")

    codex = None
    if a.section in ("a", "both"):
        try:
            codex = codex_usage()
        except Exception as e:
            log_event({"event": "error", "section": "codex-usage", "error": str(e)[:500]})

    msg = compose(stale, landed, first_run, a.section, repo_state, codex)

    with open(REPORT, "w") as f:
        f.write(msg + "\n\n---\n\n")
        if stale:
            f.write("Not running, technical detail:\n"
                    + "".join(f"- {tech}\n" for tech, _ in stale) + "\n")
        f.write("Still healthy:\n" + "\n".join(f"- {o}" for o in ok) + "\n")
        if landed:
            f.write("\nFull not-landed list:\n")
            for it in landed:
                f.write(f"- {it.get('what','?')} | waits on {it.get('who_or_what_it_waits_on','?')} "
                        f"| since {it.get('since','?')} | cost: {it.get('cost_if_ignored','?')}\n")
        if repo_state:
            f.write("\nFull stale repo-state list:\n")
            for s in repo_state:
                f.write(f"- {s}\n")

    print(msg)
    print(f"\n[full report: {REPORT}]")

    if a.dry_run:
        log_event({"event": "dry-run", "stale": len(stale), "landed": len(landed)})
        return 0

    sent = False
    capped = False
    if not a.no_telegram:
        if already_sent_today(msg):
            capped = True
            log_event({"event": "capped", "reason": "identical message already sent today"})
        else:
            sent, err = send_telegram(msg)
            if sent:
                mark_sent(msg)
            else:
                notify("Weekly check-up", "Could not reach Telegram. The check-up is saved on this Mac.")
    if not sent and a.no_telegram:
        notify("Weekly check-up", f"{len(stale)} background jobs stopped, "
                                  f"{len(landed)} finished things not followed up")

    with open(HEARTBEAT, "w") as f:
        f.write(now() + "\n")
    log_event({"event": "swept", "stale": len(stale), "landed": len(landed),
               "repo_state": len(repo_state), "telegram": sent, "capped": capped})
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log_event({"event": "crash", "error": str(e)[:500]})
        notify("Weekly check-up", "The check-up stopped with an error. Ask Claude to look at it.")
        sys.exit(1)
