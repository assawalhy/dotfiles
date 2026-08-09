# AI Coding Agent Instructions for `/bin`

This is a **personal utility collection** of standalone CLI tools and scripts for media processing, development and productivity automation.

> **Layout note:** this directory is `common/bin` in the dotfiles repo and is linked to `~/bin` on both macOS and Linux, so **scripts here must be portable**.
> Linux/X11-only tools (`keyboard`, `screenlayouts`, `monitor-my-ram`, and everything under `arch-scripts/`) live in `linux/bin/` instead and are only linked on Linux.
> For clipboard access always use `clip` (`clip` to copy, `clip -o` to paste) rather than `xsel`/`xclip`/`pbcopy` directly -- it resolves the backend at runtime.

## Architecture & Purpose

- **No central application** – each script is independent and self-contained
- **Language diversity**: Bash (majority), Node.js, Perl, with some shell wrappers
- **Usage**: Direct CLI invocation with argument parsing; most are single-purpose tools
- **No interdependencies**: Scripts don't call each other; they invoke external tools (ffmpeg, yt-dlp, fzf, etc.)

## Key Scripts & Categories

### Media Processing

- **`montag`** (507 lines, Bash) – Complex video/audio manipulation wrapper around ffmpeg
  - Handles: trimming, speed adjustment, GIF conversion, thumbnail extraction, speech-to-text
  - Pattern: `function-name()` definitions with `case` statements for CLI argument parsing
  - Uses `collect-arg-and-validate()` pattern to parse `-i` input flag (can be repeated)
  - Validation logic separates argument collection from processing
- **`ydi`** – yt-dlp interactive wrapper with whiptail for dependency selection
- **`ytdl-list`**, **`mpv-yt`** – YouTube downloading and playback utilities

### System & Display Control

- **`keyboard`** (Bash, `set -e`) – Keyboard layout cycling with xkbmap

  - Pattern: `get_kbdlayout()`, `set_kbdlayout()`, `cycle()` functions
  - Loads `.Xmodmap` configs for layout-specific key remapping
  - Integration point: i3status updates (commented code shows callback pattern)

- **`scr`** (Bash, `set -e`) – simplescreenrecorder wrapper for recording control

  - Pattern: `case` statement with fallthrough logic (`;&` operator)
  - Advanced feature: PID-based process communication via `/proc/$PID/fd/0`

- **`emojis`** – Emoji picker using fzf, reads from `emojis.txt` (CSV format)
- **`wal`** – Colorscheme/wallpaper management
- **`windows`** – Window management helper
- **`dwm-iconbar`**, **`xset-my-root`** – Display and DWM integration

### Productivity & Data Utilities

- **`obsidian-export`** (Bash, `set -e`) – Obsidian vault exporter with tag filtering

  - Pattern: Array manipulation (`readarray -t vault_md_files`), bash glob expansion (`shopt -s nullglob`)
  - Output formats: Markdown or PDF concatenation with optional file-name headers

- **`acade-format`** (Node.js ESM) – Clipboard formatter using spawn() to call xsel
- **`emojis-window`** – Emoji picker variant (window-based)

### System Monitoring & Maintenance

- **`monitor-my-ram`** – Simple infinite loop monitoring RAM with pkill trigger
- **`git-large-objects`** – Git repository analysis
- **`finalurl`** – HTTP redirect resolver using curl with `-L` flag

### Lightweight/Wrapper Tools

- **`alac`**, **`alcrty`** – Alacritty terminal wrappers (one uses `LIBGL_ALWAYS_SOFTWARE=1`)
- **`egrep`**, **`checkstyle`** – Grep and code style helpers
- **`microphone`** – Audio/Mumble integration
- **`name-sorted-date`**, **`notify-posture`**, **`runwomic`** – Specialized utilities

## Essential Patterns

### Error Handling & Robustness

- **Strict mode standard**: `set -e` used in complex/critical scripts (montag, obsidian-export, keyboard, scr, ytdl-list)

  - Implies: fail-fast on any unhandled error; rarely try/catch patterns
  - When absent: script handles errors inline or is genuinely fault-tolerant (e.g., monitor-my-ram infinite loop)

- **Help messages**: Built-in `print-help()` function with structured tables using box-drawing characters

  - Example: `┌──┬─────┬────┄` format (see montag, obsidian-export)
  - Shown via `-h` or `--help` flags; often exit after display

- **Debug output**: `echo-debug()` utility function in montag; quiet mode via `-q` flag
  - Usage: `echo-debug error: message` with exit codes (typically 1 or 2 for validation errors)

### Argument Parsing

- **Long + short flags**: Both `-i` and `--input`, `-s` and `--start` (montag pattern)
- **Repeated flags**: `-i input1 -i input2` for multiple inputs (montag supports this; TODO comment notes parsing complexity)
- **Flag ordering**: Flexible; final positional argument often is output file
- **Validation after collection**: `collect-arg-and-validate()` pattern validates before execution (montag)

### File Location & Dependencies

- **Script self-location**: Use `$(which "$0")` or `$(dirname "$(which "$0")")` to find sibling resources (emojis script finds emojis.txt)
- **Config files**: Home directory patterns for `.Xmodmap`, layout-specific `~/.${layout}.Xmodmap`
- **External tools assumed installed**: ffmpeg, yt-dlp, fzf, xsel, xkbmap, curl, whiptail, etc.

### I/O & Data Flow

- **Clipboard integration**: xsel used for read/write (`acade-format` spawns xsel for clipboard read)
- **Pipe-friendly**: Most tools write to stdout (emojis, finalurl output single result)
- **CSV data**: `emojis.txt` is CSV; parsed with `cut -d',' -f1`

### Function & Variable Naming

- **kebab-case for functions**: `print-help`, `collect-arg-and-validate`, `get-file-containing-tags` (Bash allows dashes)
- **UPPER_CASE for important vars**: `SCR_PID`, `SCR_STATUS` in scr script
- **Prefix for state**: `is_*` booleans (is_help, is_quiet, is_yes), `*_options` or `*_args` for lists

## Development Workflow

### Testing & Validation

- No automated test framework observed; validation is inline argument checking
- Scripts are typically tested manually with `-h` for syntax verification
- Complex scripts (montag, obsidian-export) have TODO comments indicating known limitations

### Debugging

- **Bash debugging**: Scripts use `set -e` but rely on stderr output from called tools
- **Quiet mode pattern**: `-q`/`--quiet` flag to suppress ffmpeg output (montag)
- **Direct tool invocation**: No logging framework; debug via tool's own verbosity flags

### Adding New Scripts

1. Choose appropriate language (Bash for system tools, Node.js for clipboard/data transformation)
2. Add shebang: `#!/usr/bin/env bash` or `#!/usr/bin/env node`
3. Add `set -e` if error-handling is critical
4. Implement `print-help()` with `-h`/`--help` support
5. Use consistent naming for flags (prefer long + short pairs)
6. Place portable scripts in `common/bin/`; put Linux/X11-only ones in `linux/bin/`
7. Ensure executable bit: `chmod +x script-name`

## External Dependencies

Scripts assume standard Linux utilities are available:

- **Media**: ffmpeg, yt-dlp, whisper (speech-to-text)
- **UI/Selection**: fzf (fuzzy find), whiptail (interactive prompts)
- **System**: `clip` (clipboard, portable wrapper). X11-only deps (xkbmap, setxkbmap, simplescreenrecorder) belong to `linux/bin/` scripts.
- **Tools**: curl, perl, git, pidof, grep, cut, awk, sed
- **Window managers**: Tested on DWM, i3 (see i3status integration patterns)

## Conventions to Preserve

- **Executable shebangs** always at line 1
- **Early help exit**: `-h` displays help and exits before any processing
- **Spacing in conditionals**: Prefer `[ condition ]` with spaces; use `(( ))` for arithmetic
- **Heredoc help blocks**: Use `-` prefix to allow indentation: `cat <<- EOF`
- **Output clarity**: Use emoji/box-drawing in help; plain text for actual output
- **Sparse comments**: Code is self-documenting; comments highlight TODOs or non-obvious logic only
