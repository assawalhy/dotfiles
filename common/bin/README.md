# bin

Scripts symlinked to `~/bin` on both platforms — see the root README for the
linking rules. This note records one non-obvious decision so it does not get
"simplified" back into a bug.

## Why downloads go through yt-dlp instead of ffmpeg

`ffmpeg` can read a URL directly (`ffmpeg -i https://…`) and do the download and
the processing in a single pass. `montag` used to work that way: `yt-dlp -g`
resolved the media URL, and `ffmpeg` fetched it. That is no longer viable —
**ffmpeg's HTTP reader is throttled by YouTube, yt-dlp's downloader is not.**

Same video, same network, same minute, 360p, bytes actually received:

| Method | Throughput |
|---|---|
| `ffmpeg -i <googlevideo-url>` (old montag path) | ~55 KB/s |
| `yt-dlp` native downloader (new path) | ~850 KB/s |

For a 54-minute lecture (~106 MB at 360p) that is the difference between ~32
minutes and a couple of minutes (128 s in a clean benchmark, 264 s end-to-end
through montag; the link varies). This was the real cause of slow downloads; the
eventual re-encode costs about 15× realtime (~3.5 min for that video), i.e.
secondary.

### Why the gap exists

- `yt-dlp` issues chunked/sectioned HTTP range requests and, for fragmented
  streams, reconnects per fragment. It never holds one long-lived connection
  long enough for the per-connection throttle to settle in.
- `ffmpeg` streams the URL as one continuous connection and simply inherits the
  throttle.
- It is **not** fixable from the ffmpeg side. `-multiple_requests 1`,
  `-http_persistent 1`, `-http_seekable 0`, a browser `User-Agent` and an
  explicit `Range: bytes=0-` header were each measured; none changed the rate.

So `ffmpeg` stays the processing tool (cut, speed, crop, mux, re-encode) and
`yt-dlp` becomes the downloading tool. That is the division of labour in
`montag`:

- **URL input** → `download-url` runs `yt-dlp` into `/tmp/montag/dl_*`, then
  `ffmpeg` reads the local file. The temp dir is registered in `temp_files` by
  the *caller*, because a `$(…)` command substitution runs in a subshell and any
  `temp_files+=` inside it would be lost.
- **A cut** (`--start`/`--duration`/`--to`) → `yt-dlp --download-sections
  "*start-end" --force-keyframes-at-cuts` fetches only that range, and `ffmpeg`
  must *not* re-apply `-ss`/`-t` (the downloaded section's timeline already
  starts at zero).
- **A full download with no filters or cuts** → `-c copy`, which skips the
  re-encode entirely.
- The default format selector is `-S res:720`. The old `-f best[height<=720]`
  matched nothing once YouTube dropped progressive (video+audio) formats.

### Codec caveat

`-c copy` keeps whatever codecs yt-dlp picked, and the default sort prefers
modern ones:

```
-S res:720                          -> av01 + opus
-S "res:360,ext:mp4:m4a"            -> av01 + aac
-S "res:360,vcodec:h264,acodec:m4a" -> avc1 + aac   (most compatible)
```

Use the last one when the file has to play everywhere; use the default when it
is for local playback and the download speed matters.
