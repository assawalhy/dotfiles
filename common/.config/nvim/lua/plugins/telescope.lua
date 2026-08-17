return {
  {
    'nvim-telescope/telescope.nvim',
    branch = 'master',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
    },
    config = function()
      local telescopeConfig = require 'telescope.config'
      local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
      vimgrep_arguments[#vimgrep_arguments + 1] = '--hidden'
      vimgrep_arguments[#vimgrep_arguments + 1] = '--glob'
      vimgrep_arguments[#vimgrep_arguments + 1] = '!**/.git/*'

      require('telescope').setup {
        defaults = {
          winblend = 10,
          prompt_prefix = '🔍 ',
          vimgrep_arguments = vimgrep_arguments,
        },
        pickers = {
          find_files = {
            theme = 'dropdown',
            find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*' },
          },
          buffers = {
            theme = 'dropdown',
          },
          oldfiles = {
            theme = 'dropdown',
          },
        },
      }
      -- monkeypatch for jdtls
      local utils = require 'telescope.utils'
      local orig_is_uri = utils.is_uri
      utils.is_uri = function(filename)
        if filename:match '^jdt://' then
          return false
        end
        return orig_is_uri(filename)
      end
      pcall(require('telescope').load_extension, 'fzf')
      -- NOTE: it is better done by fzf.vim plugin
      vim.keymap.set('n', '<leader>O', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
      vim.keymap.set('n', '<leader>o', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>p', require('telescope.builtin').find_files, { desc = 'Search [G]it [F]iles' })
      vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', require('telescope.builtin').grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })
    end,
  },
}
