return {
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- Useful plugin to show you pending keybinds.
  { 'folke/which-key.nvim', opts = {} },

  -- Generative AI (copilot alternative)
  {
    'Exafunction/codeium.vim',
    event = "BufEnter",
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    -- stylua: ignore
    keys = {
      {
        "s",
        mode = { "n", "o", "x" },
        function() require("flash").jump() end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "o" },
        function() require("flash").treesitter() end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function() require("flash").remote() end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function() require("flash").treesitter_search() end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function() require("flash").toggle() end,
        desc = "Toggle Flash Search",
      },
    },
  },

  {
    'numToStr/Comment.nvim',
    keys = {
      { 'gc',    mode = { 'x', 'n' }, desc = 'Comment' },
      { '<C-_>', mode = { 'x', 'n' }, desc = 'Comment' },
    },
    config = function()
      require('Comment').setup({
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
        mappings = {
          ---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
          basic = true,
          ---Extra mapping; `gco`, `gcO`, `gcA`
          extra = true,
        }
      })
    end
  },

  {
    'tpope/vim-surround',
    keys = { { 'ds' }, { 'cs' }, { 'ys' }, { 'S', mode = 'x' } },
  },

  {
    'windwp/nvim-autopairs',
    event = "BufEnter",
    opts = {},
  },

  { 'famiu/bufdelete.nvim', cmd = { 'Bdelete', 'Bwipeout' } },

  {
    'mg979/vim-visual-multi',
    priority = 1000,
    branch = 'master',
  },

  {
    'junegunn/vim-easy-align',
    keys = {
      { 'ga', '<Plug>(EasyAlign)', mode = { 'x', 'n' } }
    }
  },

  {
    'mbbill/undotree',
    cmd = 'UndotreeToggle',
    keys = {
      { "<leader>u", ':UndotreeToggle<CR>', mode = 'n' }
    },
    config = function()
      vim.o.undodir = os.getenv('HOME') .. '/.vim/undodir'
    end
  },

  {
    'fedepujol/move.nvim',
    cmd = 'Move',
    keys = {
      { '<A-j>', ':MoveLine(1)<CR>',    mode = 'n', silent = true },
      { '<A-k>', ':MoveLine(-1)<CR>',   mode = 'n', silent = true },
      { '<A-j>', ':MoveBlock(1)<CR>',   mode = 'v', silent = true },
      { '<A-k>', ':MoveBlock(-1)<CR>',  mode = 'v', silent = true },
      { '<A-l>', ':MoveHChar(1)<CR>',   mode = 'n', silent = true },
      { '<A-h>', ':MoveHChar(-1)<CR>',  mode = 'n', silent = true },
      { '<A-l>', ':MoveHBlock(1)<CR>',  mode = 'v', silent = true },
      { '<A-h>', ':MoveHBlock(-1)<CR>', mode = 'v', silent = true },
    }
  },

  {
    'justinmk/vim-sneak',
    keys = {
      { 'f', '<Plug>Sneak_f' },
      { 'F', '<Plug>Sneak_F' },
      { 't', '<Plug>Sneak_t' },
      { 'T', '<Plug>Sneak_T' },
    },
  },
}