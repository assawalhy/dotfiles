return {
  -- Detect tabstop and shiftwidth automatically
  'tpope/vim-sleuth',

  -- Useful plugin to show you pending keybinds.
  { 'folke/which-key.nvim', opts = {} },

  {
    'folke/flash.nvim',
    event = 'VeryLazy',
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
      require('Comment').setup {
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
        mappings = {
          ---Operator-pending mapping; `gcc` `gbc` `gc[count]{motion}` `gb[count]{motion}`
          basic = true,
          ---Extra mapping; `gco`, `gcO`, `gcA`
          extra = true,
        },
      }
    end,
  },

  {
    'tpope/vim-surround',
    keys = {
      { 'ds', desc = 'Delete surround' },
      { 'cs', desc = 'Change surround' },
      { 'ys', desc = 'Surround' },
      { 'S',  mode = 'x',              desc = 'Surround (visual)' },
    },
  },

  {
    'windwp/nvim-autopairs',
    event = 'BufEnter',
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
      { 'ga', '<Plug>(EasyAlign)', mode = { 'x', 'n' }, desc = 'Easy align' },
    },
  },

  {
    'mbbill/undotree',
    cmd = 'UndotreeToggle',
    keys = {
      { '<leader>u', ':UndotreeToggle<CR>', mode = 'n', desc = 'Undotree' },
    },
    config = function()
      vim.o.undodir = os.getenv 'HOME' .. '/.vim/undodir'
    end,
  },

  {
    'fedepujol/move.nvim',
    keys = {
      { '<A-j>', ':MoveLine(1)<CR>',    mode = 'n', silent = true, desc = 'Move line down' },
      { '<A-k>', ':MoveLine(-1)<CR>',   mode = 'n', silent = true, desc = 'Move line up' },
      { '<A-j>', ':MoveBlock(1)<CR>',   mode = 'v', silent = true, desc = 'Move selection down' },
      { '<A-k>', ':MoveBlock(-1)<CR>',  mode = 'v', silent = true, desc = 'Move selection up' },
      { '<A-l>', ':MoveHChar(1)<CR>',   mode = 'n', silent = true, desc = 'Move char right' },
      { '<A-h>', ':MoveHChar(-1)<CR>',  mode = 'n', silent = true, desc = 'Move char left' },
      { '<A-l>', ':MoveHBlock(1)<CR>',  mode = 'v', silent = true, desc = 'Move selection right' },
      { '<A-h>', ':MoveHBlock(-1)<CR>', mode = 'v', silent = true, desc = 'Move selection left' },
    },
  },

  {
    'justinmk/vim-sneak',
    keys = {
      { 'f', '<Plug>Sneak_f', desc = 'Sneak forward' },
      { 'F', '<Plug>Sneak_F', desc = 'Sneak backward' },
      { 't', '<Plug>Sneak_t', desc = 'Sneak till forward' },
      { 'T', '<Plug>Sneak_T', desc = 'Sneak till backward' },
    },
  },

  {
    'rest-nvim/rest.nvim',
    commands = { 'Http' },
    ft = 'http',
  },
}
