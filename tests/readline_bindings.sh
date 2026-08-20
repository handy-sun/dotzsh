#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

generated="$tmpdir/common.sh"
bash "$repo_root/common.sh.in" stdout > "$generated"

binding_output="$(HOME="$tmpdir/home" GENERATED="$generated" \
    LC_ALL=C bash --noprofile --norc -ic '
        source "$GENERATED"
        bind -p
        bind -v
    ' 2>/dev/null)"

grep -Fq '"\C-w": backward-kill-word' <<< "$binding_output"
grep -Fq 'set bind-tty-special-chars off' <<< "$binding_output"

HOME="$tmpdir/home" GENERATED="$generated" CAPTURE="$tmpdir/readline.capture" \
    BASH_BIN="$(command -v bash)" \
    python3 - <<'PY'
import os
import pty
import select
import shlex
import time


def read_until(fd, marker, timeout=5):
    output = b""
    deadline = time.monotonic() + timeout
    while marker not in output and time.monotonic() < deadline:
        readable, _, _ = select.select([fd], [], [], deadline - time.monotonic())
        if readable:
            output += os.read(fd, 4096)
    if marker not in output:
        raise AssertionError(f"timed out waiting for {marker!r}: {output!r}")


def wait_capture(path, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(path):
            with open(path, encoding="utf-8") as capture:
                lines = capture.read().splitlines()
            if len(lines) >= 2:
                return lines
        time.sleep(0.01)
    raise AssertionError(f"timed out waiting for {path}")


generated = os.environ["GENERATED"]
capture = os.environ["CAPTURE"]
bash_bin = os.environ["BASH_BIN"]
pid, fd = pty.fork()
if pid == 0:
    os.execv(bash_bin, ["bash", "--noprofile", "--norc", "-i"])

try:
    read_until(fd, b"bash")
    init = (
        "stty werase '^W'; "
        f"source {shlex.quote(generated)}; "
        f"CAPTURE={shlex.quote(capture)}; "
        '_dotzsh_test_capture() { printf "%s\\n%s\\n" "$READLINE_LINE" '
        '"$READLINE_POINT" > "$CAPTURE"; }; '
        "bind -x '\"\\C-]\":_dotzsh_test_capture'; "
        "printf '__DOTZSH_READLINE_READY__\\n'\n"
    )
    os.write(fd, init.encode())
    read_until(fd, b"__DOTZSH_READLINE_READY__")

    os.write(fd, b"\x1d")
    wait_capture(capture)
    time.sleep(0.05)

    cases = {
        "foo/bar": "foo/",
        "foo-bar": "foo-",
        "foo.bar": "foo.",
        "foo:bar": "foo:",
        "foo=bar": "foo=",
        "foo/bar  ": "foo/",
        "foo/bar-baz_qux": "foo/bar-baz_",
    }
    for line, expected in cases.items():
        os.unlink(capture)
        os.write(fd, b"\x15" + line.encode() + b"\x17\x1d")
        actual, point = wait_capture(capture)
        assert actual == expected, (line, expected, actual)
        assert int(point) == len(expected), (line, expected, point)
        time.sleep(0.05)

finally:
    try:
        os.write(fd, b"\x15exit\n")
    except OSError:
        pass
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass
PY

noninteractive_stderr="$(
    HOME="$tmpdir/home" GENERATED="$generated" \
        bash --noprofile --norc -c 'source "$GENERATED"' 2>&1 >/dev/null
)"
[[ -z "$noninteractive_stderr" ]]
