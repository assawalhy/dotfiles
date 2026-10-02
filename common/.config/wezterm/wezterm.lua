local wezterm = require 'wezterm'

local config = wezterm.config_builder()

-- BiDi (Arabic/Hebrew) text support. These two fields are undocumented
-- upstream, which is why `enable_bidi` is not a thing: the real keys are
-- bidi_enabled / bidi_direction (see wezterm config/src/config.rs).
-- ParagraphDirectionHint: LeftToRight | RightToLeft | AutoLeftToRight | AutoRightToLeft.
config.bidi_enabled = true
config.bidi_direction = 'AutoLeftToRight'

-- Arabic glyphs: wezterm builds a fixed fallback chain from its built-in
-- list and never asks fontconfig for a per-codepoint substitute, so the
-- Arabic mono face (Kawkab Mono) has to be named explicitly or bidi
-- reorders text whose glyphs are all missing.
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'Kawkab Mono',
  'Noto Sans Mono',
}

return config
