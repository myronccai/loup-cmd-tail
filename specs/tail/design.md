# Design: tail

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the arguments
into `Options`, handles `--help` and `--version`, and calls
`commands.tail.run_tail`. `run_tail` reads each operand whole, picks the part
to print with pure functions (`tail_lines`, `first_byte`) and writes it, with a
header when there are several operands. With `-f` it then enters `follow`,
a polling loop that never returns.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (usage errors are status 1, as in GNU tail) |
| `source/cli/count.loup` | `parse_size` (digits, `+`, blanks, multiplier suffixes, overflow), `parse_count` (`+N`/`-N`, GNU's messages), `parse_seconds`, `quote_arg` |
| `source/cli/args.loup` | `Options`, `UsageError`, `Obsolete`, `match_long`, `check_follow`, `obsolete_count`, `parse_args` |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run the command, map exceptions to status 1 |
| `source/cli/output.loup` | C stdio through `extern native "c"`: `is_utf8`, `print_bytes`, `file_size`, `copy_from` |
| `source/commands/tail.loup` | `tail_lines`, `first_byte`, `header`, `show_headers`, `quote_name`, `io_reason`, `follow`, `run_tail` |

## Parsing

`obsolete_count` implements GNU's `parse_obsolete_option`: when the first
argument is `-N` or `+N` (digits optional) followed by `b`, `c` or `l` and then
`f`, and at most one operand (or `--` and one operand) follows, it is the
count. Otherwise `parse_args` walks the arguments as getopt_long does: short
options in groups, where `-n`, `-c` and `-s` take the rest of the group or the
next argument; long options matched exactly or by a unique prefix;
`--follow[=name|descriptor]` checked like GNU's argmatch; operands in order;
`--` ends the options. Count, seconds and misplaced-digit errors come back
with `try_help = false`, as GNU prints no "Try" line after them.

## Selecting the output

- Lines: `tail_lines` splits the text on the delimiter (`\n`, or NUL under
  `-z`), counts a final piece without a delimiter as a line, and joins the
  pieces from the first kept line to the end. Native `split` and `join` work
  on bytes, so the output is the input's own bytes.
- Bytes: `run_tail` reads the operand as `bytes`, `first_byte` gives where to
  start, and `print_bytes` writes the slice: through `decode()` when it is
  well-formed UTF-8, through C's `putchar` otherwise (a Loup string cannot
  hold a broken character).

## Follow

The roadmap's plan was to re-read each file at every check and print the
growth. In a native build every `readBytes` result stays allocated, so a
1 MB log checked once a second would add 1 MB of memory per second. `follow`
therefore uses C's stdio for the files it watches: `file_size` opens the file
and asks `ftell` for its end, and `copy_from` seeks to the last offset printed
and copies the new bytes with `fgetc`/`putchar`. Memory stays flat and only
new data is read. Between checks it calls `system.time.sleepNs` (the
roadmap's `core.time.sleep` is `async`, which native builds refuse).

On each check, for each watched file in operand order:

- a file that cannot be read (removed, no permission) is skipped;
- a file shorter than its offset was truncated: print
  `tail: NAME: file truncated` and start again from byte 0;
- a file longer than its offset has new data: print its header first if
  headers are on and the last output came from another file, then the bytes.

The last file printed starts out as the last operand, as in GNU, so the
first growth of any other file prints its header. Standard input is watched
only when it is a regular file (a pipe cannot be read again). If no operand
could be opened, tail prints `tail: no files remaining` and exits with 1.

## Differences from GNU tail

- Each operand is read whole for the first output (no streaming reads in
  Loup 1.26.0, ROADMAP T2), so tail on an endless input never prints, and
  memory grows with the input.
- `-f` checks the file by its name at every interval, like
  `--follow=name` without `--retry`: after a log rotation it follows the new
  file. `--follow=descriptor` is accepted but behaves the same. `-F`,
  `--retry`, `--pid` and `--max-unchanged-stats` are not implemented.
- `-f` needs the native binary: `loup run` (`make run`) stops at the first
  check, because only native builds can call C. So does raw byte output.
- `-s` takes digits with an optional fraction (`0.5`, `.25`); GNU also takes
  exponents and hexadecimal floats. Intervals are rounded down to
  milliseconds.
- Counts must be below 2^63; GNU accepts up to 2^64 - 1.
- Messages always quote like GNU in the C locale (`'x'`).
- An operand that exists but cannot be read stops the native binary with the
  runtime's own `IoError` message and status 1 (no `stat()` to check
  permissions first, T1).
- `--version` prints one line.

## Error handling

`run_tail` checks `exists` and `isDir` before reading. A missing operand gives
`tail: cannot open 'NAME' for reading: No such file or directory`; a
directory gets its header, `tail: error reading 'NAME': Is a directory` and,
under `-f`, `tail: NAME: cannot follow end of this type of file; giving up on
this name`. Both set status 1 and the loop moves on.

## Testing

- `tests/count_test.loup`: numbers, suffixes, `+`/`-`, seconds, messages.
- `tests/args_test.loup`: options, groups, `--follow=HOW`, the obsolete form
  and where it applies, misplaced digits, usage errors.
- `tests/tail_test.loup`: `tail_lines` (last N, from N, partial last line,
  NUL), `first_byte`, headers, quoting.
- `tests/output_test.loup`: `is_utf8`.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary on files and standard input, byte for
  byte, plus `-f` runs in the background against files the script appends
  to, truncates and writes a split character into, a piped standard input,
  and no readable files.
