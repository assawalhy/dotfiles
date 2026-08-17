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
        snippets = {
          opts = {
            search_paths = { '~/myp/problem-solving' },
            filter_snippets = function(_, file)
              return vim.fn.fnamemodify(file, ':t') == 'cpp.json'
            end,
          },
        },
      },
    },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
}
