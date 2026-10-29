return {
  {
    'williamboman/mason-lspconfig.nvim',
    opts = {
      ensure_installed = {
        'bashls',
        'clangd',
        'pyright',
        'ts_ls',
        'eslint',
        'intelephense',
        'html',
        'lua_ls',
        'jdtls',
        'kotlin_language_server',
      },
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
      local gate = require('config.lsp_gate')
      for _, server in ipairs { 'bashls', 'clangd', 'pyright', 'ts_ls', 'eslint', 'prismals', 'biome', 'intelephense', 'html', 'lua_ls', 'tailwindcss' } do
        gate.gate(server)
      end
      -- jdtls + Kotlin (kotlin_lsp, mason kls fallback): JVM servers with
      -- their own memory guard, heap cap and launch details (config/java.lua).
      require('config.java').setup()
      -- prismals is deliberately not in ensure_installed above: it is offered
      -- on the first .prisma buffer instead (config/prisma.lua).
      require('config.prisma').setup()
    end,
  },
  { 'folke/lazydev.nvim', ft = 'lua', opts = { library = { { path = '${3rd}/luv/library', words = { 'vim%.uv' } } } } },
}
