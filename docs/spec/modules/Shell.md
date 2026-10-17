# Shell

Core model: the app carries a small set of ordinary command-line tools (ios_system, BSD-3) and runs them inside one folder of its own. The model uses it through one tool, `runShell`, and the user through a Shell screen. It is not Linux: no package manager, no compiler, no background processes.

## Words
- Workspace: the folder `Documents/Shell` in the app. The shell starts there and cannot leave it.
- Command line: one string, parsed in code into words, pipes, redirects and `;`/`&&` joins before anything runs.

## Parts
- ShellPolicy (pure, tested, in ToolKit): splits a command line into commands, classifies each as read, write, delete or network, refuses unsafe ones, and checks every path argument against the workspace.
- ShellRunner (App, needs the runner): loads ios_system, sets the working directory and environment (HOME and PWD in the workspace, no inherited PATH), runs with a time limit, captures stdout and stderr up to 64 KB.
- runShell tool: argument `command`. Reads run at once. Everything else goes through an approval card showing the exact command and the classification. Network or write after untrusted context always asks.
- Shell screen (Settings > Advanced > Shell): a plain terminal view with history, a file list of the workspace with share and delete, and a Clear workspace button. The user's own typing needs no approval card but uses the same sandbox.

## Classification (ShellPolicy)
- read: ls, cat, head, tail, wc, grep, find (without -exec/-delete), pwd, echo, sort, uniq, cut, tr, diff, stat, du, file, basename, dirname, date, which
- write: mkdir, touch, cp, mv, tee, sed -i, any `>` or `>>`, tar (create or extract), gzip, gunzip, chmod, ln (never symlinks out)
- delete: rm, rmdir, find with -delete or -exec, truncate. Irreversible tier; the card names what is deleted.
- network: curl, wget, scp, sftp, ssh, ping, nslookup. Always a card, and the host is shown. Downloads land in the workspace only.
- refused: sh, bash, zsh, eval, exec, source, `.`, xargs with a command, sudo, su, env with a command, nohup, background `&`, command substitution `$( )` and backticks, subshells, `cd` out of the workspace, any command not in the table.
- A pipeline or `&&` chain takes the highest class of its parts. An unknown command is refused, never guessed.

## Path rules
- Every argument that looks like a path is resolved against the workspace and must stay inside it after resolving `..` and symlinks. `~` means the workspace. Absolute paths are allowed only if they resolve inside it.
- The workspace folder is created on first use and excluded from backup only if the user asks (not by default).
- Reads of other app folders (chats, notes, keys, Keychain items) are impossible by construction: they live outside the workspace.

## Limits
- 20 s per command, then the command is cancelled and the output so far is returned with a note.
- 64 KB output; more is cut with a note.
- No stdin: interactive programs (vi, less, top) are refused.
- The tool is offered to online models through findTools and the keyword search; Apple's on-device model and downloaded models do not get it.

## Not responsible
- Running downloaded executables: only the bundled command set runs; a downloaded script file is text unless a bundled interpreter (perl, awk, sed) is told to read it, and that goes through the same approval.
- Python, compilers, package managers.
- Access outside the workspace (iCloud, Files provider folders). A later task may add folders the user grants.

## Invariants
- The model can never run a command the user did not see when the class is anything but read.
- A command that fails the path check is not run at all, and the refusal says which argument.
- Diagnostics records the command word and class and the outcome, never arguments or output.
