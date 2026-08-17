return {
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
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
      require('bufferline').setup {
        options = {
          diagnostics = 'nvim_lsp',
          separator_style = 'slant',
          hover = {
            enabled = true,
            delay = 200,
            reveal = { 'close' },
          },
        },
      }
    end,
  },

  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = 'BufEnter',
    priority = 1002,
    opts = {
      indent = { char = '┊' },
      scope = {
        show_start = false,
      },
    },
  },

  {
    'brenoprata10/nvim-highlight-colors',
    config = function()
      require('nvim-highlight-colors').setup {
        render = 'background', -- or 'foreground' or 'first_column'
        enable_named_colors = true,
        enable_tailwind = true,
      }
    end,
  },

  {
    'folke/todo-comments.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {},
  },

  {
    'Pocco81/true-zen.nvim',
    keys = {
      { '<leader>zn', ':TZNarrow<CR>', desc = 'True zen (narrow)' },
      { '<leader>zf', ':TZFocus<CR>', desc = 'True zen (focus)' },
      { '<leader>zm', ':TZMinimalist<CR>', desc = 'True zen (minimalist)' },
      { '<leader>za', ':TZAtaraxis<CR>', desc = 'True zen (ataraxis)' },
      { mode = 'v', '<leader>zn', ":'<,'>TZNarrow<CR>", desc = 'True zen (narrow selection)' },
    },
  },

  {
    'xiyaowong/transparent.nvim',
    opts = {
      extra_groups = {
        'NormalFloat',
        'NeoTreeNormal',
        'NeoTreeNormalNC',
        'NeoTreeEndOfBuffer',
        'NeoTreeCursorLine',
        'NeoTreeDirectoryName',
        'NeoTreeDirectoryIcon',
        'NeoTreeRootName',
        'NeoTreeFileName',
        'NeoTreeFileIcon',
        'NeoTreeFileNameOpened',
        'NeoTreeIndentMarker',
        'NeoTreeFloatBorder',
        'NeoTreeFloatTitle',
        'NeoTreeTitleBar',
        'BufferLineFill',
        'BufferLineBackground',
        'BufferLineBuffer',
        'BufferLineTab',
        'BufferLineTabSelected',
        'BufferLineTabClose',
        'BufferLineCloseButton',
        'BufferLineCloseButtonSelected',
        'BufferLineModified',
        'BufferLineModifiedSelected',
        'BufferLineSeparator',
        'BufferLineSeparatorSelected',
        'BufferLineIndicator',
        'BufferLineIndicatorSelected',
        'BufferLineHint',
        'BufferLineHintSelected',
        'BufferLineInfo',
        'BufferLineInfoSelected',
        'BufferLineWarning',
        'BufferLineWarningSelected',
        'BufferLineError',
        'BufferLineErrorSelected',
        'BufferLineDevIconDefault',
        'StatusLine',
        'StatusLineNC',
        'WinBar',
        'WinBarNC',
      },
    },
  },
}
