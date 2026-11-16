#!/bin/bash
# Run every hooks/tests/test-*.sh. Non-zero if any file fails.
cd "$(dirname "$0")" || exit 1
rc=0
for t in test-*.sh; do
  echo "== $t"
  bash "$t" || rc=1
done
exit $rc
