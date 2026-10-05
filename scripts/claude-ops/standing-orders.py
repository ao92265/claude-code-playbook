#!/usr/bin/env python3
"""Standing Orders nightly judge — notify-only v1.

Walks ~/.claude/standing-orders/orders.yaml, runs each active order's mechanical
probe, has a cheap headless Claude judge the probe OUTPUT against the condition
prose, and notifies (macOS) on fired / expired / error. Append-only event log,
heartbeat file, mutable state in state.json (orders.yaml stays user-owned).

Auth follows the daydream.sh pattern: long-lived OAuth token read from the macOS
keychain (service: daydream-oauth) at spawn time, passed via env, never argv,
never a file under ~/.claude. No token -> loud one-time notification, exit 0.
"""
import json, os, subprocess, sys, datetime, fcntl

HOME = os.path.expanduser("~")
DIR = os.path.join(HOME, ".claude", "standing-orders")
ORDERS = os.path.join(DIR, "orders.yaml")
STATE = os.path.join(DIR, "state.json")
LOG = os.path.join(DIR, "log.jsonl")
HEARTBEAT = os.path.join(DIR, "heartbeat")
JUDGE_MODEL = "haiku"
PROBE_TIMEOUT = 90
PROBE_MAX_CHARS = 4000

def now():
    return datetime.datetime.now().astimezone().isoformat(timespec="seconds")

def log_event(ev):
    ev["ts"] = now()
    with open(LOG, "a") as f:
        f.write(json.dumps(ev) + "\n")

def notify(title, body):
    try:
        subprocess.run(["osascript", "-e",
                        'display notification "{}" with title "{}"'.format(
                            body.replace('\\', '').replace('"', "'")[:180],
                            title.replace('"', "'"))],
                       timeout=10, capture_output=True)
    except Exception:
        pass  # notification is best-effort; the log line is the record

def keychain_token():
    r = subprocess.run(["security", "find-generic-password", "-a", os.environ.get("USER", ""),
                        "-s", "daydream-oauth", "-w"], capture_output=True, text=True, timeout=15)
    return r.stdout.strip() if r.returncode == 0 else ""

def judge(condition, probe_output, token):
    """Ask a headless haiku: is the condition met per this evidence? -> dict"""
    prompt = (
        "You are a strict condition judge. Reply with ONLY a JSON object, no prose.\n"
        'Schema: {"met": true|false, "confidence": 0.0-1.0, "evidence": "<=40 words quoting the probe output"}\n'
        "Judge conservatively: if the probe output is ambiguous, an error page, or empty, met=false.\n\n"
        f"CONDITION:\n{condition}\n\nTODAY: {datetime.date.today().isoformat()}\n\n"
        f"PROBE OUTPUT:\n{probe_output[:PROBE_MAX_CHARS]}\n"
    )
    env = dict(os.environ, CLAUDE_CODE_OAUTH_TOKEN=token, DISABLE_OMC="1", STANDING_ORDERS_CHILD="1")
    r = subprocess.run(["claude", "--print", "--model", JUDGE_MODEL,
                        "--permission-mode", "bypassPermissions"],
                       input=prompt, env=env, capture_output=True, text=True, timeout=180)
    raw = r.stdout.strip()
    start, end = raw.find("{"), raw.rfind("}")
    if start == -1 or end == -1:
        raise ValueError(f"judge returned no JSON (exit {r.returncode}): {raw[:200]}")
    return json.loads(raw[start:end + 1])

def save_state(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1)
    os.replace(tmp, STATE)  # atomic — a crash mid-write can't corrupt state.json

def main():
    import yaml
    # single-instance lock: an overrunning cycle must not race the next one
    lock = open(os.path.join(DIR, ".lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log_event({"event": "skipped", "reason": "previous run still active (lock held)"})
        return 0
    with open(ORDERS) as f:
        orders = yaml.safe_load(f)["orders"]
    state = {}
    if os.path.exists(STATE):
        with open(STATE) as f:
            state = json.load(f)

    token = keychain_token()
    if not token:
        if not state.get("_no_token_notified"):
            notify("Standing Orders DORMANT", "No daydream-oauth token in keychain. Run: claude setup-token")
            state["_no_token_notified"] = True
            save_state(state)
        log_event({"event": "dormant", "reason": "no keychain token"})
        return 0
    state.pop("_no_token_notified", None)

    today = datetime.date.today()
    for i, o in enumerate(orders):
        # everything per-order is inside this try: one malformed entry
        # (missing key, bad expiry, probe/judge blowup) must never abort the
        # rest of the registry or discard earlier orders' state updates.
        oid = None
        try:
            oid = o["id"]
            st = state.setdefault(oid, {"fires": 0, "status": "active"})
            if st["status"] != "active":
                continue
            if today > datetime.date.fromisoformat(str(o["expiry"])):
                st["status"] = "expired"
                notify("Standing Order EXPIRED unfired", f"{oid}: {o['action'][:120]}")
                log_event({"event": "expired", "order": oid})
                continue
            p = subprocess.run(o["probe"], shell=True, capture_output=True, text=True, timeout=PROBE_TIMEOUT)
            probe_out = (p.stdout + ("\n[stderr] " + p.stderr if p.stderr.strip() else "")).strip()
            if not probe_out:
                raise ValueError(f"empty probe output (exit {p.returncode})")
            verdict = judge(o["condition"], probe_out, token)
            if verdict.get("met"):
                st["fires"] += 1
                if st["fires"] >= int(o.get("max_fires", 1)):
                    st["status"] = "done"
                notify("Standing Order FIRED", f"{oid}: {o['action'][:140]}")
                log_event({"event": "fired", "order": oid, "fires": st["fires"],
                           "confidence": verdict.get("confidence"), "evidence": verdict.get("evidence", "")[:400]})
            else:
                log_event({"event": "held", "order": oid,
                           "confidence": verdict.get("confidence"), "evidence": verdict.get("evidence", "")[:400]})
        except Exception as e:
            notify("Standing Order ERROR", f"{oid or f'orders[{i}]'}: {e}")
            log_event({"event": "error", "order": oid or f"orders[{i}]", "error": str(e)[:500]})
        finally:
            save_state(state)  # persist after every order — a later crash loses nothing
    with open(HEARTBEAT, "w") as f:
        f.write(now() + "\n")
    return 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        log_event({"event": "crash", "error": str(e)[:500]})
        notify("Standing Orders CRASHED", str(e)[:150])
        sys.exit(1)
