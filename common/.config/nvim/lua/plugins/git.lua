return {
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
}