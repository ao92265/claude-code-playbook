"""Find real `git commit` and `git push` runs in a Bash tool command.

Shared by hooks/push-gate.py and skills/myinsights/harvest_local.py so the nudge
and the score agree. A word match is not enough: `git commit -m "fix push"`,
`git stash push`, `echo "git commit later"` and heredoc text must not count, and
`--dry-run` does nothing. git must be at command position and the subcommand must
be exactly commit or push.
"""
import re
import shlex

SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "{", "}", "|&"}
WRAPPERS = {"sudo", "time", "nohup", "command", "env", "rtk", "exec", "xargs", "!",
            "then", "do", "else", "elif", "if", "while", "until"}
WRAPPER_WITH_VALUE = {"timeout": 1, "-u": 1}  # timeout 60 git ..., env -u X git ...
HEREDOC = re.compile(r"(?<!<)<<(-?)[ \t]*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def _lines(cmd):
    """Command lines with backslash continuations joined and heredoc bodies dropped."""
    end = None
    for line in cmd.replace("\\\n", " ").splitlines():
        if end is not None:
            if (line.lstrip("\t") if end[0] else line) == end[1]:
                end = None
            continue
        m = HEREDOC.search(line)
        if m:
            end = (m.group(1) == "-", m.group(2))
        yield line


def _segments(cmd):
    for line in _lines(cmd):
        try:
            lex = shlex.shlex(line, posix=True, punctuation_chars=True)
            lex.whitespace_split = True
            lex.commenters = ""
            toks = list(lex)
        except ValueError:
            toks = line.split()
        for k, t in enumerate(toks):        # a comment starts only at a token start
            if t.startswith("#"):
                toks = toks[:k]
                break
        seg = []
        for t in toks:
            if t in SEPARATORS:
                if seg:
                    yield seg
                seg = []
            else:
                seg.append(t)
        if seg:
            yield seg


def git_actions(cmd):
    """Yield (action, folder) in order. action is "cd", "commit" or "push".
    folder is the target of `cd X` or `git -C X`, else None."""
    for seg in _segments(cmd):
        i = 0
        while i < len(seg):
            t = seg[i]
            if t in WRAPPER_WITH_VALUE:
                i += 1 + WRAPPER_WITH_VALUE[t]
            elif t in WRAPPERS or ("=" in t and not t.startswith("-")) or (i and seg[i - 1] == "timeout" and t[:1].isdigit()):
                i += 1
            else:
                break
        if i >= len(seg):
            continue
        if seg[i] == "cd" and i + 1 < len(seg):
            if "$" not in seg[i + 1]:          # an unexpanded variable is no folder
                yield "cd", seg[i + 1]
            continue
        if seg[i] != "git" and not seg[i].endswith("/git"):
            continue
        i += 1
        folder = None
        while i < len(seg) and seg[i].startswith("-"):
            if seg[i] in GIT_OPTS_WITH_VALUE and i + 1 < len(seg):
                if seg[i] == "-C" and "$" not in seg[i + 1]:
                    folder = seg[i + 1]
                i += 2
            else:
                i += 1
        if i >= len(seg) or seg[i] not in ("commit", "push"):
            continue
        if "--dry-run" in seg[i + 1:] or (seg[i] == "push" and "-n" in seg[i + 1:]):
            continue
        yield seg[i], folder
