# Epic 17 — Playwright browser automation (replace the desktop-only `browser` tool)

## Goal

Give the agent working browser automation from the terminal, where the built-in
`browser` Code Mode namespace is dead, without changing how the desktop app
behaves.

## Findings (researched, not assumed)

1. **The built-in `browser` namespace is desktop-app-backed.** The tools guide:
   "The `browser` Code Mode namespace controls the browser attached by the
   OpenCode desktop app." Its failure in the terminal is by design, not a bug.

2. **It can be removed with a permission rule.** "A `browser` deny rule with
   resource `*` removes the browser catalog; browser operations do not issue
   individual permission prompts." So
   `{ "action": "browser", "resource": "*", "effect": "deny" }`.

3. **"Terminal only, desktop untouched" is NOT achievable by config.**
   Permissions resolve as lower-priority config → global config → agent rules.
   There is no client/frontend dimension. `cli.json` holds terminal-only
   *preferences* (themes, keybinds, sessions, tabs, plugins, debugging);
   `permissions` is server config and is not part of `cli.json`. A deny rule is
   therefore global and also removes the namespace in the desktop app.

4. **Playwright's own maintainers argue against MCP for coding agents.** Both
   `playwright-mcp` and `playwright-cli` READMEs say: "If you are using a
   **coding agent**, you might benefit from using the **CLI+SKILLS** instead…
   CLI invocations are more token-efficient: they avoid loading large tool
   schemas and verbose accessibility trees into the model context."

5. **The prerequisites are already met.**
   - Node `v24.21.0` (needs 18+)
   - Chromium already cached: `~/.cache/ms-playwright` has `chromium-1234`,
     `chromium-1243`, both `chromium_headless_shell-*`, and `ffmpeg-1011`
   - `npx playwright --version` → `1.63.0`
   - The opencode **service** has `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0`,
     `XDG_RUNTIME_DIR=/run/user/1000` — so a Playwright child process can open
     a real visible browser on the Wayland session from the terminal.

6. **The repo already has both mechanisms this needs.**
   - `agents-skill|<id>|<desc>|<git-url>@<folder>` git-clones a skill into
     `~/.agents/skills/<id>`. opencode does read that directory (7 of the 8
     catalog entries are installed there and all 7 appear in the session skill
     list; `teach` is missing from both because it is not installed).
   - `microsoft/playwright-cli` ships `skills/playwright-cli/SKILL.md` plus 10
     `references/*.md` — exactly the `<git-url>@<folder>` shape.
   - `agent-tool|<id>|<desc>|setup/agent-tools.sh install <tool>` + an
     `npm install -g` bin installer already exists as `zvec_grep_bin_install`,
     including the NixOS read-only-prefix workaround.

## Approach

Recommended route — CLI + skill, wired through the existing catalog:

```
setup/agent-skills.list     + agent-tool|playwright-cli   → npm i -g @playwright/cli
                           + agents-skill|playwright      → clone @skills/playwright-cli
setup/agent-tools.sh       + playwright_cli_bin_install / _status / dispatch / usage
~/.config/opencode/AGENTS.md  + one steering section
```

The skill lands in `~/.agents/skills/playwright/`, so the agent uses `shell`
against purpose-built `playwright-cli` commands. No MCP tool schemas are added
at all.

## Decisions

- **Playwright CLI + skill, not `@playwright/mcp`** — *(confirmed)* upstream
  recommendation for coding agents (finding 4). MCP would add ~30 permanently
  loaded tool schemas plus verbose accessibility-tree output to a session whose
  input ceiling is 512k, on the same machine where context cost is already a
  concern.
- **Steer via `~/.config/opencode/AGENTS.md`, no global deny** — *(confirmed)*
  keeps the desktop app exactly as it is (finding 3 makes a scoped deny
  impossible). Cost: the model may occasionally try `browser` first and waste
  one turn on the `browser.disconnected` error before falling back.
- **Catalog git-clone over `playwright-cli install --skills`** — the catalog is
  this repo's own mechanism and does not depend on where that installer chooses
  to write for each harness.
- **V2 config shapes** — if the MCP route is chosen instead, the entry must be
  `mcp.servers.<name>` with `disabled`, not `enabled`. Note the existing
  `zvec_grep` entry in `opencode.json` is V1-shaped (server directly under
  `mcp`, `enabled: true`) and still resolves, so it is left alone.
- **`browser` left un-denied for now** — escalate to the deny rule only if the
  steering line proves insufficient.

## Risks

- **Chromium build mismatch.** `@playwright/cli@latest` may pin a Playwright
  version other than the cached `1.63.0` and want a Chromium build that is not
  in `~/.cache/ms-playwright`. Mitigation is `playwright-cli install` (or
  `npx playwright install chromium`) — a verification step, not an assumption.
- **`npm -g` on NixOS** has a read-only prefix; the existing
  `zvec_grep_bin_install` pattern redirects to `npm_config_prefix=$HOME/.local`
  and is reused here.
- **The steering line is not repo-managed.** `~/.config/opencode/AGENTS.md` is a
  hand-maintained local file, so this instruction will not survive a fresh
  machine.
- **Headed mode is not guaranteed to keep working** if the background service is
  ever restarted from a non-graphical context and loses `DISPLAY` /
  `WAYLAND_DISPLAY`. Headless remains available as the fallback.
- **`playwright-cli` is headless by default**; `open --headed` is needed to
  watch it. Easy to forget and confusing when a screenshot "just works" with no
  window visible.

## Out of scope (flagged, not fixed)

- **`jq` is required by `setup/agent-tools.sh:56` but absent from
  `setup/packages.list`** — on a machine bootstrapped from this repo, the
  `context7` and `zvec_grep` MCP entries silently no-op. Also epic 16.
- **opencode reads `~/.config/opencode/AGENTS.md`, not `~/.agents/AGENTS.md`**,
  which is the file `link-files` wires to `common/.agents/AGENTS.md`. So the
  repo-managed global agent instructions are invisible to opencode.
