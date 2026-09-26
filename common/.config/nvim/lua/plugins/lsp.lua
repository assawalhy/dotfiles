return {
  {
    'williamboman/mason-lspconfig.nvim',
    opts = {
      ensure_installed = { 'bashls', 'clangd', 'pyright', 'ts_ls', 'eslint', 'intelephense', 'html', 'lua_ls' },
      automatic_enable = false,
    },
    dependencies = {
      { 'williamboman/mason.nvim', opts = {} },
      'neovim/nvim-lspconfig',
    },
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.lsp.config('html', { filetypes = { 'html', 'twig', 'hbs' } })
      for _, server in ipairs { 'bashls', 'clangd', 'pyright', 'ts_ls', 'eslint', 'biome', 'intelephense', 'html', 'lua_ls' } do
        -- Oversized files stay LSP-free (see config/autocmds.lua).
        vim.lsp.enable(server, function(bufnr)
          return not vim.b[bufnr].large_file
        end)
      end
    end,
  },
  { 'folke/lazydev.nvim', ft = 'lua', opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } } },
}
