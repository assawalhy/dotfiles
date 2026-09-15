return {
  {
    'lewis6991/gitsigns.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    opts = {
      signs = {
        add = { text = '┃' },
        change = { text = '┃' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      signcolumn = true,
      on_attach = function(bufnr)
        local gitsigns = require('gitsigns')
        local map = function(mode, lhs, rhs, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, lhs, rhs, opts)
        end

        -- navigation
        map('n', ']c', function()
          if vim.wo.diff then return ']c' end
          vim.schedule(function() gitsigns.nav_hunk('next') end)
          return '<Ignore>'
        end, { expr = true, desc = 'Next hunk' })

        map('n', '[c', function()
          if vim.wo.diff then return '[c' end
          vim.schedule(function() gitsigns.nav_hunk('prev') end)
          return '<Ignore>'
        end, { expr = true, desc = 'Previous hunk' })

        -- actions
        map('n', '<leader>gs', gitsigns.stage_hunk, { desc = 'Git: stage hunk' })
        map('v', '<leader>gs', function() gitsigns.stage_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
          { desc = 'Git: stage selection' })
        map('n', '<leader>gr', gitsigns.reset_hunk, { desc = 'Git: reset hunk' })
        map('v', '<leader>gr', function() gitsigns.reset_hunk { vim.fn.line('.'), vim.fn.line('v') } end,
          { desc = 'Git: reset selection' })
        map('n', '<leader>gS', gitsigns.stage_buffer, { desc = 'Git: stage buffer' })
        map('n', '<leader>gR', gitsigns.reset_buffer, { desc = 'Git: reset buffer' })
        map('n', '<leader>gU', gitsigns.undo_stage_hunk, { desc = 'Git: undo stage hunk' })
        map('n', '<leader>gp', gitsigns.preview_hunk, { desc = 'Git: preview hunk' })
        map('n', '<leader>glu', gitsigns.preview_hunk_inline, { desc = 'Git: preview hunk inline' })

        -- blame
        map('n', '<leader>gb', function() gitsigns.blame_line { full = true } end, { desc = 'Git: blame line' })
        map('n', '<leader>gg', gitsigns.toggle_current_line_blame, { desc = 'Git: toggle current line blame' })

        -- diff / quickfix
        map('n', '<leader>gf', gitsigns.diffthis, { desc = 'Git: diff against HEAD' })
        map('n', '<leader>gq', gitsigns.setqflist, { desc = 'Git: hunks quickfix list' })
        map('n', '<leader>gx', gitsigns.toggle_word_diff, { desc = 'Git: toggle word diff' })

        -- telescope file history
        map('n', '<leader>gt', require('telescope.builtin').git_bcommits, { desc = 'Git: file commit history' })

        -- text object
        map({ 'o', 'x' }, 'ih', gitsigns.select_hunk, { desc = 'Git: select hunk' })
      end,
    },
  },

  {
    'rashedInt32/lazydiff.nvim',
    cmd = {
      'Lazydiff',
      'LazydiffOff',
      'LazydiffRefresh',
      'LazydiffNext',
      'LazydiffPrev',
      'LazydiffFirst',
      'LazydiffFloat',
      'LazydiffFloatOff',
    },
    keys = {
      { '<leader>dd', '<cmd>Lazydiff<cr>', desc = 'Git: toggle inline diff' },
      { '<leader>dD', '<cmd>LazydiffFloat<cr>', desc = 'Git: inline diff (all files)' },
      { ']h', '<cmd>LazydiffNext<cr>', desc = 'Git: next diff hunk' },
      { '[h', '<cmd>LazydiffPrev<cr>', desc = 'Git: previous diff hunk' },
    },
    config = function()
      require('lazydiff').setup()
    end,
  },

  {
    'kdheepak/lazygit.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = {
      'LazyGit',
      'LazyGitConfig',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    keys = {
      { '<leader>gL', '<cmd>LazyGit<cr>',                  desc = 'Git: lazygit (project)' },
      { '<leader>gH', '<cmd>LazyGitFilterCurrentFile<cr>', desc = 'Git: file history' },
    },
    config = function()
      vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
    end,
  },
}
