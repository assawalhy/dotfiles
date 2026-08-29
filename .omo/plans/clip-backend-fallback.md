# Plan: bin/clip must fall back when its preferred backend is unreachable

## Problem

On WSL, copies via `bin/clip` (any script/tool: tmux, shell aliases, nvim)
silently fail to reach the Windows clipboard, while direct `xsel` works.

## Diagnosis (evidence)

The Wayland↔X11↔Windows sync chain itself is **healthy** in a fresh
environment:

| Test | Path | Result |
|---|---|---|
| A | `wl-copy` → `xsel` (via VcXsrv) | `WLONLY7` propagated ✅ |
| B | `xclip` → `wl-paste` | `XONLY8` propagated ✅ |
| C | `clip` (wl branch) → both backends | `CLIPVIACLIP` ✅ |

WSLg 1.0.65; weston.log shows normal RDP idle/wake cycling.

The real defect is in `bin/clip`'s backend selection:

```sh
elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
  exec wl-copy        # ← runtime failure here = dead end
```

1. `command -v` proves the **binary exists**, not that the compositor is
   **reachable**. In any stale shell/tmux server opened before today's
   os.sh symlink guard, `$WAYLAND_DISPLAY=wayland-0` is set but
   `$XDG_RUNTIME_DIR/wayland-0` does not exist → wl-copy fails *after*
   `exec` replaced the process → exit non-zero, xclip/xsel never tried.
2. Callers ignore stderr/exit codes → silent data loss.

## Change (single file)

`common/bin/clip` — keep interface byte-compatible:
no args = copy stdin→CLIPBOARD; `-o` paste; `-p` primary; `-op/-po`; unknown
option exits 2. Backend priority unchanged: pbcopy → wayland → xclip → xsel.

New semantics:

1. **Socket-aware wayland candidacy**: only prefer wayland when
   `WAYLAND_DISPLAY` is set AND binaries exist AND the socket exists —
   handle absolute-path `WAYLAND_DISPLAY`, else check
   `${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$WAYLAND_DISPLAY`.
2. **Runtime fallback**: attempt each candidate and check its exit code;
   on failure try the next. No bare `exec` on the Linux paths.
3. **Copy path buffers stdin once** to an mktemp file first (command
   substitution would strip trailing newlines); each backend reads `<"$tmp"`.
4. Paste path: first backend that exits 0 prints to stdout and wins.
5. Final failure keeps current message + exit 1.

### Reference implementation shape

```sh
xdg="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
case "${WAYLAND_DISPLAY-}" in
  /*) wsock="$WAYLAND_DISPLAY" ;;
  '') wsock='' ;;
  *) wsock="$xdg/$WAYLAND_DISPLAY" ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }
wl_ok() { [ -n "$wsock" ] && [ -S "$wsock" ] && have wl-copy && have wl-paste; }

if [ "$out" = 1 ]; then
  if wl_ok; then
    if [ "$sel" = primary ]; then wl-paste --primary --no-newline && exit 0
    else wl-paste --no-newline && exit 0; fi
  fi
  if [ -n "${DISPLAY-}" ]; then
    if have xclip && xclip -selection "$sel" -o && exit 0; then :; fi
    if have xsel && xsel -o --"$sel" && exit 0; then :; fi
  fi
else
  tmp=$(mktemp "${TMPDIR:-/tmp}/clip.XXXXXX") || exit 1
  cat >"$tmp"
  ok=1
  if have pbcopy; then
    pbcopy <"$tmp" && ok=0          # macOS: -p degrades to clipboard
  elif wl_ok; then
    if [ "$sel" = primary ]; then wl-copy --primary <"$tmp" && ok=0
    else wl-copy <"$tmp" && ok=0; fi
  fi
  if [ "$ok" -ne 0 ] && [ -n "${DISPLAY-}" ]; then
    if have xclip && xclip -selection "$sel" -i <"$tmp"; then ok=0
    elif have xsel && xsel -i --"$sel" <"$tmp"; then ok=0
    fi
  fi
  rm -f "$tmp"
  [ "$ok" -eq 0 ] || { echo 'clip: no working clipboard tool (pbcopy/wl-copy/xclip/xsel)' >&2; exit 1; }
fi
```

Executor may refine details but must preserve: interface, backend order,
byte-exact stdin handling, fallback-on-failure.

## Verification battery (executor runs all, reports raw output)

Wrap read commands in `timeout 5`: clipboard tools fork selection-owner
processes that hold pipes open.

```sh
sh -n common/bin/clip                                   # syntax

# T1 fresh roundtrip
printf 'CLIPRT9' | ./clip && timeout 5 ./clip -o        # expect CLIPRT9

# T2 THE REGRESSION TEST: simulated stale env (socket missing) -> X11 fallback
mkdir -p /tmp/opencode/fakexr
printf 'FALLBACK7' | env XDG_RUNTIME_DIR=/tmp/opencode/fakexr ./clip; echo "exit=$?"
env XDG_RUNTIME_DIR=/tmp/opencode/fakexr timeout 5 ./clip -o   # expect FALLBACK7
timeout 5 xsel -o -b                                           # expect FALLBACK7

# T3 paste direction under broken wayland env
printf 'PASTEFB5' | ./clip
env XDG_RUNTIME_DIR=/tmp/opencode/fakexr timeout 5 ./clip -o   # expect PASTEFB5

rm -rf /tmp/opencode/fakexr
```

Expected: every step succeeds; before this change T2/T3 fail with
exit=1 / empty output.

## User remediation after apply

Old processes carry the broken environment: restart tmux server
(`tmux kill-server`), reopen shells, restart nvim.
