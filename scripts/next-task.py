#!/usr/bin/env python3
"""Read docs/spec/TASKS.md.

  next-task.py              print the next runnable task (pending or needs-fix, deps done, above STOP)
  next-task.py --files ID   print the files task ID may touch, one per line
  next-task.py --list       print id, status for every task

Exit 0 with a task, 2 when blocked by STOP, 3 when nothing is runnable, 1 on error.
"""
import re
import sys
from pathlib import Path

TASKS = Path("docs/spec/TASKS.md")


# Each table may have its own header; these spellings mean the same column.
ALIASES = {"id": "#", "deps": "depends", "acceptance": "acceptance check"}


def is_done(status):
    return status.lower().startswith("done")


def split_list(cell):
    cell = cell.strip()
    if cell in ("", "-"):
        return []
    return [p.strip().strip("`") for p in re.split(r"[,\s]+", cell) if p.strip()]


def parse(path):
    header = None
    tasks = []
    stop_after = None
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s == "STOP":
            if stop_after is None:
                stop_after = len(tasks)
            continue
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if header is None or cells[0].lower() in ("#", "id"):
            header = [ALIASES.get(c.lower(), c.lower()) for c in cells]
            continue
        if all(set(c) <= set("-: ") for c in cells):
            continue
        row = dict(zip(header, cells))
        if not re.fullmatch(r"[A-Za-z]*\d+[A-Za-z]?", row.get("#", "")):
            continue
        row["_pos"] = len(tasks)
        tasks.append(row)
    if header is None:
        sys.exit("no task table in " + str(path))
    return tasks, stop_after


def main():
    path = TASKS
    args = sys.argv[1:]
    if "--tasks" in args:
        i = args.index("--tasks")
        path = Path(args[i + 1])
        del args[i:i + 2]
    if not path.exists():
        print(f"missing {path}", file=sys.stderr)
        return 1
    tasks, stop_after = parse(path)
    by_id = {t["#"]: t for t in tasks}

    if args and args[0] == "--list":
        for t in tasks:
            print(f"{t['#']}\t{t.get('status', '')}\t{t.get('task', '')}")
        return 0

    if args and args[0] == "--files":
        t = by_id.get(args[1])
        if not t:
            print(f"no task {args[1]}", file=sys.stderr)
            return 1
        for f in split_list(t.get("files", "")):
            print(f)
        return 0

    for t in tasks:
        if t.get("status", "").lower() == "in progress":
            print(f"task {t['#']} is in progress: finish or reset it first", file=sys.stderr)
            return 3

    for t in tasks:
        status = t.get("status", "").lower()
        if status not in ("pending", "needs-fix"):
            continue
        # Rows without a Files column are checks for the user, not agent tasks.
        if not split_list(t.get("files", "")):
            continue
        deps = split_list(t.get("depends", ""))
        if any(not is_done(by_id.get(d, {}).get("status", "")) for d in deps):
            continue
        if stop_after is not None and t["_pos"] >= stop_after:
            print(f"STOP reached before task {t['#']}: waiting for the user", file=sys.stderr)
            return 2
        print(f"{t['#']}\t{t.get('task', '')}")
        print(f"module: {t.get('module', '')}")
        print(f"files: {t.get('files', '')}")
        print(f"check: {t.get('acceptance check', '')}")
        return 0

    print("nothing runnable", file=sys.stderr)
    return 3


if __name__ == "__main__":
    sys.exit(main())
