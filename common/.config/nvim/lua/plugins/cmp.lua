return {
  -- Autocompletion
  'hrsh7th/nvim-cmp',
  event = 'BufEnter',
  dependencies = {
    -- Adds LSP completion capabilities
    'hrsh7th/cmp-nvim-lsp',

    -- Snippet Engine & its associated nvim-cmp source
    {
      'L3MON4D3/LuaSnip',
      version = 'v2.*',
      build = 'make install_jsregexp'
    },
    'saadparwaiz1/cmp_luasnip',
    'rafamadriz/friendly-snippets',
    {
      'benfowler/telescope-luasnip.nvim',
      dependencies = { 'nvim-telescope/telescope.nvim', }
    },

    -- Display vscode-like pictograms to neovim built-in lsp
    'onsails/lspkind.nvim',
  },
  config = function()
    local has_words_before = function()
      unpack = unpack or table.unpack
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    end

    local cmp = require 'cmp'
    local luasnip = require 'luasnip'
    local lspkind = require('lspkind')

    require('luasnip.loaders.from_vscode').lazy_load()
    require('luasnip.loaders.from_snipmate').lazy_load()
    require('telescope').load_extension('luasnip')
    luasnip.config.setup {}

    vim.keymap.set({ "i", "s" }, "<C-E>", function()
      if luasnip.choice_active() then
        luasnip.change_choice(1)
      end
    end, { silent = true })

    cmp.setup {
      sources = {
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
      },
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      formatting = {
        format = lspkind.cmp_format()
      },
      mapping = cmp.mapping.preset.insert {
        ['<C-n>'] = cmp.mapping.select_next_item(),
        ['<C-p>'] = cmp.mapping.select_prev_item(),
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete {},
        ['<CR>'] = cmp.mapping.confirm {
          behavior = cmp.ConfirmBehavior.Replace,
          select = true,
        },
        ["<Tab>"] = cmp.mapping(function(fallback)
          -- if cmp.visible() then
          --   cmp.select_next_item()
            -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
            -- that way you will only jump inside the snippet region
          -- elseif has_words_before() then
          --   cmp.complete()
          if luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { "i", "s" }),

        ["<S-Tab>"] = cmp.mapping(function(fallback)
          -- if cmp.visible() then
          --   cmp.select_prev_item()
          if luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      },
    }
  end
}
