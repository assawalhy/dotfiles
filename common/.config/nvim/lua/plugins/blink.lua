return {
  'saghen/blink.cmp',
  version = '1.*',
  opts = {
    keymap = { preset = 'default' },
    appearance = { nerd_font_variant = 'mono' },
    completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 }, list = { selection = { preselect = true, auto_insert = false } } },
    sources = {
      default = { 'lsp', 'path', 'buffer', 'snippets' },
      providers = {
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
