# 30 montag fast clip

- [x] Resolve title, stream URLs and User-Agent in one `yt-dlp --print` call with marker
      prefixes, parsed by one helper. Checked: 7 tests in `tests/montag.bats`, plus the
      sample video (2 urls) and `-f bestaudio` (1 url).
- [x] URL inputs: ffmpeg opens the stream URLs with `-user_agent`,
      `-request_size 1048576` and per input `-ss`/`-t`.
- [x] Delete the section machinery: `download-url`, `url_download_section`,
      `build-ytdlp-download-section`, `time-to-seconds`, `seconds-to-time`, the
      `/tmp/montag/dl_*` directory. Checked: `bash -n`, no leftover references.
- [x] Encoder flags per container: `-row-mt 1 -cpu-used 4` for webm,
      `-preset veryfast -crf 23` for mp4.
- [x] Update the help NOTES and drop the stale throttle comments.
- [x] Add `tests/montag.bats` for the resolver parser: two URLs, one URL, missing
      headers, no url, empty input.
- [x] Manual runs on the sample video: clip with speed (6.43 s out of 8 s), audio only
      (20.000 s), split (4 parts), plain copy (646 s, av1+opus), thumbnail generation,
      a local file clip, and a `--text` smoke test.
- [x] Final verification: `bash -n` OK, `bats tests/link-files.bats` 99 ok,
      `bats tests/link-known-issues.bats` 4 known failures, `bats tests/select.bats` ok,
      `bats tests/montag.bats` 7 ok. Timing, same clip on both scripts, same window:
      60 s clip at 1.25x, old 212 s, new 8 s, both 48.033 s out. The reported 9:50 clip
      at 1.25x: new 377 s as webm, 51 s as mp4.

Two fixes beyond the plan, both in code this change touched, both verified broken on
the pre-change script as well:

- a local input now gets `-i`; with `-t` or `-to` before a bare path ffmpeg read the
  path as the output file, so every local clip failed
- `--text` sets `output_target` to the temp file, otherwise ffmpeg wrote the real
  output and whisper read a temp file that was never written

Known, unchanged: `--thumb <image>` with a `.webm` output fails, ffmpeg cannot put a
webp stream in a webm container. Same exit code and same 264 byte file on the old
script.