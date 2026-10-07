#!/usr/bin/env bash
# Install a pre-commit hook that rejects staged files outside task <id>'s file list.
# docs/spec/ is always allowed. Entries ending in / allow a directory.
#   install-hook.sh <id>     install for a task
#   install-hook.sh --off    remove the restriction
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
command -v cygpath >/dev/null 2>&1 && here="$(cygpath -m "$here")"
hooks="$(git rev-parse --git-path hooks)"
allow="$(git rev-parse --git-path bpm-allowed)"
mkdir -p "$hooks"

if [ "${1:-}" = "--off" ]; then
  rm -f "$allow"
  echo "task restriction removed"
  exit 0
fi

id="${1:?usage: install-hook.sh <task-id> | --off}"
py="$(command -v python3 || command -v python)"
"$py" "$here/next-task.py" --files "$id" > "$allow"
if [ ! -s "$allow" ]; then
  rm -f "$allow"
  echo "task $id lists no files; fill the Files column first" >&2
  exit 1
fi

if [ -f "$hooks/pre-commit" ] && ! grep -q 'bpm-allowed' "$hooks/pre-commit"; then
  mv "$hooks/pre-commit" "$hooks/pre-commit.bpm-prev"
fi

cat > "$hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
allow="$(git rev-parse --git-path bpm-allowed)"
hooks="$(git rev-parse --git-path hooks)"
if [ -x "$hooks/pre-commit.bpm-prev" ]; then "$hooks/pre-commit.bpm-prev" || exit 1; fi
[ -f "$allow" ] || exit 0
bad=0
while IFS= read -r f; do
  case "$f" in docs/spec/*) continue ;; esac
  ok=0
  while IFS= read -r a; do
    a="${a%$'\r'}"
    [ -z "$a" ] && continue
    case "$a" in
      */) case "$f" in "$a"*) ok=1 ;; esac ;;
      *) [ "$f" = "$a" ] && ok=1 ;;
    esac
  done < "$allow"
  if [ $ok -eq 0 ]; then echo "blocked: $f is outside the task's file list" >&2; bad=1; fi
done < <(git diff --cached --name-only)
exit $bad
HOOK
chmod +x "$hooks/pre-commit"
echo "hook installed for task $id:"
sed 's/^/  /' "$allow"
