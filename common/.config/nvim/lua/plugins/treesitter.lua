-- skip backwards compatibility routines and speed up loading
vim.g.skip_ts_context_commentstring_module = true

return {
  {
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
      'windwp/nvim-ts-autotag',
      'HiPhish/nvim-ts-rainbow2',
      {
        'JoosepAlviste/nvim-ts-context-commentstring',
        opts = { enable_autocmd = false },
      },
    },
    build = ':TSUpdate',
    config = function()
      require 'nvim-treesitter'.setup {
        install_dir = vim.fn.stdpath 'data' .. '/site',
      }

      -- Syntax highlighting (:h treesitter-highlight).
      -- Regex highlighting is disabled to mirror the old
      -- `additional_vim_regex_highlighting = false`.
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          if pcall(vim.treesitter.start) then
            vim.bo.syntax = ''
          end
        end,
      })

      -- Treesitter-based indentation (experimental, from nvim-treesitter docs)
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          if pcall(vim.treesitter.get_parser) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Auto-install parsers (replaces the old `ensure_installed`)
      require 'nvim-treesitter'.install {
        'c',
        'cpp',
        'go',
        'lua',
        'python',
        'rust',
        'tsx',
        'typescript',
        'vimdoc',
        'vim',
      }

      -- Autotag
      require('nvim-ts-autotag').setup {
        opts = {
          enable_rename = true,
          enable_close_on_slash = false,
        },
      }

      -- Textobjects
      require('nvim-treesitter-textobjects').setup {
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      }

      require('nvim-ts-rainbow2').setup {
        enable = true,
        extended_mode = true,
        max_file_lines = 1000,
      }

      local function textobj(query)
        require('nvim-treesitter-textobjects.select').select_textobject(query, 'textobjects')
      end

      -- select
      vim.keymap.set({ 'x', 'o' }, 'aa', function() textobj '@parameter.outer' end)
      vim.keymap.set({ 'x', 'o' }, 'ia', function() textobj '@parameter.inner' end)
      vim.keymap.set({ 'x', 'o' }, 'af', function() textobj '@function.outer' end)
      vim.keymap.set({ 'x', 'o' }, 'if', function() textobj '@function.inner' end)
      vim.keymap.set({ 'x', 'o' }, 'ac', function() textobj '@class.outer' end)
      vim.keymap.set({ 'x', 'o' }, 'ic', function() textobj '@class.inner' end)

      -- move
      local move = require('nvim-treesitter-textobjects.move')
      vim.keymap.set({ 'n', 'x', 'o' }, ']m', function() move.goto_next_start('@function.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, ']]', function() move.goto_next_start('@class.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, ']M', function() move.goto_next_end('@function.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, '][', function() move.goto_next_end('@class.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, '[m', function() move.goto_previous_start('@function.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, '[[', function() move.goto_previous_start('@class.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, '[M', function() move.goto_previous_end('@function.outer', 'textobjects') end)
      vim.keymap.set({ 'n', 'x', 'o' }, '[]', function() move.goto_previous_end('@class.outer', 'textobjects') end)

      -- swap
      local swap = require('nvim-treesitter-textobjects.swap')
      vim.keymap.set('n', ';aa', function() swap.swap_next '@parameter.inner' end)
      vim.keymap.set('n', ';A', function() swap.swap_previous '@parameter.inner' end)

      require('ts_context_commentstring').setup {
        enable_autocmd = false,
      }

      -- Folding
      -- NOTE: 'kevinhwang91/nvim-ufo' now handles it
    end,
  },

  {
    'Wansmer/treesj',
    opts = { use_default_keymaps = false },
    keys = {
      {
        ';s',
        function()
          require('treesj').split()
        end,
        desc = 'TreeSJ - Split',
      },
      {
        ';j',
        function()
          require('treesj').join()
        end,
        desc = 'TreeSJ - Join',
      },
      {
        ';m',
        function()
          require('treesj').toggle()
        end,
        desc = 'TreeSJ - Toggle',
      },
      {
        ';M',
        function()
          require('treesj').toggle { split = { recursive = true } }
        end,
        desc = 'TreeSJ - Toggle recursively',
      },
    },
  },
}
