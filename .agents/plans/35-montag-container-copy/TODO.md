# 35 montag container aware stream copy

- [x] `container-allows-codec`, `input-codecs` and `can-stream-copy` as top level functions ending in a bare `}`. Checked: `bash -n common/bin/montag`.
- [x] `can-stream-copy` as the last condition of the copy branch, so an unfit copy falls into the existing re encode branch. Checked: `bash -n`, and the branch is reached in the printed command.
- [x] `tests/montag.bats`: the table (vp8 into mp4 rejected, vp9 into mp4 accepted, h264 into webm rejected, aac into webm rejected, mkv unpoliced) and the gate with `ffprobe` stubbed (vp8 input refuses the copy, h264 input takes it, an empty probe keeps the copy). Checked: `bats tests/montag.bats`.
- [x] Re run the failing command on `~/Videos/Screencasts/Screencast From 2026-10-28 21-11-58.webm` with the mp4 output, then `ffprobe` the result. Checked: h264 in mp4, 39.204 s.
- [x] Update the montag.bats expected count in `AGENTS.md`.
- [x] Final verification: `bash -n`, `bats tests/montag.bats`, and a control run that must still copy (same input, `.webm` output, `-c copy` in the printed command).
- [x] libx264 refused the odd 1679 pixel width of the screencast, so the mp4, mov and m4v branch appends `scale=trunc(iw/2)*2:trunc(ih/2)*2` to the `-vf` it already has, sets `-pix_fmt yuv420p` and `-movflags +faststart`. Checked: the real screencast encodes to h264 1678x976, and a `--crop` run keeps its crop filter ahead of the scale.
- [x] The even size scale covers every re encode, not only the mp4 family: mkv, avi and ts fall to the ffmpeg default encoder (libx264, mpeg4, mpeg2video) and refuse an odd frame size too. Checked: 1678x976 for mp4, mkv, avi and ts from the 1679 wide source, and a `-c copy` run into mkv still prints `-c copy`.
