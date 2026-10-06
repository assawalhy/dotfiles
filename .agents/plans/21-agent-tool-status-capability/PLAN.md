# PLAN — agent-tools status must not be blocked by a pi that can't take packages

## Goal
`setup/agent-tools.sh status <tool>` returns a real answer on this machine. Today
`status plannotator` prints nothing even though plannotator is fully installed
(binary + opencode plugin + claude plugin), because the status gate demands the
pi leg too — and the `pi` on PATH is the Go port, which has no package/extension
runtime at all, so that leg can never pass.

## Findings (researched on this machine)

1. **The silence is by contract, not a crash.** `status` exits 0 and prints the
   marker only when the tool is wired in *every harness present*
   (`agent-tools.sh:8-10`, dispatch `status:*` branches). No output = "not
   fully installed". Confirmed by `bash -x`: the run reaches `plannotator_status`,
   and the only leg that zeroes the accumulator is `pi`.

2. **plannotator itself is fully installed.** `~/.local/bin/plannotator`
   (0.28.4), `plugins: ["@plannotator/opencode@latest"]` in opencode.json, and
   `plannotator@plannotator` in `~/.claude/plugins/installed_plugins.json`.
   Dropping the pi leg makes status print
   `/home/assawalhy/.agents/tools/plannotator` today, no install needed.

3. **The pi leg can never pass here.** `pi` is `~/go/bin/pi` =
   `github.com/sky-valley/pi` (a pure-Go port, `packages.list:101`
   `go:github.com/sky-valley/pi/cmd/pi`). Its CLI has no `install`, no
   `list`, no `config` — only print mode / REPL / `models` / `sessions`, and
   `pi install …` exits 1 with `no API key found for provider "anthropic"`.
   Upstream `earendil-works/pi` documents `pi install npm:@plannotator/pi-extension`
   as *the* install path, and the port's own UPSTREAM.md lists the extensions
   runtime as unported. So `~/.pi/agent/npm/node_modules/@plannotator/pi-extension`
   is unreachable, permanently, with this pi.

4. **`harness_present pi` is the wrong gate.** It is true (the `~/.pi/agent`
   dir exists) but says nothing about whether pi can host a *package*. The Go
   port does load skills (`LoadSkills` reads `~/.pi/agent/skills` and
   `~/.agents/skills`), so the skill-shaped pi legs are fine — only the
   package-shaped ones are impossible.

5. **Install is silently broken the same way, and hides it.**
   `plannotator_pi_install` runs `pi install … 2>/dev/null`; the command fails,
   stderr is discarded, `run_harness` returns 0, and `plannotator_install`
   propagates only `plannotator_bin_install`'s status — so the catalog reports
   a clean install while the pi leg never happened. `context7_pi_install` has
   the identical defect (and `context7 status` is also empty for a second,
   separate reason: its opencode MCP entry is missing — see Risks).

6. **The same class of bug is in the catalog.** `agent-skills.list:47`
   `pi-package|tmustier-pi-extensions` installs with `pi install git:…` — an
   impossible command on this machine — and `agent-skills.sh:66-68` has a
   `pi-package/plannotator` status branch for a catalog id that no longer
   exists (dead code). `--list` shows item 12 as permanently `[ ]`.

7. Cosmetic, in the same function: the accumulator in `plannotator_status` is
   named `klaus` (copy-paste leftover), and `harness_status_print`
   (`agent-tools.sh:47`) is defined but never called.

## Approach

```
setup/agent-tools.sh
├── pi_supports_packages()          NEW  capability probe
│     pi --help | grep -q 'pi install'
│     (upstream pi lists it; the Go port's help does not)
├── plannotator_pi_install/status    gate on pi_supports_packages, else
│                                    print a "- pi: no package support, skipped"
├── context7_pi_install/status       same gate
└── plannotator_status               rename klaus -> ok; drop dead helper

setup/agent-skills.list
└── tmustier entry                   keep, but the install field notes the
                                     pi requirement (or drop — see D4)
```

The probe is capability-based (does this pi advertise `install`?), not
identity-based (`is it the Go port?`) — so it stays correct if upstream pi
grows or the port gains the runtime.

## Decisions

- **D1 Gate the pi legs on a capability probe, not on harness presence.**
  `harness_present` answers "is this harness installed"; a second probe answers
  "can it host a package". Rejected: dropping pi from the catalog entirely —
  loses the integration on machines with upstream pi, where it works.
  Rejected: treating a failed `pi install` as non-fatal but still gating status
  on it — that is exactly today's bug.
- **D2 Keep the all-or-nothing status contract** (marker only when every
  *capable* harness is wired). Rejected: "print the marker if any leg passes" —
  it would report a half-installed tool as installed, which is worse than
  silence because the catalog then skips it forever.
- **D3 Status keeps its stdout contract; diagnostics go to stderr.** The
  catalog (`agent-skills.sh:81`) captures stdout with `2>/dev/null`, so
  per-harness `ok` / `missing` lines on stderr are free and turn the next
  occurrence of this bug into a one-line answer. Rejected: a `--verbose`
  flag — an extra contract for a script whose stdout is already
  machine-consumed.
- **D4 `pi-package|tmustier-pi-extensions`: leave the entry, document the
  requirement.** Removing it is a scope call the user owns (it may be wanted
  on a machine with upstream pi). Flagged in the approval ask.
- **D5 Fix install's silence at the same time as status.** A pi leg that cannot
  run must say so, or the catalog keeps reporting installs that never happened.
- **D6 No bats suite.** `tests/` covers `link-files.bash` and the select parser;
  `agent-tools.sh` has no harness and adding one (fake `$HOME`, stub `pi` on
  `PATH`) is a separate piece of work. Verification here is `bash -n` plus live
  `status` runs before/after. Flagged as follow-up.

## Milestones

1. `pi_supports_packages` probe + gates on plannotator and context7 pi legs.
2. `plannotator_status` accumulator renamed; dead `harness_status_print` removed.
3. stderr per-harness diagnostics on the status path.
4. Live verify: `status plannotator` prints the marker; `install plannotator`
   reports the pi skip instead of silence; `bash -n` clean; link-files suite
   still green.

## Risks

- **context7 will still report empty after this.** Its opencode leg is
  genuinely missing (no `context7` key in opencode.json's `mcp` object) and its
  pi leg is the Go-port wall. That's a second, independent gap — out of scope
  here, but it means `status context7` staying silent is *not* this bug's
  residue. Say the word if you want it in the same change.
- **Switching pi to upstream Node pi** would make every pi leg installable, but
  it is a `packages.list` change with a Node 22+ requirement, not a status fix.
  Named, not taken.
- `~/.claude/plugins/marketplaces/backnotprop-plannotator..clone` is a broken
  clone (`.git` only, no checkout). `claude plugin list` still reports the
  plugin installed and enabled, so the status leg is correct; cleaning that
  directory is separate.