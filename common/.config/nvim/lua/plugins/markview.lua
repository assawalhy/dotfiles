-- Markdown previewer. Needs the markdown + markdown_inline parsers, which
-- treesitter.lua compiles on demand when the first .md buffer opens.
return {
  {
    'OXY2DEV/markview.nvim',
    ft = 'markdown',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {},
  },
}
