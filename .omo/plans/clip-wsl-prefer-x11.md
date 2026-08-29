# Plan: clip should prefer the X11 backend under WSL (Win+V history parity)

## Problem

After the fallback rework, all copies reach the Windows clipboard and paste
fine — but copies routed through the **Wayland/WSLg backend never appear in
the Windows clipboard history (Win+V)**, while copies made via
`xsel`/`xclip` do.

## Cause

| Backend | Route into Windows | Paste works | Win+V history |
|---|---|---|---|
| xclip/xsel (DISPLAY→VcXsrv) | VcXsrv runs on Windows and calls the Win32 clipboard API directly | ✅ | ✅ recorded |
| wl-copy (WSLg Weston) | RDP clipboard channel of WSLg | ✅ | ❌ skipped — Windows ignores clipboard updates arriving over RDP for history |

Empirical confirmation from the user: same machine, same content — xclip/xsel
copies show in Win+V, clip (wl branch) copies don't.

## Change

`common/bin/clip` — one addition, no interface changes:

When **both** `WSL_DISTRO_NAME` and `DISPLAY` are non-empty, try the X11
backends (xclip → xsel) **before** the Wayland backend, keeping the existing
runtime-fallthrough in both directions:

```sh
prefer_x11=0
if [ -n "${WSL_DISTRO_NAME-}" ] && [ -n "${DISPLAY-}" ]; then
  prefer_x11=1    # VcXsrv route: its Windows-side owner feeds Win+V history;
fi                # WSLg/RDP route pastes fine but history skips it
```

Copy section becomes: `pbcopy` (unchanged) → if `prefer_x11`: x11 chain then
wayland; else: wayland then x11 chain (existing fallback logic reused).
Paste section mirrors the same preference.

Native Linux desktops and macOS are untouched: the flag requires the WSL
env var, so backend order there stays exactly as today.

## Verification battery

Wrap reads in `timeout 5` (forked selection owners hold pipes).

```sh
sh -n common/bin/clip

# T1 fresh roundtrip unchanged
printf 'CLIPRT9' | ./common/bin/clip && timeout 5 ./common/bin/clip -o   # CLIPRT9

# T2 backend selection: under WSL env the trace must show xclip/xsel, NOT wl-copy
printf 'SELPROBE1' | sh -x ./common/bin/clip 2>&1 | grep -m1 -E 'wl-copy|xclip|xsel'
# expect a line containing xclip or xsel; must NOT match wl-copy

# T3 broken-wayland fallback still intact
mkdir -p /tmp/opencode/fakexr
printf 'FALLBACK7' | env XDG_RUNTIME_DIR=/tmp/opencode/fakexr ./common/bin/clip; echo "exit=$?"  # exit=0
env XDG_RUNTIME_DIR=/tmp/opencode/fakexr timeout 5 ./common/bin/clip -o                          # FALLBACK7
rm -rf /tmp/opencode/fakexr

# T4 non-WSL order preserved (simulate bare Linux): wayland still preferred
printf 'ORDERCHK' | env -u WSL_DISTRO_NAME sh -x ./common/bin/clip 2>&1 | grep -m1 -E 'wl-copy|xclip|xsel'
# expect wl-copy line (socket exists in real env)
```

Final human check (only the user can do it): copy anything via `clip`,
press Win+V on Windows — the entry must be listed.

## Notes

- nvim's `vim.g.clipboard` routes through `clip`, so `;y` gains history
  visibility automatically; tmux/shell aliases likewise.
