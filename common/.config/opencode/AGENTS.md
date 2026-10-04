<!-- ZVEC_GREP_START -->
## zvec-grep

Choose the evidence source before the retrieval mode.

### Workspace evidence
- Use the current workspace as the evidence source when the user asks about local material, prior context establishes it as relevant, or the question concerns how the current project works—even if the workspace is not mentioned explicitly.
- A workspace may contain any mix of code, documents, configuration, and data.
- Do not use workspace retrieval for unrelated open-world questions, current external facts, or web content that does not depend on local evidence.

### Retrieval routing
- When an exact word, phrase, name, date, identifier, filename, path, configuration key, error message, source fragment, literal, or regex is known and locating its occurrences is sufficient, use `zvec_grep_zvec_grep_rg` when it is listed by the current host; otherwise native Grep or `rg`.
- Use `zvec_grep_zvec_grep_search` when wording or location is unknown, or when the answer requires semantic, conceptual, fuzzy, or paraphrase discovery; relationships, chronology, causality, architecture, or data or control flow; or comparison or synthesis across files, sections, or documents.
- For a mixed task with exact anchors that still requires relationships or cross-file synthesis, call `zvec_grep_zvec_grep_search` with the concept and anchors, then use `zvec_grep_zvec_grep_rg` when it is listed by the current host; otherwise native Grep or `rg` for focused follow-up.
- When no sufficient exact anchor is available and the user asks whether conceptually related material exists locally, make at most one focused `zvec_grep_zvec_grep_search` probe using the question plus distinctive names, dates, or terms. This probe does not apply to exact quotations, configuration keys, filenames, regexes, or exhaustive occurrence requests. Continue only when results are relevant; otherwise stop and report that the indexed workspace did not establish the answer.
- Before broad file reads or delegating workspace discovery, use the appropriate search route. Do not delegate solely to locate material, and stop when the evidence is sufficient.

### Search evidence
- Search results include bounded source snippets. Treat a sufficient snippet as already-read evidence, and read a cited file only when a required detail falls outside the snippet.

### Freshness and index lifecycle
- Pass a daemon-visible absolute `root` on every zvec-grep workspace call.
- Read `freshness` and `background_refresh` from search results without a status preflight.
- When results are `served_from_current_index`, use them when sufficient instead of waiting for the background refresh.
- If the index is missing but exact or regex lookup can answer the task, use `zvec_grep_zvec_grep_rg` when it is listed by the current host; otherwise native Grep or `rg`.
- Build a missing workspace index on your own when semantic or cross-file search is needed; no user request required. Pass `--embedding local/potion-multilingual-128m` (already cached) since no default model is configured. Skip building when exact or regex lookup can answer the task.
- Never drop or rebuild an existing index, and never widen file selection with `--no-ignore`, unless the user asks.

<!-- ZVEC_GREP_END -->

## Skills — load them proactively

When a request matches an available skill's description, load and follow that skill before doing
the work. Do not wait for the user to name it; an explicit skill mention is confirmation, not the
trigger. Check the available-skills list for every task — if two appear to match, load the closer
one, not both speculatively.

## Browser automation

The built-in `browser` tool namespace is attached to the OpenCode **desktop
app**. In a terminal session every call fails with `browser.disconnected` — do
not reach for it there. Use `playwright-cli` via the `playwright` skill:

- `playwright-cli open <url> --browser chromium`
- **Always pass `--browser chromium`** unless you know branded Google Chrome is
  installed. The default is the `chrome` channel at
  `/opt/google/chrome/chrome`, which many systems do not provide — NixOS among
  them — and the call then dies with
  `Chromium distribution 'chrome' is not found`. `--browser chromium` selects
  Playwright's own bundled build instead. Other channels: `firefox`, `webkit`,
  `msedge`.
- Headless by default. Pass `--headed` to watch it, e.g. when I need to sign in.
- `playwright-cli --help` — full command list; the skill covers the rest.
- `playwright-cli close-all` — shut every session down when done.

If the bundled build itself fails to launch with
`error while loading shared libraries`, that is a host packaging gap, not
something to work around: tell me which library is missing. On NixOS the fix
belongs in `programs.nix-ld.libraries` in `configuration.nix`, not in a
per-command `LD_LIBRARY_PATH` — mixing store paths from different closure
generations pulls in a mismatched glibc.

If a task genuinely needs the desktop app's browser, say so instead of working
around it silently.

## Login walls and bot checks

When a site blocks automation with a login wall, a bot check, a captcha, or a
2FA prompt, stop and ask me to pass it. I sign in or complete the check in the
browser (`playwright-cli open <url> --browser chromium --headed`), then tell you
to continue. Do not abandon the site or quietly substitute another method, such
as web search, for the same information. Wait for my go-ahead, then resume from
where the run stopped.

## Transcription (audio → text)

Use local whisper.cpp for any audio transcription; never upload audio to a cloud service.

- Runner: any local `whisper-cli` from whisper.cpp. It reads mp3, ogg, wav and
  flac directly. If it is not already on PATH, wrap it in whatever package
  manager the machine uses — e.g. `nix shell nixpkgs#whisper-cpp -c
  whisper-cli ...`, `brew install whisper-cpp`, or `apt install whisper-cpp`.
  Do not hardcode one package manager into the command.
- Model: `~/.cache/whisper.cpp/ggml-large-v3-turbo.bin` (best quality/speed tradeoff on CPU, good for Arabic). If missing, download from `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin`.
- Command: `whisper-cli -m <model> -f <audio> -l <lang> -t <cores> -otxt -osrt -of <output>`; e.g. `-l ar` for Arabic.
- Long recordings: run in the background and keep working; do not poll for completion.
- Ollama does not transcribe audio; it only post-processes text. Whisper is the STT tool.
