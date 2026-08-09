-- Set <space> as the leader key
-- NOTE: should be before loading plugins
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Install package manager: https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
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
    -- Theme inspired by Atom
    'navarasu/onedark.nvim',
    priority = 1000,
    config = function()
      vim.cmd.colorscheme 'onedark'
    end,
  },

  {
    'nvim-lualine/lualine.nvim',
    priority = 1001,
    opts = {
      options = {
        icons_enabled = false,
        theme = 'onedark',
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require("bufferline").setup {
        options = {
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          hover = {
            enabled = true,
            delay = 200,
            reveal = { 'close' }
          }
        }
      }

      vim.keymap.set('n', '<tab>n', '<CMD>tabnew<CR>', {})
      vim.keymap.set('n', '<tab>l', '<CMD>BufferLineCycleNext<CR>', {})
      vim.keymap.set('n', '<tab>h', '<CMD>BufferLineCyclePrev<CR>', {})
      vim.keymap.set('n', '<tab>x', '<CMD>BufferLineCloseOthers<CR>', {})
      vim.keymap.set('n', '<tab>p', '<CMD>BufferLinePick<CR>', {})
      vim.keymap.set('n', '<tab>P', '<CMD>BufferLineTogglePin<CR>', {})
    end
  },

  {
    'lukas-reineke/indent-blankline.nvim',
    main = "ibl",
    event = 'BufEnter',
    priority = 1002,
    opts = {
      indent = { char = "┊" },
      scope = {
        show_start = false,
      }
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
      vim.cmd([[nmap <C-_> gcc]])
      vim.cmd([[xmap <C-_> gc]])
    end
  },

  {
    'Pocco81/true-zen.nvim',
    keys = {
      { '<leader>zn', ':TZNarrow<CR>',     {} },
      { '<leader>zf', ':TZFocus<CR>',      {} },
      { '<leader>zm', ':TZMinimalist<CR>', {} },
      { '<leader>za', ':TZAtaraxis<CR>',   {} },
      { mode = 'v',   '<leader>zn',        ":'<,'>TZNarrow<CR>", {} },
    }
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
    'brenoprata10/nvim-highlight-colors',
    config = function()
      require("nvim-highlight-colors").setup {
        render = 'background', -- or 'foreground' or 'first_column'
        enable_named_colors = true,
        enable_tailwind = true,
      }
    end
  },

  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {}
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
    'tanvirtin/vgit.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
    config = function()
      require('vgit').setup({
        keymaps = {
          ['n <leader>gs'] = function() require('vgit').buffer_hunk_stage() end,
          ['n <leader>gr'] = function() require('vgit').buffer_hunk_reset() end,
          ['n <leader>gp'] = function() require('vgit').buffer_hunk_preview() end,
          ['n <leader>gb'] = function() require('vgit').buffer_blame_preview() end,
          ['n <leader>gf'] = function() require('vgit').buffer_diff_preview() end,
          ['n <leader>gh'] = function() require('vgit').buffer_history_preview() end,
          ['n <leader>gu'] = function() require('vgit').buffer_reset() end,
          ['n <leader>gg'] = function() require('vgit').buffer_gutter_blame_preview() end,
          ['n <leader>glu'] = function() require('vgit').buffer_hunks_preview() end,
          ['n <leader>gls'] = function() require('vgit').project_hunks_staged_preview() end,
          ['n <leader>gd'] = function() require('vgit').project_diff_preview() end,
          ['n <leader>gq'] = function() require('vgit').project_hunks_qf() end,
          ['n <leader>gx'] = function() require('vgit').toggle_diff_preference() end,
        },
      })
    end

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

  { import = 'plugins' },
}, {})

---------------------------------------------------------------
---------------------------------------------------------------
---------------------------------------------------------------

-- Set highlight on search
vim.o.hlsearch = false
vim.o.incsearch = false

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = 'a'

-- Sync clipboard between OS and Neovim.
-- vim.o.clipboard = 'unnamedplus'

-- Disable
vim.o.wrap = false

-- Enable break indent
vim.o.breakindent = true

vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- Padding in top and bottom while move up and down in the buffer
vim.o.scrolloff = 10

-- End of line and tabs symbols
vim.o.list = true
vim.opt.listchars:append "eol:↴"

---------------------------------------------------------------
---------------------------------------------------------------
---------------------------------------------------------------

-- copy to clipboard
-- ~/bin/clip comes from the dotfiles repo and picks pbcopy / wl-copy / xclip /
-- xsel at runtime, so this needs no platform branch.
-- NOTE: vim.fn.executable() returns a number, and 0 is truthy in Lua -- it must
-- be compared against 1, never used as a bare condition.
function CopyBuffer()
  if vim.fn.executable('clip') ~= 1 then
    vim.notify("Can't find `clip` -- is ~/bin on your PATH?", vim.log.levels.ERROR)
    return
  end
  vim.cmd('silent write !clip')
  print('Buffer is copied')
end

vim.keymap.set('x', ';y', '"+y', { desc = "Copy selection to sys clipboard" })
vim.keymap.set('n', ';wc', CopyBuffer, { desc = "Copy current buffer to sys clipboard" })
vim.keymap.set('x', 'gsw', "'<,'> ! awk '{ print length(), $0 } | sort -n | cut -d\\  -f2-'<CR><ESC>",
  { desc = "Sort selected lines by line width" })

-- easily move in wrapped lines
vim.keymap.set('n', 'j', "v:count ? 'j' : 'gj'", { silent = true, expr = true })
vim.keymap.set('n', 'k', "v:count ? 'k' : 'gk'", { silent = true, expr = true })

-- navigate tabs done by bufferline plugin
-- navigate windows
vim.keymap.set('n', '<C-w><C-q>', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-w>q', '<CMD>bd<cr>', { desc = 'Delete buffer' })
vim.keymap.set('n', '<C-l>', '<C-w>l', {})
vim.keymap.set('n', '<C-h>', '<C-w>h', {})
vim.keymap.set('n', '<C-j>', '<C-w>j', {})
vim.keymap.set('n', '<C-k>', '<C-w>k', {})

-- vim.keymap.set("n", "<C-d>", "<C-d>zz")
-- vim.keymap.set("n", "<C-u>", "<C-u>zz")
-- vim.keymap.set("n", "n", "nzzzv")
-- vim.keymap.set("n", "N", "Nzzzv")

-- delete without yanking
vim.keymap.set('n', ';d', '"_d', {})
vim.keymap.set('n', ';c', '"_c', {})
vim.keymap.set('n', ';D', '"_D', {})
vim.keymap.set('v', ';d', '"_d', {})
vim.keymap.set('v', ';c', '"_c', {})
vim.keymap.set('v', ';D', '"_D', {})
vim.keymap.set('v', ';p', '"_dP', {})

vim.cmd [[
command! LocalTerm let s:term_dir=expand('%:p:h') | below new | call termopen([&shell], {'cwd': s:term_dir })
]]

vim.keymap.set('n', '<space>t', ':LocalTerm<cr>', { desc = 'Open a terminal in the current file\'s directory' })

-- Highlight on yank
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})
