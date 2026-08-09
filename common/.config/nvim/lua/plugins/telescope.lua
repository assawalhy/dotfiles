return {
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
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
      require('telescope').setup({
        defaults = {
          winblend = 10,
          prompt_prefix = "🔍 ",
        },
        pickers = {
          find_files = {
            theme = "dropdown",
          },
          buffers = {
            theme = "dropdown",
          },
          oldfiles = {
            theme = "dropdown",
          },
        },
      })
      pcall(require('telescope').load_extension, 'fzf')
      -- NOTE: it is better done by fzf.vim plugin
      vim.keymap.set('n', '<leader>O', require('telescope.builtin').oldfiles, { desc = '[?] Find recently opened files' })
      vim.keymap.set('n', '<leader>o', require('telescope.builtin').buffers, { desc = '[ ] Find existing buffers' })
      vim.keymap.set('n', '<leader>p', require('telescope.builtin').find_files, { desc = 'Search [G]it [F]iles' })
      vim.keymap.set('n', '<leader>sh', require('telescope.builtin').help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', require('telescope.builtin').grep_string,
        { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', require('telescope.builtin').live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', require('telescope.builtin').diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to telescope to change theme, layout, etc.
        require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })
    end
  },

  -- {
  --   'junegunn/fzf.vim',
  --   dependencies = {
  --     'junegunn/fzf',
  --     build = function() vim.fn['fzf#install']() end,
  --   },
  --   keys = {
  --     { '<leader>p', ":Files<CR>",   desc = "[fzf.vim] Files fzf finder" },
  --     { '<leader>o', ":Buffers<CR>", desc = "[fzf.vim] Opened buffers fzf finder" },
  --     { '<leader>O', ":History<CR>", desc = "[fzf.vim] v:oldfiles and open buffers" },
  --   }
  -- },

}
