# 32 montag language flag

- [x] `-l`/`--language` in `collect-arg-and-validate`, `is-language-code` with the
      D7 regex, help row and one example. Checked: `bash -n`, `montag -h` box still
      aligned, `montag --language english` exits 2.
- [x] `build-language-format` and `list-language-codes` as top-level functions
      ending in a bare `}`.
- [x] `prepare-input-and-output`: conflict errors for `--ytdl -f`, `--ydi` and a
      local input, `-f` injection for the language case, and the resolve failure
      message that names the language and lists the codes.
- [x] `tests/montag.bats`: video selector, audio selector, a region code, the
      resolution variable, validator accept and reject cases including
      `ar][ext=mkv`, and two offline CLI tests for the conflict errors.
- [x] `AGENTS.md`: montag.bats expected count.
- [x] Final verification: `bash -n`, `bats tests/montag.bats`, a dry run of
      `montag -i <url> --language ar -s .. -d ..` up to the prompt, and a real 15 s
      clip checked with `ffprobe` for an `ar` audio stream.

## Notes from execution

Three of the six items needed a second pass, all found by the checks in the item:

- The `-f` conflict test was first written as a `case` with two alternatives,
  `*" -f "*|*" -f)`. The second alternative has one unbalanced quote and bash
  fails to parse the whole file, so the check became a `[[ =~ ]]` match on
  `(^|[[:space:]])-f`, which is also what yt-dlp sees.
- `assert_resolve` in the bats file lost its `done )` to a rewrite of the
  adjacent lines, which broke all 7 pre-existing resolver tests. Restored.
- `montag --yes` after the output name exits 2: the positional output must come
  last. Unrelated to this change, same before and after.

## Verified

- `bats tests/montag.bats` 16 ok, 0 not ok. The 7 resolver tests are unchanged.
- 15 s clip at 00:10:00 with `--language ar`, 10.8 s wall, 15.048 s out, h264 plus
  aac, 1280x720.
- The audio of that clip and the same window with `--language en-US` have
  different md5, so the flag picks a different track rather than silently
  returning the original.
- `--language zz` fails and prints `this video offers: ar bn de-DE en-US es-US
  fr-FR hi id it iw ja ko ml nl-NL pl pt-BR ru uk`.
- `--ytdl "--no-warnings"` with `--language ar` composes, the two-input ffmpeg
  command is the same as without the extra option.

Not covered by the run: the `bv*[height<=720]+ba[language=X]` fallback alternative
never fired on the sample video, since it has an h264 stream and an m4a track for
every language it carries. The selector strings are unit tested, the fallback
branch is not exercised against a live site.

Known: the output container carries no language tag. ffmpeg writes
`TAG:language=und` for the audio stream in an mp4 output. montag does not pass
`-metadata:s:a:0 language=`, so a player cannot tell the track apart from the
original by looking at the file. Not changed here: an mp4 language tag takes a
two letter code, so `--language en-US` and `--language pt-BR` would need a
mapping table first.
