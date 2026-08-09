-- skip backwards compatibility routines and speed up loading
vim.g.skip_ts_context_commentstring_module = true

return {
  {
    'nvim-treesitter/nvim-treesitter',
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
      'windwp/nvim-ts-autotag',
      -- 'HiPhish/nvim-ts-rainbow2',
      {
        'JoosepAlviste/nvim-ts-context-commentstring',
        opts = { enable_autocmd = false, }
      }
    },
    build = ':TSUpdate',
    config = function()
      require 'nvim-treesitter.configs'.setup {
        ensure_installed = {
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
        },
        auto_install = false,
        autotag = {
          enable = true,
          enable_rename = true,
          enable_close_on_slash = false,
        },
        indent = { enable = true, },
        highlight = {
          enable = true,

          -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
          -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
          -- Using this option may slow down your editor, and you may see some duplicate highlights.
          -- Instead of true it can also be a list of languages
          additional_vim_regex_highlighting = false,
        },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = '<c-space>',
            node_incremental = '<c-space>',
            scope_incremental = '<c-s>',
            node_decremental = '<c-s-space>',
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
            keymaps = {
              -- You can use the capture groups defined in textobjects.scm
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
              [']m'] = '@function.outer',
              [']]'] = '@class.outer',
            },
            goto_next_end = {
              [']M'] = '@function.outer',
              [']['] = '@class.outer',
            },
            goto_previous_start = {
              ['[m'] = '@function.outer',
              ['[['] = '@class.outer',
            },
            goto_previous_end = {
              ['[M'] = '@function.outer',
              ['[]'] = '@class.outer',
            },
          },
          swap = {
            enable = true,
            swap_next = {
              [';aa'] = '@parameter.inner',
            },
            swap_previous = {
              [';A'] = '@parameter.inner',
            },
          },
        },
      }

      require('ts_context_commentstring').setup {
        enable_autocmd = false,
      }

      -- Folding
      -- NOTE: 'kevinhwang91/nvim-ufo' now handles it
      -- vim.o.foldmethod = "expr"
      -- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
      -- vim.o.foldenable = false
    end
  },

  {
    'Wansmer/treesj',
    opts = { use_default_keymaps = false },
    keys = {
      { ';s', function() require('treesj').split() end,  desc = 'TreeSJ - Split' },
      { ';j', function() require('treesj').join() end,   desc = 'TreeSJ - Join' },
      { ';m', function() require('treesj').toggle() end, desc = 'TreeSJ - Toggle' },
      {
        ';M',
        function()
          require('treesj').toggle({ split = { recursive = true } })
        end,
        desc = 'TreeSJ - Toggle recursively'
      },
    },
  },
}
