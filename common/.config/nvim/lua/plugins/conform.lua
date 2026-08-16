return {
  'stevearc/conform.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    require('conform').setup {
      formatters_by_ft = {
        lua = { 'stylua' },
        python = { 'black', 'isort' },
        javascript = { 'prettierd', 'prettier' },
        go = { 'gofmt', 'goimports' },
        shell = { 'beautysh' },
      },
      format_on_save = { lsp_format = 'fallback', timeout_ms = 500 },
    }
    vim.api.nvim_create_user_command('Format', function()
      require('conform').format { lsp_format = 'fallback', timeout_ms = 500 }
    end, { desc = 'Format with conform.nvim' })
  end,
}
