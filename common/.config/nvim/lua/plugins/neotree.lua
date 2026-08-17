return {
  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>e', ':Neotree toggle<cr>', desc = 'NeoTree' },
    },
    opts = {
      reveal = true,
      commands = {
        copy_selector = function(state)
          local node = state.tree:get_node()
          local filepath = node:get_id()
          local filename = node.name
          local modify = vim.fn.fnamemodify

          local vals = {
            ['BASENAME'] = modify(filename, ':r'),
            ['EXTENSION'] = modify(filename, ':e'),
            ['FILENAME'] = filename,
            ['PATH (CWD)'] = modify(filepath, ':.'),
            ['PATH (HOME)'] = modify(filepath, ':~'),
            ['PATH'] = filepath,
            ['URI'] = vim.uri_from_fname(filepath),
          }

          local options = vim.tbl_filter(function(val)
            return vals[val] ~= ''
          end, vim.tbl_keys(vals))
          if vim.tbl_isempty(options) then
            vim.notify('No values to copy', vim.log.levels.WARN)
            return
          end
          table.sort(options)
          vim.ui.select(options, {
            prompt = 'Choose to copy to clipboard:',
            format_item = function(item)
              return ('%s: %s'):format(item, vals[item])
            end,
          }, function(choice)
            local result = vals[choice]
            if result then
              vim.notify(('Copied: `%s`'):format(result))
              vim.fn.setreg('+', result)
            end
          end)
        end,
      },
      window = {
        width = 25,
        mappings = {
          Y = 'copy_selector',
        },
      },
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          hide_dotfiles = false,   -- show .config & all dotfiles by default
          hide_gitignored = false, -- show gitignored, auto-dimmed by NeoTreeGitIgnored
          hide_ignored = false,    -- show .ignore/.neotreeignore files, dimmed
          hide_by_name = {         -- hidden by default, appears when H toggled
            '.git',
            '.DS_Store',
            'thumbs.db',
          },
        },
      },
      source_selector = {
        winbar = true,
        statusline = true,
      },
    },
  },
}
