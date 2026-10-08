return {
  'saghen/blink.cmp',
  version = '1.*',
  dependencies = {
    {
      'supermaven-inc/supermaven-nvim',
      opts = {
        disable_inline_completion = false,
        disable_keymaps = false,
        log_level = 'off',
        keymaps = {
          accept_suggestion = '<Tab>',
          clear_suggestion = '<C-]>',
          accept_word = '<C-j>',
        },
      },
    },
    'huijiro/blink-cmp-supermaven',
  },
  opts = {
    keymap = { preset = 'default' },
    appearance = { nerd_font_variant = 'mono' },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 500 },
      ghost_text = { enabled = true },
      list = { selection = { preselect = true, auto_insert = false } },
    },
    sources = {
      default = { 'lsp', 'supermaven', 'path', 'buffer', 'snippets' },
      providers = {
        supermaven = {
          name = 'supermaven',
          module = 'blink-cmp-supermaven',
          async = true,
        },
        -- The snippets registry is keyed by file basename and matched against
        -- the buffer's filetype, so snippets/cpp.json serves C++ and
        -- snippets/kotlin.json serves Kotlin. No `filter_snippets` needed: the
        -- search path is a leaf directory that holds nothing else.
        snippets = {
          opts = {
            search_paths = { require('config.cp').snippets_dir() },
          },
        },
      },
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
