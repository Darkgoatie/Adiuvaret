#!/usr/bin/env bash
# Mechanical review of a landed task. Prints a PASS/FAIL/WARN table; exits 1 on any FAIL.
#   review.sh <base> <head> [--baseline-errors N] [--max-files N]
# Env: SMOKE (default scripts/smoke.sh), TEST_PATHS (pathspecs for test files).
# The end-to-end run with real binaries is still yours to do.
set -uo pipefail

base="${1:?usage: review.sh <base> <head>}"; head="${2:?usage: review.sh <base> <head>}"; shift 2
baseline_errors=""; max_files=25
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline-errors) baseline_errors="$2"; shift 2 ;;
    --max-files) max_files="$2"; shift 2 ;;
    *) echo "unknown arg $1" >&2; exit 1 ;;
  esac
done
smoke="${SMOKE:-scripts/smoke.sh}"
fail=0; rows=()
row() { rows+=("$(printf '%-5s %-22s %s' "$1" "$2" "$3")"); [ "$1" = FAIL ] && fail=1; return 0; }

range="$base..$head"
git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "bad base $base" >&2; exit 1; }
git rev-parse -q --verify "$head^{commit}" >/dev/null || { echo "bad head $head" >&2; exit 1; }
changed="$(git diff --name-only "$range")"

# 1. smoke on a clean worktree
wt="$(mktemp -d "${TMPDIR:-/tmp}/bpm-review.XXXXXX")"; rmdir "$wt"
command -v cygpath >/dev/null 2>&1 && wt="$(cygpath -m "$wt")"
if git worktree add -q --detach "$wt" "$head" 2>/dev/null; then
  if [ -f "$wt/$smoke" ]; then
    log="$wt.log"
    ( cd "$wt" && bash "$smoke" ) >"$log" 2>&1; rc=$?
    errs=$(grep -c 'ERROR' "$log" || true)
    if [ $rc -ne 0 ]; then row FAIL smoke "exit $rc (log: $log)"; else row PASS smoke "exit 0"; fi
    if [ -n "$baseline_errors" ] && [ "$errs" -gt "$baseline_errors" ]; then
      row FAIL "error lines" "$errs > baseline $baseline_errors"
    else
      row PASS "error lines" "$errs${baseline_errors:+ (baseline $baseline_errors)}"
    fi
  else
    row WARN smoke "$smoke not found at $head"
  fi
  git worktree remove --force "$wt" >/dev/null 2>&1
else
  row FAIL smoke "could not create worktree"
fi

# 2. weakened tests
tp=(${TEST_PATHS:-})
if [ ${#tp[@]} -eq 0 ]; then
  tp=(':(glob)**/test*/**' ':(glob)**/*test*' ':(glob)**/*spec*' ':(glob)**/__tests__/**')
fi
tdiff="$(git diff -U0 "$range" -- "${tp[@]}" 2>/dev/null)"
skips=$(printf '%s\n' "$tdiff" | grep -E '^\+' | grep -cE '#\[ignore\]|pytest\.mark\.skip|\b(it|describe|test)\.(skip|todo)\b|\bxit\(|@Disabled|@Ignore|t\.Skip\(' || true)
rets=$(printf '%s\n' "$tdiff" | grep -E '^\+[^+]' | grep -cE '^\+\s*return\s*;?\s*$' || true)
asserts=$(printf '%s\n' "$tdiff" | grep -E '^-[^-]' | grep -ciE 'assert|expect\(' || true)
added_asserts=$(printf '%s\n' "$tdiff" | grep -E '^\+[^+]' | grep -ciE 'assert|expect\(' || true)
[ "$skips" -gt 0 ] && row FAIL "skip markers" "$skips added" || row PASS "skip markers" "none added"
[ "$rets" -gt 0 ] && row WARN "early returns" "$rets bare returns added in tests" || row PASS "early returns" "none"
if [ "$asserts" -gt "$added_asserts" ]; then row FAIL asserts "-$asserts +$added_asserts"; else row PASS asserts "-$asserts +$added_asserts"; fi

# 3. new public functions with no callers
names=$(git diff -U0 "$range" | grep -E '^\+[^+]' | sed -nE \
  -e 's/^\+\s*pub(\([a-z]+\))?\s+(async\s+)?fn\s+([A-Za-z0-9_]+).*/\3/p' \
  -e 's/^\+\s*export\s+(default\s+)?(async\s+)?function\s*\*?\s*([A-Za-z0-9_]+).*/\3/p' \
  -e 's/^\+\s*export\s+const\s+([A-Za-z0-9_]+)\s*=\s*(async\s*)?\(.*/\1/p' \
  -e 's/^\+def\s+([A-Za-z][A-Za-z0-9_]*).*/\1/p' \
  -e 's/^\+func\s+([A-Z][A-Za-z0-9_]*).*/\1/p' | sort -u)
uncalled=()
for n in $names; do
  c=$(git grep -wc "$n" "$head" 2>/dev/null | awk -F: '{s+=$NF} END{print s+0}')
  [ "$c" -le 1 ] && uncalled+=("$n")
done
[ ${#uncalled[@]} -gt 0 ] && row WARN "uncalled public fns" "${uncalled[*]}" || row PASS "uncalled public fns" "$(echo $names | wc -w) new, all referenced"

# 4. spec updated with code
code=$(printf '%s\n' "$changed" | grep -v '^docs/spec/' | grep -c . || true)
spec=$(printf '%s\n' "$changed" | grep -c '^docs/spec/' || true)
if [ "$code" -gt 0 ] && [ "$spec" -eq 0 ]; then row FAIL "spec updated" "$code code files, 0 spec files"; else row PASS "spec updated" "$spec spec files"; fi

# 5. commit size
ncommits=$(git rev-list --count "$range")
big=$(git rev-list "$range" | while read -r c; do
  n=$(git diff-tree --no-commit-id --name-only -r "$c" | wc -l)
  [ "$n" -gt "$max_files" ] && echo "$(git rev-parse --short "$c"):$n"
done)
if [ -n "$big" ]; then row FAIL "commit size" "over $max_files files: $big"; else row PASS "commit size" "$ncommits commits"; fi

# 6. history and working tree
resets=$(git reflog --date=iso -n 200 | grep -cE 'reset:|rebase|commit \(amend\)' || true)
[ "$resets" -gt 0 ] && row WARN "reflog" "$resets reset/rebase/amend entries (check they predate the task)" || row PASS reflog "clean"
dirty=$(git status --porcelain | grep -c . || true)
row INFO "working tree" "$dirty uncommitted entries (compare with before the task)"

printf '%s\n' "Review $base..$head" "----------------------------------------"
printf '%s\n' "${rows[@]}"
exit $fail
