#!/bin/bash
# firewall.sh must ignore destructive-looking TEXT inside heredoc bodies written
# to files, but still block real commands and heredocs fed to a shell.
HOOK="$HOME/.claude/hooks/firewall.sh"
FAIL=0
R='r''m -r''f'   # built up so this test file never trips the firewall itself
run() { jq -n --arg c "$2" '{tool_input:{command:$c}}' | env -u CLAUDE_SKIP_HOOKS -u OMC_SKIP_HOOKS "$HOOK" >/dev/null 2>&1; got=$?
  [ "$got" -eq "$1" ] && echo "OK   $3" || { echo "FAIL $3 (want $1 got $got)"; FAIL=$((FAIL+1)); }; }
NL=$'\n'
run 0 "cat > /tmp/x.md <<'EOF'${NL}notes about $R being blocked${NL}EOF" "quoted EOF heredoc body to file is allowed"
run 0 "cat > /tmp/x.md <<EOF${NL}$R /tmp/a${NL}EOF" "bare EOF heredoc body is allowed"
run 0 "python3 - <<'PY'${NL}print('$R')${NL}PY" "non-EOF delimiter body is allowed"
run 0 "cat <<-\"MD\" > /tmp/y${NL}	$R z${NL}	MD" "<<- with indented delimiter is allowed"
run 2 "cat > /tmp/x <<'EOF'${NL}hi${NL}EOF${NL}$R /tmp/real" "real rm after heredoc ends is blocked"
run 2 "$R /tmp/real && cat > /tmp/x <<'EOF'${NL}hi${NL}EOF" "real rm before heredoc is blocked"
run 2 "bash <<'EOF'${NL}$R /tmp/real${NL}EOF" "heredoc fed to bash is still blocked"
run 2 "ssh host <<EOF${NL}$R /tmp/real${NL}EOF" "heredoc fed to ssh is still blocked"
run 2 "$R /tmp/plain" "plain recursive force rm is blocked"
run 0 "echo \"$R x\"" "quoted string mention is allowed"
run 2 "echo \"use cat <<EOF for that\"${NL}$R /tmp/real" "<<WORD inside quotes does not hide later lines"
run 2 "echo \$((a<<b))${NL}$R /tmp/real" "arithmetic shift does not hide later lines"
run 2 "cat <<NOEND > /tmp/x${NL}$R /tmp/real" "unterminated heredoc body is checked"
run 2 "cat <<'EOF' | bash${NL}$R /tmp/real${NL}EOF" "quoted heredoc piped to bash is blocked"
run 2 "cat <<SH | sh${NL}$R /tmp/real${NL}SH" "heredoc piped to sh is blocked"
run 2 "cat <<EOF | sudo bash${NL}$R /tmp/real${NL}EOF" "heredoc piped to sudo bash is blocked"
run 2 "x=\$(cat <<'EOF'${NL}$R /tmp/real${NL}EOF${NL})${NL}eval \"\$x\"" "heredoc captured into a variable is checked"
run 2 "/bin/bash <<'EOF'${NL}$R /tmp/real${NL}EOF" "absolute path bash is blocked"
run 2 ". /dev/stdin <<EOF${NL}$R /tmp/real${NL}EOF" "dot-source of stdin is blocked"
run 2 "bash \\${NL}<<EOF${NL}$R /tmp/real${NL}EOF" "bash with line continuation is blocked"
run 2 "cat <<\"E\"OF${NL}$R /tmp/real${NL}EOF${NL}E" "split quoted delimiter is checked"
run 2 "cat <<EOF > /tmp/x; $R /tmp/real${NL}hi${NL}EOF" "real rm on the opener line is blocked"
run 0 "git commit -m \"\$(cat <<'EOF'${NL}docs: explain $R guard${NL}EOF${NL})\"" "commit message heredoc is allowed"
run 0 "cat <<<'$R x'" "here-string is not a heredoc"
run 2 "bash<<EOF${NL}$R /tmp/real${NL}EOF" "shell name touching << is blocked"
run 2 "cat <<EOF|sh>/dev/null${NL}$R /tmp/real${NL}EOF" "pipe to sh with redirect is blocked"
run 2 "\"bash\" <<EOF${NL}$R /tmp/real${NL}EOF" "quoted shell name is blocked"
run 2 "\$SHELL <<EOF${NL}$R /tmp/real${NL}EOF" "SHELL variable is blocked"
run 2 "cat <<EOF |${NL}$R /tmp/real${NL}EOF${NL}sh" "shell named after the body is blocked"
run 2 "{ cat <<EOF${NL}$R /tmp/real${NL}EOF${NL}} | bash" "group piped to bash is blocked"
run 2 "x=\"\$(cat <<EOF${NL}$R /tmp/real${NL}EOF${NL})\"; eval \"\$x\"" "quoted capture then eval is blocked"
run 2 "# e.g. cat <<EOF${NL}$R /tmp/real${NL}EOF" "<< in a comment does not hide later lines"
run 2 "((a<<b))${NL}$R /tmp/real${NL}b" "bare arithmetic does not hide later lines"
run 2 "echo \"it's\"; $R 'x'" "apostrophe inside double quotes does not swallow a command"
run 2 "echo \$'it\\'s'; $R 'x'" "ANSI-C quote does not swallow a command"
run 0 "cat > /tmp/b.sh <<'EOF'${NL}#!/bin/bash${NL}$R build${NL}EOF" "writing a shell script with a shebang is allowed"
echo "failures: $FAIL"; exit $FAIL
