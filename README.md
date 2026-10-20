# loup-cmd-tail

GNU `tail` recreated in [Loup](https://code-craft.ai/references/loup): print
the last lines or bytes of files, or everything from line or byte N on, and
follow files as they grow with `-f`.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                       # native binary: build/tail
make ci                          # check, unit tests, build, end-to-end tests
make run ARGS="-n 3 README.md"   # run from source with loup run (not for -f)
```

```text
$ build/tail -n 3 numbers.txt
98
99
100
$ build/tail -n +3 names.txt
Cy
Dee
$ build/tail -2 names.txt
Cy
Dee
$ build/tail -c 7 numbers.txt
99
100
$ build/tail -n 1 names.txt numbers.txt
==> names.txt <==
Dee

==> numbers.txt <==
100
$ build/tail -s x names.txt; echo "exit $?"
tail: invalid number of seconds: 'x'
exit 1
$ build/tail --version
tail (loup-cmd-tail) 0.1.0
```

Following a log while another process appends `request 1` and `request 2`
to it (stopped with Ctrl-C):

```text
$ build/tail -f -s 0.2 app.log
started
request 1
request 2
```

With no FILE, or when FILE is `-`, tail reads standard input. The output is
the input's own bytes, also when a byte count cuts a UTF-8 character.

| Option | Meaning |
|---|---|
| `-n N`, `--lines=N` | print the last N lines (default 10); `-n -N` is the same |
| `-n +N` | print from line N on (`+1` and `+0` are the whole file) |
| `-c N`, `--bytes=N` | print the last N bytes |
| `-c +N` | print from byte N on |
| `-f`, `--follow[=name\|descriptor]` | keep printing data appended to the files |
| `-s N`, `--sleep-interval=N` | with `-f`, check every N seconds (default 1; `0.5` works) |
| `-q`, `--quiet`, `--silent` | never print `==> NAME <==` headers |
| `-v`, `--verbose` | always print headers (by default only for several files) |
| `-z`, `--zero-terminated` | lines end with NUL, not newline |
| `-N`, `+N`, `-Nc`, `-Nf`, ... | GNU's obsolete count, as the only option before at most one file |

N may end in a multiplier: `b` 512, `K`/`k`/`KiB` 1024, `kB` 1000, and
likewise `M`, `MB`, `G`, `GB`, `T`, `P`, `E`. Short options combine
(`-fn5`), options may follow file names, `--` ends the options, and long
options may be shortened to any unique prefix (`--li=5`).

Under `-f`, tail prints a file's header again whenever its output switches
to another file, reports `tail: NAME: file truncated` and starts over when a
file shrinks, and does not follow a piped standard input.

Exit status: `0` on success; `1` if any operand could not be read or the
command line was invalid. `-f` runs until it is killed.

## Differences from GNU tail

- Each file is read whole for the first output (Loup 1.26.0 has no streaming
  reads), so an endless input never prints anything, and memory grows with
  the input.
- `-f` follows each file by name, checking it every interval like
  `--follow=name` without `--retry`; `--follow=descriptor` is accepted but
  behaves the same. `-F`, `--retry`, `--pid` and `--max-unchanged-stats` are
  not implemented.
- `-f` reads only the new bytes, through C's stdio (`fopen`, `fseek`,
  `ftell`, `fgetc`) called with `extern native "c"`: Loup's `io.fs` has no
  `stat` or seek, and re-reading the whole file at each check would keep a
  copy of it in memory every time in a native build. Only the native binary
  can call C, so `loup run` (`make run`) stops at the first check with
  `unsupported instruction`, and likewise when it has to print bytes that are
  not whole UTF-8 characters.
- `-s` takes digits with an optional fraction (`2`, `0.5`, `.25`); GNU also
  takes exponents. Intervals are rounded down to milliseconds.
- Counts must be below 2^63; GNU accepts up to 2^64 - 1.
- Messages always quote like GNU in the C locale (`'x'`, not `‘x’`).
- A file that exists but cannot be read (no read permission) stops the native
  binary with the runtime's message, e.g.
  `IoError: read_text failed on 'secret': Permission denied (os error 13)`,
  and status 1. Missing files and directories are reported as GNU does.
- `--version` prints a single line.

## Layout

```text
source/main.loup             # entry point
source/appinfo.loup          # name, version, exit statuses
source/cli/count.loup        # GNU number syntax, +N/-N, seconds
source/cli/args.loup         # GNU getopt-style parsing, obsolete -N/+N form
source/cli/usage.loup        # --help and --version text
source/cli/app.loup          # run(): parse, dispatch, exit status
source/cli/output.loup       # C stdio: exact byte output, file size, copy from an offset
source/commands/tail.loup    # line and byte selection, headers, errors, the -f loop
tests/*_test.loup            # unit tests (make test)
tests/fixtures/              # files read by the unit tests
tests/e2e.sh                 # end-to-end tests of build/tail, including -f (make e2e)
specs/tail/                  # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
