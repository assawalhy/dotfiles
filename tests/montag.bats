#!/usr/bin/env bats
#
# montag.bats -- unit tests for the yt-dlp resolver parser in
# common/bin/montag. montag is a script with no harness of its own, so
# parse-resolver-output is extracted and driven directly: no network, no
# yt-dlp, no ffmpeg, no side effects.
#
# The awk extractor matches `parse-resolver-output() {` up to the first `}` at
# column 0, so keep the function top-level and end it with a bare `}`.

ROOT="$BATS_TEST_DIRNAME/.."

# assert_resolve <input> <want-status> <want-url-count> <want-title> <want-ua>
# Runs the real parser on the marked lines a yt-dlp --print call produces and
# compares what it set. The globals it fills are reset first, since the
# function resets them itself only for its own inputs.
assert_resolve() {
  eval "$(awk '/^parse-resolver-output\(\)/,/^}/' "$ROOT/common/bin/montag")"
  ( resolved_title=''; input_urls=(); ua=''
    status=0
    parse-resolver-output "$1" || status=$?
    [ "$status" = "$2" ] || { printf 'status %s, want %s\n' "$status" "$2" >&2; exit 1; }
    [ "${#input_urls[@]}" = "$3" ] || {
      printf '%s urls, want %s\n' "${#input_urls[@]}" "$3" >&2; exit 1; }
    [ "$resolved_title" = "$4" ] || {
      printf 'title [%s], want [%s]\n' "$resolved_title" "$4" >&2; exit 1; }
    [ "$ua" = "$5" ] || { printf 'ua [%s], want [%s]\n' "$ua" "$5" >&2; exit 1; }
    for url in "${input_urls[@]}"; do
      case "$url" in http*) : ;; *) printf 'not a url [%s]\n' "$url" >&2; exit 1 ;; esac
    done )
}

# what a merged video+audio selection prints: two urls, headers under
# requested_formats.0
MERGED='MONTAG-TITLE:Some Video.webm
MONTAG-URL:https://host/video?sig=a
MONTAG-URL:https://host/audio?sig=b
MONTAG-URL:NA
MONTAG-HDR:{"User-Agent": "UA/1.0", "Accept": "*/*"}
MONTAG-HDR:NA'

# what an audio-only selection prints: one url, headers at the top level
AUDIO='MONTAG-TITLE:Some Audio.webm
MONTAG-URL:NA
MONTAG-URL:NA
MONTAG-URL:https://host/audio?sig=c
MONTAG-HDR:NA
MONTAG-HDR:{"User-Agent": "UA/2.0"}'

@test "montag- resolver: merged selection gives the title, both urls and the ua" {
  assert_resolve "$MERGED" 0 2 "Some Video.webm" "UA/1.0"
}

@test "montag- resolver: single format selection gives one url from %(url)s" {
  assert_resolve "$AUDIO" 0 1 "Some Audio.webm" "UA/2.0"
}

@test "montag- resolver: the first headers line wins, NA lines are skipped" {
  assert_resolve 'MONTAG-URL:https://host/a
MONTAG-HDR:NA
MONTAG-HDR:{"User-Agent": "UA/first", "Accept": "*/*"}
MONTAG-HDR:{"User-Agent": "UA/second"}' 0 1 "" "UA/first"
}

@test "montag- resolver: no User-Agent in the headers leaves ua empty" {
  assert_resolve 'MONTAG-URL:https://host/a
MONTAG-HDR:{"Accept": "*/*"}' 0 1 "" ""
}

@test "montag- resolver: a url with a colon, query and dashes survives intact" {
  assert_resolve 'MONTAG-URL:https://rr1---sn-x.googlevideo.com/videoplayback?expire=1&itag=398&sig=a%3D%3D' \
    0 1 "" ""
  eval "$(awk '/^parse-resolver-output\(\)/,/^}/' "$ROOT/common/bin/montag")"
  ( input_urls=()
    parse-resolver-output 'MONTAG-URL:https://rr1---sn-x.googlevideo.com/videoplayback?expire=1&itag=398&sig=a%3D%3D'
    [ "${input_urls[0]}" = 'https://rr1---sn-x.googlevideo.com/videoplayback?expire=1&itag=398&sig=a%3D%3D' ] )
}

@test "montag- resolver: without a stream url the parse fails" {
  assert_resolve 'MONTAG-TITLE:Broken.mp4
MONTAG-URL:NA
MONTAG-HDR:NA' 1 0 "Broken.mp4" ""
}

@test "montag- resolver: empty input fails" {
  assert_resolve '' 1 0 "" ""
}