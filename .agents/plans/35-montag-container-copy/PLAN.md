# 35 montag container aware stream copy

## Goal

`montag -i in.webm out.mp4` with no cut and no filter must not choose `-c copy`. The mp4 muxer has no tag for vp8, so the copy dies at the header write. The copy must be taken only when the input codecs fit the output container.

## Research

The failed run: `~/Videos/Screencasts/Screencast From 2026-10-15 17-02-01.webm`, `ffprobe` reports one stream, `vp8`, no audio. `common/bin/montag:539` takes the copy branch on "no filters and no cuts" alone. It never looks at the codecs or at the output container, so a container change between the input and the output is not part of the decision.

Codec tables measured on this machine, ffmpeg 8.1.2, each source remuxed with `-c copy` from a matroska file:

| codec | mp4 | webm |
|---|---|---|
| h264, hevc, mpeg4, mjpeg | yes | no |
| vp8 | no | yes |
| vp9, av1 | yes | yes |
| aac, mp3, ac3, flac | yes | no |
| opus, vorbis | yes | yes |

mp4 accepts vp9, so a rule of the form "webm codecs never go to mp4" would be wrong.

## Approach

Three top level functions next to `is-language-code` and `build-language-format`, and one more condition on the copy branch. A copy that no longer applies falls through to the re encode branch that already exists, which picks `libx264` for mp4 and `libvpx-vp9` for webm. No new encoder settings.

```
build-ffmpeg-command
  |
  +-- no cuts, no filters, no mute ... (today's condition)
  |
  +-- can-stream-copy ?  --ffprobe--> input-codecs  --> container-allows-codec
  |         |
  |        yes -> cmd+=(-c copy)
  |         no -> falls through to the re encode branch (x264 / vp9)
```

## Decisions

- ffprobe the inputs rather than match extensions: extensions lie, a `.mkv` can hold h264, and a url input has no extension at all. Rejected: extension family matching, because mkv with h264 into mp4 is a legal copy that the rule would turn into a full re encode. Rejected: a hardcoded webm into mp4 special case, because it misses the audio cases and the reverse direction.
- Police mp4, mov, m4v and webm only. Every other container keeps today's copy behaviour, so no unrelated workflow changes.
- Call `can-stream-copy` as the last condition of the copy branch. A clip, a speed change, a mute or a gif never probes.
- Probe every input ffmpeg will read, both stream urls of a merged url input included, because each stream has to fit and a webm carries vp8 plus opus.
- Pass `-user_agent` to the probe for a url input, the same argument ffmpeg reads those urls with.
- A missing or failing ffprobe prints nothing and the copy proceeds as today. A visible ffmpeg error is better than a silent re encode of a long video.
- Test the table directly and the gate with `ffprobe` stubbed as a shell function, so `tests/montag.bats` stays free of ffmpeg and network.

## Milestones

1. `container-allows-codec`, `input-codecs` and `can-stream-copy` in `common/bin/montag`.
2. `can-stream-copy` as the last condition of the copy branch.
3. `tests/montag.bats` cases for the table and the gate.
4. Re run the failing command on the real screencast, check the result with ffprobe.
5. Final verification: `bash -n`, `bats tests/montag.bats`.

## Odd frame sizes

The first re encode of the live screencast failed: `libx264` refuses an odd width or height and the source is 1679x976. The re encode branch now appends `scale=trunc(iw/2)*2:trunc(ih/2)*2` to the `-vf` the command already has, because a second `-vf` argument would replace the first one, so a `--crop` keeps its filter ahead of the scale. The same branch sets `-pix_fmt yuv420p`, and for the mp4 family `-movflags +faststart`.

Every re encode gets the scale, not only the mp4 family. An mkv, avi or ts output has no tuned branch and ffmpeg picks its default encoder, which is `libx264`, `mpeg4` or `mpeg2video`; all three refuse an odd frame size the same way. Measured: 1678x976 for mp4, mkv, avi and ts from the 1679 wide source. The real screencast came out h264 1678x976, 39.204 s, yuv420p.

## Risks

- The ffprobe on a googlevideo url costs one extra request per stream. Accepted: the copy is wrong for the webm formats yt-dlp offers, and the probe reads headers only.
- The tables are measured on ffmpeg 8.1.2. A later ffmpeg that accepts more codecs makes the guard fire less often, never wrongly.

## Notes

- The failed run left a 0 byte `Screencast From 2026-10-15 17-02-01.mp4` next to the source. The re run overwrites it.
- Not covered by the tests: a real url run, the tests stub the probe. The local screencast in milestone 4 is the live check.