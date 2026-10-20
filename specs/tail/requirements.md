# Requirements: tail

## Introduction

`tail` prints the last part of each file: by default its last ten lines. With
`-f` it keeps running and prints whatever is appended to the files. This
repository recreates GNU coreutils `tail` in Loup, including counts from the
end or from the start, file-name headers, GNU's number syntax and its
obsolete `-N`/`+N` forms. It is the fourth command in the loup-cmd series.

## Requirements

### Requirement 1: Lines and bytes

**User Story:** As a shell user, I want the end of a file so that I can see
the latest entries of a log.

#### Acceptance Criteria

1. WHEN tail is run without a count, THE program SHALL print the last 10
   lines of each operand, or the whole operand if it has fewer.
2. WHEN `-n N` (`--lines=N`, also `-n -N`) is given, THE program SHALL print
   the last N lines; WHEN `-n +N` is given, SHALL print from line N on.
3. WHEN `-c N` (`--bytes=N`) is given, THE program SHALL print the last N
   bytes; WHEN `-c +N` is given, SHALL print from byte N on.
4. THE program SHALL count a final line without a newline as a line, and
   print the selected bytes exactly, also when a count cuts a multi-byte
   character or the input is binary.
5. WHEN `-z` is given, THE program SHALL end lines with NUL instead of
   newline.

### Requirement 2: Numbers

**User Story:** As a script author, I want GNU's number syntax so that
existing scripts behave the same.

#### Acceptance Criteria

1. THE program SHALL accept counts with GNU's multiplier suffixes (`b`, `K`,
   `kB`, `KiB`, `M`, ...) and report `tail: invalid number of lines: 'X'`
   (or `bytes`), with `: Value too large for defined data type` when the
   count does not fit, exiting with status 1.
2. WHEN the only option is GNU's obsolete form `-N` or `+N`, optionally
   followed by `b`, `c` or `l` and then `f` (`-5`, `+3`, `-2c`, `-10f`), and
   at most one file follows, THE program SHALL treat it as that count.
3. WHEN a digit appears as an option anywhere else, THE program SHALL print
   `tail: option used in invalid context -- N` and exit with status 1.

### Requirement 3: Headers

**User Story:** As a shell user, I want to know which file each part came
from when I look at several at once.

#### Acceptance Criteria

1. WHEN more than one operand is given, THE program SHALL print
   `==> NAME <==` before each one, with an empty line before every header
   but the first; standard input is named `standard input`.
2. WHEN `-q` (`--quiet`, `--silent`) is given, THE program SHALL print no
   headers; WHEN `-v` (`--verbose`) is given, SHALL print them even for one
   operand.

### Requirement 4: Follow

**User Story:** As someone watching a log, I want new lines printed as they
are written so that I do not have to run tail again.

#### Acceptance Criteria

1. WHEN `-f` (`--follow`, `--follow=name`, `--follow=descriptor`) is given,
   THE program SHALL, after the normal output, check the files every
   interval and print any bytes appended since the last check, until it is
   killed.
2. WHEN `-s N` (`--sleep-interval=N`) is given, THE program SHALL wait N
   seconds between checks (default 1; decimals allowed); a bad value SHALL
   give `tail: invalid number of seconds: 'X'` and status 1.
3. WHEN output switches to a different file and headers are on, THE program
   SHALL print that file's header first.
4. WHEN a followed file becomes shorter, THE program SHALL print
   `tail: NAME: file truncated` and then the file's content from the start.
5. WHEN standard input is a pipe, THE program SHALL not follow it; WHEN no
   operand could be opened, SHALL print `tail: no files remaining` and exit
   with status 1.

### Requirement 5: Command line and errors

**User Story:** As a shell user, I want GNU's option syntax and messages so
that tail fits into existing scripts.

#### Acceptance Criteria

1. THE program SHALL accept combined short options (`-qn5`), options after
   operands, `--`, `-` for standard input, and long options abbreviated to a
   unique prefix; the last count option wins.
2. WHEN an option is unknown, ambiguous, lacks its argument or has one it
   does not take, THE program SHALL print GNU's message and
   `Try 'tail --help' for more information.` and exit with status 1.
3. WHEN an operand does not exist, THE program SHALL print
   `tail: cannot open 'NAME' for reading: No such file or directory`; WHEN it
   is a directory, SHALL print its header and
   `tail: error reading 'NAME': Is a directory`; in both cases continue and
   exit with status 1.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or the version line and exit with status 0.
