#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run in a temporary directory holding the fixture files made
# below, so error messages show short names.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# expect_file NAME EXPECTED FILE
# Compares the contents of FILE with the string EXPECTED.
expect_file() {
    printf '%s' "$2" > "$TMP/want"
    if cmp -s "$TMP/want" "$3"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $1"
        diff <(od -c "$TMP/want") <(od -c "$3") | sed 's/^/    /' | head -20
    fi
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    want stderr: $want_err"
        sed 's/^/    got stderr:  /' "$TMP/err" | head -5
    fi
}

cd "$TMP" || exit 1
seq 1 12 > twelve
printf 'a\nb\nc' > abc
printf 'h\303\251llo\n' > utf
printf 'x\0y\0z' > nul
printf '\001\377\376\375\n' > binary
: > empty
mkdir dir

# Lines
check "default ten lines"  0 $'3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n' twelve
check "-n 2"               0 $'11\n12\n'                        -n 2 twelve
check "-n -2"              0 $'11\n12\n'                        -n -2 twelve
check "-n2 attached"       0 $'11\n12\n'                        -n2 twelve
check "--lines=2"          0 $'11\n12\n'                        --lines=2 twelve
check "-n +11"             0 $'11\n12\n'                        -n +11 twelve
check "-n +0 is all"       0 $'a\nb\nc'                         -n +0 abc
check "-n 0"               0 ''                                 -n 0 twelve
check "partial last line"  0 'c'                                -n 1 abc
check "more than there are" 0 $'a\nb\nc'                        -n 50 abc
check "empty file"         0 ''                                 empty
IN=abc check "stdin"       0 $'b\nc'                            -n 2
IN=abc check "dash"        0 $'b\nc'                            -n 2 -
check "-2 obsolete"        0 $'11\n12\n'                        -2 twelve
check "+11 obsolete"       0 $'11\n12\n'                        +11 twelve
printf 'y\0z' > "$TMP/want-z"
check_file "-z"            0 "$TMP/want-z"                      -z -n 2 nul

# Bytes
check "-c 3"               0 $'12\n'                            -c 3 twelve
check "-c +25"             0 $'12\n'                            -c +25 twelve
check "-3c obsolete"       0 $'12\n'                            -3c twelve
check "-c 5 in a char"     0 $'\251llo\n'                       -c 5 utf
check "-c +3 in a char"    0 $'\251llo\n'                       -c +3 utf
printf '\376\375\n' > "$TMP/want-bin"
check_file "binary -c 3"   0 "$TMP/want-bin"                    -c 3 binary
if [ "$("$BIN" -c 3 binary | od -An -tx1)" = " fe fd 0a" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: binary -c 3 into a pipe"
fi

# Headers
check "two files"          0 $'==> abc <==\nc\n==> twelve <==\n12\n'  -n 1 abc twelve
check "-q"                 0 $'c12\n'                           -q -n 1 abc twelve
check "-v one file"        0 $'==> twelve <==\n12\n'            -v -n 1 twelve
IN=abc check "stdin header" 0 $'==> standard input <==\nc'      -vn1

# Errors
check "missing file"       1 $'==> abc <==\nc\n==> twelve <==\n12\n'  -n 1 abc missing twelve
check_err "missing message" 1 "tail: cannot open 'missing' for reading: No such file or directory" missing
check "directory"          1 $'==> dir <==\n\n==> abc <==\nc'   -n 1 dir abc
check_err "directory message" 1 "tail: error reading 'dir': Is a directory" dir
check_err "bad count"      1 "tail: invalid number of lines: '+x'"       -n +x twelve
check_err "too large"      1 "tail: invalid number of bytes: '1Z': Value too large for defined data type" -c 1Z twelve
check_err "bad seconds"    1 "tail: invalid number of seconds: 'x'"      -s x twelve
check_err "digit option"   1 "tail: option used in invalid context -- 5" -n 1 -5 twelve
check_err "missing argument" 1 $'tail: option requires an argument -- \'n\'\nTry \'tail --help\' for more information.' -n
check_err "invalid option" 1 $'tail: invalid option -- \'x\'\nTry \'tail --help\' for more information.' -x
check_err "bad --follow"   1 $'tail: invalid argument \'x\' for \'--follow\'\nValid arguments are:\n  - \'descriptor\'\n  - \'name\'\nTry \'tail --help\' for more information.' --follow=x
check_err "ambiguous"      1 $'tail: option \'--s\' is ambiguous; possibilities: \'--silent\' \'--sleep-interval\'\nTry \'tail --help\' for more information.' --s

# Follow: run tail -f in the background, change the files, then stop it.
printf 'a\nb\n' > log
printf 'one\n' > other
"$BIN" -f -s 0.1 -n 1 log > "$TMP/follow1" 2>&1 &
pid=$!
sleep 1; printf 'c\n' >> log
sleep 1; printf 'd' >> log
sleep 1; kill "$pid"; wait "$pid" 2>/dev/null
expect_file "-f prints appended data" $'b\nc\nd' "$TMP/follow1"

printf 'a\n' > log
"$BIN" -f -s 0.1 log other > "$TMP/follow2" 2>&1 &
pid=$!
sleep 1; printf 'b\n' >> log
sleep 1; printf 'two\n' >> other
sleep 1; printf 'x\n' > log
sleep 1; printf '\303' >> other
sleep 1; printf '\251\n' >> other
sleep 1; kill "$pid"; wait "$pid" 2>/dev/null
expect_file "-f headers, truncation, split character" \
    $'==> log <==\na\n\n==> other <==\none\n\n==> log <==\nb\n\n==> other <==\ntwo\ntail: log: file truncated\n\n==> log <==\nx\n\n==> other <==\n\303\251\n' \
    "$TMP/follow2"

printf 'a\nb\n' | timeout 5 "$BIN" -f -n 1 > "$TMP/follow3" 2>&1
expect_file "-f ignores a pipe" $'b\n' "$TMP/follow3"

timeout 5 "$BIN" -f missing > "$TMP/follow4" 2>&1
status=$?
expect_file "-f with no files" $'tail: cannot open \'missing\' for reading: No such file or directory\ntail: no files remaining\n' "$TMP/follow4"
expect_file "-f with no files: status" "1" <(printf '%s' "$status")

# Help and version
check "version"            0 $'tail (loup-cmd-tail) 0.1.0\n'    --version
"$BIN" --help > "$TMP/help"
if head -1 "$TMP/help" | grep -q '^Usage: tail \[OPTION\]... \[FILE\]...$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: help"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
