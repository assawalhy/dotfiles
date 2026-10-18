# 36 — File preview (video, PDF, office, typed placeholder)

## Goal

One preview path for every non-text file, on all four surfaces: git diff/show/log,
lazygit, ranger, nvim.

- raster image -> inline image (today: works)
- video -> first-frame thumbnail (today: magick works, nothing calls it)
- PDF -> page 1 render
- office -> extracted text (docx/odt via pandoc, xlsx/pptx via python zipfile)
- everything else -> a typed placeholder line, never binary garbage

Each family tries a chain of popular tools and uses the first one that exists, so
the same script works on this laptop and on a machine that only has one renderer.

## Approach

- New `common/bin/file-preview` is the single implementation. It classifies by
  extension, confirms with `file --mime-type` when `file` exists, then picks the
  first available tool from that family's chain, renders or extracts, and always
  exits 0 (except `--render-out`, which reports failure to ranger).
- Modes:
  - default: inline OSC 1337 escape for renderables, delta for text, extracted
    text for office, placeholder otherwise (human-facing whole file)
  - `--raw`: same classification, no delta and no colour (git textconv)
  - `--text`: never emits an escape, so the output is safe inside a buffer or a
    preview pane: text rendering for rasters, stream metadata for video/audio,
    extracted text for office, listing for archives, placeholder otherwise
    (ranger's fallback and the nvim preview buffer)
  - `--render-out FILE`: pick the best raster renderer and write the image to
    FILE; exit 0 on success, 1 on failure (ranger's image cache)
- Tool chains, first available wins:

  | family | chain |
  |---|---|
  | raster -> image | `magick` (IM7), `convert` (IM6), else raw bytes |
  | raster -> text | `chafa`, `viu`, `timg`, `img2txt` (libcaca), `catimg`, `jp2` |
  | svg | `magick`, `rsvg-convert`, `inkscape`, `cairosvg` |
  | video frame | `ffmpegthumbnailer`, `magick '{src}[0]'`, `ffmpeg -frames:v 1` |
  | pdf | `pdftoppm`, `pdftocairo` (poppler), `magick -density 150 '{src}[0]'` (gs), `gs -sDEVICE=png16m`, `mutool draw` (mupdf) |
  | ps/eps | `magick`, `gs`, `pdftoppm` |
  | docx/odt/rtf/epub -> text | `pandoc`, `odt2txt`, `catdoc`, python zipfile |
  | xlsx/ods -> text | `xlsx2csv`, python zipfile, `ssconvert` (gnumeric), `libreoffice --headless` |
  | pptx/odp -> text | python zipfile, `libreoffice --headless` |
  | office -> image | `libreoffice --headless` then the pdf chain, `unoconv` |
  | archives -> listing | `atool -l`, `bsdtar -tf`, `unzip -l`, `tar -tf`, `7z l` |
  | audio -> text | `mediainfo`, `exiftool`, `ffprobe`; embedded cover via `ffmpeg` then raster |
  | fonts -> text | `fontimage` (fontforge), `exiftool`, `otfinfo` |
  | type detection | `file --mime-type`, python `mimetypes` fallback |

- git: the `img` textconv driver is renamed `preview` and its attribute globs
  grow to video, audio, pdf/ps/eps, and office. `git-img-textconv` becomes a
  thin wrapper on `file-preview --raw`. `git-img-preview` (lazygit `I`) drops
  its hardcoded raster list and calls `file-preview`.
- ranger: `scope.sh` stops carrying its own renderer calls for image, video and
  pdf; it calls `file-preview --render-out "${IMAGE_CACHE_PATH}"` and exits 6,
  and `file-preview --text` for office, archives, mime-typed text fallbacks and
  the placeholder. Ranger inherits the whole chain, including chafa text
  rendering when image previews are disabled. Its `MIMETYPE` falls back to
  python `mimetypes` when `file` is absent, so previews work before the rebuild.
- nvim: `snacks.image` formats regain `pdf`, `mp4`, `mov`, `avi`, `mkv`,
  `webm`, `m4v`, `wmv`, `flv` (its defaults already carry the pdf and video
  magick args, page defaults to 0). `config/nontext.lua` drops pdf and video
  (snacks owns them now) and fills the buffer from `file-preview --text`, so the
  typed preview or placeholder is visible instead of an empty buffer.
- nix: add `file`, `ghostscript`, `ffmpegthumbnailer`; LibreOffice stays
  detected-only (too heavy to install).

Availability on this machine (verified today):

| tool | state | used for |
|---|---|---|
| magick (ImageMagick 7) | present | raster, video frame, fallback pdf |
| ffmpeg | present | magick's video delegate, cover art |
| pdftoppm, pdftocairo | present | PDF raster |
| pandoc | present | docx/odt/epub to markdown |
| python3 | present | xlsx/pptx zipfile extraction |
| ghostscript | missing from PATH, built in /nix/store | magick PDF read, direct pdf |
| file (libmagic) | missing from PATH | ranger mime, type line |
| ffmpegthumbnailer | missing | preferred video thumbnail |
| chafa, viu, timg, catimg, img2txt, mutool, xlsx2csv, odt2txt, catdoc, rsvg-convert, inkscape, atool, bsdtar, 7z, unoconv | missing | picked up when a machine has them |
| libreoffice | missing | detected only, not installed |

The missing `file` is a live bug: ranger's `scope.sh` builds `MIMETYPE` from
`file --mime-type`, so with `file` absent no `handle_image` branch matches and
ranger previews raster images not at all right now.

## Decisions

| # | Decision | Why | Rejected |
|---|----------|-----|----------|
| D1 | One `file-preview` script, thin per-surface callers | one tool registry and one extraction implementation instead of four | duplicate chains in textconv, scope.sh, nontext.lua |
| D2 | PDF page 1 rendered, not `pdftotext` | the ask is "preview of pdfs"; matches raster behaviour; text stays one flag away | pdftotext in textconv (loses the visual preview) |
| D3 | office is text fallback only | nothing renders pptx/xlsx here; pandoc covers docx/odt | LibreOffice (~1.5 GB, new build) |
| D4 | ONLYOFFICE `x2t` not used | tried offline, conversion fails without its renderer harness (`Couldn't create temp folder`, XML/CLI errors); undocumented and hash-pinned | x2t headless renderer |
| D5 | add `ghostscript_headless` | magick needs the gs CLI to read PDF; `ghostscript_headless` is the same 10.07.1 build already in the store, while the default `ghostscript` is the with-X variant and would be a new build for a CLI-only need | pdftoppm-only (nvim snacks pdf args go through magick), with-X `ghostscript` |
| D6 | add `file` | ranger mime and the placeholder type line both need it; previews are broken without it | python `mimetypes` (no content sniff) |
| D7 | rename `img` driver to `preview` | the driver now handles more than images; two references only | keep `img`, misleading name |
| D8 | add `ffmpegthumbnailer`, keep magick as first fallback | it is the standard video thumbnailer and much cheaper than a full ffmpeg pass; other machines may have only one of the two | magick-only (works here, ignores the request) |
| D9 | tool chains, not one hardcoded tool per family | "as many popular tools as you can"; each machine uses what it has | single-tool branches as today |
| D10 | archives are out of the git attribute set | a package listing in a diff is noise; ranger/nvim still show one via `--raw` | textconv for zip/tar |
| D11 | office-to-image only if `libreoffice`/`unoconv` exists | free win on a machine that has them, no install cost here | install LibreOffice |
| D12 | textconv stays capped and never fails | a diff must not hang or balloon | unbounded render |
| D13 | a fourth `--text` mode for surfaces that cannot carry an escape | `--raw` emits OSC 1337 for renderables, which is garbage inside an nvim buffer or a ranger pane with images off; `--text` degrades to chafa text, stream metadata or the placeholder | `--raw` everywhere (buffer filled with escapes) |

## Milestones

1. W1 `common/bin/file-preview` (tool chains + modes) + git wiring
   (`attributes`, `.gitconfig`, `git-img-textconv`, `git-img-preview`).
2. W2 ranger `scope.sh` delegating to `file-preview`.
3. W3 nvim `images.lua`, `nontext.lua`, `README.md`.
4. W4 `nix/configuration.nix` + `setup/packages.list` (`file`, `ghostscript`,
   `ffmpegthumbnailer`), rebuild.
5. Verify: link-files, bats, pty checks, user visual pass.

W2 and W3 depend on W1's CLI; they touch disjoint files and can run parallel.

## Risks

- PDF renders only after the rebuild adds `ghostscript`; before that the
  placeholder shows. Same for ranger mime, which needs `file`.
- A rebuild needs sudo and syncs the whole `nix/` tree; the working tree already
  carries unrelated uncommitted hunks there.
- Tool probing runs `command -v` per candidate per preview. Each preview is its
  own process, so there is no cross-call cache; keep the chains short and skip a
  chain entirely when the extension rules it out.
- textconv now runs on more blob types (video, pdf, office). Rendering is capped
  and failures fall back to text, so a diff cannot hang on a bad file.
- `--raw` for office shells out to pandoc/python per preview; ranger previews
  many files, so the extractor chain runs only for office extensions.
