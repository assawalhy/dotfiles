# 32 montag language flag

## Goal

`montag` gets a `--language` flag so a dubbed audio track can be picked without
hand-writing a yt-dlp format selector.

Today the only way is `--ytdl`, which takes over format selection entirely and has
to spell out the container filters:

```
montag -i <url> --ytdl "-f bv*[height<=720][ext=mp4][vcodec^=avc1]+ba[language=ar][ext=m4a]/bv*[height<=720]+ba[language=ar]"
```

Target:

```
montag -i <url> --language ar
```

## What was verified on the sample video (Lecture 3: GFS, 4942 s)

| selector | resolves to |
|---|---|
| `ba[lang=ar]` | error, `lang` is not a yt-dlp field name |
| `ba[language=ar]` | `251-6` |
| `-f bv*[height<=720][ext=mp4][vcodec^=avc1]+ba[language=ar][ext=m4a]` | `136+140-0` (720p avc1, ar 129 kbps) |
| the same with a `/bv*[height<=720]+ba[language=ar]` fallback | still `136+140-0` |
| `bestaudio[language=ar][abr<=128k]` | `251-6`, the same track the default selector picks for en-US |
| any selector with `language=zz` | error, no such track |

Language codes on this video: ar bn de-DE en-US es-US fr-FR hi id it iw ja ko ml
nl-NL pl pt-BR ru uk.

## Approach

```
montag -i <url> --language ar -s 00:10:00 -d 300 lecture3-ar.mp4
  |  collect-arg-and-validate: -l/--language <code>, is-language-code check
  |  prepare-input-and-output: ytdl_options+=(-f <selector>)
  |  resolve-url-input: yt-dlp resolves, ffmpeg cuts and encodes as before
```

The flag only builds the `-f` value. Every other path, the resolver call, the
ffmpeg inputs and the encoder branches, stay as they are.

## Decisions

- D1 `--language` builds the yt-dlp `-f` selector itself. Rejected: a post-download
  or ffmpeg-side language switch, there is no second audio stream to switch to
  once ffmpeg has the URLs.
- D2 Video selector is `bv*[height<=720][ext=mp4][vcodec^=avc1]+ba[language=X][ext=m4a]`
  with a `bv*[height<=720]+ba[language=X]` fallback. h264 plus m4a is what montag
  re-encodes fastest (plan 30, D5 and D7), and the audio container has to match
  the output container. Rejected: `bv*+ba[language=X]` alone, it resolves AV1 plus
  opus, the container becomes webm, and the clip then goes through the slow vp9
  encode. Rejected: falling back to the original language, a silent English clip
  for `--language ar` is the wrong result.
- D3 Audio-only and `--text` selector is `bestaudio[language=X][abr<=128k]`, the
  existing audio selector plus the language filter. ffmpeg writes mp3 for both, so
  the input container does not matter.
- D4 The resolution cap reuses the `-S res:720` default as a `default_resolution`
  variable, so the two selectors cannot drift apart.
- D5 `--language` together with `--ytdl` that carries its own `-f`, or with
  `--ydi`, exits 2: both own format selection and the later `-f` would silently
  win. `--ytdl` without `-f` (cookies, rate limit, username) composes fine.
- D6 `--language` with a local file exits 2, there is no format selection to apply.
- D7 A language code is `^[A-Za-z]{2,3}(-[A-Za-z]{2,4})?$`, checked before anything
  else runs. The code goes into an unquoted yt-dlp argument, so `ar][ext=mkv` has
  to be rejected before it can inject filter syntax.
- D8 When the resolve fails under `--language`, the error names the language and
  lists the codes the video offers, taken from `yt-dlp -F` on that failure path
  only. Rejected: a `--list-languages` flag, it costs a network call on every run
  to answer a question that only arises on failure, and its name does not fit the
  13 column help box without widening every row.
- D9 No change to the existing default when `--language` is absent, including
  `--ytdl`, which still overrides everything.

## Milestones

1. `-l`/`--language` in `collect-arg-and-validate`, `is-language-code`, help row
   and one example.
2. `build-language-format` and `list-language-codes`, both top-level with a bare
   `}` so the bats extractor can reach them.
3. Wire into `prepare-input-and-output`: the two conflict errors, the `-f` value,
   and the enriched resolve failure message.
4. `tests/montag.bats`: selector strings, the validator including the injection
   case, and two offline CLI tests for the conflict errors.
5. `AGENTS.md` montag.bats expected count.

## Risks

- `-f` is passed as its own array element and yt-dlp splits the string itself.
  Verified working for the whole selector, including the `/` fallback.
- The language filter sees a site specific language code. `--language ar` may be
  `ar-001` on another site, and the validator accepts that shape.
- The sample video is the only one tested. A site with no language tagged audio at
  all takes the resolve failure path and now prints an extra line.
- `common/bin/README.md` documents montag's pre plan 30 path (the temp dir, the
  two encodes, `-c copy` reasoning). It is stale and not part of this change.
