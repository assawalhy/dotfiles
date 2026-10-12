# 30 montag fast clip

## Goal

`montag` on a URL should fetch only the requested clip and encode it once. Today the
clip is encoded twice and the fetch runs at a fifth of the line speed.

Sample run: 10:46 video, clip 0 to 9:50, 1.25x, 12 thread i7-10850H, line about 340 KB/s.

| step | today | after |
|---|---|---|
| section fetch | ffmpeg reader at 67 KB/s | same reader, 619 KB/s, one flag |
| encode 1 | yt-dlp re-encode, av1 to vp9, 0.745x in the log | dropped |
| encode 2 | montag filter pass, same speed | one pass: vp9 row-mt about 1.4x, x264 about 10x |
| total for 9:50 | about 26 min (two encodes) | about 7 min (webm) or about 2 min (mp4) |

Measured after the change, 12 thread i7-10850H, one clip, same window for both scripts:

| run | wall | output |
|---|---|---|
| old, 60 s clip at 1.25x | 212 s | 48.033 s |
| new, 60 s clip at 1.25x | 8 s | 48.033 s |
| new, 9:50 clip at 1.25x, webm | 377 s | 472.033 s |
| new, 9:50 clip at 1.25x, mp4 | 51 s | 472.033 s |

The old cost scales with clip length (two encodes at 0.5x to 0.75x realtime), so the
9:50 clip was around 25 to 35 min.

## Why it is slow today

1. `--download-sections` never uses yt-dlp's own downloader. yt-dlp returns FFmpegFD
   whenever a section is requested (`downloader/__init__.py:89`), so the URL still goes
   to ffmpeg. The range header idea did not take effect.
2. montag passes `--force-keyframes-at-cuts`, so yt-dlp drops `-c copy`
   (`downloader/external.py:513`) and the section download re-encodes as well.
3. montag then runs a second ffmpeg for the speed filter. Two full encodes per clip.
4. ffmpeg's HTTP reader is 5x slower than the line: 67 KB/s against 345 KB/s for curl
   on the same URL, back to back. `-request_size 1048576` fixes it: 619 KB/s.
5. The "yt-dlp is about 15 times faster" comment is stale. yt-dlp native 140 KB/s,
   chunked 138 KB/s, ffmpeg 67 KB/s, curl 345 KB/s. yt-dlp was line bound, not
   tool bound, and the line is faster than all of them were.

## Approach

Hand the stream URLs to montag's own ffmpeg. It range reads the clip, cuts precisely and
applies every filter in one pass. yt-dlp only resolves the URL, the title and the
User-Agent.

```
today:  yt-dlp --download-sections --force-keyframes-at-cuts  (ffmpeg reads and encodes)
          |  ffmpeg -i temp.webm -vf setpts ...                 (encodes again)

after:  yt-dlp --print urls, title, http headers                (no media)
          |  ffmpeg -request_size 1M -user_agent UA
                    -ss 9:42 -t 0:08 -i vURL -ss 9:42 -t 0:08 -i aURL
                    -vf setpts=PTS/1.25 -af atempo=1.25 out
```

## Decisions

- D1 Direct URL inputs to ffmpeg, yt-dlp only resolves. Rejected: keeping yt-dlp as
  the downloader (5x slower reader, forces one extra encode, two encode paths).
- D2 Pass `-user_agent` taken from yt-dlp's `http_headers`. ffmpeg without a UA gets
  403 from YouTube; a hardcoded UA is a stale guess.
- D3 Add `-request_size 1048576` for URL inputs: 67 KB/s becomes 619 KB/s.
- D4 Cut with input `-ss`/`-t` plus a re-encode, never `-c copy`, when a range is
  requested. A copy cut starts at the previous keyframe: measured 536.97 s for a
  540 s request, 3 s of extra head.
- D5 Encoder flags: vp9 gets `-row-mt 1 -cpu-used 4` (2.3x), mp4 keeps x264 and gets
  `-preset veryfast` (10x). Cost: slightly lower quality per bitrate, larger files.
- D6 Delete the section machinery (`download-url`, `url_download_section`,
  `build-ytdlp-download-section`, `time-to-seconds`, `seconds-to-time`, the dl_ temp
  dir). One path. Rejected: keeping it as a fallback, dead and untested code.
- D7 Output container rule unchanged: the extension picks the codec. An mp4 output is
  the fast option, the user opts in by naming one.

## Milestones

1. One yt-dlp call resolves title, URLs and headers, parsed by one helper.
2. ffmpeg reads URL inputs directly with `-user_agent`, `-request_size` and the cut args.
3. Section code and the transient download dir removed, help text and stale comments fixed.
4. Encoder flags per output container.
5. Checks: `bash -n`, the bats suites, and manual runs for clip with speed, audio only,
  split, plain copy, and a local file.

## Risks

- Formats ffmpeg cannot read on its own (m3u8 or dash manifests, private videos that
  need cookies). yt-dlp downloads those today; this plan drops that path on purpose
  and adds a fallback only if a real site breaks.
- Header extraction has to fall back for single format selections, where
  `requested_formats` does not exist.
- `-request_size` is measured on YouTube only.
- The i7 has 12 threads but vp9 without `-row-mt` is single thread bound, which is why
  the old default ran at 0.6x realtime while x264 reaches 10x.
