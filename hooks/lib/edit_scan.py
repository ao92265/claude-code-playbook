"""Which files a transcript tool call writes to. Copied from the review gate in
verify-gate.sh (which keeps its own inline copy) so other stop gates can share it.
Read the comments there for why each rule exists."""
import os
import re

EDITORS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
SOURCE = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".vue", ".svelte", ".py",
          ".sh", ".bash", ".zsh", ".rb", ".go", ".rs", ".cs", ".java", ".kt",
          ".swift", ".sql", ".php", ".c", ".cc", ".cpp", ".h", ".hpp", ".m",
          ".scala", ".ex", ".exs")
# Prose and machine state. Editing a plan, a memory or a scratch file is not the
# kind of work that needs a second pair of eyes.
SKIP = ("/.claude/plans/", "/.claude/state/", "/.claude/projects/", "/scratchpad/",
        "/.omc/", "/node_modules/")
# The machine's temp roots earn their place: writing a probe script there is what
# a reviewer does, and counting it made the review look like fresh unreviewed
# work. Matched as a PREFIX, not a substring, or a repo with its own tmp/ folder
# would go dark: /home/x/Repos/app/src/tmp/helper.ts is real work.
SKIP_ROOTS = ("/tmp/", "/private/tmp/", "/var/folders/")

REDIRECT = re.compile(r"(?<![-=])(?:>>?|\btee\s+(?:-a\s+)?)\s*([\"']?)([^\s;|&()\"']+)\1")
# Only the run of arguments belonging to this sed, not the rest of the command.
# Sweeping the whole string counted every path inside a heredoc that merely
# quoted a sed example, which is how this gate first over-reported on itself.
SED_IN_PLACE = re.compile(r"\bsed\s+-i\b([^;|&\n]*)")
# Heredoc bodies are data, not commands. A redirect quoted inside one is text.
HEREDOC = re.compile(r"<<-?\s*([\"']?)(\w+)\1.*?^\2$", re.S | re.M)
# The directory a relative write lands in, when the command says so itself.
CD_PREFIX = re.compile(r"\bcd\s+([\"']?)(/[^\s;|&()\"']+)\1")
TOKEN = re.compile(r"[^\s;|&()\"']+")
# Backtick by code point: a literal one here would end the shell heredoc early.
SHELL_META = "$%*{}" + chr(96)


def shell_targets(command: str):
    """Files a shell command writes to. Redirect and tee name an exact target.
    'sed -i' does not, because its flag takes an optional suffix argument that
    cannot be told from a filename, so every source-looking token in that one
    command segment counts.

    Nothing carrying a shell metacharacter, because command text is full of
    things shaped like filenames that are not files: '%s/eps.ts' from a printf
    template, '$S/bad.ts' from an unexpanded variable. Counting those is how
    this gate once reported 12 changed files on a session that changed one.

    A relative target is kept only when the same command says where it lands
    ('cd /repo && cat > src/x.ts', which is the common shape). The anchor is the
    LAST cd before that particular write, not the first in the string: 'cd /tmp
    && ls; cd /repo && cat > src/a.ts' belongs to /repo, and filing it under
    /tmp would invent a path that does not exist. With no cd before it at all,
    the directory is unknowable from here and the write is dropped."""
    body = HEREDOC.sub(" ", command)
    found = [(m.start(), m.group(2)) for m in REDIRECT.finditer(body)]
    for m in SED_IN_PLACE.finditer(body):
        found.extend((m.start(), t) for t in TOKEN.findall(m.group(1)))
    cds = [(m.start(), m.group(2)) for m in CD_PREFIX.finditer(body)]
    resolved = []
    for offset, target in found:
        if any(c in target for c in SHELL_META):
            continue
        if target.startswith("/"):
            resolved.append(os.path.normpath(target))
            continue
        anchor = [d for pos, d in cds if pos < offset]
        if anchor:
            resolved.append(os.path.normpath(anchor[-1].rstrip("/") + "/" + target))
    return resolved


def qualifies(data: dict) -> str:
    path = str(data.get("file_path") or data.get("notebook_path") or "")
    if (path.endswith(SOURCE) and not path.startswith(SKIP_ROOTS)
            and not any(s in path for s in SKIP)):
        return path
    return ""


