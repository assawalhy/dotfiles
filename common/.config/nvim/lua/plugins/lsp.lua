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
      -- clangd is a prebuilt binary with no toolchain of its own: it searches
      -- only its resource dir, /usr/local/include and /usr/include, so the
      -- libstdc++ headers never resolve. ~/.config/clangd/config.yaml names the
      -- driver to query, and clangd only queries drivers allowed here. The list
      -- covers Debian, Arch, both Homebrew prefixes and the NixOS profile; the
      -- last entry is the gxx-cuda wrapper that answers the CUDA probe g++
      -- rejects (plans 45 and 50).
      local gxx_cuda = vim.fn.expand('~/bin/gxx-cuda')
      vim.lsp.config('clangd', {
        cmd = {
          'clangd',
          '--query-driver=/usr/bin/g++,/usr/local/bin/g++,/opt/homebrew/bin/g++,/run/current-system/sw/bin/g++,'
            .. gxx_cuda,
        },
      })
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
