-- skip backwards compatibility routines and speed up loading
vim.g.skip_ts_context_commentstring_module = true

-- Rainbow delimiters configuration (replaces nvim-ts-rainbow2)
local rainbow_colors = {
  'RainbowDelimiterViolet',
  'RainbowDelimiterCyan',
  'RainbowDelimiterYellow',
  'RainbowDelimiterRed',
  'RainbowDelimiterBlue',
  'RainbowDelimiterOrange',
  'RainbowDelimiterGreen',
}

vim.g.rainbow_delimiters = {
  strategy = {
    [''] = 'rainbow-delimiters.strategy.global',
  },
  query = {
    [''] = 'rainbow-delimiters',
  },
  highlight = rainbow_colors,
}

local rainbow_hl = {
  { RainbowDelimiterRed = '#e06c75' },
  { RainbowDelimiterOrange = '#d19a66' },
  { RainbowDelimiterYellow = '#e5c07b' },
  { RainbowDelimiterGreen = '#98c379' },
  { RainbowDelimiterCyan = '#56b6c2' },
  { RainbowDelimiterBlue = '#61afef' },
  { RainbowDelimiterViolet = '#c678dd' },
}

for _, hl in ipairs(rainbow_hl) do
  for name, fg in pairs(hl) do
    vim.api.nvim_set_hl(0, name, { fg = fg })
  end
end

return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-textobjects',
        branch = 'main',
      },
      'windwp/nvim-ts-autotag',

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

      -- Parsers compile lazily: the first buffer of a whitelisted language
      -- kicks off a background install instead of compiling everything at
      -- startup.
      local wanted = {
        c = true,
        cpp = true,
        go = true,
        lua = true,
        python = true,
        rust = true,
        tsx = true,
        typescript = true,
        vim = true,
        vimdoc = true,
        http = true,
        json = true,
        xml = true,
        html = true,
        latex = true,
        markdown = true,
      }

      -- parsers a language needs alongside its own
      local companions = {
        markdown = { 'markdown_inline' },
      }

      local installing = {}

      -- returns true when the parser is ready; otherwise starts the install
      -- and polls until it compiles, then replays FileType on the buffer so
      -- highlighting and indentexpr pick it up (~90s budget)
      local function ensure_parser(lang, bufnr)
        if pcall(vim.treesitter.language.add, lang) then return true end

        if not installing[lang] then
          installing[lang] = true

          local langs = { lang }
          vim.list_extend(langs, companions[lang] or {})
          require('nvim-treesitter').install(langs)
        end

        local function poll(attempt)
          if attempt > 45 then return end
          if not pcall(vim.treesitter.language.add, lang) then
            vim.defer_fn(function() poll(attempt + 1) end, 2000)
            return
          end

          installing[lang] = nil
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_exec_autocmds('FileType', { buffer = bufnr })
          end
        end

        vim.defer_fn(function() poll(1) end, 1000)
        return false
      end

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          -- Oversized files stay plain (see config/autocmds.lua).
          if vim.b[args.buf].large_file then return end

          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          if not wanted[lang] then return end

          if not ensure_parser(lang, args.buf) then return end

          -- Syntax highlighting (:h treesitter-highlight).
          -- Regex highlighting is disabled to mirror the old
          -- `additional_vim_regex_highlighting = false`.
          if pcall(vim.treesitter.start) then
            vim.bo.syntax = ''
          end

          -- Treesitter-based indentation (experimental, from nvim-treesitter docs)
          if pcall(vim.treesitter.get_parser) then
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

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



      local function textobj(query)
        require('nvim-treesitter-textobjects.select').select_textobject(query, 'textobjects')
      end

      -- select
      vim.keymap.set({ 'x', 'o' }, 'aa', function() textobj '@parameter.outer' end, { desc = 'Select outer parameter' })
      vim.keymap.set({ 'x', 'o' }, 'ia', function() textobj '@parameter.inner' end, { desc = 'Select inner parameter' })
      vim.keymap.set({ 'x', 'o' }, 'af', function() textobj '@function.outer' end, { desc = 'Select outer function' })
      vim.keymap.set({ 'x', 'o' }, 'if', function() textobj '@function.inner' end, { desc = 'Select inner function' })
      vim.keymap.set({ 'x', 'o' }, 'ac', function() textobj '@class.outer' end, { desc = 'Select outer class' })
      vim.keymap.set({ 'x', 'o' }, 'ic', function() textobj '@class.inner' end, { desc = 'Select inner class' })

      -- move
      local move = require('nvim-treesitter-textobjects.move')
      vim.keymap.set({ 'n', 'x', 'o' }, ']m', function() move.goto_next_start('@function.outer', 'textobjects') end, { desc = 'Next function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']]', function() move.goto_next_start('@class.outer', 'textobjects') end, { desc = 'Next class start' })
      vim.keymap.set({ 'n', 'x', 'o' }, ']M', function() move.goto_next_end('@function.outer', 'textobjects') end, { desc = 'Next function end' })
      vim.keymap.set({ 'n', 'x', 'o' }, '][', function() move.goto_next_end('@class.outer', 'textobjects') end, { desc = 'Next class end' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[m', function() move.goto_previous_start('@function.outer', 'textobjects') end, { desc = 'Previous function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[[', function() move.goto_previous_start('@class.outer', 'textobjects') end, { desc = 'Previous class start' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[M', function() move.goto_previous_end('@function.outer', 'textobjects') end, { desc = 'Previous function end' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[]', function() move.goto_previous_end('@class.outer', 'textobjects') end, { desc = 'Previous class end' })

      -- swap
      local swap = require('nvim-treesitter-textobjects.swap')
      vim.keymap.set('n', ';aa', function() swap.swap_next '@parameter.inner' end, { desc = 'Swap parameter with next' })
      vim.keymap.set('n', ';A', function() swap.swap_previous '@parameter.inner' end, { desc = 'Swap parameter with previous' })

      require('ts_context_commentstring').setup {
        enable_autocmd = false,
      }

      -- Folding
      -- NOTE: 'kevinhwang91/nvim-ufo' now handles it
    end,
  },

  { 'HiPhish/rainbow-delimiters.nvim' },

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
